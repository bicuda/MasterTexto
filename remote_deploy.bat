@echo off
echo ==========================================
echo      MasterTexto - Remote Deploy
echo ==========================================
echo.
echo Este script vai:
echo 1. Enviar o arquivo 'deploy.sh' para o seu VPS.
echo 2. Conectar via SSH e rodar o instalador.
echo.

set VPS_USER=root
set VPS_IP=207.180.246.127

echo.
echo [Config] Usuario: %VPS_USER% | IP: %VPS_IP%

echo.
echo [1/2] Enviando script para o servidor...
scp deploy.sh %VPS_USER%@%VPS_IP%:~/deploy.sh

if %errorlevel% neq 0 (
    echo.
    echo ❌ Erro ao enviar arquivo. Verifique a senha ou IP.
    pause
    exit /b
)

echo.
echo [2/2] Conectando e rodando instalador...
echo (Voce pode precisar digitar a senha novamente para o 'sudo')
echo.

ssh -t %VPS_USER%@%VPS_IP% "chmod +x ~/deploy.sh && bash ~/deploy.sh"

echo.
echo Pressione qualquer tecla para sair...
pause
