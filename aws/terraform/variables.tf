variable "aws_region" {
  type    = string
  default = "ap-east-1"
}

variable "name" {
  type    = string
  default = "friend-nas-recovery"
}

variable "instance_type" {
  type    = string
  default = "t3.nano"
}

variable "vpc_cidr" {
  type    = string
  default = "10.203.0.0/24"
}

variable "subnet_cidr" {
  type    = string
  default = "10.203.0.0/28"
}

variable "ssh_port" {
  type    = number
  default = 22
}

variable "reverse_port" {
  type    = number
  default = 22010
}

variable "nas_source_cidrs" {
  description = "Public source ranges allowed to establish the restricted NAS tunnel"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "recovery_tunnel_public_key" {
  description = "Public key used only by the NAS reverse-forward client"
  type        = string
  validation {
    condition     = startswith(var.recovery_tunnel_public_key, "ssh-ed25519 ")
    error_message = "Expected an Ed25519 OpenSSH public key."
  }
}

