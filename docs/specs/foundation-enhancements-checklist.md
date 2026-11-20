# 底层基础设施待增强清单 (Foundation Enhancements Checklist)

本文档基于对同级目录 `ateng-boot`、`ateng-cloud`、`ateng-ui` 源码、Git 提交记录及 GitHub Issues 状态核查整理，受 [底层缺口即停工规范](../../.agents/rules/foundation-first-gate.md) 硬门禁约束：**凡标为“硬停工等待项”的缺口，上层严禁编写临时降级/绕过补丁，必须待底座完成通用改造、通过独立性验收并发布递进正式版后，再升级恢复上层开发**。

> **2026-11-20 核实结论**：
> - 原 `ateng-boot`（`#1076~#1080`、`#1093`、`#1094`、`ateng-boot-flyway`）、`ateng-cloud`（`#198~#205`）与 `ateng-ui`（`#362~#365`）已全部在对应底座 `dev` 分支完成修改并关闭 Issue，**目前均尚未正式发布递进版本**（`ateng-boot` 仍为 `1.2.0`、`ateng-cloud` 仍为 `1.0.0`、`ateng-ui` npm 仍为 `1.0.0`）；
> - 新增 `ateng-boot` 持久层实体体系净切重构单 **`B8`（[`atengk/ateng-boot#1134`](https://github.com/atengk/ateng-boot/issues/1134)）**，待其改造完成后随 `ateng-boot` 下一递进正式版一并发布解锁。

---

## 0. 阻塞与就绪矩阵总览 (Spec 0 ~ Spec 5)

| 上层阶段 | 依赖底座项 | 当前状态 | 规划期可推进工作 | 编码开工解锁条件 |
| :--- | :--- | :---: | :--- | :--- |
| **Spec 1**（公共原语/事件/骨架） | `ateng-boot-core`（已就绪） | 🟢 无新增缺口 | 公共常量、错误码、`DomainEventPublisher` 与工程骨架 | 规划确认后即可落实公共原语 |
| **Spec 2**（认证会话/动态路由/基础壳） | **B1** (`#1076`)、**B2** (`#1077`)、**B4** (`#1079`)、**B5** (`flyway`/`#1094`)、**U0** (`#362~#364`)、**U1** (`#365`) | 🟡 **底座 `dev` 已闭环，待发版**（🔴 仍阻塞正式代码锁版合入） | 完整 DDL、接口/时序详设文档；仅可按第 5 节 SOP 本地 `-SNAPSHOT`/`yalc` 提前试验证 | `ateng-boot:1.2.1+` 与 `ateng-ui:1.0.1+` 正式发布并锁版 |
| **Spec 3**（RBAC/数据权限/可开关多租户） | **B2** (`#1077`)、**B3** (`#1078`)、**B7** (`#1093`)、**B8** (`#1134`，实体重构)、**U0** (`#362~#364`) | 🔴 **受 B8 待改 + 统一发版硬停工阻塞** | DDL 与实体映射契约详设（`BaseLogicEntity`/`TenantAware<Long>`） | **B8** 在 `ateng-boot` 改造完成且与 `ateng-boot:1.2.1+`/`1.3.0`、`ateng-ui:1.0.1+` 一并正式发版 |
| **Spec 4**（字典/参数/Excel批注/审计） | **B5** (`#1094` 枚举接管开关、`OperateLogModel`)、**B8** (`#1134`)、**U0** (`#362`) | 🔴 随 **B8** 与统一发版阻塞 | 协议详设与字典/导入导出规划 | 同上（`ateng-boot` 与 `ateng-ui` 正式发版） |
| **Spec 5**（`ateng-cloud` 双态并存挂壳） | **B6** (`#1080`)、**C1~C6** (`#198~#205`) | 🟡 **底座 `dev` 已闭环，待发版**（仅阻塞 Cloud 阶段） | 双装配桥接设计与目录规划 | `ateng-cloud:1.0.1+` 随新版 `ateng-boot` 对齐并正式发布 |

---

## 1. `ateng-boot` (`1.2.0` ➔ 目标 `1.2.1+` / `1.3.0+`)

### [B1] 高优先级：Sa-Token 注解鉴权与多账号路由 (`loginType`) 自动联动

- **改造内容**：在 `ateng-boot-satoken` 增加开关/动态 `StpLogic` 路由解析（`@SaCheckPermission` / `@SaCheckRole` 等未显式指定 `type` 时，按命中路由 `login-type-routes` 或 `primary-login-type` 自动路由到对应 `StpLogic`）。
- **准入纪律**：**严禁在上层 Controller 重复手写 `type = "admin"` 绕过**。
- **核实状态**：- [x] `ateng-boot` `dev` 已实现并关闭 Issue（[`atengk/ateng-boot#1076`](https://github.com/atengk/ateng-boot/issues/1076)，提交 `e1182df3`） ➔ **待正式发版锁版**

---

### [B2] 高优先级：超管角色可配置化收敛与 `@DataScope` 上下文自动桥接

- **改造内容**：
  1. `SaTokenProperties` 增加可配置超管角色集合 `superAdminRoles`（允许上层收敛覆盖为 `["super_admin"]`）及通配符开关；
  2. `AtengSaTokenInterceptor` 通过弱依赖桥接自动同步并清理 `DataPermissionContextHolder`。
- **准入纪律**：**严禁在上层自写后置拦截器补丁同步 `DataPermissionContextHolder`**。
- **核实状态**：- [x] `ateng-boot` `dev` 已实现并关闭 Issue（[`atengk/ateng-boot#1077`](https://github.com/atengk/ateng-boot/issues/1077)，提交 `e1182df3`） ➔ **待正式发版锁版**

---

### [B3] 中优先级：未登录租户请求头解析与超管受控切租户 SPI 钩子

- **改造内容**：提供未登录请求头 `X-Tenant-Id` 解析策略与 `TenantHeaderSwitchValidator` SPI 钩子，支撑平台超管受控切换租户视角。
- **准入纪律**：**严禁在上层注册低优先级拦截器绕过覆盖**。
- **核实状态**：- [x] `ateng-boot` `dev` 已实现并关闭 Issue（[`atengk/ateng-boot#1078`](https://github.com/atengk/ateng-boot/issues/1078)，提交 `e1182df3`） ➔ **待正式发版锁版**

---

### [B4] 中优先级：`LoginFailureLockService` 多租户与多账号作用域隔离键

- **改造内容**：新增带 `(tenantId, loginType, account, clientIp)` 的防碰撞定界重载方法，消除跨租户同名账号误锁。
- **准入纪律**：**严禁在上层手动拼串降级调用**。
- **核实状态**：- [x] `ateng-boot` `dev` 已实现并关闭 Issue（[`atengk/ateng-boot#1079`](https://github.com/atengk/ateng-boot/issues/1079)，提交 `298aaa95`） ➔ **待正式发版锁版**

---

### [B5] `ateng-boot-web` 枚举端点自主接管开关、`ateng-boot-flyway` 与已就绪能力

- **枚举字典自主接管（`#1094`）**：`ateng-boot-web` 已于 `dev` 新增 `ateng.boot.web.enum.endpoint-enabled`（默认 `true`，提交 `9a013643`）；`ateng-solid` 将配置 **`endpoint-enabled: false`**，仅注入 `EnumDictionaryRegistry` 并由 `ateng-solid-system` 自建 `SysEnumController` 挂载 `/admin/system/enums` 实施 `@SaCheckLogin` 及后续权限/租户管控；
- **`ateng-boot-flyway`**：已在 `ateng-boot` `dev` 实现（含高危 DDL 预检守卫、生产 `clean` 物理熔断、与 MyBatis-Plus 初始化顺序屏障及 H2 兼容），待正式发版后取消 `ateng-solid-bootstrap/pom.xml` 中注释并启用；
- **`OperateLogModel` & `PasswordUtil` & `BeanUtil`**：`1.2.0` 已就绪。
- **核实状态**：- [x] `#1094`（[`atengk/ateng-boot#1094`](https://github.com/atengk/ateng-boot/issues/1094)）与 `ateng-boot-flyway` 已在 `dev` 实现闭环 ➔ **待正式发版锁版**

---

### [B6] 中优先级（阻塞 Spec 5）：`BusinessException` 支持可选 `traceId` 字段

- **改造内容**：`BusinessException` 新增可选 `traceId` 字段与 `withTraceId` 链式绑定，`Result.getOrThrow` 与 `GlobalExceptionHandler` 自动透传回填。
- **核实状态**：- [x] `ateng-boot` `dev` 已实现并关闭 Issue（[`atengk/ateng-boot#1080`](https://github.com/atengk/ateng-boot/issues/1080)，提交 `0df1c682`） ➔ **待正式发版锁版**

---

### [B7] 高优先级（阻塞多租户模式运行）：`CachedStpInterface` 与 `PermissionCacheService` 可选租户维度隔离

- **改造内容**：`SaTokenProperties.PermissionCacheProperties` 新增 `tenantScoped` 开关，在缓存键、定向失效与集群同步广播中隔离租户维度角色权限缓存。
- **核实状态**：- [x] `ateng-boot` `dev` 已实现并关闭 Issue（[`atengk/ateng-boot#1093`](https://github.com/atengk/ateng-boot/issues/1093)，提交 `298aaa95`） ➔ **待正式发版锁版**

---

### [B8] 高优先级（🆕 硬停工等待 · 阻塞 Spec 3 实体与 DDL 编码）：`ateng-boot-mybatis-plus` 实体阶梯与正交能力接口净切重构

- **现状与源码锚点**：
  - 当前 `ateng-boot-mybatis-plus/.../entity/` 中 `BaseTimeEntity` 死锁继承 `BaseIdEntity`（`Long`），自定义主键 `BaseGenericEntity<ID>` 无法复用审计与软删；
  - `BaseFullEntity`（`Integer deleted 0/1` + `version`）与 `BaseDeleteIdEntity`（`Long deleted` `delval="id"` + `version`）双轨冗余、命名晦涩且将 `@Version` 乐观锁强绑于软删；
  - `TenantEntity` 写死 `String getTenantId()`，与 `tenant_id BIGINT`（`Long tenantId`）不兼容导致 `BatchUtil.autoHeal` 失效；`BatchUtil` 默认填 `version=1` 与 DDL `DEFAULT 0` 不一致。
- **目标通用改造（净切移除旧 `BaseDeleteIdEntity`、`TenantEntity` 与 `Integer deleted` 双轨模型）**：
  1. 提取 5 个正交能力接口：`Identifiable<ID>`、`TenantAware<T>`（兼容 `Long` 与 `String`）、`Auditable`、`Versioned`、`LogicDeletable<T>`；
  2. 落地泛型与雪花双阶梯：泛型链 `BaseGenericEntity<ID>` ➔ `BaseGenericTimeEntity<ID>` ➔ `BaseGenericAuditEntity<ID>` ➔ `BaseGenericLogicEntity<ID>`；雪花链 `BaseIdEntity` ➔ `BaseTimeEntity` ➔ `BaseEntity` ➔ `BaseLogicEntity`（统一 `Long deleted` `delval="id"`，**无锁**）➔ `BaseFullEntity`（追加 `@Version Integer version` 默认 `0`）；
  3. `DefaultMetaObjectHandler` 与 `BatchUtil` 全量面向正交接口自愈并统一 `version` 初始默认值为 `0`。
- **准入纪律**：**严禁在 `ateng-solid` 中基于旧 `BaseDeleteIdEntity` 或自写基类绕过提前编写持久层实体**；等待本单改造并随 `ateng-boot` 下一递进正式版发布后，上层直接继承 `BaseLogicEntity` / `BaseFullEntity` 与 `TenantAware<Long>`。
- **状态**：- [ ] 已提交 Issue 待底座净切重构与双轴验收（[`atengk/ateng-boot#1134`](https://github.com/atengk/ateng-boot/issues/1134)）

---

## 2. `ateng-cloud` (`1.0.0` ➔ 目标 `1.0.1+` / 阻塞 Spec 5 微服务并存挂壳)

> 经核查，`ateng-cloud` `dev` 分支（提交 `fe44549`、`c82d9b5`）已完整修复并关闭以下全部 8 个关联 Issue，目前尚未正式发版：

- **BOM 基线升级对齐**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#198`](https://github.com/atengk/ateng-cloud/issues/198)，待随 `ateng-boot` 下一递进版再次核对 BOM 版本号）
- **`SaTokenGatewayFilter` 多账号与 `LoginUser` 协议修复**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#199`](https://github.com/atengk/ateng-cloud/issues/199)）
- **[C1] `ateng-cloud-feign` 与 `ateng-cloud-sentinel` 共存兼容**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#200`](https://github.com/atengk/ateng-cloud/issues/200)）
- **[C2] `ateng-cloud-gateway` 支持平台超管受控切换 `X-Tenant-Id`**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#201`](https://github.com/atengk/ateng-cloud/issues/201)）
- **[C3] 网关与 Feign 补全注入 `SA-SAME-TOKEN` 请求头**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#202`](https://github.com/atengk/ateng-cloud/issues/202)）
- **[C4] Feign / Dubbo 远端异常 `traceId` 回传与 HTTP `409`/`504` 映射**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#203`](https://github.com/atengk/ateng-cloud/issues/203)）
- **[C5] `AtengDubboExceptionFilter` 剥离非白名单 `cause` 开关**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#204`](https://github.com/atengk/ateng-cloud/issues/204)）
- **[C6] `AtengSentinelEnvironmentPostProcessor` 尊重总开关及限流口径对齐**：- [x] `dev` 已闭环（[`atengk/ateng-cloud#205`](https://github.com/atengk/ateng-cloud/issues/205)）

---

## 3. `ateng-ui` (`1.0.0` ➔ 目标 `1.0.1+` / `1.1.0+`)

> 经核查，`ateng-ui` `dev` 分支（提交 `ea2e643`、`1e90cd7`、`48105c4`、`d72e0ba`）已全部实现并关闭 `U0` 与 `U1` 相关 Issue，待 npm 发布递进正式版后即在 `ateng-solid-admin-web/package.json` 升级锁定：

### [U0] 等待 `ateng-ui` `dev` 已合入修复发布正式版至 npm

- **已闭环修复项**：
  1. [`atengk/ateng-ui#362`](https://github.com/atengk/ateng-ui/issues/362)：分页契约对齐 `current`/`size`/`sorts` 与 `records`/`total`/`pages`（提交 `ea2e643`）；
  2. [`atengk/ateng-ui#363`](https://github.com/atengk/ateng-ui/issues/363)：修复 `v-permission`/`v-role` 在自定义 `AuthManager` 实例下上下文隔离失效（提交 `1e90cd7`）；
  3. [`atengk/ateng-ui#364`](https://github.com/atengk/ateng-ui/issues/364)：支持 `createAtengVue({ superAdminRoles: ['super_admin'] })` 覆写超管角色集合（提交 `48105c4`）。
- **状态**：- [x] `dev` 已完成修改并关闭 Issue ➔ **待 npm 发布正式递进版本后升级锁定**

---

### [U1] `AtengProLayout / ProMenuItemNode` 原生字符串图标解析扩展点

- **已闭环改造**：`AtengProLayout` / `ProMenu` 已在 `dev` 支持字符串图标自定义解析回调 `iconResolver`（不写死绑定 `@element-plus/icons-vue`）。
- **状态**：- [x] `dev` 已实现并关闭 Issue（[`atengk/ateng-ui#365`](https://github.com/atengk/ateng-ui/issues/365)，提交 `d72e0ba`） ➔ **待 npm 发布正式递进版本后接入**

---

### [U2] 纯配置集成：`AtengVue` 显式覆写 `superAdminRoles: ['super_admin']`
- 依托 `U0`（`#364`）发版后，在 `src/main.ts` 配置 `createAtengVue({ httpClient, authManager: adminAuthManager, tenantManager, superAdminRoles: ['super_admin'] })`，与后端 B2 保持一致。

### [U3] 纯布局集成：`KeepAlive` 多标签缓存联动
- `AtengProLayout` 与 `AtengTabsNav` 负责 UI 布局与页签派发，`ateng-solid-admin-web` 在 `AdminLayout.vue` 组合 `useTabsNav`（`@atengk/vue`）与 `<KeepAlive :include="cachedViews">` 属于标准应用层布局装配，无需改底座。

---

## 4. 发版前历史弃用写法净切清理追踪（非功能阻塞 · 随新版同步清除）

趁三座底座尚未正式发版并大规模接入，以下净切移除 `@Deprecated` 与旧版兼容包装的 Issue 建议随本次递进版本一并完成：

- **`ateng-boot`**：[`#1135`](https://github.com/atengk/ateng-boot/issues/1135)（`core`/`web`/`mybatis-plus`/`excel`/`observability`/`openapi`）、[`#1136`](https://github.com/atengk/ateng-boot/issues/1136)（`redis`/`satoken`）、[`#1137`](https://github.com/atengk/ateng-boot/issues/1137)（`job`/`ai`/`notification`/`tcp`）
- **`ateng-cloud`**：[`#206`](https://github.com/atengk/ateng-cloud/issues/206)（`dubbo`/`nacos`）
- **`ateng-ui`**：[`#366`](https://github.com/atengk/ateng-ui/issues/366)（`@atengk/vue` `superAdminRole`、`@atengk/element-plus` `filterColumnVNodes` 旧签名）
