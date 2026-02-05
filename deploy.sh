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
FRONT_PORT="80"
BACK_PORT="3010"
# Usando sslip.io para ter um domínio válido para HTTPS
SERVER_NAME="mastertexto.207.180.246.127.sslip.io"

echo "=========================================="
echo "    MASTERTEXTO - DEPLOY AUTOMÁTICO (HTTPS)"
echo "=========================================="
echo "🔹 Repo: $REPO_URL"
echo "🔹 Site: http://$SERVER_NAME"
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

cat <<EOF | sudo tee "$NGINX_CONF"
server {
    listen $FRONT_PORT;
    server_name $SERVER_NAME;

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

# Enable Site
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Restart Nginx to apply config before Certbot
sudo nginx -t
sudo systemctl restart nginx

echo "🔒 Configurando HTTPS com Certbot..."
# Non-interactive, agree to TOS, no email, redirect HTTP to HTTPS
sudo certbot --nginx -d $SERVER_NAME --non-interactive --agree-tos --email admin@$SERVER_NAME --redirect

echo "=========================================="
echo "✅ DEPLOY FINALIZADO!"
echo "📍 Site: https://$SERVER_NAME"
echo "=========================================="
