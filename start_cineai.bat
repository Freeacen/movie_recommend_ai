@echo off
title CineAI - Movie Recommend AI
cd /d "%~dp0"
echo ========================================================
echo   CineAI - Film Takip ve Yapay Zeka Oneri Uygulamasi
echo ========================================================
echo.
echo Uygulama tarayicinizda aciliyor...
start "" "http://localhost:8080"
echo Sunucu calisiyor: http://localhost:8080
echo Kapatmak icin bu pencereyi kapatabilirsiniz.
echo.
python serve.py
