resource "aws_instance" "demo" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = "mittanv"

  # Run bootstrap script on EC2 with runner token and GH_PAT
  user_data = templatefile("${path.module}/../scripts/bootstrap.sh", {
    runner_token = var.runner_token
    GH_PAT       = var.gh_pat
  })

  tags = {
    Name = "mitta-polyglot-org"
  }
}

