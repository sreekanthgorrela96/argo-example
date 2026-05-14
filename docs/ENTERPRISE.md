# Enterprise Kubernetes target (GitOps)

This document maps the Minikube POC to hardening you typically add on a shared platform (EKS, GKE, AKS, or on-prem).

## Ingress and TLS

- Use the platform standard ingress controller (NGINX, AWS ALB GKE Ingress, etc.).
- Issue certificates with **cert-manager** (Let’s Encrypt private ACME, or corporate PKI) or use cloud-managed certs on the load balancer.
- Replace `secureforge.local` with real DNS; remove dependency on `/etc/hosts`.
- Set `ingressClassName` to the cluster’s agreed class.

## Argo CD

- Disable reliance on the initial **admin** password in production: configure **SSO (OIDC)** with your IdP.
- Create **AppProject** resources (see `argocd/appproject-secureforge.yaml`) to restrict source repos and destination namespaces.
- Grant teams **Argo CD RBAC** (project roles) instead of sharing one admin user.
- Run **HA** controller/server replicas if your platform team requires it; size per official Argo CD docs.
- Store the GitOps repo credential as an Argo CD **repository secret** (SSH deploy key or PAT with least privilege); avoid wide PATs in `Application` specs.

## Secrets and registry

- Prefer **workload identity** (IRSA, GKE Workload Identity, etc.) or **External Secrets Operator** / Vault / cloud secret managers over long-lived `docker-registry` passwords in Kubernetes.
- If `imagePullSecrets` are required, sync them from a controlled secret store; do not commit credentials to Git.

## Manifests and environments

- Use **overlays** (`k8s-manifests/overlays/dev`, `.../prod`) or Helm charts; Argo CD `Application` `path` points at the right overlay per cluster.
- Add **ResourceQuota** / **LimitRange** in namespace templates as mandated by platform.

## Policy and security

- **NetworkPolicies** to limit ingress/egress for `secureforge`.
- **Admission policies** (Kyverno, OPA Gatekeeper) for allowed registries, required labels, and approved base images.
- **Image scanning** in CI (not a substitute for admission policy).

## Observability and operations

- Scrape Argo CD metrics; alert on sync failures and unhealthy applications.
- Ship application logs/metrics to the central stack.
- **Runbooks**: sync failure (RBAC, repo auth), `ImagePullBackOff` (registry/auth), rollback via Git revert or Argo CD UI/history.

## CI (Jenkins)

- Store registry and Git credentials in **Jenkins Credential Store**; use branch protection and optional PR-based promotions for production manifest changes.

## On-premises Kubernetes as the Argo CD destination

Minikube proves the GitOps mechanics; for a real on-prem cluster you keep the same **Jenkins → Git → Argo CD** flow and only change **where Argo CD deploys**.

1. **Kubeconfig** on the machine running `argocd` CLI (or in your GitOps automation): a context that points at your on-prem API server (`https://<api>:6443`) with valid credentials (client cert, exec plugin, or OIDC).
2. **Register the cluster with Argo CD** (run from a shell that can reach both the Argo CD API and the on-prem API):

   ```bash
   argocd login <argocd-host>:443 --grpc-web
   argocd cluster add <your-on-prem-context> --name on-prem-prod
   ```

   Argo CD stores a cluster secret and exposes an internal `server` URL for that cluster (shown in `argocd cluster list` / UI).

3. **Point the Application at that server** — in `argocd/application.yaml` (or an overlay you apply per environment), set:

   ```yaml
   spec:
     destination:
       server: https://<value-from-argocd-cluster-list>
       namespace: secureforge
   ```

   Keep `repoURL` / `path` pointed at the same GitOps repo; only `destination.server` (and optionally `namespace`) changes per target cluster.

4. **Network**: the Argo CD **application controller** must reach the on-prem Kubernetes API (firewall, VPN, or private link). If Argo CD runs inside the same network as the cluster, this is usually straightforward.

5. **Private Git / registry**: configure Argo CD **repository credentials** and cluster **imagePullSecrets** (or workload identity) the same way you would for any private on-prem registry.

After this, a Jenkins build that pushes a new tag and commits the `image: … # secureforge-ci-image` line still triggers Argo CD to sync and roll out on the on-prem cluster automatically.
