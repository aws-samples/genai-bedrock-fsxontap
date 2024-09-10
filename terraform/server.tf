
resource "aws_iam_instance_profile" "embedding_profile" {
  name = "embedding_profile"
  role = aws_iam_role.ec2_embedding_role.name
}


resource "aws_iam_role" "ec2_embedding_role" {
  name = "EC2-${var.aws_region}-EmbeddingRole"

  assume_role_policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
)
}


resource "aws_iam_role_policy_attachment" "ssm_policy_1" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
    role       = aws_iam_role.ec2_embedding_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy_2" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role       = aws_iam_role.ec2_embedding_role.name
}

resource "aws_iam_role_policy" "ec2_embedding_policy" {
  name        = "EC2-${var.aws_region}-EmbeddingPolicy"
  role        = aws_iam_role.ec2_embedding_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "aoss:APIAccessAll",
          "aoss:CreateAccessPolicy",
          "aoss:CreateSecurityPolicy",
          "aoss:CreateCollection"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:collection/${aws_opensearchserverless_collection.fsxnragvector.id}",
        "Sid": "aoss"
      },
      {
        "Sid": "bedrock",
        "Effect": "Allow",
        "Action": [
          "bedrock:GetFoundationModel",
          "bedrock:InvokeModel"
        ],
        "Resource": ["arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"]
      },
      {
        "Sid": "ecr",
        "Effect": "Allow",
        "Action": [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ],
        "Resource": ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${aws_ecr_repository.fsxnragembed.name}",
                     "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${aws_ecr_repository.fsxnragvector.name}",
                     "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${aws_ecr_repository.fsxnragchat.name}"]  
      },
      {
        "Sid": "sts",
        "Effect": "Allow",
        "Action": [
            "aoss:ListCollections",
            "aoss:BatchGetCollection",
            "ecr:GetAuthorizationToken",
            "sts:GetCallerIdentity"
            ],
        "Resource": ["*"]
      }
    ]
    })
}

data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "embedding_host" {
  ami           = data.aws_ami.linux.id
  instance_type = "m5.2xlarge"
  key_name      = aws_key_pair.server_key.key_name
  subnet_id     = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.fsx_sg.id]
  iam_instance_profile = aws_iam_instance_profile.embedding_profile.name

  metadata_options {
    http_tokens = "required"
    http_put_response_hop_limit = 2
    http_endpoint = "enabled"
  }
  
  tags = {
    Project = "bedrockfsxn"
    Name   = "embedding_host"
  }

  user_data = <<-EOF
    #!/bin/sh
    set -ex
    sudo yum update -y &&
    sudo yum install -y cifs-utils &&
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    sudo mkdir /tmp/data
    sudo mkdir /tmp/db
    sudo mount -t cifs //${tostring(tolist(aws_fsx_ontap_storage_virtual_machine.bedrocksvm.endpoints[0].smb[0].ip_addresses)[0])}/c$/${aws_fsx_ontap_volume.bedrockrag.name} /tmp/data -o user=admin,password="${random_string.fsx_password.result}",domain=bedrock-01.com,iocharset=utf8,mapchars,mfsymlinks
    sudo mount -t nfs ${aws_fsx_ontap_volume.ragdb.storage_virtual_machine_id}.${aws_fsx_ontap_volume.ragdb.file_system_id}.fsx.${var.aws_region}.amazonaws.com:${aws_fsx_ontap_volume.ragdb.junction_path} /tmp/db
    sudo aws ecr get-login-password --region ${var.aws_region} | sudo docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
    sudo docker run -d -v /tmp/data:/opt/netapp/ai/data -v /tmp/db:/opt/netapp/ai/db -e ENV_REGION='${var.aws_region}' -e ENV_OPEN_SEARCH_SERVERLESS_COLLECTION_NAME='${aws_opensearchserverless_collection.fsxnragvector.name}' ${aws_ecr_repository.fsxnragembed.repository_url}:latest 
    sudo docker run -d -p 8501:8501 -e CHAT_URL='${aws_api_gateway_stage.stage.invoke_url}/${aws_api_gateway_resource.root.path_part}' ${aws_ecr_repository.fsxnragchat.repository_url}:latest
  EOF
}