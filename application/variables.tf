
variable "vpc_id" {}
variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "cpu" {
  default = 1024
}
variable "memory" {
  default = 2048
}
variable "desired_count" {
  default = 1
}
variable "image_url" {
  default = "xuyangbo/open-webui:v0.3.7"
}
variable "container_port" {
  default = 8080
}
