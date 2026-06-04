@echo off
title ML Service (Ideal Match)
cd /d D:\dating\2nd\dating-main\dating-main\ml-service
if not exist data mkdir data
set KMP_DUPLICATE_LIB_OK=TRUE
echo Starting Ideal Match ML service on http://localhost:8010 ...
".venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8010
echo.
echo ML service stopped. Press any key to close.
pause >nul
