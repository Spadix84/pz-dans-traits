@echo off
rem Project Zomboid Vitality Project live dashboard: opens http://127.0.0.1:8642 in your browser.
rem Start the game (single player) with Project Zomboid Vitality Project enabled and keep this window open.
cd /d "%~dp0"
python dashboard.py %*
pause
