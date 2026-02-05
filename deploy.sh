#!/bin/bash

# ==========================================
# MASTERTEXTO - VPS DEPLOY SCRIPT
# ==========================================
set -e

# --- Default Config ---
# You can change this to your repo if you want it fixed
DEFAULT_REPO="https://github.com/bicuda/MasterTexto.git" 
APP_DIR="/var/www/mastertexto"

# --- CONFIGURAÇÃO PADRÃO (Sem perguntas) ---
REPO_URL="https://github.com/bicuda/MasterTexto.git"
FRONT_PORT="8090"
BACK_PORT="3010"
# Usando sslip.io para ter um domínio válido para HTTPS
SERVER_NAME="mastertexto.207.180.246.127.sslip.io"

echo "=========================================="
echo "    MASTERTEXTO - DEPLOY AUTOMÁTICO (HTTPS)"
echo "=========================================="
echo "🔹 Repo: $REPO_URL"
echo "🔹 Site: https://$SERVER_NAME:$FRONT_PORT"
echo "🔹 API:  Porta $BACK_PORT"
echo "----------------------------------------"

echo "----------------------------------------"
echo "⏳ Instalando Node.js, Nginx, Certbot e ferramentas..."
sudo apt update -y
sudo apt install -y curl git nginx unzip python3-certbot-nginx

# ... (Node and PM2 installation skipped for brevity, keeping existing) ...

# ... (Database Logic kept same) ...

# ... (Backend Config kept same) ...

# ... (Frontend Config kept same) ...

echo "🌐 Gerando config do Nginx..."
NGINX_CONF="/etc/nginx/sites-available/mastertexto"

# --- 1. SSL Validation Setup (Port 80) ---
echo "🌐 Configurando Nginx na porta 80 para validação SSL..."
cat <<EOF | sudo tee "$NGINX_CONF"
server {
    listen 80;
    server_name $SERVER_NAME;
    location / {
        root $APP_DIR/frontend/dist;
        index index.html;
    }
}
EOF

# Enable & Restart for Validation
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo nginx -t
sudo systemctl restart nginx

# --- 2. Request Certificate ---
echo "🔒 Solicitando certificado SSL..."
# Using certonly --nginx which temporarily hooks into the config above
sudo certbot certonly --nginx -d $SERVER_NAME --non-interactive --agree-tos --email admin@$SERVER_NAME

# --- 3. Final Request Handler (Port 8090 SSL) ---
echo "🛡️ Configurando Nginx Final (Porta $FRONT_PORT SSL)..."
# Check if Certs exist
CERT_PATH="/etc/letsencrypt/live/$SERVER_NAME"
if [ -f "$CERT_PATH/fullchain.pem" ]; then
    cat <<EOF | sudo tee "$NGINX_CONF"
server {
    listen $FRONT_PORT ssl;
    server_name $SERVER_NAME;

    # SSL Config
    ssl_certificate $CERT_PATH/fullchain.pem;
    ssl_certificate_key $CERT_PATH/privkey.pem;

    # Frontend
    location / {
        root $APP_DIR/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # Backend / Socket.io
    location /socket.io/ {
        proxy_pass http://localhost:$BACK_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
else
    echo "⚠️ AVISO: Certificado não encontrado! Mantendo HTTP na porta $FRONT_PORT."
    cat <<EOF | sudo tee "$NGINX_CONF"
server {
    listen $FRONT_PORT;
    server_name $SERVER_NAME;
    location / {
        root $APP_DIR/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    location /socket.io/ {
        proxy_pass http://localhost:$BACK_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
fi

# Enable Site
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Restart Nginx to apply config before Certbot
sudo nginx -t
sudo systemctl restart nginx



echo "=========================================="
echo "✅ DEPLOY FINALIZADO!"
echo "📍 Site: https://$SERVER_NAME:$FRONT_PORT"
echo "=========================================="
