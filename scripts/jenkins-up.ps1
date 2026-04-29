# Start local Jenkins for Argo CD POC (requires Docker Desktop)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Write-Host "Building and starting Jenkins on http://localhost:8081 ..."
docker compose -f docker-compose.jenkins.yml up -d --build

Write-Host ""
Write-Host "Initial admin password:"
docker exec jenkins-argocd-poc cat /var/jenkins_home/secrets/initialAdminPassword 2>$null
Write-Host ""
Write-Host "Next: open http://localhost:8081 and follow docs/JENKINS-LOCAL.md"
