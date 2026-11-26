# Issue 跟踪器与工单协作规范 (GitHub Issues)

本项目统一使用根仓库 **`atengk/ateng-solid`** 的 **GitHub Issues** 集中管理全部跨端规划、Wayfinder 路线图决策单与各端编码实现工单（`ready-for-agent`），通过 `gh` CLI 操作（标签映射详见 [`triage-labels.md`](./triage-labels.md)）。

> **单仓统一工单 + 多仓物理隔离源码（2026-11-24 确立）**：
> - **统一工单入口**：全部规划决策单（`wayfinder:*`）与编码实现单（`ready-for-agent`）均集中创建、追踪并串联原生 `blockedBy` 依赖链于 **`atengk/ateng-solid`**；实现工单标题统一加代码归属前缀：
>   - `[server]`：代码落地于独立仓库 `ateng-solid-server`；
>   - `[admin-web]`：代码落地于独立仓库 `ateng-solid-admin-web`；
>   - `[fullstack]`：跨仓联调冒烟、发版锁版或根仓治理任务；
> - **源码独立提交**：代码开发、本地测试、Git 提交与推送仍严格在各自独立子仓执行，严禁将子仓源码提交到根仓；
> - **上游底座缺口例外**：发现 `ateng-boot`、`ateng-cloud`、`ateng-ui` 基础设施缺失或缺陷时，按 [`foundation-first-gate.md`](./foundation-first-gate.md) 直接提至对应上游底座仓库（`atengk/ateng-boot` / `atengk/ateng-cloud` / `atengk/ateng-ui`）。

---

## 1. `gh` CLI 常用操作约定

> 在子仓库目录（如 `ateng-solid-server/`、`ateng-solid-admin-web/`）执行工单读写时，**必须显式附加 `-R atengk/ateng-solid`**，避免误建或查错目标仓库。

- **创建工单**：`gh issue create -R atengk/ateng-solid --title "<标题>" --label "<标签>" -F <body-file>`（长文本强制使用 `-F <file>`）
- **查看工单**：`gh issue view <number> -R atengk/ateng-solid --json number,title,body,labels,comments`
- **列表查询**：`gh issue list -R atengk/ateng-solid --state open --label "ready-for-agent" --json number,title,labels,assignees`
- **关联父子工单（Sub-issues）**：`gh issue create -R atengk/ateng-solid --parent <parent> ...` 或 `gh issue edit <parent> -R atengk/ateng-solid --add-sub-issue <child>`；若环境不支持，则在子单顶部注明 `Part of #<parent>`
- **阻塞依赖（Blocking）**：优先使用原生依赖 `gh issue create -R atengk/ateng-solid --blocked-by "<n1>,<n2>"` 或 `gh issue edit <child> -R atengk/ateng-solid --add-blocked-by <blocker>`；查询未关闭阻塞数：`gh issue view <n> -R atengk/ateng-solid --json blockedBy --jq '[.blockedBy.nodes[] | select(.state == "OPEN")] | length'`；不可用时回退至正文顶部 `Blocked by: #<n>`
- **评论与状态流转**：`gh issue comment <number> -R atengk/ateng-solid -F <file>`、`gh issue edit <number> -R atengk/ateng-solid --add-label "<add>" --remove-label "<remove>"`、`gh issue edit <number> -R atengk/ateng-solid --add-assignee "@me"`
- **关闭工单**：先评论交付说明 `gh issue comment <number> -R atengk/ateng-solid -F <summary-file>`，再执行 `gh issue close <number> -R atengk/ateng-solid`（`[server]` / `[admin-web]` 功能与缺陷单只要关联底座改动已提交底座 `dev` 且通过底座单测、本仓已提交 `dev` 且本地全量测试通过即可关单；发版锁版统一由发版收口单追踪）

> **目标仓库校验**：首次执行写操作前确认目标仓库为 `atengk/ateng-solid`（底座缺口单除外），严禁向第三方插件上游误提单。

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
