#!/bin/bash

set -e

echo "======================================"
echo " APROVISIONANDO WEB1"
echo "======================================"

export DEBIAN_FRONTEND=noninteractive

# -----------------------------
# 1. Actualizar Ubuntu
# -----------------------------
apt-get update -y

# -----------------------------
# 2. Instalar Node.js y utilidades
# -----------------------------
apt-get install -y \
    nodejs \
    npm \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    unzip

echo "Node:"
node --version

echo "NPM:"
npm --version

# -----------------------------
# 3. Instalar Consul
# -----------------------------
rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg

wget -O- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list

apt-get update -y
apt-get install -y consul

echo "Consul:"
consul version

# -----------------------------
# 4. Configurar Consul server
# -----------------------------
mkdir -p /etc/consul.d
mkdir -p /opt/consul

cat > /etc/consul.d/consul.hcl <<'EOF'
datacenter = "dc1"

data_dir = "/opt/consul"

node_name = "web1"

server = true

bootstrap_expect = 1

bind_addr = "192.168.56.11"

advertise_addr = "192.168.56.11"

client_addr = "0.0.0.0"

ui_config {
  enabled = true
}
EOF

chown -R consul:consul /etc/consul.d
chown -R consul:consul /opt/consul

# -----------------------------
# 5. Corregir Type=notify
# -----------------------------
mkdir -p /etc/systemd/system/consul.service.d

cat > /etc/systemd/system/consul.service.d/override.conf <<'EOF'
[Service]
Type=simple
EOF

systemctl daemon-reload

# -----------------------------
# 6. Copiar aplicación NodeJS
# -----------------------------
mkdir -p /opt/microproyecto

cp /vagrant/app/server.js /opt/microproyecto/server.js

# -----------------------------
# 7. Servicio NodeJS puerto 3000
# -----------------------------
cat > /etc/systemd/system/microapp.service <<'EOF'
[Unit]
Description=Servidor NodeJS Microproyecto
After=network.target

[Service]
Type=simple
Environment=PORT=3000
ExecStart=/usr/bin/node /opt/microproyecto/server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# -----------------------------
# 8. Replica NodeJS puerto 3001
# -----------------------------
cat > /etc/systemd/system/microapp3001.service <<'EOF'
[Unit]
Description=Servidor NodeJS Microproyecto Replica 3001
After=network.target

[Service]
Type=simple
Environment=PORT=3001
ExecStart=/usr/bin/node /opt/microproyecto/server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# -----------------------------
# 9. Registrar servicio 3000
# -----------------------------
cat > /etc/consul.d/web.json <<'EOF'
{
  "service": {
    "id": "web1-3000",
    "name": "web",
    "address": "192.168.56.11",
    "port": 3000,
    "check": {
      "http": "http://192.168.56.11:3000/health",
      "interval": "5s",
      "timeout": "2s"
    }
  }
}
EOF

# -----------------------------
# 10. Registrar replica 3001
# -----------------------------
cat > /etc/consul.d/web3001.json <<'EOF'
{
  "service": {
    "id": "web1-3001",
    "name": "web",
    "address": "192.168.56.11",
    "port": 3001,
    "check": {
      "http": "http://192.168.56.11:3001/health",
      "interval": "5s",
      "timeout": "2s"
    }
  }
}
EOF

chown -R consul:consul /etc/consul.d

# -----------------------------
# 11. Validar Consul
# -----------------------------
consul validate /etc/consul.d

# -----------------------------
# 12. Iniciar servicios
# -----------------------------
systemctl daemon-reload

systemctl enable consul
systemctl restart consul

systemctl enable microapp
systemctl restart microapp

systemctl enable microapp3001
systemctl restart microapp3001

echo "======================================"
echo " WEB1 APROVISIONADA CORRECTAMENTE"
echo " IP: 192.168.56.11"
echo " NodeJS: 3000 y 3001"
echo " Consul: SERVER"
echo "======================================"