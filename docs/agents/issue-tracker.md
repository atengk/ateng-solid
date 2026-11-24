# Issue 跟踪器与工单协作规范 (GitHub Issues)

本仓库（`atengk/ateng-solid`）使用 **GitHub Issues** 管理跨端工作区规划、全局规格与跨仓协调任务，统一通过 `gh` CLI 操作（标签映射详见 [`triage-labels.md`](./triage-labels.md)）。

> **多仓分工**：跨端蓝图与工作区治理单归属 `atengk/ateng-solid`；后端实现单归属 `atengk/ateng-solid-server`；前端实现单归属 `atengk/ateng-solid-admin-web`；上游底座缺口按 [`foundation-first-gate.md`](./foundation-first-gate.md) 提至对应底座仓库（`ateng-boot` / `ateng-cloud` / `ateng-ui`）。

---

## 1. `gh` CLI 常用操作约定

- **创建工单**：`gh issue create --title "<标题>" --label "<标签>" -F <body-file>`（长文本强制使用 `-F <file>`）
- **查看工单**：`gh issue view <number> --json number,title,body,labels,comments`
- **列表查询**：`gh issue list --state open --label "ready-for-agent" --json number,title,labels,assignees`
- **关联父子工单（Sub-issues）**：`gh issue create --parent <parent> ...` 或 `gh issue edit <parent> --add-sub-issue <child>`；若环境不支持，则在子单顶部注明 `Part of #<parent>`
- **阻塞依赖（Blocking）**：优先使用原生依赖 `gh issue create --blocked-by <n>` 或 `gh issue edit <child> --add-blocked-by <blocker>`；查询未关闭阻塞数：`gh issue view <n> --json blockedBy --jq '[.blockedBy.nodes[] | select(.state == "OPEN")] | length'`；不可用时回退至正文顶部 `Blocked by: #<n>`
- **评论与状态流转**：`gh issue comment <number> -F <file>`、`gh issue edit <number> --add-label "<add>" --remove-label "<remove>"`、`gh issue edit <number> --add-assignee "@me"`
- **关闭工单**：先评论交付说明 `gh issue comment <number> -F <summary-file>`，再执行 `gh issue close <number>`

> **目标仓库校验**：首次执行写操作前可运行 `gh repo view --json nameWithOwner` 确认目标仓库为当前自有仓，严禁向第三方插件上游误提单。

---

## 2. Windows PowerShell 避坑铁律与 Git 授权停止门禁

1. **特殊字符双引号包裹**：在 Windows PowerShell 中，包含 `@`、`,` 的参数必须加双引号（如 `--add-assignee "@me"`），避免被解析为 Splatting 变量。
2. **多行正文强制 `-F <file>`**：创建 Issue 或回写报告时严禁命令行拼接多行字符串，必须先写入会话 Scratch 临时文件（禁止污染项目目录）再通过 `-F <file>` 传入，确保 UTF-8 编码无乱码、无本地盘符泄漏。
3. **显式两级 Git 授权门禁**：未收到用户明确“提交/commit”或“推送/push”指令前，修改默认停留在本地工作区，严禁擅自提交、推送或关闭远端 Issue。

---

## 3. 外部 PR 分诊开关与 Wayfinding 约定

- **PRs as a request surface: no.**（默认不将外部 PR 作为需求分诊入口；若后续需要开放可改为 `yes`）。
- **Wayfinding 操作（`/wayfinder`）**：
  - 路线图主单标注 `wayfinder:map`，承载 Notes / Decisions-so-far / Fog；
  - 子工单通过父子关联或 `Part of #<map>` 挂载，标注 `wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）；
  - 认领首动作执行 `gh issue edit <n> --add-assignee "@me"`；完成后评论结论、关单并将决策指针追加回 Map。
