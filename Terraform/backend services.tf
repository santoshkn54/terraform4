resource "aws_db_subnet_group" "vprofile-subgrp" {
  name       = "main"
  subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1], module.vpc.private_subnets[2]]
  tags = {
    Name = "subnet group for RDS"
  }

}
resource "aws_elasticache_subnet_group" "vprofile-ecache-subgrp" {
  name       = "vprofile-ecache-subgrp"
  subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1], module.vpc.private_subnets[2]]

}
resource "aws_db_instance" "vprofile-rds" {
  instance_class         = "db.m5.large"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7.44"
  db_name                = var.dbname
  username               = var.dbuser
  password               = var.dbpass
  parameter_group_name   = "default.mysql5.6"
  multi_az               = "false"
  publicly_accessible    = "false"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.vprofile-subgrp.name
  vpc_security_group_ids = [aws_security_group.vprofile-backend-sg.id]

}
resource "aws_elasticache_cluster" "vprofile-cache" {

  cluster_id           = "vprofile-cache"
  engine               = "memcached"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.memcached1.6"
  port                 = 11211
  security_group_ids   = [aws_security_group.vprofile-backend-sg.id]
  subnet_group_name    = aws_elasticache_subnet_group.vprofile-ecache-subgrp.name

}
resource "aws_mq_broker" "vprofile-rmq" {
  broker_name        = "vprofile-rmq"
  engine_type        = "ActiveMQ"
  engine_version     = "5.18"
  host_instance_type = "mq.t2.micro"
  security_groups    = [aws_security_group.vprofile-backend-sg.id]
  subnet_ids         = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  deployment_mode    = "SINGLE_INSTANCE"
  auto_minor_version_upgrade = true

  user {

    username = var.rmquser
    password = var.rmqpass
  }


}
resource "aws_launch_template" "launchtemplate" {
  name          = "example-launch-template"
  image_id      = "ami-00eb69d236edcfaf8" # Replace with your AMI ID
  instance_type = "t3.small"

  # Optional: Other settings like security groups, IAM roles, etc.
  key_name = aws_key_pair.vprofilekey.key_name
}

# Define your Auto Scaling Group using Launch Template
resource "aws_autoscaling_group" "autoscalinglaunchtemplate" {
  desired_capacity    = 2
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = [module.vpc.public_subnets[0], module.vpc.public_subnets[1], module.vpc.public_subnets[2]] # Replace with your subnets
  launch_template {
    id      = aws_launch_template.launchtemplate.id
    version = "$Latest"
  }

  # Optional: Other settings like load balancer, health checks, etc.
}


