# Jenkins Setup

This directory provisions a Jenkins master that runs the pipeline defined in the
repository root [`Jenkinsfile`](../Jenkinsfile).

## 1. Start Jenkins

```bash
cd jenkins
docker compose up -d --build
```

On first boot, Jenkins installs the plugins listed in `plugins.txt`.

Unlock it:

```bash
docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Open http://localhost:8080, paste the password, and create an admin user.

## 2. Required credentials

Create these under **Manage Jenkins → Credentials → System → Global credentials**:

| ID          | Kind                    | Purpose                                  |
|-------------|-------------------------|------------------------------------------|
| `env-b-ssh` | SSH Username with private key | Deploy to Environment B (Oracle Cloud VM) |

> Environment A defaults to `localhost`, so it needs no SSH credential.
> Until Phase 6 provisions the Oracle VM, leave the `ENV_B_HOST` build parameter
> blank — the `Deploy Environment B` stage is skipped automatically.

## 3. Create the pipeline job

Option A (recommended) — **Multibranch Pipeline**:
1. **New Item → Multibranch Pipeline**
2. *Branch Sources → Add source → GitHub*
3. Set *Repository HTTPS URL* to `https://github.com/<you>/cobol-banking-app`
4. Add a GitHub credential if the repo is private (it is public in this project)
5. Save. Jenkins discovers and builds every branch containing a `Jenkinsfile`.

Option B — **Pipeline**:
1. **New Item → Pipeline**
2. *Definition → Pipeline script from SCM*
3. *SCM → Git*, set the repository URL and branch `*/main`
4. Save.

## 4. Build triggers

- **Webhook (recommended):** in the GitHub repo **Settings → Webhooks → Add webhook**,
  set the payload URL to `http://<jenkins-host>:8080/github-webhook/` (or the
  multibranch `.../multibranch-webhook-trigger/invoke?token=...`), content type
  `application/json`, event *Just the push event*. Requires the Jenkins host to
  be reachable from GitHub (use a tunnel like ngrok for a local Jenkins).
- **SCM polling (no inbound access needed):** in the job's *Build Triggers*,
  enable **Poll SCM** with a schedule such as `H/5 * * * *`.

## 5. Agent requirements

The Jenkins agent running the pipeline must be able to:

- reach the CI mainframe's **JES2 reader (port 3505)** and **web syslog (port 8038)**
  — set `MF_HOST` / `SYSLOG_URL` parameters if the mainframe is not on the agent;
- run `python3` (3.8+);
- for Environment A, find the TK5 printer file (or set `TK5_PRINTER`).

Environment A ("localhost") assumes native TK5 is running on the agent per
`setup_tk5.sh` + `run_hercules.sh` (see `how-to-run-tk5.md`).

## 6. Build Time capture

Jenkins records per-stage durations automatically (the `timestamps()` option adds
console timestamps). The pipeline additionally writes in-run wall-clock timers to
`results/*-timing.json`, which feed the **Build Time** metric in the report.
