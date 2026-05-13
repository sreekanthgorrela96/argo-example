# Fixing `git push` 403 from Jenkins to GitHub

If the pipeline logs:

```text
remote: Permission to OWNER/REPO.git denied to USERNAME.
fatal: unable to access 'https://github.com/...': The requested URL returned error: 403
```

Docker and the manifest **sed** step already worked; only **push** to GitHub failed.

## 1. Personal access token (PAT) permissions

The Jenkins credential used in **`github-token-creds`** must allow **writing** to this repository.

### Classic PAT ([GitHub → Settings → Developer settings](https://github.com/settings/tokens))

Enable scope **`repo`** (Full control of private repositories). Read-only or “public only” tokens cannot push to `main`.

### Fine-grained PAT

- **Repository access:** include **`sreekanthgorrela96/argo-example`** (or the whole org if appropriate).
- **Permissions → Repository permissions → Contents:** **Read and write**.

Regenerate the token after changing scopes, then update the Jenkins credential.

## 2. Branch protection on `main`

If **Settings → Rules / Branch protection** requires pull requests or restricts who can push, a PAT that is not allowed to bypass those rules will get **403**.

Options:

- Allow the account that owns the PAT to push to `main`, or  
- Add a **ruleset bypass** for that actor (org/repo policy permitting), or  
- Change the pipeline to push to a branch like `ci/manifest-updates` and merge via PR (more setup).

## 3. SSO (organizations)

If the repo is under an **SSO-enforced** org, open the token in GitHub → **Configure SSO** → **Authorize** for that org.

## 4. Jenkins credential type

The [Jenkinsfile](../Jenkinsfile) expects **`usernamePassword`**: password field = PAT. The clone URL uses **`x-access-token:${GIT_TOKEN}`**, which matches [GitHub’s HTTPS guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#using-a-personal-access-token-on-the-command-line).

If you use **Secret text** only, switch the pipeline to a `string` binding or keep **usernamePassword** with any username and the PAT in the password field.

## 5. Remote URL stripped before push

Some Git versions store `origin` **without** credentials after clone, so `git push` can hit GitHub without the PAT and return **403**. The Jenkinsfile runs `git remote set-url origin` to the `x-access-token` URL immediately before `git push`. If 403 persists after that change, focus on sections 1–3 (token scopes, branch protection, SSO).
