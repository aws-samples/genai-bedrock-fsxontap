resource "tls_private_key" "alb_private_key" {
  algorithm   = "RSA"
  rsa_bits    = 2048
}


resource "tls_self_signed_cert" "alb_self_signed_cert" {
  private_key_pem = tls_private_key.alb_private_key.private_key_pem

  validity_period_hours = 87600

  subject {
    common_name         = "bedrock-01.com"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

}

resource "aws_acm_certificate" "alb_acm_cert" {
  private_key       = tls_private_key.alb_private_key.private_key_pem
  certificate_body  = tls_self_signed_cert.alb_self_signed_cert.cert_pem
}