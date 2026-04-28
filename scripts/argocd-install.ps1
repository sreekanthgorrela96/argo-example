# Install Argo CD into the cluster (POC: minikube or any cluster with kubectl)
$ErrorActionPreference = "Stop"

Write-Host "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

$installUrl = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
Write-Host "Applying Argo CD from $installUrl"
kubectl apply -n argocd -f $installUrl

Write-Host "Wait for Argo CD to be ready (optional):"
Write-Host "  kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s"
Write-Host ""
Write-Host "Get initial admin password:"
Write-Host "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$_)) }"
Write-Host ""
Write-Host "Port-forward UI (then open https://localhost:9080 , accept self-signed cert):"
Write-Host "  kubectl port-forward svc/argocd-server -n argocd 9080:443"
