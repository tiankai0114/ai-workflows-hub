# ai-workflows-hub

AI-driven development workflow library. 供任何 GitHub repo 通过 Reusable Workflows 引用，零基础设施、零运维。

## 包含内容

### 引用型（`uses:` 直接引用）

| 文件 | 类型 | 说明 |
|------|------|------|
| `.github/actions/claude-bedrock/` | Composite Action | Claude via LiteLLM 调用核心（兼容 Anthropic API） |
| `.github/actions/jira-handler/` | Composite Action | 调用 Jira REST API 创建 Issue |
| `.github/actions/teams-handler/` | Composite Action | 发送 Teams 通知 |
| `.github/workflows/claude-plan.yml` | Reusable Workflow | PGE Planner — 分析 Issue，生成里程碑计划 |
| `.github/workflows/claude-implement.yml` | Reusable Workflow | PGE Generator + Rework — 实现代码 |
| `.github/workflows/claude-evaluate.yml` | Reusable Workflow | PGE Evaluator + Milestone Advance — 评审 PR |
| `.github/workflows/claude-code-review.yml` | Reusable Workflow | Code Review — 人工 PR 的轻量代码审查 |
| `.github/workflows/claude-decompose.yml` | Reusable Workflow | Decomposer — 将大 Issue 拆分为子 Issue |
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

## 接入新 Repo 步骤

### 1. 复制模板文件

```bash
# 从 ai-library 仓库克隆或下载 templates/ 目录
gh repo clone tiankai0114/ai-workflows-hub /tmp/ai-workflows-hub

# 复制模板到目标 repo
cp /tmp/ai-workflows-hub/templates/labels.yml .github/labels.yml
cp -r /tmp/ai-workflows-hub/templates/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE
cp /tmp/ai-workflows-hub/templates/CLAUDE.md.template CLAUDE.md
mkdir -p .cursor/skills
cp -r /tmp/ai-workflows-hub/templates/cursor-skills/clean-code .cursor/skills/
cp -r /tmp/ai-workflows-hub/templates/cursor-skills/refactor .cursor/skills/
```

### 2. 导入 PGE 标签

```bash
gh label import .github/labels.yml
```

### 3. 填写 CLAUDE.md

编辑 `CLAUDE.md`，填入项目描述、子模块结构、开发规范、key commands 等内容。这是 AI Agent 的"知识库"，内容越详细效果越好。

### 4. 添加 LiteLLM API Key Secret

在目标 repo 的 **Settings → Secrets and variables → Actions** 中添加：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `LITELLM_API_KEY` | `sk-xxxx...` | LiteLLM 分配的 API Key（即 `ANTHROPIC_AUTH_TOKEN`） |

> 所有 workflow 通过 `secrets: api_key: ${{ secrets.LITELLM_API_KEY }}` 传入，  
> action 内部自动设置 `ANTHROPIC_API_KEY` 和 `ANTHROPIC_BASE_URL` 环境变量。

### 5. 创建 GitHub App

1. 在 GitHub 创建一个 App（Settings → Developer settings → GitHub Apps）
2. 授权：Issues: Read & Write, Pull Requests: Read & Write, Contents: Read & Write
3. 安装到目标 repo
4. 获取 App ID 和 Private Key
5. 在 repo Secrets 中添加：
   - `GH_APP_ID` — App 的数字 ID
   - `GH_APP_PRIVATE_KEY` — App 的 Private Key（PEM 格式）
6. 获取 Bot 的 User ID：`gh api users/YOUR_APP_NAME%5Bbot%5D --jq .id`

### 6. 添加触发文件

在目标 repo 创建 `.github/workflows/` 文件，调用 library：

```yaml
# .github/workflows/pge-plan.yml
name: "Claude: Planner"
on:
  issues:
    types: [labeled]
jobs:
  plan:
    if: github.event.label.name == 'pge/status:ready'
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-plan.yml@v1
    with:
      bot_name: "your-app-name[bot]"
      bot_id: "YOUR_BOT_ID"
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
      figma_token: ${{ secrets.FIGMA_TOKEN }}
```

