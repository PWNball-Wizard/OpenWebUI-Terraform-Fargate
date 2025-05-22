
resource "aws_ecs_cluster" "openwebui" {
  name = "openwebui-cluster"
}

resource "aws_security_group" "openwebui_sg" {
  name        = "openwebui-sg"
  description = "Allow HTTP traffic"
  vpc_id      = var.vpc_id

  # Permitir tráfico HTTP (para el ALB)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir tráfico interno al contenedor (puerto 8080 del container)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #Anterior en app.tfvars
    #"930142908117.dkr.ecr.us-east-1.amazonaws.com/open-webui:latest",
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_ecs_task_definition" "openwebui_task" {
  family                   = "openwebui-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  #execution_role_arn       = "arn:aws:iam::930142908117:role/fargateTaskExecutionRole"
  execution_role_arn = "arn:aws:iam::713881831402:role/fargateTaskExecutionRole"

  container_definitions = jsonencode([{
    name      = "openwebui"
    image     = var.image_url
    essential = true
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
  }])
}

resource "aws_lb" "openwebui_alb" {
  name               = "openwebui-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.openwebui_sg.id]
}

resource "aws_lb_target_group" "openwebui_tg" {
  name        = "openwebui-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path                = "/"
    port                = "8080"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.openwebui_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openwebui_tg.arn
  }
}

resource "aws_ecs_service" "openwebui_service" {
  name            = "openwebui-service"
  cluster         = aws_ecs_cluster.openwebui.id
  task_definition = aws_ecs_task_definition.openwebui_task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.openwebui_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.openwebui_tg.arn
    container_name   = "openwebui"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
}
