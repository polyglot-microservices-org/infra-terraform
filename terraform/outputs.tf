output "instance_id" {
  description = "The ID of the created EC2 instance"
  value       = aws_instance.demo.id
}

output "public_ip" {
  description = "The public IP of the instance"
  value       = aws_instance.demo.public_ip
}
