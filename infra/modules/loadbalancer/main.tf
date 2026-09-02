resource "aws_lb" "this" {
  name                       = "${var.project_name}-alb${var.name_suffix_physical}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  tags = {
    Name = "${var.project_name}-alb${var.name_suffix_tag}"
  }
}

resource "aws_lb_target_group" "this" {
  name                 = "${var.project_name}-tg${var.name_suffix_physical}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    path                = "/health"
    matcher             = "200"

  }
  tags = {
    Name = "${var.project_name}-tg${var.name_suffix_tag}"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  dynamic "default_action" {
    for_each = var.acm_certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }

  }
  dynamic "default_action" {
    for_each = var.acm_certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }

    }

  }
  tags = {
    Name = "${var.project_name}-http-listener${var.name_suffix_tag}"
  }
}

resource "aws_lb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
  tags = {
    Name = "${var.project_name}-https-listener${var.name_suffix_tag}"
  }
}

resource "aws_route53_record" "app" {
  count   = var.create_route53_record ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.fqdn
  type    = "A"
  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
