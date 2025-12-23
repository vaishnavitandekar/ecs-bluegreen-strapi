output "ecr_repo" {
  value = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "strapi_url" {
  value = "http://${aws_lb.strapi_alb.dns_name}"
}

output "public_subnet_ids" {
  value = data.aws_subnets.public.ids
}