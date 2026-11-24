# 全端架构蓝图与工程规范索引 (Specs)

本目录收录跨端共用的系统级蓝图、契约参考与底座演进跟踪清单。

| 文档 | 核心内容 | 适用角色 |
| :--- | :--- | :--- |
| [首期 MVP 架构与领域蓝图](./mvp-architecture-and-domain-blueprint.md) | 首期精简技术栈与底座模块范围、二期延后边界、后端 5 模块与数据表域归属、前后端联调拓扑 | 架构师、全端开发、AI Agent |
| [底层基础设施待增强清单](./foundation-enhancements-checklist.md) | `ateng-boot`（B1–B15）、`ateng-cloud`（#198–#206 / C1–C6）与 `ateng-ui`（U0–U8）实测状态、`dev` 闭环核查与发版解锁门禁 | 底座维护者、开发启动前自检 |
| [第一阶段编码开工准入检查表](./phase1-coding-readiness-checklist.md) | 跨端 1:1 终审汇总、第一阶段 `V1.0.1` 种子数据核对表与 `Spec 1 ~ Spec 4` 编码开工前门禁检查项 | 全端开发、代码评审、AI Agent |
| [跨端通信协议与数据契约](../agents/contracts.md) | 统一响应信封、6 位分段错误码、雪花 `string` 主键、`tenant_id BIGINT`、`/admin/**` 路由与权限/Excel 协议唯一真源 | 全端开发、代码评审、AI Agent |
| [编码规范、架构拆解与注释准则](../agents/coding-standards.md) | 公共提取阶梯、大类/大文件拆分线、设计模式选型、事务防 N+1 与文档/逻辑注释规范 | 全端开发、代码评审、AI Agent |

## 第一阶段产品需求文档 (PRD) 与高保真交互原型

- **设计系统与全站交互规范**：
  - [Precision Slate & Cobalt 设计系统规范](./prd/design-system.md)
  - [第一阶段总览与全站交互规范](./prd/00-overview-and-ux-standards.md)
- **分域产品需求文档（PRD）**：
  - [01 · 认证登录、工作台、个人中心与在线会话 PRD](./prd/01-auth-and-workspace.md)
  - [02 · 组织架构与 RBAC 权限管理 PRD](./prd/02-org-and-rbac.md)
  - [03 · SaaS 多租户与租户套餐管理 PRD](./prd/03-tenant-and-package.md)
  - [04 · 静态枚举、动态字典、系统参数与审计日志 PRD](./prd/04-enum-dict-config-audit.md)
- **底座一手调研基线与交互原型套件**：
  - [`ateng-boot:1.2.0` 一手源码调研与约束报告](./prd/_research/boot-1.2.0-constraints.md)
  - [`@atengk/{core,vue,element-plus}@1.1.0` 组件能力调研报告](./prd/_research/ui-1.1.0-capabilities.md)
  - [第一阶段高保真可交互 HTML 原型套件索引](../prototypes/phase1/README.md)（主总装入口：[`index.html`](../prototypes/phase1/index.html)）

## 子仓库专职设计规范入口

- **后端设计规范（独立仓库 `ateng-solid-server`）**：
  - [数据库建模与 Flyway 迁移规范](../../ateng-solid-server/docs/specs/database-and-flyway-spec.md)
  - [认证会话、RBAC 与 `@DataScope` 数据权限规范](../../ateng-solid-server/docs/specs/auth-rbac-and-datascope-spec.md)
  - [管理端接口契约与业务错误码明细规范](../../ateng-solid-server/docs/specs/api-and-error-codes-spec.md)
  - [工程配置基线与 ArchUnit 架构守卫规格](../../ateng-solid-server/docs/specs/configuration-and-archunit-spec.md)
- **前端设计规范（独立仓库 `ateng-solid-admin-web`）**：
  - [前端工程结构、路由权限与样式混用规范](../../ateng-solid-admin-web/docs/specs/frontend-architecture-and-conventions.md)
  - [前端页面视图、动态路由与 Store 契约规格](../../ateng-solid-admin-web/docs/specs/views-and-routes-spec.md)
