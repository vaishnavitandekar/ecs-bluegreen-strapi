data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "public_a" {
  filter {
    name   = "tag:Name"
    values = ["public-a"]
  }
}

data "aws_subnet" "public_b" {
  filter {
    name   = "tag:Name"
    values = ["public-b"]
  }
}
