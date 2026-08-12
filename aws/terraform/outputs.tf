output "instance_id" {
  value = aws_instance.recovery.id
}

output "elastic_ip" {
  value = aws_eip.recovery.public_ip
}

output "ssm_port_forward_command" {
  value = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.recovery.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"${var.reverse_port}\"],\"localPortNumber\":[\"22011\"]}'"
}

