if (-not (Test-Path .previous_version)) {
    Write-Error "No previous version recorded to roll back to!"
    exit 1
}

$prevTag = (Get-Content .previous_version).Trim()
Write-Host "Rolling back to previous version: $prevTag" -ForegroundColor Yellow

(Get-Content .env) -replace "^IMAGE_TAG=.*", "IMAGE_TAG=$prevTag" | Set-Content .env
Set-Content -Path .current_version -Value $prevTag

docker compose -f docker-compose.prod.yml up -d

Write-Host "Verifying rolled back application..."
Start-Sleep -Seconds 5
$res = Invoke-RestMethod -Uri "http://api.debyez.localhost/api/health/full"
Write-Host "Rollback complete. Active tag: $prevTag (Status: $($res.status))" -ForegroundColor Green