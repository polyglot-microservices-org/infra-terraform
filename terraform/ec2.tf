resource "aws_instance" "demo" {
  ami           = "ami-xxxxxxxx" # your AMI
  instance_type = "t3.medium"
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  user_data = base64encode(templatefile("${path.module}/../scripts/bootstrap.sh", {
    GH_PAT                = var.gh_pat
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    AWS_REGION            = var.aws_region
    setup_script          = file("${path.module}/../scripts/setup.sh")
    kubeadm_script        = file("${path.module}/../scripts/kubeadm.sh")
  }))
}
