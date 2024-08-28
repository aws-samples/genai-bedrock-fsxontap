resource "aws_lb_target_group_attachment" "chat_load_balancer_attachment" {
  target_group_arn = aws_lb_target_group.chat_load_balancer_target_group.arn
  target_id        = aws_instance.embedding_host.id
  port             = 8501
}


resource "aws_lb_target_group" "chat_load_balancer_target_group" {
  name     = "chat-load-balancer-target-group"
  port     = 8501
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = module.vpc.vpc_id
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

resource "aws_lb_listener" "chat_load_balancer_listener" {
  load_balancer_arn = aws_lb.chat_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "chat_load_balancer_listener2" {
  load_balancer_arn = aws_lb.chat_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb_acm_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_load_balancer_target_group.arn
  }
}

resource "aws_lb" "chat_load_balancer" {
  name               = "chat-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.chat_lb_sg.id]
  subnets            = module.vpc.public_subnets

}

resource "aws_security_group" "chat_lb_sg" {
  name_prefix = "security group for chat load balancer access"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "chat_lb_sg"
  }
}

resource "aws_security_group_rule" "chat_lb_sg_inbound" {
  description       = "allow inbound traffic to alb"
  from_port         = 80
  protocol          = "tcp"
  to_port           = 80
  security_group_id = aws_security_group.chat_lb_sg.id
  type              = "ingress"
  cidr_blocks       = ["${data.http.ip.response_body}/32"]
}

resource "aws_security_group_rule" "chat_lb_sg_inbound_443" {
  description       = "allow inbound traffic to alb"
  from_port         = 443
  protocol          = "tcp"
  to_port           = 443
  security_group_id = aws_security_group.chat_lb_sg.id
  type              = "ingress"
  cidr_blocks       = ["${data.http.ip.response_body}/32"]
}

resource "aws_security_group_rule" "chat_lb_sg_outbound" {
  description       = "allow outbound traffic to anywhere"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.chat_lb_sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}