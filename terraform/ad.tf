resource "aws_directory_service_directory" "bedrockad" {
  name     = "bedrock-01.com"
  password = random_string.fsx_password.result
  edition  = "Standard"
  type     = "MicrosoftAD"
  short_name = "BEDROCK-01"

  vpc_settings {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnets
  }
  

  tags = {
    Project = "bedrockfsxn"
  }
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

resource "aws_iam_instance_profile" "ad_profile" {
  name = "ad_profile"
  role = aws_iam_role.ec2_ad_role.name
}


resource "aws_iam_role" "ec2_ad_role" {
  name = "EC2-${var.aws_region}-ADRole"

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


resource "aws_iam_role_policy_attachment" "ssm_ad_policy_1" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
    role       = aws_iam_role.ec2_ad_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_ad_policy_2" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role       = aws_iam_role.ec2_ad_role.name
}

resource "aws_instance" "ad_host" {
  ami           = data.aws_ami.windows.id
  instance_type = "t2.medium"
  key_name      = aws_key_pair.server_key.key_name
  subnet_id     = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.fsx_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ad_profile.name

  metadata_options {
    http_tokens = "required"
  }
  
  tags = {
    Project = "bedrockfsxn"
    Name   = "ad_host"
  }
}


resource "aws_ssm_association" "ad_host" {
  name = "AWS-JoinDirectoryServiceDomain"

  parameters = {
    directoryId = aws_directory_service_directory.bedrockad.id
    directoryName = "bedrock-01.com"
    dnsIpAddresses = tostring(tolist(aws_directory_service_directory.bedrockad.dns_ip_addresses)[0])
    directoryOU = "OU=Computers,OU=bedrock-01,DC=bedrock-01,DC=com"
  }

  targets {
    key    = "InstanceIds"
    values = [aws_instance.ad_host.id]
  }
}


