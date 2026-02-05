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

# Preserve Database (and journal files) if exists
DB_BACKUP_DIR="/tmp/mastertexto_db_backup"
rm -rf "$DB_BACKUP_DIR"
mkdir -p "$DB_BACKUP_DIR"

if [ -f "$APP_DIR/backend/prisma/dev.db" ]; then
    echo "   💾 Salvando banco de dados (e arquivos temporários)..."
    cp "$APP_DIR/backend/prisma/dev.db"* "$DB_BACKUP_DIR/" 2>/dev/null || true
fi

# Move existing folder to backup if exists
if [ -d "$APP_DIR" ]; then
    echo "   Backup da versão anterior..."
    sudo mv "$APP_DIR" "$APP_DIR.bak.$(date +%s)"
fi

sudo mkdir -p "$APP_DIR"
sudo chown -R $USER:$USER "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"

# Restore Database
if [ -f "$DB_BACKUP_DIR/dev.db" ]; then
    echo "   💾 Restaurando banco de dados..."
    mkdir -p "$APP_DIR/backend/prisma"
    cp "$DB_BACKUP_DIR/dev.db"* "$APP_DIR/backend/prisma/"
    # Ensure permissions for all db files
    chmod 777 "$APP_DIR/backend/prisma/"
    chmod 666 "$APP_DIR/backend/prisma/dev.db"* 2>/dev/null || true
fi

echo "⚙️ Configurando Backend..."
cd "$APP_DIR/backend"
npm install
# Generate Prisma Client
npx prisma generate
# Create .env
echo "PORT=$BACK_PORT" > .env
# Ensure the prisma directory exists and has permissions
mkdir -p "$APP_DIR/backend/prisma"
# Recursive 777 to allow journal file creation/deletion
chmod -R 777 "$APP_DIR/backend/prisma"

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
# sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Restart Nginx
sudo nginx -t
sudo systemctl restart nginx

echo "=========================================="
echo "✅ DEPLOY FINALIZADO!"
echo "📍 Site: http://$SERVER_NAME:$FRONT_PORT"
echo "=========================================="
echo "📝 Exibindo logs do servidor (Ctrl+C para sair)..."
pm2 logs mastertexto-api --lines 20
