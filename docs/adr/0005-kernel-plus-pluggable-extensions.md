# ADR-0005: “最小稳定内核 + 装配期可插拔扩展”框架扩展模型

- **状态**：`Accepted`
- **日期**：2026-11-20
- **作者**：Ateng
- **影响范围**：`ateng-solid` 全端内核与二期扩展域（`ateng-solid-server`、`ateng-solid-admin-web`）

---

## 1. 背景与痛点

`ateng-solid` 面向企业级二次开发，既需要开箱即用的基础管理功能，又必须在后续演进中接入 OAuth2 第三方登录、站内信/实时消息、定时任务、多数据源以及各类行业业务模块（`biz-*`）。若处理不当极易落入两类极端：
1. **耦合堆积**：将全部扩展逻辑硬写进核心 `auth` / `system` 与前端基础视图中，导致无需该功能的项目背负大量冗余依赖与死代码，且二开后内核无法升级；
2. **过度热插拔**：强行引入 OSGi、自定义 ClassLoader 热加载或前端微前端（qiankun / Module Federation），带来远超管理台收益的类加载隔离复杂度、上下文割裂与性能开销。

---

## 2. 核心决策

1. **采用“装配期可插拔（Assembly-Time Pluggable）”而非运行期热插拔**：
   - **后端**：核心 5 模块（`common`/`system-api`/`system`/`auth`/`bootstrap`）作为不可拆的稳定内核保持一体；扩展特性（`ateng-solid-ext-*`）与行业业务（`ateng-solid-biz-*`）做为独立 Maven 子模块，通过 Spring Boot `AutoConfiguration.imports` + `@ConditionalOnProperty` 在启动壳 `pom.xml` **增减 Maven 依赖即可插拔**（仅允许向内依赖 `common` 与 `*-api`，严禁反向依赖或修改 `auth`/`system`）。
   - **前端**：在单一 Vite SPA 内定义轻量 `SolidFeatureModule` 契约，扩展特性内聚于 `src/modules/<feature>/`（自包含 `api`/`views`/`stores`/`routes`），由核心通过 `import.meta.glob` 自动扫描注册并受开关/后端下发菜单驱动，**增删目录或关闭开关即可插拔**，由 Vite Tree-shaking 自动剔除未启用产物。
2. **内核与扩展归属界限**：
   - **最小稳定内核（不可插拔）**：管理端认证会话（账密登录/验证码/个人中心/在线会话）、可开关多租户与套餐、部门/岗位/角色/菜单/用户与 `@DataScope`、静态枚举/动态字典/系统参数、登录与操作审计、前端基础布局壳与动态路由框架；
   - **官方可插拔扩展（二期按需装配）**：第三方登录（`ext-social`）、站内信与 WebSocket/SSE（`ext-realtime`）、定时任务调度控制台（`ext-job`）、多数据源（`ext-datasource`）等；
   - **行业二开扩展（`biz-*`）**：全部业务领域实现。
3. **内核预留 4 项轻量插拔 SPI（零改源码接入）**：
   - **认证策略 SPI (`AuthGrantHandler`)**：核心 `auth` 内置 `password` 处理器并按 `grantType` 自动路由全部容器 Bean，后续扩展短信/社交登录零修改 `auth` 源码；
   - **领域事件端口 (`DomainEventPublisher` + `@EventListener`)**：生命周期动作广播事件，扩展模块被动订阅响应；
   - **安全白名单与枚举汇聚**：扩展模块通过 `SaTokenWhitelistProvider` SPI 注册匿名路径，通过 `@IBaseEnum` 自动进入静态枚举字典端点；
   - **模块级独立 Flyway 迁移**：带库表的扩展模块自持 `classpath:db/migration/<module>/` 与独立 `table` 历史表（依托 `ateng-boot-flyway` 多数据源/多目标能力），严禁改写内核迁移序列。
4. **核心实体防侵入扩展红线**：
   - 扩展模块需要向 `sys_user` / `sys_tenant` 等内核主体追加业务属性时，**严禁修改内核表结构与实体类**，统一通过独立扩展子表（`ext_*` / `biz_*`，以 `user_id` 等 `1:1`/`1:N` 关联）实现，保障框架内核平滑升级。
5. **规划期与 UI 插槽克制原则**：
   - 首期保持工程精简，不提前创建空的 `ext-*`、`biz-*` 模块或空目录；前端仅在核心页（如登录页/个人中心）按需预留轻量 Extension Slot，不提前造重型插件引擎。

---

## 3. 后果与权衡

- **优点**：兼具极简维护成本与高度模块化裁剪能力；与 `ateng-cloud` 同源并存架构完全正交（独立 `biz-*` 模块既可随单体装配，也可单独挂接成微服务）；保障核心框架零冲突升级。
- **代价**：扩展业务若需向主列表补充展示字段或向核心表单加控件，需通过聚合查询/子表接口或前端扩展插槽对接，不允许图省事直接改核心表或核心 Controller。
