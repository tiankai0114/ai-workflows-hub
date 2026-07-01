# 🤖 ai-workflows-hub 接入指南

简体中文 · [English](./onboarding.en.md)

> 将 AI 驱动的开发工作流（PGE）集成到任意 GitHub Repo
>
> 先用**一条命令**准备好所有文件，再完成几项无法脚本化的云端配置即可。完成后给 Issue 加标签，AI 自动写代码、开 PR、评审。

`AWS Bedrock` · `GitHub Actions` · `Claude`

| ⚡ 文件准备 | 🔧 云端手动配置 | 🔁 可复用 |
| --- | --- | --- |
| 1 条命令 / 约 1 分钟 | 约 20 分钟 | 每个新 Repo 独立接入 |

流程分两部分：① 脚本自动复制所有文件；② AWS Role / GitHub App / Secrets / Actions 权限等需人工在控制台完成。其中 **AWS Role 需他人配置，建议第一时间发起**。

---

## 📦 第一部分 · 一键准备文件（脚本自动完成）

### 步骤 1 · 运行安装脚本

在你的目标 repo 根目录运行 hub 提供的 `install.sh`，它会把标签、Issue 模板、5 个 PGE workflow、验证脚本、全部 SKILL 和 `CLAUDE.md` 一次性复制到位。

```bash
# 1) 克隆 hub 到临时目录
git clone https://github.com/tiankai0114/ai-workflows-hub.git /tmp/ai-workflows-hub

# 2) 进入你的 repo 根目录，运行安装脚本
cd /path/to/your-repo
bash /tmp/ai-workflows-hub/scripts/install.sh
```

> [!NOTE]
> 脚本**只做文件准备**，不会改动任何 GitHub / AWS 云端配置，可安全重复运行。复制完成后，进入第二部分完成人工配置。

脚本自动完成以下文件准备：

- ✅ `.github/labels.yml` — PGE 标签定义
- ✅ `.github/ISSUE_TEMPLATE/` — 3 个 Issue 模板（prd / change-request / bug）
- ✅ `.github/workflows/pge-*.yml` — 5 个触发 workflow（decompose / plan / implement / code-review / evaluate）
- ✅ `.github/scripts/pge-verify.sh` — 可执行的验证脚本占位（需后续改成真实 build/lint/test）
- ✅ `.cursor/skills/` — 全部 7 个 SKILL（clean-code、refactor、frontend、backend、api-design、testing、security）
- ✅ `CLAUDE.md` — 从模板复制（若已存在则跳过，可加 `--force` 覆盖）

---

## 🔧 第二部分 · 云端配置（需人工完成）

### 步骤 2 · 申请 AWS Bedrock Role 权限

首次接入时，只需联系相关团队把该 Role 的 OIDC 信任策略配置到你的 repo 即可（一次性操作）。

> [!WARNING]
> 此步骤依赖他人在 AWS 控制台配置，属于**异步等待项**。请**第一时间发起**，其余步骤（3~8）可并行进行，无需干等。在此 Role 配置好之前，workflow 无法调用 Bedrock。

- 联系 **Build/Release team**，或邮件 `ktian@telenavsoftware.com`
- 提供你的 repo 全名 `YOUR_ORG/YOUR_REPO`，用于加入 Role 的信任策略
- 配置完成后，workflow 即可通过 GitHub OIDC assume 该 Role 调用 Bedrock

### 步骤 3 · 创建 GitHub App（Bot）

Generator / Evaluator 需要以 bot 身份提交代码和开 PR。Code Review、Decompose 和 Plan 不需要 App 私钥。

