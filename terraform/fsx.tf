
resource "random_string" "fsx_password" {
  length           = 8
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  numeric           = true
  special          = true
  override_special = "!"
}

resource "aws_security_group" "fsx_sg" {
  name_prefix = "security group for fsx access"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "fsx_sg"
  }
}

resource "aws_security_group_rule" "fsx_sg_inbound" {
  description       = "allow inbound traffic to fsx"
  from_port         = 0
  protocol          = "-1"
  to_port           = 0
  security_group_id = aws_security_group.fsx_sg.id
  type              = "ingress"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "fsx_sg_outbound" {
  description       = "allow outbound traffic to anywhere"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.fsx_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_fsx_ontap_file_system" "bedrockfs" {
  storage_capacity    = 2048
  deployment_type     = "MULTI_AZ_1"
  throughput_capacity = 512
  
  subnet_ids          = module.vpc.private_subnets
  preferred_subnet_id = module.vpc.private_subnets[0]
  security_group_ids  = [aws_security_group.fsx_sg.id]
  route_table_ids    = module.vpc.private_route_table_ids
  
  fsx_admin_password = random_string.fsx_password.result

  tags = {
    Name = var.fsxname
  }
}

resource "aws_fsx_ontap_storage_virtual_machine" "bedrocksvm" {
  file_system_id = aws_fsx_ontap_file_system.bedrockfs.id
  name           = "brsvm"
  svm_admin_password = random_string.fsx_password.result
  
  active_directory_configuration {
    netbios_name = "BRSVM"

    self_managed_active_directory_configuration {
      dns_ips     = aws_directory_service_directory.bedrockad.dns_ip_addresses
      domain_name = "BEDROCK-01.COM"
      password    = random_string.fsx_password.result
      username    = "Admin"
      file_system_administrators_group = "AWS Delegated Administrators"
      organizational_unit_distinguished_name = "OU=Computers,OU=bedrock-01,DC=bedrock-01,DC=com"
    }
  }
}

resource "aws_fsx_ontap_volume" "bedrockrag" {
  name                       = "bedrockrag"
  junction_path              = "/bedrockrag"
  size_in_megabytes          = 1024
  storage_efficiency_enabled = true
  security_style = "MIXED"
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.bedrocksvm.id
}

resource "aws_fsx_ontap_volume" "ragdb" {
  name                       = "ragdb"
  junction_path              = "/ragdb"
  size_in_megabytes          = 1024
  storage_efficiency_enabled = true
  security_style = "UNIX"
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.bedrocksvm.id
}

resource "aws_secretsmanager_secret" "fsxn_password_secret" {
  name = "AmazonBedrock-FSx-NetAPP-ONTAP-${random_string.suffix.result}"
  description = "FSxN CSI Driver Password"
}

resource "aws_secretsmanager_secret_version" "fsxn_password_secret" {
    secret_id     = aws_secretsmanager_secret.fsxn_password_secret.id
    secret_string = jsonencode({
    username = "admin@bedrock-01.com"
    password = "${random_string.fsx_password.result}"
  })
}