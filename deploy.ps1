param (
    [Parameter(Mandatory=$true)]
    [string]$Tag
)

if (Test-Path .env) {
    Get-Content .env | ForEach-Object {
        if ($_ -match "^IMAGE_TAG=(.*)$") {
            $prev = $matches[1]
            Set-Content -Path .previous_version -Value $prev
        }
    }
}

Write-Host "Deploying version: $Tag"
(Get-Content .env) -replace "^IMAGE_TAG=.*", "IMAGE_TAG=$Tag" | Set-Content .env
Set-Content -Path .current_version -Value $Tag

docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

Write-Host "Verifying deployment health..."
Start-Sleep -Seconds 10

try {
    $res = Invoke-RestMethod -Uri "http://api.debyez.localhost/api/health/full" -TimeoutSec 10
    if ($res.status -eq "ok") {
        Write-Host "Deployment of tag $Tag verified successfully!" -ForegroundColor Green
    } else {
        throw "Health check returned non-ok status"
    }
} catch {
    Write-Warning "Health verification failed! Triggering rollback..."
    .\rollback.ps1
}