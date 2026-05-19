resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = var.cross_zone_enabled

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_lb_target_group" "http" {
  name     = "${var.name}-http"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled  = true
    protocol = "TCP"
    port     = 80
  }

  tags = merge(var.tags, {
    Name = "${var.name}-http-tg"
  })
}

resource "aws_lb_target_group" "https" {
  name     = "${var.name}-https"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled  = true
    protocol = "TCP"
    port     = 443
  }

  tags = merge(var.tags, {
    Name = "${var.name}-https-tg"
  })
}

resource "aws_lb_target_group_attachment" "http" {
  count            = length(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = var.target_instance_ids[count.index]
  port             = 80
}

resource "aws_lb_target_group_attachment" "https" {
  count            = length(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.https.arn
  target_id        = var.target_instance_ids[count.index]
  port             = 443
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}