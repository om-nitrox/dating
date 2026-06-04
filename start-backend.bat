@echo off
title Reverse Match Backend
cd /d D:\dating\2nd\dating-main\dating-main\backend
echo Starting backend API on http://localhost:5000 ...
call npm start
echo.
echo Backend stopped. Press any key to close.
pause >nul
