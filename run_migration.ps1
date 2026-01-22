#!/usr/bin/env pwsh
# WattBuddy Database Migration Script

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "WattBuddy Database Migration" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Read .env file
$envFile = "wattbuddy-server\.env"
$databaseUrl = $null

if (Test-Path $envFile) {
    Write-Host "📄 Reading .env file..." -ForegroundColor Yellow
    $lines = @(Get-Content $envFile)
    foreach ($line in $lines) {
        if ($line -like "DATABASE_URL=*") {
            $databaseUrl = $line -replace "DATABASE_URL=", ""
            break
        }
    }
}

if ([string]::IsNullOrEmpty($databaseUrl)) {
    Write-Host "❌ ERROR: DATABASE_URL not found" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found DATABASE_URL: $($databaseUrl.Substring(0, 20))..." -ForegroundColor Green
Write-Host ""

$migrationFile = "wattbuddy-server\migrations\001_add_device_tables.sql"
if (-not (Test-Path $migrationFile)) {
    Write-Host "❌ Migration file not found: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "📄 Using migration file: $migrationFile" -ForegroundColor Cyan
Write-Host ""

Write-Host "⏳ Running migration..." -ForegroundColor Yellow
Write-Host ""

# Parse DATABASE_URL - format: postgres://user:password@host:port/database
$dbUrl = $databaseUrl
$user = ""
$password = ""
$host = ""
$port = "5432"
$database = ""

# Split by ://
if ($dbUrl -like "*://*") {
    $parts = $dbUrl -split "://"
    $connStr = $parts[1]
    
    # Split by @
    $atIndex = $connStr.LastIndexOf("@")
    if ($atIndex -gt 0) {
        $userPwd = $connStr.Substring(0, $atIndex)
        $hostPortDb = $connStr.Substring($atIndex + 1)
        
        # Parse user:password
        $colonIndex = $userPwd.IndexOf(":")
        if ($colonIndex -gt 0) {
            $user = $userPwd.Substring(0, $colonIndex)
            $password = $userPwd.Substring($colonIndex + 1)
        }
        
        # Parse host:port/database
        $slashIndex = $hostPortDb.IndexOf("/")
        if ($slashIndex -gt 0) {
            $database = $hostPortDb.Substring($slashIndex + 1)
            $hostPort = $hostPortDb.Substring(0, $slashIndex)
        } else {
            $hostPort = $hostPortDb
        }
        
        # Parse host:port
        $portColonIndex = $hostPort.LastIndexOf(":")
        if ($portColonIndex -gt 0) {
            $host = $hostPort.Substring(0, $portColonIndex)
            $port = $hostPort.Substring($portColonIndex + 1)
        } else {
            $host = $hostPort
        }
    }
}

Write-Host "Parsed connection:" -ForegroundColor Gray
Write-Host "  User: $user" -ForegroundColor Gray
Write-Host "  Host: $host" -ForegroundColor Gray
Write-Host "  Port: $port" -ForegroundColor Gray
Write-Host "  Database: $database" -ForegroundColor Gray
Write-Host ""

# Set environment variable for psql
$env:PGPASSWORD = $password

# Find psql
$psqlCmd = "psql"
$psqlLocations = @(
    "C:\Program Files\PostgreSQL\16\bin\psql.exe",
    "C:\Program Files\PostgreSQL\15\bin\psql.exe",
    "C:\Program Files\PostgreSQL\14\bin\psql.exe",
    "C:\Program Files (x86)\PostgreSQL\15\bin\psql.exe"
)

foreach ($loc in $psqlLocations) {
    if (Test-Path $loc) {
        $psqlCmd = $loc
        break
    }
}

Write-Host "Using: $psqlCmd" -ForegroundColor Gray
Write-Host ""

# Run psql with the migration file
Write-Host "Executing migration..." -ForegroundColor Cyan

try {
    & $psqlCmd -h $host -p $port -U $user -d $database -f $migrationFile
    $exitCode = $LASTEXITCODE
} catch {
    Write-Host "❌ Error executing psql: $_" -ForegroundColor Red
    $exitCode = 1
}

# Clear password
$env:PGPASSWORD = $null

Write-Host ""

if ($exitCode -eq 0) {
    Write-Host "✅ Migration completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Tables created/updated:" -ForegroundColor Green
    Write-Host "  ✓ energy_readings (added columns)" -ForegroundColor Green
    Write-Host "  ✓ users (added unique username constraint)" -ForegroundColor Green
    Write-Host "  ✓ device_configs (new)" -ForegroundColor Green
    Write-Host "  ✓ relay_status (new)" -ForegroundColor Green
    Write-Host "  ✓ device_control_logs (new)" -ForegroundColor Green
    Write-Host "  ✓ user_sessions (new)" -ForegroundColor Green
    Write-Host ""
    Write-Host "🚀 Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Start backend:   cd wattbuddy-server && npm start" -ForegroundColor Cyan
    Write-Host "  2. Start Flutter:   flutter run" -ForegroundColor Cyan
    Write-Host "  3. Test multi-user: Create 2+ accounts and verify data isolation" -ForegroundColor Cyan
} else {
    Write-Host "❌ Migration failed! Exit code: $exitCode" -ForegroundColor Red
    exit 1
}
