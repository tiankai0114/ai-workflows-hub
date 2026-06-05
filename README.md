# ai-workflows-hub

AI 驱动的开发工作流公共库。任何 GitHub repo 通过 Reusable Workflows 引用，零基础设施、零运维。

AI 模型调用基于 **AWS Bedrock（Claude）**，通过 GitHub OIDC 免密钥 assume IAM Role。

---

## 包含内容

### 引用型（`uses:` 直接引用）

| 文件 | 类型 | 说明 |
|------|------|------|
| `.github/actions/claude-bedrock/` | Composite Action | AWS Bedrock Claude 调用核心（OIDC 认证） |
| `.github/actions/jira-handler/` | Composite Action | 调用 Jira REST API 创建 Issue |
| `.github/actions/teams-handler/` | Composite Action | 发送 Teams 通知 |
| `.github/workflows/claude-plan.yml` | Reusable Workflow | PGE Planner — 分析 Issue，自动问答，生成里程碑计划 |
| `.github/workflows/claude-implement.yml` | Reusable Workflow | PGE Generator + Rework — 实现代码，开 PR |
| `.github/workflows/claude-evaluate.yml` | Reusable Workflow | PGE Evaluator + Milestone Advance — 评审 PR，推进里程碑 |
| `.github/workflows/claude-code-review.yml` | Reusable Workflow | Code Review — 人工 PR 的轻量代码审查 |
| `.github/workflows/claude-decompose.yml` | Reusable Workflow | Decomposer — 将大 Issue 拆分为带依赖关系的子 Issue |
| `.github/workflows/cloudwatch-debug.yml` | Reusable Workflow | CloudWatch 日志轮询 → Claude 分析 → Jira/Teams |

### 复制型（从 `templates/` 复制一次）

| 文件 | 说明 |
|------|------|
| `templates/labels.yml` | PGE 标签体系，`gh label import` 导入 |
| `templates/ISSUE_TEMPLATE/` | Issue 模板（prd / bug / change-request） |
| `templates/CLAUDE.md.template` | CLAUDE.md 骨架 |
| `templates/cursor-skills/clean-code/SKILL.md` | 跨项目代码质量基线 |
| `templates/cursor-skills/refactor/SKILL.md` | 跨项目重构协议 |

---

## 接入新 Repo — 完整步骤

### 前提条件

- 目标 repo 已托管在 GitHub
- 有 AWS 账号，且已创建 Bedrock 可用的 IAM Role（见步骤 2）

---

### 步骤 1：复制模板文件

```bash
# 克隆 library
gh repo clone tiankai0114/ai-workflows-hub /tmp/ai-workflows-hub

# 进入目标 repo 根目录
cd /path/to/your-repo

# 复制模板
cp /tmp/ai-workflows-hub/templates/labels.yml .github/labels.yml
cp -r /tmp/ai-workflows-hub/templates/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE
cp /tmp/ai-workflows-hub/templates/CLAUDE.md.template CLAUDE.md
mkdir -p .cursor/skills
cp -r /tmp/ai-workflows-hub/templates/cursor-skills/clean-code .cursor/skills/
cp -r /tmp/ai-workflows-hub/templates/cursor-skills/refactor .cursor/skills/
```

### 步骤 2：配置 AWS IAM Role（Trust Policy）

