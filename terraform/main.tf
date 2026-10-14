data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  public_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  app_cidrs    = ["10.0.11.0/24", "10.0.12.0/24"]
  db_cidrs     = ["10.0.21.0/24", "10.0.22.0/24"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.app_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project_name}-app-private-${count.index + 1}"
    Tier = "application"
  }
}

resource "aws_subnet" "db" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.db_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project_name}-db-private-${count.index + 1}"
    Tier = "database"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags = {
    Name = "${var.project_name}-nat"
  }
}

resource "aws_route_table" "app_private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}-app-private-rt"
  }
}

resource "aws_route_table_association" "app_private" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app_private.id
}

resource "aws_route_table" "db_private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-db-private-rt"
  }
}

resource "aws_route_table_association" "db_private" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db_private.id
}

# Security group for the public Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow public HTTP traffic to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Security group for application EC2 instances
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow HTTP only from the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# Security group for the MySQL database
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow MySQL only from application instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from application tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "aws-devops-assignment-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }
  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target group for application EC2 instances
resource "aws_lb_target_group" "app" {
  name     = "aws-devops-assignment-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# HTTP listener forwards requests to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ALB DNS name
output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}


# Find the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template for application EC2 instances
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = "ami-099e8d197bd6d3538"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.app_ec2.name
  }

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -eux
    dnf install -y nginx
    systemctl enable --now nginx
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html>
      <head><title>AWS DevOps Assignment</title></head>
      <body>
        <h1>AWS DevOps Assignment</h1>
        <p>Nginx test page is running successfully.</p>
        <p>Served from an EC2 instance in a private subnet.</p>
      </body>
    </html>
    HTML
  USERDATA
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-app"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group across two private application subnets
resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-asg"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = aws_subnet.app[*].id
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}
# RDS subnet group
resource "aws_db_subnet_group" "mysql" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS MySQL database
resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  engine_version = "8.4.11"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 30
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "appdb"
  username = "appadmin"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period = 1
  multi_az                = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-alb-logs-323708468873-ap-south-1"
  force_destroy = false

  tags = {
    Name    = "${var.project_name}-alb-logs"
    Purpose = "ALB access logs"
  }
}

# Block public access to the log bucket
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt log files at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Allow ELB to write access logs
data "aws_elb_service_account" "main" {}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"

        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }

        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid    = "AllowALBLogDeliveryAclCheck"
        Effect = "Allow"

        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }

        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.alb_logs
  ]
}

# S3 bucket for application storage
resource "aws_s3_bucket" "app_storage" {
  bucket        = "${var.project_name}-app-storage-323708468873-ap-south-1"
  force_destroy = false

  tags = {
    Name    = "${var.project_name}-app-storage"
    Purpose = "Application storage"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt stored application files
resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable object versioning
resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for EC2 application instances
resource "aws_iam_role" "app_ec2" {
  name = "${var.project_name}-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-app-ec2-role"
  }
}

# Allow access only to the application storage bucket
resource "aws_iam_role_policy" "app_s3_access" {
  name = "${var.project_name}-app-s3-access"
  role = aws_iam_role.app_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.app_storage.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.app_storage.arn}/*"
      }
    ]
  })
}

# Instance profile connects the IAM role to EC2
resource "aws_iam_instance_profile" "app_ec2" {
  name = "${var.project_name}-app-ec2-profile"
  role = aws_iam_role.app_ec2.name
}
