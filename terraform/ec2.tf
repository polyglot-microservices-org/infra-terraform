resource "aws_instance" "demo" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = "mittanv" 

user_data = templatefile("${path.module}/../scripts/bootstrap.sh", {
    runner_token = var.runner_token
  })

  tags = {
    Name = "mitta-polyglot"
  }
}
