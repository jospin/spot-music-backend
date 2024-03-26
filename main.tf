terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.27"
      }
  }
  required_version = ">= 0.14.9"
}

# Configure a provider
provider "aws" {
  region = "us-east-1"
}

# Crie o grupo de acesso de administrador
resource "aws_iam_group" "administrators" {
  name = "administrators"
}

# Crie o grupo de acesso de usuários comuns
resource "aws_iam_group" "users" {
  name = "users"
}

# Política para administradores
data "aws_iam_policy_document" "administrator_policy" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

# Associe a política de administrador ao grupo de administradores
resource "aws_iam_group_policy_attachment" "administrator_attachment" {
  group      = aws_iam_group.administrators.name
  policy_arn = aws_iam_policy.administrator_policy.arn
}

# Política para usuários comuns
data "aws_iam_policy_document" "user_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::bucket-0/*",
      "arn:aws:s3:::bucket-1/*",
    ]
  }
}

# Associe a política de usuário comum ao grupo de usuários
resource "aws_iam_group_policy_attachment" "user_attachment" {
  group      = aws_iam_group.users.name
  policy_arn = aws_iam_policy.user_policy.arn
}

# 8 VPCs com 1 serviço em cada
resource "aws_vpc" "vpcs" {
  count             = 8
  cidr_block        = "10.${count.index}.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${count.index}"
  }
}

# sub-redes públicas e privadas em cada VPC
resource "aws_subnet" "public_subnets" {
  count                   = 8
  vpc_id                  = aws_vpc.vpcs[count.index].id
  cidr_block              = "10.${count.index}.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private_subnets" {
  count                   = 8
  vpc_id                  = aws_vpc.vpcs[count.index].id
  cidr_block              = "10.${count.index}.1.0/24"

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# tabela de roteamento e associe com as sub-redes públicas
resource "aws_route_table" "public_route_table" {
  count       = 8
  vpc_id      = aws_vpc.vpcs[count.index].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway[count.index].id
  }
}

resource "aws_route_table_association" "public_route_associations" {
  count          = 8
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table[count.index].id
}

# tabela de roteamento e associe com as sub-redes privadas
resource "aws_route_table" "private_route_table" {
  count       = 8
  vpc_id      = aws_vpc.vpcs[count.index].id
}

resource "aws_route_table_association" "private_route_associations" {
  count          = 8
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table[count.index].id
}

# 2 gateways
resource "aws_internet_gateway" "gateway" {
  count = 2
  vpc_id = aws_vpc.vpcs[count.index].id
}


# 2 zonas DNS
resource "aws_route53_zone" "dns_zones" {
  count = 2
  name  = "example${count.index}.com"
}

# 2 clusters Kubernetes usando EKS
resource "aws_eks_cluster" "kubernetes_clusters" {
  count = 2
  name  = "cluster-${count.index}"
  vpc_config {
    subnet_ids = [aws_subnet.private_subnets[count.index].id]
  }
}

#  5 brokers Kafka usando MSK
resource "aws_msk_cluster" "kafka_clusters" {
  count                    = 5
  cluster_name             = "kafka-cluster-${count.index}"
  kafka_version            = "2.8.0"
  number_of_broker_nodes   = 3
  broker_node_group_info {
    instance_type          = "kafka.m5.large"
    client_subnets         = [aws_vpc.vpcs[0].cidr_block]
  }
}

# 4 bancos de dados usando RDS
resource "aws_db_instance" "databases" {
  count             = 4
  instance_class    = "db.t3.micro"
  engine            = "mysql" # ou qualquer outro banco suportado
  engine_version    = "8.0"
  allocated_storage = 20
  storage_type      = "gp2"
  multi_az          = false
  subnet_group_name = aws_db_subnet_group.default.name
}

# 2 buckets S3
resource "aws_s3_bucket" "buckets" {
  count = 2
  bucket = "bucket-${count.index}"
  acl    = "private"
}

# 2 instâncias do Redis usando ElastiCache
resource "aws_elasticache_cluster" "redis_clusters" {
  count             = 2
  engine            = "redis"
  engine_version    = "6.x"
  node_type         = "cache.t2.micro"
  num_cache_nodes   = 1
  parameter_group_name = "default.redis6.x"
}

# Configure as regras de segurança dos grupos de instâncias
resource "aws_security_group" "admin_group" {
  name_prefix        = "admin-sg-"
  vpc_id             = aws_vpc.vpcs[0].id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "user_group" {
  name_prefix        = "user-sg-"
  vpc_id             = aws_vpc.vpcs[0].id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# Associe as instâncias ao grupo de segurança correto
resource "aws_instance" "example" {
  count         = 2
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnets[0].id

  security_groups = [count.index == 0 ? aws_security_group.admin_group.name : aws_security_group.user_group.name]
}
