# 🤖 ai-workflows-hub Onboarding Guide

[简体中文](./onboarding.zh-CN.md) · English

> Integrate the AI-driven development workflow (PGE) into any GitHub repo.
>
> First prepare all files with **one command**, then complete a few cloud configurations that cannot be scripted. Once done, just add a label to an Issue and AI will write code, open PRs, and review them.

`AWS Bedrock` · `GitHub Actions` · `Claude`

| ⚡ File prep | 🔧 Manual cloud config | 🔁 Reusable |
| --- | --- | --- |
| 1 command / ~1 min | ~20 min | Onboard each new repo independently |

The process has two parts: ① the script copies all files automatically; ② the AWS Role / GitHub App / Secrets / Actions permissions must be done manually in the consoles. The **AWS Role requires someone else to configure it, so kick it off first**.

---

## 📦 Part 1 · One-Command File Prep (automated by script)

### Step 1 · Run the install script

From your target repo root, run the `install.sh` provided by the hub. It copies the labels, Issue templates, 5 PGE workflows, the verify script, all SKILLs, and `CLAUDE.md` into place in one go.

```bash
# 1) Clone the hub into a temp directory
git clone https://github.com/tiankai0114/ai-workflows-hub.git /tmp/ai-workflows-hub

# 2) Go to your repo root and run the install script
cd /path/to/your-repo
bash /tmp/ai-workflows-hub/scripts/install.sh
```

> [!NOTE]
> The script **only prepares files**. It does not touch any GitHub / AWS cloud configuration and is safe to re-run. After the copy completes, move on to Part 2 for the manual configuration.

The script prepares the following files automatically:

- ✅ `.github/labels.yml` — PGE label definitions
- ✅ `.github/ISSUE_TEMPLATE/` — 3 Issue templates (prd / change-request / bug)
- ✅ `.github/workflows/pge-*.yml` — 5 trigger workflows (decompose / plan / implement / code-review / evaluate)
- ✅ `.github/scripts/pge-verify.sh` — an executable placeholder verify script (replace with real build/lint/test later)
- ✅ `.cursor/skills/` — all 7 SKILLs (clean-code, refactor, frontend, backend, api-design, testing, security)
- ✅ `CLAUDE.md` — copied from template (skipped if it already exists; use `--force` to overwrite)

---

## 🔧 Part 2 · Cloud Configuration (manual)

### Step 2 · Request AWS Bedrock Role permissions

For first-time onboarding, you only need to ask the relevant team to add your repo to the Role's OIDC trust policy (a one-time operation).

> [!WARNING]
> This step depends on someone configuring it in the AWS console, so it is an **asynchronous, blocking item**. **Kick it off first**; the remaining steps (3~8) can proceed in parallel — no need to wait idly. Until this Role is configured, the workflows cannot call Bedrock.

- Contact the **Build/Release team**, or email `ktian@telenavsoftware.com`
- Provide your full repo name `YOUR_ORG/YOUR_REPO` so it can be added to the Role's trust policy
- Once configured, the workflows can assume the Role via GitHub OIDC to call Bedrock

### Step 3 · Create a GitHub App (Bot)

The Generator / Evaluator need to commit code and open PRs as a bot. Code Review, Decompose, and Plan do not need the App private key.

