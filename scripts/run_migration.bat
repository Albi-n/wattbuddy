@echo off
REM WattBuddy Database Migration Script
echo.
echo ==========================================
echo WattBuddy Database Migration
echo ==========================================
echo.

REM Parse .env file for DATABASE_URL
setlocal enabledelayedexpansion
set "envFile=wattbuddy-server\.env"
set "databaseUrl="

if exist "!envFile!" (
    echo Reading .env file...
    for /f "delims==" %%A in ('type "!envFile!"') do (
        if "%%A"=="DATABASE_URL" (
            for /f "tokens=2 delims==" %%B in ('findstr "DATABASE_URL=" "!envFile!"') do (
                set "databaseUrl=%%B"
            )
        )
    )
)

if "!databaseUrl!"=="" (
    echo ERROR: DATABASE_URL not found in .env file
    pause
    exit /b 1
)

echo Found DATABASE_URL: !databaseUrl!
echo.

REM Check if migration file exists
if not exist "wattbuddy-server\migrations\001_add_device_tables.sql" (
    echo ERROR: Migration file not found
    pause
    exit /b 1
)

echo Running migration: 001_add_device_tables.sql
echo.

REM Extract user, password, host, port, database from DATABASE_URL
REM Expected format: postgres://user:password@host:port/database
REM This is a simplified version - you may need to adjust based on your actual database setup

REM Use psql directly (assumes psql is in PATH)
echo Executing migration...
psql !databaseUrl! -f "wattbuddy-server\migrations\001_add_device_tables.sql"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: Migration completed!
    echo.
    echo Tables created:
    echo   + device_configs
    echo   + relay_status
    echo   + device_control_logs
    echo   + user_sessions
    echo.
    echo Next steps:
    echo   1. Start backend: cd wattbuddy-server ^&^& npm start
    echo   2. Start Flutter: flutter run
    echo   3. Test multi-user data isolation
) else (
    echo.
    echo ERROR: Migration failed with exit code %ERRORLEVEL%
    pause
    exit /b 1
)

pause
