# SecureForge GitOps (Minikube POC + enterprise)

Jenkins (or manual Git) updates the `image:` line (suffix `# secureforge-ci-image`) in `k8s-manifests/base/deployment.yaml`; **Argo CD** syncs this repo to Kubernetes.

## Repository layout

| Path | Purpose |
|------|--------|
| [k8s-manifests](k8s-manifests/) | Kustomize root (POC); includes [base](k8s-manifests/base/) manifests |
| [k8s-manifests/overlays/dev](k8s-manifests/overlays/dev/) | 1 replica (cheap dev) |
| [k8s-manifests/overlays/prod](k8s-manifests/overlays/prod/) | 3 replicas + higher resources |
| [argocd](argocd/) | `Application` and `AppProject` examples |
| [scripts](scripts/) | Minikube bootstrap, Argo CD install, validation |
| [docs](docs/) | E2E demo steps and enterprise hardening |
| [enterprise](enterprise/) | Example patches (OIDC placeholder, ExternalSecret) |
| [Jenkinsfile](Jenkinsfile) | Build → push → update manifests branch |
| [docker-compose.jenkins.yml](docker-compose.jenkins.yml) | Local Jenkins (Docker) for CI POC |
| [docs/JENKINS-LOCAL.md](docs/JENKINS-LOCAL.md) | Install Jenkins, credentials, Pipeline job |

## Minikube POC

1. Start Docker Desktop (or your container runtime), then:
   ```powershell
   .\scripts\minikube-setup.ps1
   ```
2. Apply the app (validates the cluster without Argo CD):
   ```powershell
   kubectl apply -k k8s-manifests
   ```
3. **Ingress:** enable addon (script does), then add to your hosts file: `$(minikube ip) secureforge.local`
4. **Or** port-forward the service:
   ```powershell
   kubectl port-forward svc/secureforge-ui -n secureforge 8080:80
   ```
   Open `http://localhost:8080`

## Argo CD (POC)

1. Install:
   ```powershell
   .\scripts\argocd-install.ps1
   ```
2. Get the initial admin password (PowerShell):
   ```powershell
   $b = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
   [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b))
   ```
3. UI: `kubectl port-forward svc/argocd-server -n argocd 9080:443` → `https://localhost:9080` (user `admin`).
4. Push **this** repo to GitHub/GitLab and edit [argocd/application.yaml](argocd/application.yaml): set `spec.source.repoURL` to your remote. For private repos, use [argocd/repository-secret.example.yaml](argocd/repository-secret.example.yaml).
5. Register the app (after `kubectl` can reach the cluster):
   ```powershell
   kubectl apply -f argocd/application.yaml
   ```
6. Change the image in `k8s-manifests/base/deployment.yaml`, commit, push — Argo CD should auto-sync if enabled.

**Validate YAML without a running cluster** (Kustomize only):

```powershell
.\scripts\validate-manifests.ps1
```

## Jenkins (local POC)

1. Start Docker Desktop, then from this repo root:
   ```powershell
   .\scripts\jenkins-up.ps1
   ```
   This writes `.env` with **`DOCKER_GID`** so user `jenkins` can access the Docker socket (see [docs/JENKINS-LOCAL.md](docs/JENKINS-LOCAL.md)).  
   Or: copy `.env.example` → `.env`, set `DOCKER_GID`, then `docker compose -f docker-compose.jenkins.yml up -d --build`
2. Open **http://localhost:8081** (8081 avoids clashing with app port-forwards on 8080).
3. Full steps (unlock, GitHub PAT credential `git-manifests-creds`, Pipeline from SCM): **[docs/JENKINS-LOCAL.md](docs/JENKINS-LOCAL.md)**.

If **`git push`** fails with **403**, see [docs/GITHUB-GIT-PUSH-403.md](docs/GITHUB-GIT-PUSH-403.md) (PAT scopes, branch protection, SSO).

## Enterprise

- Overlay path for prod Argo CD: `k8s-manifests/overlays/prod` — see [argocd/application-prod-overlay.yaml](argocd/application-prod-overlay.yaml) (apply [argocd/appproject-secureforge.yaml](argocd/appproject-secureforge.yaml) first so `project: secureforge` exists).
- Hardening checklist: [docs/ENTERPRISE.md](docs/ENTERPRISE.md)
- Example snippets: [enterprise/](enterprise/)

## E2E demo

Step-by-step checklist: [docs/E2E-DEMO.md](docs/E2E-DEMO.md)

## Private container registry

Create pull secret in `secureforge` and uncomment `imagePullSecrets` in `k8s-manifests/base/deployment.yaml`:

```powershell
kubectl create secret docker-registry regcred `
  --docker-username=YOUR_USER `
  --docker-password=YOUR_PASS `
  --docker-server=YOUR_REGISTRY `
  -n secureforge
```
