# Context Map: ateng-solid

**ateng-solid** 是兼具“**底座实战试金石**”与“**可直接二开的企业级开源上层框架**”双定位的多端聚合工作区（Polyrepo Workspace），由根仓库统筹跨端通信契约与系统级蓝图，各端作为独立 Git 仓库并行演进并保持运行时解耦。

---

## Contexts (工作区与子工程边界)

- **[Root 根工作区](./AGENTS.md)**（`ateng-solid`）：
  聚合工作区总控中心。维护全端跨端契约唯一真源（[`docs/agents/contracts.md`](./docs/agents/contracts.md)）、底层零补丁与跨仓联调 SOP（[`docs/agents/foundation-first-gate.md`](./docs/agents/foundation-first-gate.md)）、编码与注释规范（[`docs/agents/coding-standards.md`](./docs/agents/coding-standards.md)）、文档 1:1 保真规范（[`docs/agents/documentation-specification.md`](./docs/agents/documentation-specification.md)）、系统级 ADR（[`docs/adr/`](./docs/adr/README.md)）、首期架构蓝图与底层待增强清单（[`docs/specs/`](./docs/specs/README.md)）及统一运维/全栈运行脚本 [`scripts/workspace.sh`](./scripts/workspace.sh) / [`scripts/solid.sh`](./scripts/solid.sh)。
- **[Server 后端核心服务](./ateng-solid-server/CONTEXT-MAP.md)**（`atengk/ateng-solid-server`，首期落地）：
  Spring Boot 3.3 + `ateng-boot` **同源双装配**后端工程（实际基线见 [pom.xml](./ateng-solid-server/pom.xml)）：首期稳固 `common` ➔ `system-api` ➔ `{system, auth}` ➔ `bootstrap` 5 模块单体，面向后续 `ateng-cloud` 并存微服务启动壳保留零重构扩展边界，对外以对称路径 `/admin/**` 暴露管理端契约。
- **[Admin Web PC 管理后台](./ateng-solid-admin-web/CONTEXT.md)**（`atengk/ateng-solid-admin-web`，首期落地）：
  Vue 3.5 + Vite + TypeScript Strict + `@atengk/core`/`@atengk/vue`/`@atengk/element-plus` + TailwindCSS（禁用 Preflight）单页后台应用，手写强类型 `src/api/*` 契约层直接对齐后端。
- **远期多端扩展工程（规划中）**：
  `ateng-solid-mp`（小程序）、`ateng-solid-app`（跨平台 App）、`ateng-solid-desktop`（PC 桌面端）、`ateng-solid-portal-web`（门户官网），各端严格通过各自终端路由前缀（`/app/**`、`/portal/**`、`/open/**`）与独立 `loginType` 接入后端，前端各端之间零代码共享。

---

## Relationships (协同与依赖拓扑)

```mermaid
flowchart LR
    subgraph Root["ateng-solid (根工作区真源)"]
        CONTRACTS["docs/agents/<br/>contracts + gate + coding + docs"]
        SPECS["docs/specs/ & docs/adr/<br/>蓝图 / 待增强清单 / 决策"]
        SCRIPT["scripts/workspace.sh + solid.sh<br/>多仓初始化 · 规约同步 · 全栈编排"]
    end

    subgraph Foundation["基础设施底座 (上游硬门禁纳管)"]
        BOOT["ateng-boot (1.2.0 基线 · dev 1.2.1-SNAPSHOT)<br/>(Spring Boot 3.3)"]
        CLOUD["ateng-cloud (1.1.0 已发版)<br/>(并存态微服务装配底座)"]
        UI["ateng-ui (1.1.0 基线 · dev yalc)<br/>(@atengk/core, vue, element-plus)"]
    end

    subgraph Repos["首期独立业务仓"]
        SERVER["ateng-solid-server<br/>同源双装配（单体先行 · 预留 Cloud 壳）"]
        ADMIN["ateng-solid-admin-web<br/>Vue 3.5 + TailwindCSS (无Preflight)"]
    end

    SCRIPT -->|单向同步并校验| SERVER
    SCRIPT -->|单向同步并校验| ADMIN
    BOOT -->|BOM 按需引入| SERVER
    CLOUD -.->|后期微服务壳并存装配| SERVER
    UI -->|npm 依赖| ADMIN
    ADMIN -->|"/admin/** (satoken-admin, X-Tenant-Id)"| SERVER
```

### 核心约束律
1. **单向规约真源律**：`contracts.md`、`foundation-first-gate.md`、`coding-standards.md` 与 `documentation-specification.md` 只允许在根仓库修订，由 `workspace.sh sync-rules` 单向分发，根仓 CI 与 `workspace.sh check-rules` 负责阻止子仓漂移。
2. **底层零补丁与双阶门禁律（`dev` 协同 · `main` 锁版）**：发现 `ateng-boot`、`ateng-cloud`、`ateng-ui` 缺失能力或缺陷时，严禁在上层编写临时补丁，严禁在底座写死本项目约定；默认先向底座提通用 Issue 并登记增强清单，**未经用户明确确认严禁直接修改外部底座仓库源码**（仅获确认后方可在底座本地改造联调）。本地刷新 `-SNAPSHOT` / `yalc` 后可在 `dev` 继续编码、测试、提交并关闭功能/缺陷 Issue，合入 `main` 与发版前必须完成底座正式发布与四项双轴验收并锁回正式版本。
3. **三层二开扩展界限律**：纯技术基础设施沉底座；通用管理域内核留 `ateng-solid`；具体行业二开业务（`biz-*`）按独立域扩展挂载，不篡改或侵入框架内核（`auth`/`system`）。
4. **终端物理隔离律**：每个前端仓库只消费对应前缀的后端端点与独立 `loginType` 会话体系（管理端独占 `/admin/**` + `satoken-admin`），后端无论是单体还是经过 `ateng-cloud-gateway`，前端仅需消费同一份 `/admin/**` 契约。
5. **无共享前端包律**：不同终端仓库之间不抽取私有共享 UI/业务源码包，通用能力一律下沉至 `ateng-ui` 或由各仓消费统一后端 API 契约。
6. **租户软删除逻辑隔离归档边界**：SaaS 多租户删除仅对租户主表（`sys_tenant`）执行逻辑删除，不在线上请求事务内级联软删子表业务/组织记录，以此避免长事务锁表并维持审计流水（`sys_oper_log`、`sys_login_log`）关联溯源；运行时由缓存驱逐、会话强退、租户可用性守卫、`RbacPrivilegeGuard` 及跨表 SQL 联合校验 `sys_tenant.deleted = 0` 与超管 `100002` 自动回退共同封闭访问路径，冷数据回收交由离线 DBA 按 `tenant_id` 分片归档/清理（详见 [`03-tenant-and-package.md`](./docs/specs/prd/03-tenant-and-package.md)）。

---

## Architectural Decisions

跨端及工作区级架构决策索引维护于 **[架构决策记录看板 (docs/adr/README.md)](./docs/adr/README.md)**。