```yaml
# .github/workflows/pge-implement.yml
name: "Claude: Generator"
on:
  issues:
    types: [labeled]
  pull_request:
    types: [labeled]
jobs:
  implement:
    if: |
      (github.event_name == 'issues' && github.event.label.name == 'pge/status:implement') ||
      (github.event_name == 'pull_request' && github.event.label.name == 'pge/pr:needs-rework')
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-implement.yml@v1
    with:
      bot_name: "your-app-name[bot]"
      bot_id: "YOUR_BOT_ID"
      mode: ${{ github.event.label.name == 'pge/pr:needs-rework' && 'rework' || 'implement' }}
      pr_number: ${{ github.event.pull_request.number || '' }}
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
      figma_token: ${{ secrets.FIGMA_TOKEN }}
```

```yaml
# .github/workflows/pge-evaluate.yml
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
      bot_name: "your-app-name[bot]"
      bot_id: "YOUR_BOT_ID"
      mode: "human-rework"
      pr_number: ${{ github.event.pull_request.number }}
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
  evaluate:
    if: |
      github.event_name == 'workflow_dispatch' ||
      (github.event.action == 'opened' && endsWith(github.event.pull_request.user.login, '[bot]')) ||
      (github.event.action == 'synchronize' && !endsWith(github.event.sender.login, '[bot]') && endsWith(github.event.pull_request.user.login, '[bot]'))
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-evaluate.yml@v1
    with:
      bot_name: "your-app-name[bot]"
      bot_id: "YOUR_BOT_ID"
      mode: "evaluate"
      pr_number: ${{ github.event.inputs.pr_number || github.event.pull_request.number }}
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
      figma_token: ${{ secrets.FIGMA_TOKEN }}
  milestone-advance:
    if: github.event.action == 'closed' && github.event.pull_request.merged == true && contains(github.event.pull_request.title, '[Milestone')
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-evaluate.yml@v1
    with:
      bot_name: "your-app-name[bot]"
      bot_id: "YOUR_BOT_ID"
      mode: "milestone-advance"
      pr_number: ${{ github.event.pull_request.number }}
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
      github_app_id: ${{ secrets.GH_APP_ID }}
      github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
```

```yaml
# .github/workflows/pge-code-review.yml
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
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
```

```yaml
# .github/workflows/pge-decompose.yml
name: "Claude: Decompose"
on:
  issues:
    types: [labeled]
jobs:
  decompose:
    if: github.event.label.name == 'pge/status:decompose'
    uses: tiankai0114/ai-workflows-hub/.github/workflows/claude-decompose.yml@v1
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
```

---

## CloudWatch 日志监控接入

```yaml
# .github/workflows/cloudwatch-monitor.yml
name: "CloudWatch Log Monitor"
on:
  schedule:
    - cron: '*/15 * * * *'  # 每 15 分钟轮询一次
  workflow_dispatch:
jobs:
  monitor:
    uses: tiankai0114/ai-workflows-hub/.github/workflows/cloudwatch-debug.yml@v1
    with:
      aws_role: "arn:aws:iam::YOUR_ACCOUNT:role/your-cw-read-role"
      log_group: "/aws/lambda/your-function"
      filter_pattern: "ERROR"
      start_time_offset_minutes: 20
      handler: "jira"
      jira_base_url: "https://your-org.atlassian.net"
      jira_project_key: "OPS"
      jira_user_email: "ci-bot@your-org.com"
    secrets:
      api_key: ${{ secrets.LITELLM_API_KEY }}
      jira_api_token: ${{ secrets.JIRA_API_TOKEN }}
```

---

## 版本说明

使用 `@v1` 引用稳定版本。主分支持续更新，建议生产环境固定到 tag。

```bash
# 发布新版本
git tag v1.x.x
git push origin v1.x.x

# 移动 floating tag (推荐)
git tag -f v1
git push origin v1 --force
```
