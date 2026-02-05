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
SERVER_NAME="207.180.246.127"

echo "=========================================="
echo "    MASTERTEXTO - DEPLOY AUTOMÁTICO"
echo "=========================================="
echo "🔹 Repo: $REPO_URL"
echo "🔹 Site: http://$SERVER_NAME:$FRONT_PORT"
echo "🔹 API:  Porta $BACK_PORT"
echo "----------------------------------------"

echo "----------------------------------------"
echo "⏳ Instalando Node.js, Nginx e ferramentas..."
sudo apt update -y
sudo apt install -y curl git nginx unzip

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

# Restart Nginx
sudo nginx -t
sudo systemctl restart nginx

echo "=========================================="
echo "✅ DEPLOY FINALIZADO!"
echo "📍 Site: http://$SERVER_NAME:$FRONT_PORT"
echo "=========================================="
