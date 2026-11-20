# 全端架构蓝图与工程规范索引 (Specs)

本目录收录跨端共用的系统级蓝图、契约参考与底座演进跟踪清单。

| 文档 | 核心内容 | 适用角色 |
| :--- | :--- | :--- |
| [首期 MVP 架构与领域蓝图](./mvp-architecture-and-domain-blueprint.md) | 首期精简技术栈与底座模块范围、二期延后边界、后端 5 模块与数据表域归属、前后端联调拓扑 | 架构师、全端开发、AI Agent |
| [底层基础设施待增强清单](./foundation-enhancements-checklist.md) | `ateng-boot`（B1–B8）、`ateng-cloud`（#198–#205 / C1–C6）与 `ateng-ui`（U0–U3）实测状态、`dev` 闭环核查与发版解锁门禁 | 底座维护者、开发启动前自检 |
| [全仓代码与架构编程规范](../../.agents/rules/coding-and-architecture.md) | 跨仓统一的分层依赖、对象映射、事务防 N+1、空安全并发、安全脱敏与交付验证总规范 | 全端开发、代码评审、AI Agent |

## 子仓库专职设计规范入口

- **后端设计规范（独立仓库 `ateng-solid-server`）**：
  - [数据库建模与 Flyway 迁移规范](../../ateng-solid-server/docs/specs/database-and-flyway-spec.md)
  - [认证会话、RBAC 与 `@DataScope` 数据权限规范](../../ateng-solid-server/docs/specs/auth-rbac-and-datascope-spec.md)
  - [管理端接口契约与业务错误码明细规范](../../ateng-solid-server/docs/specs/api-and-error-codes-spec.md)
  - [工程配置基线与 ArchUnit 架构守卫规格](../../ateng-solid-server/docs/specs/configuration-and-archunit-spec.md)
- **前端设计规范（独立仓库 `ateng-solid-admin-web`）**：
  - [前端工程结构、路由权限与样式混用规范](../../ateng-solid-admin-web/docs/specs/frontend-architecture-and-conventions.md)
  - [前端页面视图、动态路由与 Store 契约规格](../../ateng-solid-admin-web/docs/specs/views-and-routes-spec.md)
