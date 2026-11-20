# ateng-solid

**ateng-solid** 是面向企业级场景的**开源全栈上层应用框架**与多端数字化系统聚合工作区（Polyrepo Workspace），以独立通用的 [`ateng-boot`](https://github.com/atengk/ateng-boot) 与 [`ateng-ui`](https://github.com/atengk/ateng-ui) 为基础设施底座，并预留向 [`ateng-cloud`](https://github.com/atengk/ateng-cloud) 微服务并存演进的模块化边界。

> **双生生态定位**：`ateng-solid` 既用真实业务场景实战验证并反哺锤炼底层底座（遇底座缺口即停工完善并正式发布底座，绝不打上层补丁将就），又将其自身沉淀为可直接面向行业二次开发的纯净、零补丁企业级上层框架。

---

## 1. 仓库矩阵与工程目录

本工程采用松耦合的多仓库架构（Polyrepo），各子工程均为完全独立的 Git 仓库，支持**从根工作区联合协同**或**单开任意子仓独立开发与发布**：

| 子工程目录 | 仓库链接 | 职责描述 | 技术基线 | 状态 |
| :--- | :--- | :--- | :--- | :--- |
| [`ateng-solid-server`](./ateng-solid-server) | [atengk/ateng-solid-server](https://github.com/atengk/ateng-solid-server) | 后端统一核心服务（5 模块 Cloud-Ready 单体） | Java 21 / Spring Boot 3.3 (`ateng-boot:1.2.0`) / Maven | 首期落地 |
| [`ateng-solid-admin-web`](./ateng-solid-admin-web) | [atengk/ateng-solid-admin-web](https://github.com/atengk/ateng-solid-admin-web) | 管理后台 Web 前端工程 | Node 22+ / pnpm 11+ / Vue 3.5 / Vite / TS / `ateng-ui` / TailwindCSS | 首期落地 |
| [`ateng-solid-mp`](./ateng-solid-mp) | - | 移动端小程序工程 | 规划中 | 待初始化 |
| [`ateng-solid-app`](./ateng-solid-app) | - | 移动端跨平台 App (iOS / Android) | 规划中 | 待初始化 |
| [`ateng-solid-desktop`](./ateng-solid-desktop) | - | PC 桌面客户端工程 | 规划中 | 待初始化 |
| [`ateng-solid-portal-web`](./ateng-solid-portal-web) | - | 门户与官网 Web 前端工程 | 规划中 | 待初始化 |

---

## 2. 架构设计原则与规范导航

1. **总控与独立自洽并存**：根仓通过 [`AGENTS.md`](./AGENTS.md)、[`.agents/rules/contracts.md`](./.agents/rules/contracts.md)、[`.agents/rules/foundation-first-gate.md`](./.agents/rules/foundation-first-gate.md)、[`.agents/rules/coding-and-architecture.md`](./.agents/rules/coding-and-architecture.md) 与 [`.agents/rules/workflow.md`](./.agents/rules/workflow.md) 统管跨端契约、编程架构规范与协同工作流；每个子仓均内置完整自洽的 `AGENTS.md`、专职规则与同步规约副本。
2. **面向 `ateng-cloud` 平滑演进**：后端采用 `common` ➔ `system-api` ➔ `{system, auth}` ➔ `bootstrap` 5 模块拓扑，严禁跨模块 SQL JOIN 与物理外键，支持未来按域拆服或无缝迁移至 `ateng-cloud`。
3. **行级多租户与套餐边界**：全库业务表 `tenant_id` 统一为 `BIGINT`（平台默认租户 `0`，业务编码 `000000`），配合 `sys_tenant_package` 收敛租户能力边界。
4. **文档、AI 索引与底座增强清单**：
   - AI 全局索引：[`llms.txt`](./llms.txt)
   - 文档 1:1 保真规范：[`docs/agents/documentation-specification.md`](./docs/agents/documentation-specification.md)
   - 全端拓扑地图：[`CONTEXT-MAP.md`](./CONTEXT-MAP.md)
   - 首期 MVP 架构蓝图：[`docs/specs/mvp-architecture-and-domain-blueprint.md`](./docs/specs/mvp-architecture-and-domain-blueprint.md)
   - 底层基础设施待增强清单：[`docs/specs/foundation-enhancements-checklist.md`](./docs/specs/foundation-enhancements-checklist.md)
   - 架构决策记录：[`docs/adr/README.md`](./docs/adr/README.md)

---

## 3. 工作区初始化与环境基线

### 3.1 环境基线
- **Java / Maven**：OpenJDK 21 LTS（启用虚拟线程）+ Apache Maven 3.9+
- **Node.js / pnpm**：Node.js v22+ + pnpm 11+
- **中间件（连接云端或测试实例）**：MySQL 8.x + Redis 7.x（本地凭据隔离于未跟踪的 `application-local.yml` / `.env.local`；单测保持 H2 / 内存离线自洽）

### 3.2 工作区治理脚本（`scripts/workspace.sh`）
全工作区统一维护单一 POSIX Bash 脚本 [`scripts/workspace.sh`](./scripts/workspace.sh)（Windows 下通过 Git Bash 直接执行）：

```bash
# 1. 首次拉取工作区：克隆缺失子仓、激活全部 Hooks、切齐 dev 分支、同步契约并检查工具链
bash scripts/workspace.sh sync
bash scripts/workspace.sh init

# 2. 日常状态巡检与公共规约同步
bash scripts/workspace.sh status
bash scripts/workspace.sh sync-rules
bash scripts/workspace.sh check-rules

# 3. 增量拉取与统一切换分支
bash scripts/workspace.sh sync --pull
bash scripts/workspace.sh checkout dev
```

---

## 4. 参与贡献与开源协议

- 分支模型与提交流程详见 [贡献指南 (`CONTRIBUTING.md`)](./CONTRIBUTING.md)，安全漏洞披露请参考 [安全策略 (`SECURITY.md`)](./SECURITY.md)。
- 本工作区基于 [Apache License 2.0](./LICENSE) 协议开源。
