resource "tls_private_key" "server_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "server_key" {
  key_name   = "server_key"
  public_key = tls_private_key.server_key.public_key_openssh
}

resource "local_sensitive_file" "server_key" {
  content = tls_private_key.server_key.private_key_pem
  filename           = "server_key.pem"
}