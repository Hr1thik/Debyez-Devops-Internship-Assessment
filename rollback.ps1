if (-not (Test-Path .previous_version)) {
    Write-Error "No previous version recorded to roll back to!"
    exit 1
}

$prevTag = (Get-Content .previous_version).Trim()
Write-Host "Rolling back to previous version: $prevTag" -ForegroundColor Yellow

# Clear temporary session override
Remove-Item env:IMAGE_TAG -ErrorAction SilentlyContinue

# Update environment file and tracker
(Get-Content .env) -replace "^IMAGE_TAG=.*", "IMAGE_TAG=$prevTag" | Set-Content .env
Set-Content -Path .current_version -Value $prevTag

# Bring up the verified previous tag
docker compose -f docker-compose.prod.yml up -d

Write-Host "Verifying rolled back application..."
Start-Sleep -Seconds 5
$res = Invoke-RestMethod -Uri "http://api.debyez.localhost/api/health/full"
Write-Host "Rollback complete. Active tag: $prevTag (Status: $($res.status))" -ForegroundColor Green