- Open [github.com/settings/apps/new](https://github.com/settings/apps/new)
- **App name**: a globally unique name; prefixing with the repo name is recommended (e.g. `your-repo-ci`)
- **Homepage URL**: your repo URL is fine
- **Webhook**: uncheck Active
- **Permissions** → Contents: Read & Write, Issues: Read & Write, Pull requests: Read & Write
- **Where installed**: Only on this account
- Click **Create GitHub App** and record the **App ID** at the top of the page
- Click **Generate a private key** and download the `.pem` file
- In the left menu, click **Install App** → install it on the target repo
- Look up the bot user ID (see the command below) and record the returned `"id"` value

```bash
# Look up the bot user ID (replace your-app-name)
curl https://api.github.com/users/your-app-name%5Bbot%5D | grep '"id"'

# Or open in a browser:
# https://api.github.com/users/your-app-name[bot]
```

> [!NOTE]
> Replace spaces in the App name with `-`, lowercase everything, and append the `[bot]` suffix to form the bot username.

### Step 4 · Add Secrets to the target repo

Open the target repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value | Required |
| --- | --- | --- |
| `GH_APP_ID` | The GitHub App's numeric ID | **Required** (Implement / Evaluate) |
| `GH_APP_PRIVATE_KEY` | Full contents of the `.pem` file (including the `-----BEGIN RSA PRIVATE KEY-----` header/footer lines) | **Required** (Implement / Evaluate) |
| `FIGMA_TOKEN` | Figma Personal Access Token | Optional (when you have Figma designs) |

> [!NOTE]
> Code Review, Decompose, and Plan only need the AWS Role ARN (written in the workflow); they do **not** need `GH_APP_ID` / `GH_APP_PRIVATE_KEY`.

### Step 5 · Enable Actions write permissions

The Generator / Evaluator need to create branches and open PRs as Actions, so you must grant permissions in the repo settings — otherwise the workflows will fail due to insufficient permissions.

Open the target repo → **Settings → Actions → General → Workflow permissions**, then:

- Select **Read and write permissions**
- Check **Allow GitHub Actions to create and approve pull requests**
- Click **Save**

> [!IMPORTANT]
> "Allow GitHub Actions to create and approve pull requests" is a repo-level switch. Even if the workflow declares `permissions`, it cannot override this, so this step must be enabled manually in the console.

### Step 6 · Replace placeholders and fill in content

A few placeholders / placeholder content in the copied files need to be filled in per your project.

**① Globally replace the bot placeholders in `.github/workflows/pge-*.yml`** (they appear in the plan / implement / evaluate files, with identical values):

| Placeholder | Replace with |
| --- | --- |
| `YOUR_BOT_ID` | The numeric user ID from Step 3 |
| `your-app[bot]` | The GitHub App bot username, e.g. `my-app-ci[bot]` |

> [!NOTE]
> `aws_role` is pre-filled with the shared Bedrock Role and **does not need to be replaced** (see Step 2 for its permission request). The decompose / code-review files have no bot placeholders and need no changes.

**② Fill in `CLAUDE.md`** — tech stack, architecture constraints, key commands, SKILL index (the AI agent's "brain" — the more detail, the better).

**③ `.github/scripts/pge-verify.sh`** — a placeholder script that just prints success by default; if needed, replace it with your own verification script.

### Step 7 · Import PGE labels

Import the PGE label system into the target repo — every workflow trigger depends on these labels. This step requires `gh` (GitHub CLI) and `ruby`. If `gh` is not installed locally, install it first (macOS ships ruby). Use `gh --version` to check whether it is installed.

```bash
# If gh is not installed, install it first (pick what fits your system)
brew install gh                 # macOS (Homebrew)
sudo apt install gh             # Debian / Ubuntu
# For other systems see https://github.com/cli/cli#installation

# Make sure the gh CLI is logged in (it will ask for a token — create one as prompted)
# When creating the token, choose Generate new token (classic) and check read:org, repo
gh auth login

# From your repo root, run the import script the hub provides (auto-detects owner/repo)
bash /tmp/ai-workflows-hub/scripts/import-labels.sh
```

### Step 8 · Commit to the default branch

Reusable workflow references, Issue templates, and labels only take effect on the **default branch** (main / master).

- Commit all the files copied by the script and filled in
- Push to the default branch
- Open the repo → Issues → New issue and confirm the template list appears

```bash
git add .github .cursor CLAUDE.md
git commit -m "chore: integrate ai-workflows-hub PGE"
git push origin main
```

---

## ✅ The Full Workflow After Onboarding

```
Create an Issue (using an Issue Template)
  ↓ Add label pge/status:ready
      [Claude Planner] scans the codebase → auto Q&A (≤3 rounds) → outputs a milestone plan
  ↓ Confirm the plan → add label pge/status:implement
      [Claude Generator] writes code → opens a PR as the bot
  ↓ The PR automatically triggers pge/pr:approved or pge/pr:needs-rework
      [Claude Evaluator] runs pge-verify.sh (build + lint + test) + code review → advances to the next Milestone if it passes
  ↓ Human review and merge the PR
```

---

## 📌 Demo Repo Reference Config (tiankai0114/search-android-demo-app)

> The following 4 items are just an example, for reference.

| Parameter | Value |
| --- | --- |
| `bot_name` | `ai-test-kai[bot]` |
| `bot_id` | `290981734` |
| GitHub App ID (`GH_APP_ID`) | `3969724` |
| App name | `ai-test-kai` |
