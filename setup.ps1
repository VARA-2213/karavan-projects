# ============================================
# KARAVAN COMPLETE SETUP SCRIPT
# Run as Administrator in PowerShell
# ============================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "    APACHE KARAVAN SETUP" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Clean up existing containers
Write-Host "`n[1/6] Cleaning up..." -ForegroundColor Yellow
docker stop $(docker ps -q) 2>$null
docker rm $(docker ps -aq) 2>$null
docker system prune -f 2>$null

# 2. Create working directory
Write-Host "`n[2/6] Setting up directory..." -ForegroundColor Yellow
$workingDir = "C:\karavan-lab"
if (-not (Test-Path $workingDir)) {
    New-Item -ItemType Directory -Path $workingDir -Force
}
Set-Location $workingDir
Write-Host "Working in: $(Get-Location)" -ForegroundColor Green

# 3. Create .env file
Write-Host "`n[3/6] Creating .env file..." -ForegroundColor Yellow
@"
# Git Repository Configuration
KARAVAN_GIT_REPOSITORY=https://github.com/karavan-dummy/karavan-lab.git
KARAVAN_GIT_USER=karavan-dummy
KARAVAN_GIT_PASSWORD=dummy-token-123
"@ | Set-Content .env -Encoding UTF8

# 4. Create docker-compose.yml
Write-Host "`n[4/6] Creating docker-compose.yml..." -ForegroundColor Yellow
@"
version: '3.8'

services:
  karavan:
    image: ghcr.io/apache/camel-karavan:latest
    container_name: karavan
    ports:
      - "8080:8080"
    environment:
      - KARAVAN_GIT_REPOSITORY=\${KARAVAN_GIT_REPOSITORY}
      - KARAVAN_GIT_USER=\${KARAVAN_GIT_USER}
      - KARAVAN_GIT_PASSWORD=\${KARAVAN_GIT_PASSWORD}
    volumes:
      - //var/run/docker.sock:/var/run/docker.sock
      - karavan-data:/app/data
    restart: unless-stopped
    depends_on:
      rabbitmq:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    restart: unless-stopped
    healthcheck:
      test: rabbitmq-diagnostics -q ping
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  karavan-data:
"@ | Set-Content docker-compose.yml -Encoding UTF8

# 5. Start containers
Write-Host "`n[5/6] Starting containers..." -ForegroundColor Yellow
docker compose up -d

# 6. Wait for startup
Write-Host "`n[6/6] Waiting for services to start (2 minutes)..." -ForegroundColor Yellow
Write-Host "Karavan (Java) needs time to initialize..." -ForegroundColor Yellow
$totalWait = 120
for ($i = 0; $i -lt $totalWait; $i++) {
    $percent = [math]::Round(($i / $totalWait) * 100)
    Write-Progress -Activity "Starting Karavan" -Status "Please wait... $i/$totalWait seconds" -PercentComplete $percent
    Start-Sleep -Seconds 1
}
Write-Progress -Activity "Starting Karavan" -Completed

# 7. Display status
Write-Host "`n=== CONTAINER STATUS ===" -ForegroundColor Cyan
docker compose ps

# 8. Test connections
Write-Host "`n=== TESTING CONNECTIONS ===" -ForegroundColor Cyan

# Test Karavan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080" -Method Head -TimeoutSec 10
    Write-Host "✓ Karavan: HTTP $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "✗ Karavan: Not responding yet" -ForegroundColor Red
}

# Test RabbitMQ
try {
    $response = Invoke-WebRequest -Uri "http://localhost:15672" -Method Head -TimeoutSec 10
    Write-Host "✓ RabbitMQ: HTTP $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "✗ RabbitMQ: Not responding yet" -ForegroundColor Red
}

# 9. Display access information
Write-Host "`n" + ("="*50) -ForegroundColor Cyan
Write-Host "          READY TO USE!" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Cyan
Write-Host "`nACCESS URLs:" -ForegroundColor Yellow
Write-Host "------------" -ForegroundColor White
Write-Host "1. KARAVAN (Integration Designer)" -ForegroundColor Green
Write-Host "   • Main URL:     http://localhost:8080/#/" -ForegroundColor Cyan
Write-Host "   • Projects:     http://localhost:8080/#/projects" -ForegroundColor Cyan
Write-Host "   • Designer:     http://localhost:8080/#/designer" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. RABBITMQ (Message Broker)" -ForegroundColor Green
Write-Host "   • Management:   http://localhost:15672" -ForegroundColor Cyan
Write-Host "   • Username:     guest" -ForegroundColor Cyan
Write-Host "   • Password:     guest" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. USEFUL COMMANDS:" -ForegroundColor Yellow
Write-Host "   • View logs:    docker compose logs" -ForegroundColor White
Write-Host "   • Stop:         docker compose down" -ForegroundColor White
Write-Host "   • Start:        docker compose up -d" -ForegroundColor White
Write-Host "   • Restart:      docker compose restart" -ForegroundColor White
Write-Host ""
Write-Host "TROUBLESHOOTING:" -ForegroundColor Red
Write-Host "----------------" -ForegroundColor White
Write-Host "• If 404 error: Clear browser cache (Ctrl+Shift+Delete)" -ForegroundColor Magenta
Write-Host "• If blank page: Wait 1 more minute, then refresh" -ForegroundColor Magenta
Write-Host "• Use Chrome/Edge for best compatibility" -ForegroundColor Magenta
Write-Host "• URL MUST contain # (hash symbol)" -ForegroundColor Magenta

# 10. Open browser
Write-Host "`nOpening browser..." -ForegroundColor Yellow
Start-Process "http://localhost:8080/#/"
Start-Sleep -Seconds 2
Start-Process "http://localhost:15672"