# RDS Subnet Group
resource "aws_db_subnet_group" "tohid_db_subnet_group" {
  name       = "tohid-task11-db-subnet-group"
  subnet_ids = ["subnet-0c0bb5df2571165a9", "subnet-0cc2ddb32492bcc41", "subnet-0f768008c6324831f"]

  tags = {
    Name = "tohid-task11-db-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "tohid_rds" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "11.22-rds.20240418"
  instance_class         = "db.t3.micro"
  db_name                = "strapidb"
  username               = "tohid"
  password               = "tohid123"
  db_subnet_group_name   = aws_db_subnet_group.tohid_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.ecs_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name = "tohid-task11-rds-instance"
  }
}