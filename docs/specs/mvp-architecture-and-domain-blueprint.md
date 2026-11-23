# 首期 MVP 架构与领域蓝图 (Blueprint)

- **规划版本**：v1.1.0
- **创建时间**：2026-11-18
- **最新修订**：2026-11-23（完成 `ateng-boot:1.2.0`、`ateng-cloud:1.1.0`、`ateng-ui:1.1.0` 双轴验收与锁版，`Spec 0` 解封）
- **关联规范**：[跨端契约](../../.agents/rules/contracts.md) | [全仓编程与架构规范](../../.agents/rules/coding-and-architecture.md) | [底层增强清单](./foundation-enhancements-checklist.md)

---

## 1. 业务目标与首期 MVP 边界

构建基于 `ateng-boot`、`ateng-cloud` 与 `ateng-ui` 的企业级多租户统一后台底座，完成认证会话、SaaS 多租户、组织架构、RBAC + 数据权限、数据字典与系统审计的首期核心闭环；同时遵循**“同源双装配（单体先行稳固 + 预留 `ateng-cloud` 微服务长期并存扩展壳）”**架构策略，从 Day 1 锁定纯接口边界与数据库/事件解耦，支持单体与微服务两套形态在不分叉核心业务代码的前提下长期共存。

### 1.1 首期纳入范围 — 最小稳定内核 (Core Kernel · In Scope)
1. **认证与会话域 (`auth`)**：管理端登录（`/admin/auth/**`、`loginType="admin"`、`satoken-admin`）、可开关图形验证码（`CaptchaTemplate`）、登录防爆破锁定（`LoginFailureLockService`）、个人信息与密码修改（`PasswordUtil` PBKDF2）、在线会话查看与强退（内核预留 `AuthGrantHandler` 认证策略 SPI 支撑扩展）。
2. **多租户基础（可开关、默认关闭，`system`）**：支持通过 `ateng.solid.tenant.enabled`（**默认 `false`**，联动 `ateng.boot.mybatis-plus.tenant.enabled`）启停多租户隔离；底层保留完整行级多租户（`tenant_id BIGINT NOT NULL DEFAULT 0`，默认平台租户 `0` / 编码 `000000`）、租户套餐（`sys_tenant_package`）及平台超管切换租户能力，关闭时首期按极简单租户开箱运行，开启后零重构激活 SaaS 多租户。
3. **组织与 RBAC (`system`)**：用户管理（含基础导入/导出对接 `ateng-boot-excel` 与头像上传对接 `ateng-boot-storage`）、角色管理（含 5 级 `@DataScope` 数据权限）、菜单权限树（`M`/`C`/`F`）、部门树与岗位管理。
4. **枚举、字典与参数 (`system`)**：关闭底座内置枚举端点（`endpoint-enabled: false`），由 `ateng-solid-system` 自建 `SysEnumController` 接管 `/admin/system/enums` 并实施 `@SaCheckLogin` 管控；动态数据字典（`sys_dict_type`/`sys_dict_data`）与系统参数（`sys_config`）。
5. **操作与登录审计 (`system`)**：登录日志（`sys_login_log`）与操作审计日志（`sys_oper_log`，对接 `@OperateLog` + `OperateLogStorageProvider` SPI）。

### 1.2 首期核心技术栈与底层模块矩阵（极简收敛 · 拒绝冗余辅助框架）

