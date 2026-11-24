# ADR-0001: Polyrepo 隔离、单向契约同步与子仓独立开发架构

- **状态**：`Accepted`（`2026-11-25` 修订：取消 `.agents/rules/` 全量常驻，迁至 `docs/agents/` 渐进披露）
- **日期**：2026-11-18（修订：`2026-11-25`）
- **作者**：Ateng
- **影响范围**：`ateng-solid`、`ateng-solid-server`、`ateng-solid-admin-web`

---

## 1. 背景与痛点

`ateng-solid` 包含后端服务及多个规划中的终端应用（管理后台、小程序、App、桌面端、门户）。研发过程中存在两种高频打开方式：
1. 在根工作区 `ateng-solid` 进行跨端联调与全局架构规划；
2. 单独打开 `ateng-solid-server` 或 `ateng-solid-admin-web` 独立开发和独立发布。

若跨端契约仅存放在根仓，单开子仓时开发者与 AI Agent 无法自动加载跨端通信规范，且易导致前后端各自演进时字段、错误码与请求头漂移；若合并为巨型 Monorepo，又会耦合 Java/Maven 与多个端栈的 CI/CD 与 Git 历史。

---

## 2. 核心决策

1. **独立 Polyrepo + 根仓治理底座**：
   - `ateng-solid` 通过 `.gitignore` 忽略子工程目录，各子仓独立管理 Git 分支（`main` 发布 + `dev` 开发）、`.githooks`、CI/CD 流水线与 `CHANGELOG`。
2. **极简常驻 `AGENTS.md` + `docs/agents/` 按需渐进披露（`2026-11-25` 修订）**：
   - 早期将 4 份长篇规则全部置入 `.agents/rules/`（`trigger: always_on`）导致单仓常驻规则高达 15k~19k tokens，叠加个人全局规则直接突破 20k 上下文预算触发规则降级（Demoted），且 `trigger: model_decision` 存在 AI 工具厂商绑定问题；
   - 修订为：**清空各仓 `.agents/rules/`**，仅保留极简常驻 `AGENTS.md`（每轮必守项目专属红线 + 强触发指针；根仓 ≤ 1,500 tok、单子仓 ≤ 2,500 tok），将跨端契约、停工联调 SOP 与各端专职细则下沉为 `docs/agents/*.md` 按需参考文档，100% 兼容 Antigravity / Claude Code / Codex / Cursor；每个子仓继续独立保有 `AGENTS.md`、`docs/agents/`、`CONTEXT*.md`、`docs/adr/` 与 `docs/specs/`。
3. **公共规约单一真源单向同步防漂移（`workspace.sh`）**：
   - 跨端契约 `docs/agents/contracts.md`、底层缺口停工与联调 SOP `docs/agents/foundation-first-gate.md`、精简编码与注释规范 `docs/agents/coding-standards.md` 与文档保真规范 `docs/agents/documentation-specification.md` 主源位于根仓，由统一 Bash 脚本 `scripts/workspace.sh`（支持 Windows Git Bash 与 Unix）提供 `sync-rules` / `check-rules`（兼容保留 `sync-contracts` / `check-contracts`）校验子仓副本一致性，消除跨仓漂移且零常驻 Token 开销。
4. **集成 `oss-template` 工程化标准**：
   - 根仓及子仓按业务应用定位裁剪集成 `oss-template` 的提交钩子（`.githooks/commit-msg`）、语义化提交与发版脚本（`scripts/commit.sh`、`scripts/release.sh`）、PR/Issue 模板与 GitHub Actions 流水线。

---

## 3. 后果与权衡

- **优点**：支持单仓独立开发、独立发版与独立 CI，同时在全端视角保持 100% 契约一致性。
- **代价**：修改跨端契约时必须在根仓执行一次 `bash scripts/workspace.sh sync-contracts` 并分别提交对应子仓；CI 通过 `check-contracts` 兜底防止遗忘。
