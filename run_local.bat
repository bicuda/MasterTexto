@echo off
echo ==========================================
echo      MasterTexto - Local Launcher
echo ==========================================

echo [1/2] Starting Backend...
start "MasterTexto Backend" cmd /k "cd backend && npm install && npx prisma db push && npm run dev"

echo [2/2] Starting Frontend...
start "MasterTexto Frontend" cmd /k "cd frontend && npm install && npm run dev"

echo.
echo System is starting up!
echo - Backend will act as the API/Socket server.
echo - Frontend will open on http://localhost:5173 (check the frontend window)
echo.
echo Keep these windows open to keep the server running.
echo To stop, just close the windows.
echo.
pause
