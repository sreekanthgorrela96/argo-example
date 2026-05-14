# End-to-end demo checklist (Jenkins → Git → Argo CD → cluster)

Use this when Docker / Minikube / Jenkins are available. No screenshots are stored in this repo; capture your own for stakeholders.

## Preconditions

- Minikube (or other cluster) running; `kubectl` context points at it.
- Argo CD installed (`scripts/argocd-install.ps1`); you can log into the UI.
- This repo pushed to a remote Git server; `argocd/application.yaml` `spec.source.repoURL` and `path` match.
- Jenkins (optional for full loop): agents with Docker, registry push access, and credential **`github-token-creds`** (see [JENKINS-LOCAL.md](JENKINS-LOCAL.md)) for the manifests repo.

## A. Git-only CD validation (no Jenkins)

1. Edit `k8s-manifests/base/deployment.yaml` and change the `image:` value on the line that ends with **`# secureforge-ci-image`** (keep that suffix so Jenkins can update the same line later).
2. Commit and push to the branch Argo CD tracks.
3. In Argo CD UI, confirm the application syncs (or wait for auto-sync).
4. Run:
   - `kubectl get pods -n secureforge`
   - `kubectl describe deploy secureforge-ui -n secureforge`
5. Confirm the new image reference appears in the ReplicaSet / pod spec.

## B. Full loop with Jenkins

1. Point the app pipeline at a repo containing this `Dockerfile` (or your app).
2. Set `DOCKER_IMAGE` (build parameter), `MANIFESTS_REPO`, and `MANIFESTS_BRANCH` in `Jenkinsfile` to your registries and repos.
3. Configure Jenkins credentials **`github-token-creds`** (username + PAT as password) and **`docker-hub-creds`** for the registry.
4. Run the pipeline; confirm:
   - Image exists in the registry with tag = build number.
   - Manifests repo has a new commit updating `k8s-manifests/base/deployment.yaml`.
   - Argo CD syncs and pods roll out.

## C. Rollback story (for managers)

- Show Argo CD **History** and **Rollback**, or revert the image commit in Git and let sync converge.
- Emphasize: **deployment history matches Git history**.

## D. Ingress (Minikube)

1. `minikube addons enable ingress`
2. `minikube ip` — add `secureforge.local` to your hosts file pointing to that IP.
3. Browse `https://secureforge.local` (or `http` depending on controller). Accept Minikube/self-signed behavior as applicable.
