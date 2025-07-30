resource "aws_db_subnet_group" "strapiapp_db_subnet_group" {
  name       = "strapiapp-task10-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "Strapi DB Subnet Group"
  }
}

resource "aws_db_instance" "tohid_rds" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "11.22-rds.20240418"
  instance_class         = "db.t3.micro"
  db_name                = "strapidb"
  username               = "tohid"
  password               = "tohid123"
  db_subnet_group_name   = aws_db_subnet_group.strapiapp_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.tohid_ecr_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name = "tohid Task10 RDS Instance"
  }
}