| 端工程 | 复用的底层核心模块 | 除底座外的外部/框架核心技术栈 |
| :--- | :--- | :--- |
| **`ateng-solid-server`** | `ateng-boot-core`、`ateng-boot-web`、`ateng-boot-mybatis-plus`、`ateng-boot-redis`、`ateng-boot-satoken`、`ateng-boot-excel`、`ateng-boot-storage`、`ateng-boot-flyway`（7+1 核心） | Java 21 LTS（虚拟线程）、Spring Boot `3.3.13`、Maven 3.9+、MySQL 8.x（`mysql-connector-j`）、Lombok、`jakarta.validation`；离线测试期 H2 + Spring Boot Test + ArchUnit `1.3.0`（对象映射复用 `ateng-boot-core` `BeanUtil` + 显式转换，**不引入** `MapStruct`/`hutool-all`/`guava`/`ateng-boot-observability`） |
| **`ateng-solid-admin-web`** | `@atengk/core`、`@atengk/vue`、`@atengk/element-plus`（3 大核心包） | Node.js `22+`、pnpm `11+`、Vue `3.5+`、Vue Router `4.5+`、Pinia `3.0+`、TypeScript `5.6+`（Strict）、Vite `6+`、Element Plus + `@element-plus/icons-vue`、TailwindCSS v4（禁用 Preflight）+ Sass；质检期 Vitest + `@vue/test-utils` + `happy-dom` + ESLint 9 + Prettier + `vue-tsc`（**不引入** `@atengk/monitor`/`lodash`/`moment`/`vue-i18n`） |

### 1.3 明确延后至二期 — 装配期可插拔扩展模块 (Pluggable Extensions · Out of Scope for MVP)
遵循 [ADR-0005](../adr/0005-kernel-plus-pluggable-extensions.md) 与 [ADR-0006](../adr/0006-stage1-minimal-stack-and-object-mapping.md)，二期特性与辅助增强不混写进首期内核，按独立扩展模块装配插拔，**首期不提前建空壳或预装重依赖**：
- 监控与可观测增强（后端 `ateng-boot-observability` 与前端 `@atengk/monitor`）
- 第三方 OAuth2 / 社会化登录（`ext-social`，消费 `ateng-boot-social` + `AuthGrantHandler` SPI）
- 站内信与 WebSocket/SSE 实时推送（`ext-realtime`，消费 `ateng-boot-realtime`）
- 分布式定时任务调度控制台（`ext-job`，消费 `ateng-boot-job-local`/`xxl`/`snail`）
- 动态多数据源物理分库（`ext-datasource`，消费 `ateng-boot-datasource`）
- 业务流/低代码表单/大屏图表（`ateng-ui` L2 重型扩展包，前端 `src/modules/*` 按需自发现装配）与多语言 `vue-i18n`

---

## 2. 系统架构拓扑与表域归属

```mermaid
flowchart TD
    Web["ateng-solid-admin-web<br/>(Vue 3.5 + Vite + ateng-ui + TailwindCSS 无Preflight)"]
    AuthCtrl["auth: /admin/auth/**<br/>登录 · 验证码 · 个人中心 · 在线会话"]
    SysCtrl["system: /admin/system/**<br/>租户/套餐 · 用户/角色/菜单/部门/岗位 · 枚举/字典/参数 · 日志"]
    SysApi["ateng-solid-system-api<br/>纯接口 + 跨模块 DTO/VO + 枚举/错误码"]
    Common["ateng-solid-common<br/>全局常量 · 上下文原语 · 通用异常码"]
    DB[("MySQL 8.x / H2(TEST)<br/>Flyway 版本化迁移(归属 system) · 零物理外键")]
    Redis[("Redis 7.x / 内存降级<br/>Sa-Token 会话 · 权限缓存 · 验证码 · 防爆破")]

    Web -->|"satoken-admin · X-Tenant-Id · X-Trace-Id"| AuthCtrl
    Web -->|"satoken-admin · X-Tenant-Id · X-Trace-Id"| SysCtrl
    AuthCtrl -->|仅依赖契约接口| SysApi
    SysCtrl -->|实现契约接口| SysApi
    SysApi --> Common
    AuthCtrl --> Common
    SysCtrl --> Common
    AuthCtrl --> Redis
    SysCtrl --> DB
    SysCtrl --> Redis
```

### 数据表按服务域物理归属（为双态共存与 Cloud 拆服零外键解耦铺路）

