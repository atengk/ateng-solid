# ateng-solid 聚合工作区总控规范 (AGENTS.md)

本仓库为 **ateng-solid** 全端开源上层应用框架的聚合工作区（Polyrepo Workspace），以完全独立通用的 `ateng-boot`、`ateng-ui` 为基础设施底座，并面向 `ateng-cloud` 微服务体系设计同源并存演进边界。

> **独立子仓与三层生态定位**：本文件作为根工作区总控入口；每个已启用子仓库均配置了**独立完整自洽的 `AGENTS.md`** 及配套治理文件。全体系严格遵守“**第一层：通用独立底座 ➔ 第二层：`ateng-solid` 零补丁上层框架内核 ➔ 第三层：二开行业业务扩展**”边界（详见 [`.agents/rules/foundation-first-gate.md`](./.agents/rules/foundation-first-gate.md) 与 [ADR-0004](./docs/adr/0004-foundation-driven-framework-coevolution.md)）。

---

## 1. 工程矩阵与技术基线

| 目录 | 独立仓库 | 定位与技术基线 | 状态 |
| :--- | :--- | :--- | :--- |
| [`./ateng-solid-server`](./ateng-solid-server) | `atengk/ateng-solid-server` | Java 21 / Spring Boot 3.3 (`ateng-boot-bom:1.2.0+`) / Maven **同源双装配架构**（先稳固 5 模块单体，预留 `ateng-cloud` 并存扩展壳） | 首期落地 |
| [`./ateng-solid-admin-web`](./ateng-solid-admin-web) | `atengk/ateng-solid-admin-web` | Node.js 22+ / pnpm 11+ / Vue 3.5 / Vite / TS Strict / `ateng-ui` + **TailwindCSS（禁 Preflight）** | 首期落地 |
| [`./ateng-solid-mp`](./ateng-solid-mp) | - | 移动端小程序工程 | 规划中 |
| [`./ateng-solid-app`](./ateng-solid-app) | - | 跨平台移动端 App | 规划中 |
| [`./ateng-solid-desktop`](./ateng-solid-desktop) | - | PC 桌面客户端工程 | 规划中 |
| [`./ateng-solid-portal-web`](./ateng-solid-portal-web) | - | 门户与官网 Web 前端工程 | 规划中 |

---

## 2. 核心协作纪律 (Workspace Rules)

1. **仓库隔离与双分支流 (Repo Isolation & Dual-Branch)**：
   - 各子工程为完全独立 Git 仓库，所有 `git add`、`git commit` 与 `git push` 严格在各自仓库内执行；严禁将子工程源码提交至根仓库。
   - 统一遵循 **`main`（稳定发布只读）+ `dev`（日常活跃开发）** 双分支策略，全仓提交严格遵循 Conventional Commits（由 `.githooks/commit-msg` 守护）。
   - 未收到明确提交/推送指令前，改动默认保留在工作区；暂存必须显式指定文件路径，严禁 `git add .` 或 `-A`。
2. **跨端契约与公共规约单一真源及同步防漂移**：
   - [`.agents/rules/contracts.md`](./.agents/rules/contracts.md) 是全端响应信封、6 位分段错误码、雪花 `string` 主键、`tenant_id BIGINT`（默认 `0`）、`/admin/<域>/<资源>` 路由、三段式权限码与 Blob/Fesod 协议的**唯一真源**；
   - [`.agents/rules/foundation-first-gate.md`](./.agents/rules/foundation-first-gate.md) 是跨 `ateng-boot`、`ateng-cloud`、`ateng-ui` 三大底座的**底层缺口即停工硬门禁**真源。
   - 任何公共规约变更须先在根仓修改，并立即执行 `bash scripts/workspace.sh sync-rules` 同步至各子仓 `.agents/rules/`（兼容保留 `sync-contracts`）。
