#!/bin/bash
set -euxo pipefail

dnf install -y python3-pip
pip3 install flask gunicorn psycopg2-binary

mkdir -p /opt/app
echo '${app_py_b64}' | base64 -d > /opt/app/app.py
echo '${index_b64}' | base64 -d > /opt/app/index.html

# DB settings (readable by root only)
install -m 600 /dev/null /etc/app.env
cat > /etc/app.env <<'ENVEOF'
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
ENVEOF

cat > /etc/systemd/system/app.service <<'UNITEOF'
[Unit]
Description=Flask demo app
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=/etc/app.env
WorkingDirectory=/opt/app
ExecStart=/usr/local/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNITEOF

systemctl daemon-reload
systemctl enable --now app