- 打开 [github.com/settings/apps/new](https://github.com/settings/apps/new)
- **App name**：填写全局唯一名称，建议加 repo 名前缀（如 `your-repo-ci`）
- **Homepage URL**：填入自己的 repo 地址即可
- **Webhook**：取消勾选 Active
- **Permissions** → Contents: Read & Write、Issues: Read & Write、Pull requests: Read & Write
- **Where installed**：Only on this account
- 点击 **Create GitHub App**，记录页面顶部的 **App ID**
- 点 **Generate a private key**，下载 `.pem` 文件
- 左侧菜单点 **Install App** → 安装到目标 repo
- 查询 bot user ID（见下方命令），记录返回的 `"id"` 值

```bash
# 查询 bot user ID（替换 your-app-name）
curl https://api.github.com/users/your-app-name%5Bbot%5D | grep '"id"'

# 或者浏览器访问：
# https://api.github.com/users/your-app-name[bot]
```

> [!NOTE]
> App name 中的空格要换成 `-`，全小写拼接 `[bot]` 后缀即是 bot username。

### 步骤 4 · 在目标 Repo 添加 Secrets

打开目标 repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret 名 | 值 | 必须 |
| --- | --- | --- |
| `GH_APP_ID` | GitHub App 的数字 ID | **必须**（Implement / Evaluate） |
| `GH_APP_PRIVATE_KEY` | `.pem` 文件完整内容（含 `-----BEGIN RSA PRIVATE KEY-----` 头尾行） | **必须**（Implement / Evaluate） |
| `FIGMA_TOKEN` | Figma Personal Access Token | 可选（有 Figma 设计稿时使用） |

> [!NOTE]
> Code Review、Decompose 和 Plan 只需要 AWS Role ARN（写在 workflow 里），**不需要** `GH_APP_ID` / `GH_APP_PRIVATE_KEY`。

### 步骤 5 · 开启 Actions 的写权限

Generator / Evaluator 需要以 Actions 身份创建分支、开 PR，必须在 repo 设置里放开权限，否则 workflow 会因权限不足而失败。

打开目标 repo → **Settings → Actions → General → Workflow permissions**，然后：

- 选中 **Read and write permissions**
- 勾选 **Allow GitHub Actions to create and approve pull requests**
- 点击 **Save** 保存

> [!IMPORTANT]
> 「允许 Actions 创建 PR」是仓库级开关，即使 workflow 里已声明 `permissions` 也无法覆盖它，因此这一步必须在控制台手动开启。

### 步骤 6 · 替换占位符并填写内容

脚本复制的文件里有几处占位符 / 占位内容需要按项目实际填写。

**① 全局替换 `.github/workflows/pge-*.yml` 里的 bot 占位符**（出现在 plan / implement / evaluate 三个文件，值完全一致）：

| 占位符 | 替换为 |
| --- | --- |
| `YOUR_BOT_ID` | 步骤 3 查到的数字 user ID |
| `your-app[bot]` | GitHub App bot username，如 `my-app-ci[bot]` |

> [!NOTE]
> `aws_role` 已预填共享 Bedrock Role，**无需替换**（其权限申请见步骤 2）。decompose / code-review 两个文件没有 bot 占位符，无需改动。

**② 填写 `CLAUDE.md`** — 技术栈、架构约束、关键命令、SKILL 索引（AI agent 的"大脑"，越详细效果越好）

**③ `.github/scripts/pge-verify.sh`** — 默认是输出成功的占位脚本，如果你有需求，可以改成你自己的校验脚本

### 步骤 7 · 导入 PGE 标签

将 PGE 标签体系导入到目标 repo，后续所有 workflow 触发都依赖这些标签。此步骤依赖 `gh`（GitHub CLI）和 `ruby`，若本地尚未安装 `gh`，请先安装（macOS 自带 ruby），可用 `gh --version` 确认是否已安装。

```bash
# 若未安装 gh，先安装（任选适合你系统的方式）
brew install gh                 # macOS (Homebrew)
sudo apt install gh             # Debian / Ubuntu
# 其他系统见 https://github.com/cli/cli#installation

# 确保 gh CLI 已登录（执行时会要求一个 token，按提示创建即可）
# 创建 token 时选择 Generate new token (classic)，权限勾选 read:org、repo
gh auth login

# 在你的 repo 根目录运行 hub 提供的导入脚本（自动识别 owner/repo）
bash /tmp/ai-workflows-hub/scripts/import-labels.sh
```

### 步骤 8 · 提交到默认分支

Reusable workflow 引用、Issue 模板、标签都必须在**默认分支**（main / master）上才会生效。

- 提交脚本复制并填写好的全部文件
- 推送到默认分支
- 打开 repo → Issues → New issue，确认模板列表出现

```bash
git add .github .cursor CLAUDE.md
git commit -m "chore: integrate ai-workflows-hub PGE"
git push origin main
```

---

## ✅ 接入完成后的完整工作流

```
创建 Issue（使用 Issue Template）
  ↓ 加标签 pge/status:ready
      [Claude Planner] 扫描代码库 → 自动问答（≤3 轮）→ 输出里程碑计划
  ↓ 确认计划 → 加标签 pge/status:implement
      [Claude Generator] 写代码 → 以 bot 身份开 PR
  ↓ PR 自动触发 pge/pr:approved 或 pge/pr:needs-rework
      [Claude Evaluator] 执行 pge-verify.sh（build + lint + test）+ 代码审查 → 通过则推进下一 Milestone
  ↓ 人工 review 并合并 PR
```

---

## 📌 demo repo 实际配置参考（tiankai0114/search-android-demo-app）

> 以下 4 项仅为一个示例，供参考。

| 参数 | 值 |
| --- | --- |
| `bot_name` | `ai-test-kai[bot]` |
| `bot_id` | `290981734` |
| GitHub App ID（`GH_APP_ID`） | `3969724` |
| App name | `ai-test-kai` |