3. **底层缺口即停工、零降级与零绑定红线（硬门禁）**：
   - 优先复用 `ateng-boot`、`ateng-cloud`、`ateng-ui` 原生能力；严禁引入 `hutool-all`、`guava`、`lodash`、`moment` 等冗余依赖。
   - **硬门禁（Zero Workaround）**：在项目及其子项目规划或开发过程中，一旦发现大型或基础设施级能力缺失、缺陷或扩展点不足，**必须立即停止该特性上层编码，严禁在上层编写临时降级或拦截器补丁将就**；应立即更新 [底层基础设施待增强清单](./docs/specs/foundation-enhancements-checklist.md) 并向对应底座仓提交 GitHub Issue，待底座完成通用改造、通过独立性四项双轴验收并发布递进正式版后，再升级恢复上层开发（详见 [`.agents/rules/foundation-first-gate.md`](./.agents/rules/foundation-first-gate.md)）。
   - **底层独立性红线**：严禁为了迎合 `ateng-solid` 将业务表名、角色名、错误码或默认租户写死进底座，底座必须可脱离 `ateng-solid` 在任意其他项目单独使用。
   - 依赖消费遵循“上层正式业务代码必须在底座发布递进正式版并锁版后再合入，严禁在 `dev`/`main` 残留 `SNAPSHOT` 或本地链接”。
4. **安全与机密脱敏红线**：
   - 云端 MySQL / Redis 等真实连接信息仅限本地被 `.gitignore` 忽略文件（`application-local.yml` / `.env.local`）持有；入库文档、脚本与样例统一使用大写占位符或环境变量。

---

## 3. 工作区治理工具 (`scripts/workspace.sh`)

本工作区统一维护单一 Bash 脚本 [scripts/workspace.sh](./scripts/workspace.sh)（兼容 Windows Git Bash 与 Linux/macOS）：

```bash
# 首次接入：克隆缺失子仓、激活全部 Hooks、初始化 dev 分支、同步契约并检查工具链
bash scripts/workspace.sh sync
bash scripts/workspace.sh init

# 日常巡检与公共规约一致性校验
bash scripts/workspace.sh status
bash scripts/workspace.sh check-rules
bash scripts/workspace.sh sync-rules

# 全仓安全切换分支（需全仓工作区干净）
bash scripts/workspace.sh checkout dev
```

---

## 4. 规约与文档导航 (Mandatory Context Pointers)

| 场景 | 必读文档 | 说明 |
| :--- | :--- | :--- |
| **底层缺口判断与停工提单（硬门禁）** | [`.agents/rules/foundation-first-gate.md`](./.agents/rules/foundation-first-gate.md) | 覆盖 `ateng-boot`/`ateng-cloud`/`ateng-ui` 的停工提 Issue 与版本锁纪律 |
| **跨端接口与数据协议变更** | [`.agents/rules/contracts.md`](./.agents/rules/contracts.md) | 响应信封、错误码段、多租户、权限码与路由隔离规范 |
| **重型跨模块任务与文档交付** | [`.agents/rules/workflow.md`](./.agents/rules/workflow.md) | Blueprint ➔ Spec ➔ Ticket 门禁与 Tested-Docs 准则 |
| **探索全端上下文拓扑** | [`CONTEXT-MAP.md`](./CONTEXT-MAP.md) | 根仓与子仓职责边界与依赖关系 |
| **查阅首期架构蓝图与底盘缺口** | [`docs/specs/README.md`](./docs/specs/README.md) | 含首期 MVP 蓝图与《底层基础设施待增强清单》 |
| **查阅工作区架构决策** | [`docs/adr/README.md`](./docs/adr/README.md) | Polyrepo 契约同步、多租户 `BIGINT` 等关键决策 |
| **后端独立开发** | [`ateng-solid-server/AGENTS.md`](./ateng-solid-server/AGENTS.md) | 5 模块 Cloud-Ready 后端规约与 Java 21 基线 |
| **前端独立开发** | [`ateng-solid-admin-web/AGENTS.md`](./ateng-solid-admin-web/AGENTS.md) | Vue 3.5 + `ateng-ui` + TailwindCSS 混合样式规约 |

---

## Agent skills

### Issue tracker

本仓库使用 GitHub Issues（通过 `gh` CLI）跟踪全端规划、工作区治理与跨仓协调任务。详见 [`docs/agents/issue-tracker.md`](./docs/agents/issue-tracker.md)。

### Triage labels

采用标准 5 角色分诊标签词表（`needs-triage` / `needs-info` / `ready-for-agent` / `ready-for-human` / `wontfix`）。详见 [`docs/agents/triage-labels.md`](./docs/agents/triage-labels.md)。

### Domain docs

本仓库采用多上下文（multi-context）聚合工作区结构（根 `CONTEXT-MAP.md` + `docs/adr/`）。详见 [`docs/agents/domain.md`](./docs/agents/domain.md)。
