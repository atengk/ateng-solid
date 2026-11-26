# ateng-solid 聚合工作区总控规范 (AGENTS.md)

**ateng-solid** 是基于独立通用底座（`ateng-boot`、`ateng-cloud`、`ateng-ui`）的全端开源框架聚合工作区（Polyrepo）；各子仓为独立 Git 仓库，各自持有自洽 `AGENTS.md`（依赖版本真源见各仓 `pom.xml`/`package.json`）。

- 首期已落地：[`ateng-solid-server`](./ateng-solid-server)（Java 21 / Spring Boot 3.3 / `ateng-boot-bom` 5 模块同源双装配）、[`ateng-solid-admin-web`](./ateng-solid-admin-web)（Node 22+ / pnpm 11+ / Vue 3.5 / TS Strict / `ateng-ui` + Tailwind v4 无 Preflight）
- 规划中：`mp` / `app` / `desktop` / `portal-web`（端间零私有共享源码包）

---

## 1. 工作区硬红线

- **仓库隔离与双分支**：各子仓独立提交推送，严禁将子仓源码提交到根仓；全仓统一 `main`（只读发布）+ `dev`（日常开发）与 Conventional Commits；未获明确指令前改动保留工作区，暂存显式指定路径（禁 `git add .`/`-A`）。
- **底层零补丁与主干锁版门禁（Zero Workaround, Lock on `main`）**：遇 `ateng-boot`/`ateng-cloud`/`ateng-ui` 能力缺失或缺陷，**严禁在上层打临时补丁、严禁底座写死 `ateng-solid` 专属约定**；**默认先向底座提通用 Issue 并登记增强清单，未经用户明确确认严禁直接修改外部底座仓库源码**（仅获确认后方可在底座本地改造联调）；`dev` 分支允许携带 `-SNAPSHOT` / `file:.yalc` 本地联调提交、推进编码与关单（允许联调期远端 `dev` CI 暂红），**严禁向 `main` 合入或基于未锁版状态发版**（由 `pre-commit`/`pre-push`/`main` CI 守护）。
- **公共规约单源同步**：跨仓公共规约仅在根仓 `docs/agents/{contracts,foundation-first-gate,coding-standards,documentation-specification}.md` 修改，改完运行 `bash scripts/workspace.sh sync-rules` 同步子仓，严禁直接修改子仓副本。
- **重型任务门禁**：仅初始化新端、新增微服务域、重构跨端协议/基表或迁移 `ateng-cloud` 时走 `Blueprint ➔ Spec ➔ Ticket`（蓝图与规格产出后各暂停确认）；常规 CRUD、页面与修 Bug 直接开发。
- **零明文凭据**：真实连接串与密钥仅存 `.gitignore` 忽略的 `application-local.yml` / `.env.local`，入库文件统一大写占位符或环境变量。

---

## 2. 工作区命令 (`scripts/workspace.sh`)

```bash
bash scripts/workspace.sh <sync | init | status | sync-rules | check-rules | checkout dev>
```

---

## 3. 按需必读文档（按场景触发）

| 何时必先读 | 文档 |
| :--- | :--- |
| 改接口、错误码、DDL、多租户、权限码、枚举或 Excel 协议 | [`docs/agents/contracts.md`](./docs/agents/contracts.md) |
| 设计新服务/页面、拆分大类、写注释或做 Code Review | [`docs/agents/coding-standards.md`](./docs/agents/coding-standards.md) |
| 怀疑遇底座缺口，或需 `-SNAPSHOT`/`yalc` 跨仓本地联调 | [`docs/agents/foundation-first-gate.md`](./docs/agents/foundation-first-gate.md) · [`foundation-enhancements-checklist.md`](./docs/specs/foundation-enhancements-checklist.md) |
| 新功能编码与测试全绿后沉淀模块 `README.md`/Specs/`llms.txt` | [`docs/agents/documentation-specification.md`](./docs/agents/documentation-specification.md) |
| 查阅全端蓝图、架构决策、拓扑与子仓开发入口 | [`llms.txt`](./llms.txt) · [`CONTEXT-MAP.md`](./CONTEXT-MAP.md) · [`docs/specs/README.md`](./docs/specs/README.md) · [`docs/adr/README.md`](./docs/adr/README.md) · [`server/AGENTS.md`](./ateng-solid-server/AGENTS.md) · [`admin-web/AGENTS.md`](./ateng-solid-admin-web/AGENTS.md) |

## Agent skills

- **Issue tracker**: [`docs/agents/issue-tracker.md`](./docs/agents/issue-tracker.md) | **Triage labels**: [`docs/agents/triage-labels.md`](./docs/agents/triage-labels.md) | **Domain docs**: [`docs/agents/domain.md`](./docs/agents/domain.md)（多上下文 `CONTEXT-MAP.md` + `docs/adr/`）
