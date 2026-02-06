@echo off
echo ==========================================
echo   MASTERTEXTO - STATUS DO SERVIDOR
echo ==========================================
echo.
echo Verificando Nginx e API...
echo.
ssh root@207.180.246.127 "echo '--- NGINX STATUS ---'; sudo systemctl status nginx --no-pager; echo ''; echo '--- BACKEND STATUS ---'; pm2 status mastertexto-api"
pause
