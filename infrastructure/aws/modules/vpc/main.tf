variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

resource "aws_vpc" "kosa_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = var.environment
    Project     = "kosa"
  }
}

resource "aws_internet_gateway" "kosa_igw" {
  vpc_id = aws_vpc.kosa_vpc.id

  tags = {
    Name        = "${var.cluster_name}-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.kosa_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = "${var.aws_region}${element(["a", "b", "c"], count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.cluster_name}-public-${count.index}"
    Environment = var.environment
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.kosa_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = "${var.aws_region}${element(["a", "b", "c"], count.index)}"

  tags = {
    Name        = "${var.cluster_name}-private-${count.index}"
    Environment = var.environment
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "database" {
  count             = 3
  vpc_id            = aws_vpc.kosa_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = "${var.aws_region}${element(["a", "b", "c"], count.index)}"

  tags = {
    Name        = "${var.cluster_name}-database-${count.index}"
    Environment = var.environment
    "kubernetes.io/role/database" = 1
  }
}

resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"

  tags = {
    Name        = "${var.cluster_name}-nat-eip-${count.index}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "kosa_nat" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.cluster_name}-nat-${count.index}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.kosa_igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.kosa_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kosa_igw.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.kosa_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.kosa_nat[count.index].id
  }

  tags = {
    Name        = "${var.cluster_name}-private-rt-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

output "vpc_id" {
  value = aws_vpc.kosa_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  value = aws_subnet.database[*].id
}