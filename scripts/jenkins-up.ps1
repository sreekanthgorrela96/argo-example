# Start local Jenkins for Argo CD POC (requires Docker Desktop)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Write-Host "Detecting Docker socket group id on host..."
try {
    $gidRaw = docker run --rm -v /var/run/docker.sock:/var/run/docker.sock alpine:3.20 stat -c '%g' /var/run/docker.sock 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker run failed: $gidRaw" }
    $dockerGid = ($gidRaw | Out-String).Trim()
    if ($dockerGid -notmatch '^\d+$') { throw "Unexpected stat output: $gidRaw" }
} catch {
    Write-Warning "Could not auto-detect DOCKER_GID (${_}). Copy .env.example to .env and set DOCKER_GID manually."
    $dockerGid = "0"
}

$envPath = Join-Path $root ".env"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($envPath, "DOCKER_GID=$dockerGid`n", $utf8NoBom)
Write-Host "Wrote $envPath with DOCKER_GID=$dockerGid (jenkins user needs this to use docker.sock)"

Write-Host "Building and starting Jenkins on http://localhost:8081 ..."
docker compose -f docker-compose.jenkins.yml --env-file $envPath up -d --build

Write-Host ""
Write-Host "Initial admin password:"
docker exec jenkins-argocd-poc cat /var/jenkins_home/secrets/initialAdminPassword 2>$null
Write-Host ""
Write-Host "Verify Docker from a Pipeline shell:  docker version && docker ps"
Write-Host "Next: open http://localhost:8081 and follow docs/JENKINS-LOCAL.md"
