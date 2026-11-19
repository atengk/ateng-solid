# 全端架构蓝图与工程规范索引 (Specs)

本目录收录跨端共用的系统级蓝图、契约参考与底座演进跟踪清单。

| 文档 | 核心内容 | 适用角色 |
| :--- | :--- | :--- |
| [首期 MVP 架构与领域蓝图](./mvp-architecture-and-domain-blueprint.md) | 首期功能范围、二期延后边界、后端 5 模块与数据表域归属、前后端联调拓扑 | 架构师、全端开发、AI Agent |
| [底层基础设施待增强清单](./foundation-enhancements-checklist.md) | 实锤核查出的 `ateng-boot`（B1–B6）、`ateng-cloud`（C1–C6）与 `ateng-ui`（U1–U3）底层不足点、源码锚点、GitHub Issue 追踪与验收标准 | 底座维护者、开发启动前自检 |

## 子仓库专职设计规范入口

- **后端设计规范（独立仓库 `ateng-solid-server`）**：
  - [数据库建模与 Flyway 迁移规范](../../ateng-solid-server/docs/specs/database-and-flyway-spec.md)
  - [认证会话、RBAC 与 `@DataScope` 数据权限规范](../../ateng-solid-server/docs/specs/auth-rbac-and-datascope-spec.md)
  - [管理端接口契约与业务错误码明细规范](../../ateng-solid-server/docs/specs/api-and-error-codes-spec.md)
  - [工程配置基线与 ArchUnit 架构守卫规格](../../ateng-solid-server/docs/specs/configuration-and-archunit-spec.md)
- **前端设计规范（独立仓库 `ateng-solid-admin-web`）**：
  - [前端工程结构、路由权限与样式混用规范](../../ateng-solid-admin-web/docs/specs/frontend-architecture-and-conventions.md)
  - [前端页面视图、动态路由与 Store 契约规格](../../ateng-solid-admin-web/docs/specs/views-and-routes-spec.md)
