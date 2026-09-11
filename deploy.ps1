param (
    [Parameter(Mandatory=$true)]
    [string]$Tag
)

$ErrorActionPreference = "Continue"

# 1. Capture the existing stable tag BEFORE doing anything
$previousTag = ""
if (Test-Path .current_version) {
    $previousTag = (Get-Content .current_version).Trim()
} elseif (Test-Path .env) {
    Get-Content .env | ForEach-Object {
        if ($_ -match "^IMAGE_TAG=(.*)$") {
            $previousTag = $matches[1].Trim()
        }
    }
}

if ($previousTag -and ($previousTag -ne $Tag)) {
    Set-Content -Path .previous_version -Value $previousTag
}

Write-Host "Targeting deployment version: $Tag"

# 2. Test pulling the new image first using an environment variable override
$env:IMAGE_TAG = $Tag
docker compose -f docker-compose.prod.yml pull
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Docker pull failed for tag $Tag! Aborting deployment and triggering rollback..."
    .\rollback.ps1
    exit 1
}

# 3. Only update .env after images are verified to exist
(Get-Content .env) -replace "^IMAGE_TAG=.*", "IMAGE_TAG=$Tag" | Set-Content .env
Set-Content -Path .current_version -Value $Tag

# 4. Deploy containers
docker compose -f docker-compose.prod.yml up -d
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Docker compose up failed! Triggering rollback..."
    .\rollback.ps1
    exit 1
}

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