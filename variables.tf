#variable "target_security_groups" {
#  description = "Security groups to add "
#  type = map(object({
#    id   = string,
#    port = string
#  }))
#}

variable "ami_id" {
  description = "Id of ami to use, else it default to whatever AWS provides under filter: amzn2-ami-hvm-* "
  default     = "ami-0b8c6b923777519db"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "vpn_udp_port" {
  type    = number
  default = 4092
}

variable "vpn_wg_port" {
  type    = number
  default = 51822
}

variable "vpc_cidr" {
  default = ""
}

variable "vpc_id" {
  default = ""
}
