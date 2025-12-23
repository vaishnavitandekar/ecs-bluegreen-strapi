data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "public_a" {
  vpc_id                  = data.aws_vpc.default.id
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

data "aws_subnet" "public_b" {
  vpc_id                  = data.aws_vpc.default.id
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}
