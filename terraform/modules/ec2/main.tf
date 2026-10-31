data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_a_id
  vpc_security_group_ids      = [var.app_security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash

              dnf update -y
              dnf install -y python3

              mkdir -p /opt/app

              cat > /opt/app/app.py <<'PYTHON'
              from http.server import BaseHTTPRequestHandler, HTTPServer
              import socket

              class Handler(BaseHTTPRequestHandler):

                  def do_GET(self):
                      hostname = socket.gethostname()

                      response = f"""
                      <html>
                      <head>
                        <title>PostgreSQL Infrastructure</title>
                      </head>
                      <body>
                        <h1>PostgreSQL Infrastructure Demo</h1>
                        <p><b>Application Server:</b> {hostname}</p>
                        <p><b>Status:</b> Healthy</p>
                        <p><b>Tier:</b> Application Tier</p>
                      </body>
                      </html>
                      """

                      self.send_response(200)
                      self.send_header("Content-Type", "text/html")
                      self.end_headers()
                      self.wfile.write(response.encode())

              server = HTTPServer(("0.0.0.0", 8080), Handler)
              server.serve_forever()
              PYTHON

              cat > /etc/systemd/system/postgres-demo-app.service <<'SERVICE'
              [Unit]
              Description=PostgreSQL Demo Application
              After=network.target

              [Service]
              ExecStart=/usr/bin/python3 /opt/app/app.py
              Restart=always
              User=root

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable postgres-demo-app
              systemctl start postgres-demo-app
              EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-app-a"
    Tier = "application"
  }
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_b_id
  vpc_security_group_ids      = [var.app_security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash

              dnf update -y
              dnf install -y python3

              mkdir -p /opt/app

              cat > /opt/app/app.py <<'PYTHON'
              from http.server import BaseHTTPRequestHandler, HTTPServer
              import socket

              class Handler(BaseHTTPRequestHandler):

                  def do_GET(self):
                      hostname = socket.gethostname()

                      response = f"""
                      <html>
                      <head>
                        <title>PostgreSQL Infrastructure</title>
                      </head>
                      <body>
                        <h1>PostgreSQL Infrastructure Demo</h1>
                        <p><b>Application Server:</b> {hostname}</p>
                        <p><b>Status:</b> Healthy</p>
                        <p><b>Tier:</b> Application Tier</p>
                      </body>
                      </html>
                      """

                      self.send_response(200)
                      self.send_header("Content-Type", "text/html")
                      self.end_headers()
                      self.wfile.write(response.encode())

              server = HTTPServer(("0.0.0.0", 8080), Handler)
              server.serve_forever()
              PYTHON

              cat > /etc/systemd/system/postgres-demo-app.service <<'SERVICE'
              [Unit]
              Description=PostgreSQL Demo Application
              After=network.target

              [Service]
              ExecStart=/usr/bin/python3 /opt/app/app.py
              Restart=always
              User=root

              [Install]
              WantedBy=multi-user.target
              SERVICE

              systemctl daemon-reload
              systemctl enable postgres-demo-app
              systemctl start postgres-demo-app
              EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-app-b"
    Tier = "application"
  }
}

resource "aws_instance" "postgres_a" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_a_id
  vpc_security_group_ids      = [var.database_security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash

              dnf update -y
              dnf install -y postgresql15-server

              postgresql-setup --initdb

              systemctl enable postgresql
              systemctl start postgresql
              EOF

  tags = {
    Name = "${var.project_name}-postgres-a"
    Tier = "database"
  }
}

resource "aws_instance" "postgres_b" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_b_id
  vpc_security_group_ids      = [var.database_security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash

              dnf update -y
              dnf install -y postgresql15-server

              postgresql-setup --initdb

              systemctl enable postgresql
              systemctl start postgresql
              EOF

  tags = {
    Name = "${var.project_name}-postgres-b"
    Tier = "database"
  }
}