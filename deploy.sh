#!/bin/bash

# ==========================================
# MASTERTEXTO - VPS DEPLOY SCRIPT
# ==========================================
set -e

# --- Default Config ---
# You can change this to your repo if you want it fixed
DEFAULT_REPO="https://github.com/bicuda/MasterTexto.git" 
APP_DIR="/var/www/mastertexto"

echo "=========================================="
echo "    MASTERTEXTO - CONFIGURAÇÃO DO SERVIDOR"
echo "=========================================="

# 1. Ask for Repo URL (or use default)
read -p "🔹 URL do Git (Enter para '$DEFAULT_REPO'): " REPO_URL
REPO_URL=${REPO_URL:-$DEFAULT_REPO}

# 2. Ask for Ports
read -p "🔹 Porta do SITE (Frontend) [ex: 8090]: " FRONT_PORT
FRONT_PORT=${FRONT_PORT:-8090}

read -p "🔹 Porta da API (Backend) [ex: 3010]: " BACK_PORT
BACK_PORT=${BACK_PORT:-3010}

read -p "🔹 Domínio ou IP do Servidor: " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-_}

echo "----------------------------------------"
echo "⏳ Instalando Node.js, Nginx e ferramentas..."
sudo apt update -y
sudo apt install -y curl git nginx unzip

# Install Node 20
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Install PM2
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
fi

echo "📂 Preparando pasta do projeto..."
# Move existing folder to backup if exists
if [ -d "$APP_DIR" ]; then
    echo "   Backup da versão anterior..."
    sudo mv "$APP_DIR" "$APP_DIR.bak.$(date +%s)"
fi

sudo mkdir -p "$APP_DIR"
sudo chown -R $USER:$USER "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"

echo "⚙️ Configurando Backend..."
cd "$APP_DIR/backend"
npm install
# Generate Prisma Client
npx prisma generate
# Create .env
echo "PORT=$BACK_PORT" > .env
echo "DATABASE_URL=\"file:./dev.db\"" >> .env
npx prisma db push

# Start/Restart Backend with PM2
pm2 stop mastertexto-api 2>/dev/null || true
pm2 delete mastertexto-api 2>/dev/null || true
pm2 start src/server.ts --interpreter ./node_modules/.bin/ts-node --name "mastertexto-api" --env PORT=$BACK_PORT
pm2 save

echo "🎨 Configurando Frontend..."
cd "$APP_DIR/frontend"
npm install
npm run build

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
