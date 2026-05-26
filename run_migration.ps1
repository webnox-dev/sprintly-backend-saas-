# Run this script to convert BOOLEAN columns to SMALLINT (0/1)
# Make sure PostgreSQL bin directory is in your PATH, or update the path below

$psqlPath = "C:\Program Files\PostgreSQL\16\bin\psql.exe"  # Update version if needed

# Check if psql exists
if (-not (Test-Path $psqlPath)) {
    Write-Host "❌ PostgreSQL psql.exe not found at: $psqlPath" -ForegroundColor Red
    Write-Host "Please update the path in this script or add PostgreSQL bin to your PATH" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Running Boolean to Integer Migration ===" -ForegroundColor Cyan

# Execute migration
& $psqlPath -U postgres -d webnox_sprintly -f "database/migrations/003_convert_boolean_to_int_improved.sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Migration completed successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Migration failed with exit code: $LASTEXITCODE" -ForegroundColor Red
}
