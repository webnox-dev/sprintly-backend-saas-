@echo off
echo Running dart pub get...
call dart pub get
if %errorlevel% neq 0 (
    echo dart pub get failed!
    exit /b %errorlevel%
)
echo dart pub get succeeded.
