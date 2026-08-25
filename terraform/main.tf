resource "aws_instance" "web" {
  # checkov:skip=CKV_AWS_88:Public EC2 is the HTTP demo endpoint; SSH remains closed.
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  monitoring                  = true
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-web"
  }

  depends_on = [aws_iam_role_policy_attachment.ssm_core]
}
