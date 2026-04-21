output "ec2_instance_id" {
  description = "AWS instance ID — needed when configuring Azure Migrate discovery."
  value       = aws_instance.source_vm.id
}

output "ec2_public_ip" {
  description = "Public IP of the source EC2 instance — use this to connect via RDP."
  value       = aws_instance.source_vm.public_ip
}

output "ec2_private_ip" {
  description = "Private IP of the source EC2 instance."
  value       = aws_instance.source_vm.private_ip
}

output "aws_region" {
  value = var.aws_region
}
