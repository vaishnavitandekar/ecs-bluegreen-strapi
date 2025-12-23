resource "aws_ecr_repository" "this" {
  name = "vaishnavi-ecs-strapii"
}

resource "aws_ecs_cluster" "this" {
  name = "strapi-cluster-vaishnavii"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "strapi-cluster-vaishnavii"
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = "strapi"
  cpu                      = 512
  memory                   = 1024
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "vaishnavi-strapii"
      essential = true
      image     = "${aws_ecr_repository.this.repository_url}:latest"

      portMappings = [{
        containerPort = 1337
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "HOST", value = "0.0.0.0" },
        { name = "PORT", value = "1337" },

        { name = "DATABASE_CLIENT", value = "postgres" },
        { name = "DATABASE_HOST", value = aws_db_instance.postgres.address },
        { name = "DATABASE_PORT", value = "5432" },
        { name = "DATABASE_NAME", value = "strapi" },
        { name = "DATABASE_USERNAME", value = "strapi" },
        { name = "DATABASE_PASSWORD", value = var.db_password },

        { name = "DATABASE_SSL", value = "true" },
        { name = "DATABASE_SSL_REJECT_UNAUTHORIZED", value = "false" },

        { name = "APP_KEYS", value = var.app_keys },
        { name = "API_TOKEN_SALT", value = var.api_token_salt },
        { name = "TRANSFER_TOKEN_SALT", value = var.transfer_token_salt },
        { name = "ENCRYPTION_KEY", value = var.encryption_key },
        { name = "ADMIN_JWT_SECRET", value = var.admin_jwt_secret },
        { name = "JWT_SECRET", value = var.jwt_secret },

        { name = "DEPLOY_VERSION", value = var.deploy_version }
      ]
    }
  ])

  depends_on = [
    aws_cloudwatch_log_group.ecs,
    aws_db_instance.postgres
  ]
}

resource "aws_ecs_service" "service" {
  name            = "strapi-service-vaishnavii"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 2

  launch_type      = "FARGATE"
  platform_version = "LATEST"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "vaishnavi-strapii"
    container_port   = 1337
  }

  network_configuration {
    subnets          = slice(data.aws_subnets.public.ids, 0, 2)
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.blue,
    aws_lb_target_group.green
  ]
}

resource "aws_codedeploy_app" "ecs" {
  name             = "vaishnavi-strapii-codedeploy-app"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "ecs" {
  app_name              = aws_codedeploy_app.ecs.name
  deployment_group_name = "vaishnavi-strapii-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.this.name
    service_name = aws_ecs_service.service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/strapi-vaishnavi"
  retention_in_days = 7

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [name]
  }
}

resource "aws_sns_topic" "ecs_alerts" {
  name = "vaishnavi-strapi-ecs-alerts"
}

resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "vaishnavi-strapi-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80

  metric_name = "CPUUtilization"
  namespace   = "AWS/ECS"
  statistic   = "Average"
  period      = 60

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.service.name
  }

  alarm_actions = [aws_sns_topic.ecs_alerts.arn]
  ok_actions    = [aws_sns_topic.ecs_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  alarm_name          = "vaishnavi-strapi-high-memory"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80

  metric_name = "MemoryUtilization"
  namespace   = "AWS/ECS"
  statistic   = "Average"
  period      = 60

  evaluation_periods  = 3
  datapoints_to_alarm = 2

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.service.name
  }

  alarm_actions = [aws_sns_topic.ecs_alerts.arn]
  ok_actions    = [aws_sns_topic.ecs_alerts.arn]
}

resource "aws_cloudwatch_dashboard" "ecs_dashboard" {
  dashboard_name = "vaishnavi-strapii-ecs-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 24
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Strapi ECS Service CPU & Memory"

          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.service.name, "ClusterName", aws_ecs_cluster.this.name],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", aws_ecs_service.service.name, "ClusterName", aws_ecs_cluster.this.name]
          ]

          period = 60
          stat   = "Average"
        }
      }
    ]
  })
}
