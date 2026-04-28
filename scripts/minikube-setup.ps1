# Minikube POC bootstrap (Windows PowerShell)
# Requires: minikube, kubectl
$ErrorActionPreference = "Stop"

Write-Host "Starting Minikube (adjust driver if needed, e.g. - driver=hyperv, docker)..."
minikube start

Write-Host "Enabling ingress (for secureforge.local)..."
minikube addons enable ingress

# Optional: local registry for private-image testing
# minikube addons enable registry
# docker run -d -p 5000:5000 --name local-registry registry:2  # or use addon docs

Write-Host "Cluster context:"
kubectl config current-context

Write-Host "Done. Add to hosts: minikube ip -> secureforge.local (see README)."
