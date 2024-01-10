############
# Database #
############

resource "aws_db_subnet_group" "main" {
  name = "${local.prefix}-main"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "${local.prefix}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  description = "Allow access to the RDS database instance."
  name        = "${local.prefix}-rds-inbound-access"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol  = "tcp"
    from_port = 5432
    to_port   = 5432

    security_groups = [
      aws_security_group.ecs_service.id
    ]
  }

  tags = {
    Name = "${local.prefix}-db-security-group"
  }
}

resource "aws_db_instance" "main" {
  identifier                 = "${local.prefix}-db"
  db_name                    = "recipe"
  allocated_storage          = 20
  storage_type               = "gp2"
  engine                     = "postgres"
  engine_version             = "15.3"
  auto_minor_version_upgrade = true
  instance_class             = "db.t4g.micro"
  username                   = var.db_username
  password                   = var.db_password
  skip_final_snapshot        = true
  db_subnet_group_name       = aws_db_subnet_group.main.name
  multi_az                   = false
  backup_retention_period    = 0
  vpc_security_group_ids     = [aws_security_group.rds.id]

  tags = {
    Name = "${local.prefix}-main"
  }
}

resource "aws_security_group" "ecs_service" {
  description = "Access rules for the ECS service."
  name        = "${local.prefix}-ecs-service"
  vpc_id      = aws_vpc.main.id

  # Outbound access to endpoints
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RDS connectivity
  egress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    cidr_blocks = [
      aws_subnet.private_a.cidr_block,
      aws_subnet.private_b.cidr_block,
    ]
  }

  # HTTP inbound access
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "api" {
  name                   = "${local.prefix}-api"
  cluster                = aws_ecs_cluster.main.name
  task_definition        = aws_ecs_task_definition.api.family
  desired_count          = 1
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = true

  network_configuration {
    assign_public_ip = true

    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]

    security_groups = [aws_security_group.ecs_service.id]
  }
}
