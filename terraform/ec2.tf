resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "target" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>mTLS OK</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF

  tags = {
    Name = "${var.project_name}-target"
  }
}

resource "aws_lb_target_group_attachment" "target" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.target.id
  port             = 80
}
