#!/bin/bash

set -e

echo "======================================"
echo " APROVISIONANDO LB"
echo "======================================"

export DEBIAN_FRONTEND=noninteractive

# ----------------------------------
# 1. Actualizar Ubuntu
# ----------------------------------
apt-get update -y

# ----------------------------------
# 2. Instalar HAProxy y utilidades
# ----------------------------------
apt-get install -y \
    haproxy \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates

echo "HAProxy:"
haproxy -v

# ----------------------------------
# 3. Agregar repositorio HashiCorp
# ----------------------------------
rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg

wget -O- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list

apt-get update -y

# ----------------------------------
# 4. Instalar Consul y consul-template
# ----------------------------------
apt-get install -y consul consul-template

echo "Consul:"
consul version

echo "Consul Template:"
consul-template -version

# ----------------------------------
# 5. Configurar Consul como CLIENTE
# ----------------------------------
mkdir -p /etc/consul.d
mkdir -p /opt/consul

cat > /etc/consul.d/consul.hcl <<'EOF'
datacenter = "dc1"

data_dir = "/opt/consul"

node_name = "lb"

server = false

bind_addr = "192.168.56.13"

advertise_addr = "192.168.56.13"

client_addr = "0.0.0.0"

retry_join = ["192.168.56.11"]
EOF

chown -R consul:consul /etc/consul.d
chown -R consul:consul /opt/consul

# ----------------------------------
# 6. Corregir Type=notify
# ----------------------------------
mkdir -p /etc/systemd/system/consul.service.d

cat > /etc/systemd/system/consul.service.d/override.conf <<'EOF'
[Service]
Type=simple
EOF

systemctl daemon-reload

systemctl enable consul
systemctl restart consul

# ----------------------------------
# 7. Esperar a que Consul responda
# ----------------------------------
echo "Esperando conexion con Consul..."

for i in {1..30}; do

    if curl -s http://127.0.0.1:8500/v1/status/leader | grep -q "192.168.56.11"; then
        echo "Consul conectado correctamente."
        break
    fi

    sleep 2

done

# ----------------------------------
# 8. Crear pagina 503 personalizada
# ----------------------------------
mkdir -p /etc/haproxy/errors

cat > /etc/haproxy/errors/503.http <<'EOF'
HTTP/1.0 503 Service Unavailable
Cache-Control: no-cache
Connection: close
Content-Type: text/html; charset=UTF-8

<!DOCTYPE html>
<html lang="es">

<head>
    <meta charset="UTF-8">
    <title>Servicio no disponible</title>
</head>

<body>

    <h1>Servicio temporalmente no disponible</h1>

    <p>
        En este momento no hay servidores web disponibles.
    </p>

    <p>
        Por favor, intente nuevamente en unos minutos.
    </p>

</body>

</html>
EOF

# ----------------------------------
# 9. Crear plantilla HAProxy
# ----------------------------------
mkdir -p /etc/consul-template

cat > /etc/consul-template/haproxy.ctmpl <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon
    maxconn 2048

defaults
    log global
    mode http
    option httplog
    option dontlognull

    timeout connect 5s
    timeout client 30s
    timeout server 30s

    errorfile 503 /etc/haproxy/errors/503.http

frontend http_front
    bind *:80
    default_backend web_back

backend web_back
    balance roundrobin

    option httpchk GET /health
    http-check expect status 200

{{ range service "web" }}
    server {{ .ID }} {{ .Address }}:{{ .Port }} check
{{ end }}

listen stats
    bind *:1936

    stats enable
    stats uri /
    stats refresh 5s
EOF

# ----------------------------------
# 10. Esperar servicios WEB
# ----------------------------------
echo "Esperando servicios web registrados en Consul..."

for i in {1..30}; do

    SERVICIOS=$(curl -s \
        http://127.0.0.1:8500/v1/health/service/web?passing=true)

    if echo "$SERVICIOS" | grep -q "web1-3000"; then
        echo "Servicios web encontrados."
        break
    fi

    sleep 2

done

# ----------------------------------
# 11. Generar configuracion HAProxy
# ----------------------------------
consul-template -once \
    -template="/etc/consul-template/haproxy.ctmpl:/etc/haproxy/haproxy.cfg"

# ----------------------------------
# 12. Validar configuracion HAProxy
# ----------------------------------
haproxy -c -f /etc/haproxy/haproxy.cfg

# ----------------------------------
# 13. Iniciar HAProxy
# ----------------------------------
systemctl enable haproxy
systemctl restart haproxy

echo "======================================"
echo " LB APROVISIONADO CORRECTAMENTE"
echo "======================================"

echo "IP Balanceador:"
echo "192.168.56.13"

echo ""
echo "Aplicacion:"
echo "http://192.168.56.13"

echo ""
echo "Estadisticas HAProxy:"
echo "http://192.168.56.13:1936"

echo ""
echo "Consul:"
consul members

echo "======================================"