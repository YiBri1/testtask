provider "aws" {
  region = "eu-central-1"
  access_key = "AKIAY7AH6XNX7LWMA35O"
  secret_key = "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"
}


data "aws_availability_zones" "available" {}
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

#--------------------------------------------------------------
resource "aws_security_group" "web" {
  name = "Dynamic Security Group"

  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_launch_configuration" "web" {
  name    = "web"
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web.id]
  user_data       = file("my_data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                 = "web"
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 1
  max_size             = 1
  min_elb_capacity     = 1
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id]
  load_balancers       = [aws_elb.web.name]

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_elb" "web" {
  name               = "WebServer-HA-ELB"
  availability_zones = [data.aws_availability_zones.available.names[0]]
  security_groups    = [aws_security_group.web.id]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }
}


#--------------------------------------------------
output "web_loadbalancer_url" {
  value = aws_elb.web.dns_name
