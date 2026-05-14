# Local Jenkins for Argo CD POC

This repo ships a **Docker Compose** stack that runs Jenkins with:

- **Docker CLI** (static binary) + **Git** (for your `Jenkinsfile` `sh` steps)
- Access to the **host Docker engine** via `/var/run/docker.sock` (build/push images)
- Pre-installed plugins: Git, Pipeline (`workflow-aggregator`), `credentials-binding`

### Why `docker` failed inside Pipeline jobs

The Jenkins process runs as user **`jenkins`** (not root). The socket `/var/run/docker.sock` is usually mode `660` and owned by group **`docker`** on the host. That group has a numeric **GID** that must match inside the container.

Compose adds Jenkins to that group via **`group_add`**. The helper script **`scripts/jenkins-up.ps1`** detects the host socket GID and writes a **`.env`** file with `DOCKER_GID=...`. If you start Compose manually, copy **`.env.example`** to **`.env`** and set `DOCKER_GID` after running:

```powershell
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock alpine:3.20 stat -c '%g' /var/run/docker.sock
```

After changing `.env`, recreate the container: `docker compose -f docker-compose.jenkins.yml up -d --force-recreate`.

## Prerequisites

1. **Docker Desktop** running (Windows: WSL2 backend recommended).
2. **GitHub PAT** with `repo` scope for `https://github.com/sreekanthgorrela96/argo-example` (clone + push).
3. **Container registry** account (e.g. Docker Hub). Set `IMAGE_NAME` in [Jenkinsfile](../Jenkinsfile) to something you can push (example: `yourdockerhubuser/secureforge-ui`).

## Start Jenkins

From the repository root (recommended — detects `DOCKER_GID`):

```powershell
.\scripts\jenkins-up.ps1
```

Or manually:

```powershell
copy .env.example .env
# Edit .env — set DOCKER_GID to output of: docker run ... stat (see above)
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

| Kind                  | ID                     | Usage |
|-----------------------|------------------------|--------|
| Username + password | `git-manifests-creds` **or** `github-token-creds` | GitHub username + **PAT** with `repo` scope. The [Jenkinsfile](https://github.com/sreekanthgorrela96/argo-example/blob/main/Jenkinsfile) in this repo uses ID **`github-token-creds`**. |
| Username + password | `docker-hub-creds`    | Docker Hub; used with **`docker.withRegistry`** (install **Docker Pipeline** plugin). |

Set the **`DOCKER_IMAGE`** parameter when you build (e.g. `yourhubuser/secureforge-ui`). Do **not** use the placeholder `your-docker-repo/secureforge-ui` — that is not your Docker Hub namespace, and push will fail with `insufficient_scope` / `denied` even if you are logged in.

Optional fallback (same Docker daemon as the host):

```bash
docker login
```

If you log in on the host only, prefer credential **`docker-hub-creds`** so Jenkins runs `docker login` inside the job (durable).

## Create the Pipeline job

1. **New Item** → name e.g. `secureforge-gitops` → **Pipeline** → OK.
2. Enable parameters: check **This project is parameterized** if you created the job without parameters, then add a **String Parameter** named **`DOCKER_IMAGE`** (must match the Jenkinsfile).
3. **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/sreekanthgorrela96/argo-example.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
4. Save → use **Build with Parameters** and set **DOCKER_IMAGE** (e.g. `myuser/secureforge-ui`), then build.

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
| `Could not find credentials docker-hub-creds` | Create a credential with ID **`docker-hub-creds`** exactly (case-sensitive). |
| `git push` **403** / `Permission denied` | PAT missing **write** access, **branch protection** on `main`, or **SSO** not authorized. See [docs/GITHUB-GIT-PUSH-403.md](GITHUB-GIT-PUSH-403.md). |
| `permission denied while trying to connect to the Docker daemon socket` | Wrong **`DOCKER_GID`**. Run the `stat` / `alpine` command above, update `.env`, then `docker compose ... up -d --force-recreate`. Use **`jenkins-up.ps1`** to regenerate `.env`. |
| `docker: not found` inside job | Rebuild image: `docker compose ... build --no-cache`. |
| `git push` fails | PAT must have **repo** scope; credential ID must be exactly **`github-token-creds`** (see [GITHUB-GIT-PUSH-403.md](GITHUB-GIT-PUSH-403.md)). |
| `sed` / `sh` errors | Pipeline must run on the built-in Linux node (default for this container). Do not use Windows batch agents for this Jenkinsfile. The deployment `image:` line must end with **`# secureforge-ci-image`**. |

## Security note

Mounting `docker.sock` gives Jenkins **full control of the host Docker**. Keep this stack **local POC only**.