在 AWS Console 找到用于 Bedrock 的 IAM Role，编辑 **Trust relationships**，加入以下 Statement（替换 `YOUR_ACCOUNT_ID` 和 `YOUR_ORG/YOUR_REPO`）：

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
    }
  }
}
```

> **注意：** `sub` 条件必须包含至少 6 个字符前缀再跟通配符（如 `repo:tiankai0114/search-android-demo-app:*`），不能用 `repo:tiankai0114/*:*` 这样的宽泛通配符，AWS 会拒绝。
>
> 每新增一个 repo 都要在此 Trust Policy 里加一条 `sub` 条件。

IAM Role 还需要附加以下权限 Policy（允许调用 Bedrock）：

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream"
  ],
  "Resource": "*"
}
```

记录 Role ARN，格式为：`arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ROLE_NAME`

---

### 步骤 3：创建 GitHub App（用于 Generator 以 bot 身份提交代码）

> Code Review 和 Decompose 不需要 GitHub App；Plan、Implement、Evaluate 需要。

1. 打开 [github.com/settings/apps/new](https://github.com/settings/apps/new)
2. 填写：
   - **App name**：`your-repo-ci`（建议加 repo 名前缀，全局唯一）
   - **Homepage URL**：`https://github.com/your-org`
   - **Webhook**：取消勾选 Active
3. 设置 **Permissions**（Repository permissions）：
   - Contents: **Read & Write**
   - Issues: **Read & Write**
   - Pull requests: **Read & Write**
4. **Where can this GitHub App be installed**：Only on this account
5. 点击 **Create GitHub App**
6. 记录页面顶部的 **App ID**（数字）
7. 往下滚动，点 **Generate a private key** → 下载 `.pem` 文件

**安装 App 到目标 repo：**

1. 左侧菜单点 **Install App**
2. 点账号旁边的 **Install**
3. 选择 **Only select repositories** → 选目标 repo → 确认

**查询 bot 的数字 User ID：**

```bash
# 把 your-app-name 替换为 App name（小写，空格换连字符）
curl https://api.github.com/users/your-app-name%5Bbot%5D | grep '"id"'
```

或浏览器访问：`https://api.github.com/users/your-app-name[bot]`

记录返回的 `"id"` 值（即 `bot_id`）。

---

### 步骤 4：在目标 repo 添加 Secrets

打开目标 repo → **Settings → Secrets and variables → Actions → New repository secret**：

| Secret 名 | 值 | 必须 |
|-----------|-----|------|
| `GH_APP_ID` | GitHub App 的数字 ID | Plan / Implement / Evaluate |
| `GH_APP_PRIVATE_KEY` | `.pem` 文件完整内容（含头尾行） | Plan / Implement / Evaluate |
| `FIGMA_TOKEN` | Figma Personal Access Token | 可选，有 Figma 设计稿时使用 |

---

### 步骤 5：导入 PGE 标签

```bash
cd /path/to/your-repo
gh label import .github/labels.yml --repo YOUR_ORG/YOUR_REPO
```

> 需要 `gh auth login` 且 token 有 `write:repo` 权限。

---

### 步骤 6：提交 Issue Templates 到默认分支

Issue Templates 必须在默认分支上才在 GitHub 的 "New Issue" 页面生效：

```bash
git add .github/ISSUE_TEMPLATE CLAUDE.md .cursor/
git commit -m "chore: add PGE issue templates, CLAUDE.md and skill files"
git push origin main   # 或 master，视你的默认分支
```

---

### 步骤 7：添加触发 Workflow 文件

在目标 repo 的 `.github/workflows/` 下创建以下文件，替换 `YOUR_ROLE_ARN`、`YOUR_BOT_NAME`、`YOUR_BOT_ID`：

**`pge-code-review.yml`** — 人工 PR 自动代码审查

```yaml
name: "Claude: Code Review"
on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]
jobs:
  review:
    if: |
      !endsWith(github.event.pull_request.user.login, '[bot]') &&
      !contains(github.event.pull_request.title, '[Milestone') &&
      !endsWith(github.event.sender.login, '[bot]')
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-code-review.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
```

**`pge-decompose.yml`** — 将大 Issue 拆分为子 Issue

```yaml
name: "Claude: Decompose"
on:
  issues:
    types: [labeled]
jobs:
  decompose:
    if: github.event.label.name == 'pge/status:decompose'
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-decompose.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
```

**`pge-plan.yml`** — 分析 Issue，生成实现计划

```yaml
name: "Claude: Planner"
on:
  issues:
    types: [labeled]
jobs:
  plan:
    if: github.event.label.name == 'pge/status:ready'
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-plan.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
      bot_id: "YOUR_BOT_ID"
      bot_name: "YOUR_BOT_NAME[bot]"
    secrets:
      figma_token: ${{ secrets.FIGMA_TOKEN }}
```

**`pge-implement.yml`** — 实现代码 + Rework

```yaml
name: "Claude: Generator"
on:
  issues:
    types: [labeled]
  pull_request:
    types: [labeled]
jobs:
  run:
    if: |
      (github.event_name == 'issues' && github.event.label.name == 'pge/status:implement') ||
      (github.event_name == 'pull_request' && github.event.label.name == 'pge/pr:needs-rework')
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-implement.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
      bot_id: "YOUR_BOT_ID"
      bot_name: "YOUR_BOT_NAME[bot]"
      mode: ${{ (github.event_name == 'pull_request' && github.event.label.name == 'pge/pr:needs-rework') && 'rework' || 'implement' }}
      pr_number: ${{ github.event.pull_request.number || '' }}
    secrets:
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
      figma_token: ${{ secrets.FIGMA_TOKEN }}
```

**`pge-evaluate.yml`** — PR 评审 + 里程碑推进

```yaml
name: "Claude: Evaluator"
on:
  pull_request:
    types: [opened, synchronize, closed]
  pull_request_review:
    types: [submitted]
  workflow_dispatch:
    inputs:
      pr_number:
        required: true
        type: string
jobs:
  human-rework:
    if: |
      github.event_name == 'pull_request_review' &&
      github.event.review.state == 'changes_requested' &&
      endsWith(github.event.pull_request.user.login, '[bot]')
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-evaluate.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
      bot_id: "YOUR_BOT_ID"
      bot_name: "YOUR_BOT_NAME[bot]"
      mode: "human-rework"
      pr_number: ${{ github.event.pull_request.number }}
    secrets:
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
  evaluate:
    if: |
      github.event_name == 'workflow_dispatch' ||
      (github.event.action == 'opened' && endsWith(github.event.pull_request.user.login, '[bot]')) ||
      (github.event.action == 'synchronize' && !endsWith(github.event.sender.login, '[bot]') && endsWith(github.event.pull_request.user.login, '[bot]'))
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-evaluate.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
      bot_id: "YOUR_BOT_ID"
      bot_name: "YOUR_BOT_NAME[bot]"
      mode: "evaluate"
      pr_number: ${{ github.event.inputs.pr_number || github.event.pull_request.number }}
    secrets:
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
      figma_token: ${{ secrets.FIGMA_TOKEN }}
  milestone-advance:
    if: |
      github.event.action == 'closed' &&
      github.event.pull_request.merged == true &&
      contains(github.event.pull_request.title, '[Milestone')
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-evaluate.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
      bot_id: "YOUR_BOT_ID"
      bot_name: "YOUR_BOT_NAME[bot]"
      mode: "milestone-advance"
      pr_number: ${{ github.event.pull_request.number }}
    secrets:
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
```

把这些文件 commit 并 push 到默认分支即可生效。

---

## 完整 PGE 工作流

```
创建 Issue（使用 Issue Template）
    ↓
加标签 pge/status:decompose（可选）
    → Claude 自动拆分为带依赖关系的子 Issue
    ↓
给子 Issue 加标签 pge/status:ready
    → Claude Planner 扫描代码库，自动问答（最多 3 轮），输出实现计划
    ↓
确认计划后加标签 pge/status:implement
    → Claude Generator 写代码，以 bot 身份开 PR
    ↓
PR 自动触发 Evaluator
    → build + lint + test + 代码审查
    → 通过：打 pge/pr:approved，推进下一个 Milestone
    → 不通过：打 pge/pr:needs-rework，触发 Generator 自动修复（最多 5 轮）
    ↓
人工 review 并合并 PR
```

---

## CloudWatch 日志监控接入（可选）

```yaml
# .github/workflows/cloudwatch-monitor.yml
name: "CloudWatch Log Monitor"
on:
  schedule:
    - cron: '*/15 * * * *'
  workflow_dispatch:
jobs:
  monitor:
    uses: tiankai0114/ai-workflows-hub/.github/workflows/cloudwatch-debug.yml@v1
    with:
      aws_role: "YOUR_ROLE_ARN"
      log_group: "/aws/lambda/your-function"
      filter_pattern: "ERROR"
      start_time_offset_minutes: 20
      handler: "jira"
      jira_base_url: "https://your-org.atlassian.net"
      jira_project_key: "OPS"
      jira_user_email: "ci-bot@your-org.com"
    secrets:
      jira_api_token: ${{ secrets.JIRA_API_TOKEN }}
```

---

## 版本管理

使用 `@v1` 引用浮动稳定版。主分支持续更新，建议生产环境固定到具体 tag。

```bash
# 发布新版本
git tag v1.x.x && git push origin v1.x.x

# 移动浮动 tag（v1 始终指向最新稳定版）
git tag -f v1 && git push origin v1 --force
```

---

## 参考：demo repo 实际配置值

以 `tiankai0114/search-android-demo-app` 为例（实际值保存在 repo secrets 中，不在此公开）：

| 参数 | 示例格式 |
|------|----|
| `aws_role` | `arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>` |
| `bot_name` | `your-app-name[bot]` |
| `bot_id` | 通过 `https://api.github.com/users/your-app-name[bot]` 查询 `id` 字段 |
| GitHub App ID（`GH_APP_ID`） | GitHub App 创建后页面顶部显示的数字 |
| App name | 创建 GitHub App 时填写的名称 |
