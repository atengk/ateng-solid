# ADR-0001: Polyrepo 隔离、单向契约同步与子仓独立开发架构

- **状态**：`Accepted`
- **日期**：2026-11-18
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
2. **根仓总控 `AGENTS.md` + 子仓独立自洽 `AGENTS.md`**：
   - 根仓维护总控 `AGENTS.md`；每个子仓拥有完整、独立可单独开发的 `AGENTS.md` 及专职 `.agents/rules/`、`CONTEXT-MAP.md`、`docs/adr/`、`docs/specs/`。
3. **公共规约单一真源单向同步防漂移（`workspace.sh`）**：
   - 跨端契约 `.agents/rules/contracts.md` 与底层缺口硬门禁 `.agents/rules/foundation-first-gate.md` 主源位于根仓，由统一 Bash 脚本 `scripts/workspace.sh`（支持 Windows Git Bash 与 Unix）提供 `sync-rules` / `check-rules`（兼容保留 `sync-contracts` / `check-contracts`）校验子仓副本一致性，彻底消除跨仓契约与停工门禁脱节。
4. **集成 `oss-template` 工程化标准**：
   - 根仓及子仓按业务应用定位裁剪集成 `oss-template` 的提交钩子（`.githooks/commit-msg`）、语义化提交与发版脚本（`scripts/commit.sh`、`scripts/release.sh`）、PR/Issue 模板与 GitHub Actions 流水线。

---

## 3. 后果与权衡

- **优点**：支持单仓独立开发、独立发版与独立 CI，同时在全端视角保持 100% 契约一致性。
- **代价**：修改跨端契约时必须在根仓执行一次 `bash scripts/workspace.sh sync-contracts` 并分别提交对应子仓；CI 通过 `check-contracts` 兜底防止遗忘。
