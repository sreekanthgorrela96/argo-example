# Local Jenkins for Argo CD POC

This repo ships a **Docker Compose** stack that runs Jenkins with:

- **Docker CLI** + **Git** (for your `Jenkinsfile` `sh` steps)
- Access to the **host Docker engine** via `/var/run/docker.sock` (build/push images)
- Pre-installed plugins: Git, Pipeline (`workflow-aggregator`), `credentials-binding`

## Prerequisites

1. **Docker Desktop** running (Windows: WSL2 backend recommended).
2. **GitHub PAT** with `repo` scope for `https://github.com/sreekanthgorrela96/argo-example` (clone + push).
3. **Container registry** account (e.g. Docker Hub). Set `IMAGE_NAME` in [Jenkinsfile](../Jenkinsfile) to something you can push (example: `yourdockerhubuser/secureforge-ui`).

## Start Jenkins

From the repository root:

```powershell
docker compose -f docker-compose.jenkins.yml up -d --build
```

Open **http://localhost:8081**

### First-time unlock

1. Get the initial admin password:

   ```powershell
   docker exec jenkins-argocd-poc cat /var/jenkins_home/secrets/initialAdminPassword
   ```

2. Paste it into the Jenkins wizard.
3. Choose **Install suggested plugins** (adds many useful plugins), or **Select plugins** and ensure Pipeline/Git stay available.
4. Create an admin user (recommended) or continue as admin.

### Install extra plugins (if needed)

**Manage Jenkins → Plugins → Available**: search for **Pipeline**, **Git**, **Credentials Binding** if anything failed to load.

## Credentials (required for the Pipeline)

**Manage Jenkins → Credentials → (global) → Add Credentials**

| Kind              | ID                     | Usage |
|-------------------|------------------------|--------|
| Username + password | `git-manifests-creds` | GitHub username + **PAT** (not your account password) |

Optional but needed for `docker push`:

- Add **Username with password** for Docker Hub (note the ID, e.g. `dockerhub-creds`).  
  Then add a **Pipeline** stage before push (or use **Manage Jenkins → Credentials** + shell `docker login` in the Jenkinsfile). Quick POC approach:

```bash
# One-time interactive login on the host (same Docker engine Jenkins uses):
docker login
```

Images are pushed via the **host** Docker daemon, so a successful `docker login` on the host often allows Jenkins jobs to push until credentials expire. For a durable setup, add `withCredentials` around `docker login` in the Jenkinsfile.

## Create the Pipeline job

1. **New Item** → name e.g. `secureforge-gitops` → **Pipeline** → OK.
2. **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/sreekanthgorrela96/argo-example.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. Save → **Build Now**.

Update **IMAGE_NAME** in the Jenkinsfile (on `main`) to your real registry image before expecting green builds.

## Validate the GitOps loop

1. Build succeeds; image is pushed with tag = build number.
2. GitHub shows a new commit on `main` updating `k8s-manifests/base/deployment.yaml`.
3. Argo CD syncs that repo to your cluster.

## Stop / reset

```powershell
docker compose -f docker-compose.jenkins.yml down
```

Remove all Jenkins data:

```powershell
docker compose -f docker-compose.jenkins.yml down -v
```

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| `permission denied` on Docker socket | Compose already runs Jenkins as root (`user: "0:0"`). Restart Docker Desktop. |
| `docker: not found` inside job | Rebuild image: `docker compose ... build --no-cache`. |
| `git push` fails | PAT must have **repo** scope; credential ID must be exactly **`git-manifests-creds`**. |
| `sed` / `sh` errors | Pipeline must run on the built-in Linux node (default for this container). Do not use Windows batch agents for this Jenkinsfile. |

## Security note

Mounting `docker.sock` gives Jenkins **full control of the host Docker**. Keep this stack **local POC only**.
