resource "aws_instance" "demo" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = "mittanv"

  user_data = base64encode(templatefile("${path.module}/../scripts/bootstrap.sh", {
    GH_PAT               = var.gh_pat
    AWS_ACCESS_KEY_ID    = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    AWS_REGION           = var.aws_region
    setup_script         = file("${path.module}/../scripts/setup.sh")
    kubeadm_script       = file("${path.module}/../scripts/kubeadm.sh")
  }))

  tags = {
    Name = "mitta-polyglot-org"
  }
}
