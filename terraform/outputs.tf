output "ec2_public_ip" {
  value       = aws_instance.devsecops_host.public_ip
  description = "The public IP address of your EC2 instance."
}
