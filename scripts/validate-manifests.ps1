# Validate Kustomize output without a live cluster (no kubectl server required).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$kmps = @(
  (Join-Path $root "k8s-manifests"),
  (Join-Path $root "k8s-manifests\overlays\dev"),
  (Join-Path $root "k8s-manifests\overlays\prod")
)
foreach ($p in $kmps) {
  Write-Host "`n--- kubectl kustomize $p ---"
  kubectl kustomize $p | Out-Null
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "OK"
}
Write-Host "`nAll kustomize builds succeeded."