| 服务域 | 核心表名 | 继承实体基类（对齐 `ateng-boot#1134`） | 租户隔离 |
| :--- | :--- | :--- | :---: |
| **系统域（平台共享）** | `sys_tenant`、`sys_tenant_package`、`sys_menu`、`sys_dict_type`、`sys_dict_data`、`sys_tenant_package_menu` | 主表 `BaseLogicEntity`（按需加锁用 `BaseFullEntity`）；关联表 `BaseIdEntity` | 否（`ignore-tables`） |
| **系统域（租户隔离）** | `sys_dept`、`sys_post`、`sys_role`、`sys_user`、`sys_config`、`sys_user_role`、`sys_user_post`、`sys_role_menu`、`sys_role_dept` | 主表 `BaseLogicEntity` + `TenantAware<Long>`（高并发状态按需 `BaseFullEntity`）；关联表 `BaseIdEntity` + `TenantAware<Long>` | 是（`tenant_id BIGINT NOT NULL DEFAULT 0`） |
| **系统域（审计流水）** | `sys_oper_log`、`sys_login_log` | `BaseIdEntity` + `TenantAware<Long>`（无软删与乐观锁） | 是（`tenant_id BIGINT NOT NULL DEFAULT 0`） |
| **认证域 (`auth`)** | 原则上**不自建持久层业务表**；会话/验证码/防爆破存储于 Redis，登录日志通过领域事件交由 `system` 落库 | - | - |

> Flyway 迁移脚本（`db/migration/system/`）直接随领域存放在 `ateng-solid-system` 模块资源目录内，确保 `ateng-solid-bootstrap`（单体宿主）与未来 `ateng-solid-cloud-system`（微服务宿主）天然共享同一份建表与种子脚本，彻底杜绝双份维护。

---

## 3. 演进拆分路线（Spec 规划）

正式开始编码前，将按以下顺序分步推进并落实测试先行闭环（首期单体 MVP 统一收敛为 **`Spec 0 ~ Spec 4`**，后续 `ateng-cloud` 同源双态并存挂壳独立归口为 **`Spec 5`**）：
1. **Spec 0（底层硬门禁前置 · ✅ 已完成双轴验收并锁版解锁）**：已于 [底层基础设施待增强清单](./foundation-enhancements-checklist.md) 核验并锁定 `ateng-boot:1.2.0`（含 `#1076~#1080`、`#1093`、`#1094`、`#1134~#1137`、`#1163~#1167` 与 `ateng-boot-flyway`）、`ateng-cloud:1.1.0`（含 `#198~#206`）及 `ateng-ui:1.1.0`（`@atengk/{core,vue,element-plus}` 含 `#362~#367`），正式开启 `Spec 1 ~ Spec 4` 编码。
2. **Spec 1（工程骨架、公共原语与扩展 SPI 定义）**：完善 `ateng-solid-server` 5 模块 POM/ArchUnit/Flyway 双模配置、公共常量/错误码/`DomainEventPublisher` 与内核 SPI 端口（如 `AuthGrantHandler` 接口定义），与 `ateng-solid-admin-web` Vite/Tailwind/ateng-ui 基座。
3. **Spec 2（认证会话闭环）**：图形验证码与多租户开关透传、账密 PBKDF2 登录、防爆破、超管启动引导初始化、`getInfo`/动态路由与在线会话管理。
4. **Spec 3（RBAC、数据权限与可开关多租户）**：菜单/角色/部门/岗位/用户管理、`@DataScope` 5 级数据权限、前端动态路由权限闭环，以及开关式 `sys_tenant`/`sys_tenant_package` 租户治理与套餐联动裁剪。
5. **Spec 4（枚举、字典、参数、文件与审计）**：上层接管 `/admin/system/enums` 静态枚举、`sys_dict`、`sys_config`、头像上传与用户 Excel 原子校验批注回写导入导出、`sys_oper_log`/`sys_login_log`。
6. **Spec 5（后续演进：`ateng-cloud` 同源双态并存挂壳）**：底座 `ateng-cloud:1.1.0` 已发布就绪，待首期单体（`Spec 1 ~ Spec 4`）稳固后，同仓并列挂载 `ateng-solid-cloud/{gateway,auth,system}` 微服务启动壳，与 `ateng-solid-bootstrap` 长期双态并存共用同一套业务核心。
