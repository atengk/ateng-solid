# 底层基础设施待增强清单 (Foundation Enhancements Checklist)

本文档基于对同级目录 `ateng-boot`、`ateng-cloud` 与 `ateng-ui` 源码及已发布制品的实测核查整理，受 [底层缺口即停工规范](../../.agents/rules/foundation-first-gate.md) 硬门禁约束：**凡标为“硬停工等待项”的缺口，上层严禁编写临时降级/绕过补丁，必须待底座完成通用改造、通过独立性验收并发布递进正式版后，再升级恢复上层开发**。

> 注：同时需持续关注上游基础对齐单 [`atengk/ateng-cloud#198`](https://github.com/atengk/ateng-cloud/issues/198)（升级对齐 `ateng-boot-bom`）与 [`atengk/ateng-cloud#199`](https://github.com/atengk/ateng-cloud/issues/199)（修复 `SaTokenGatewayFilter` 多账号与 `LoginUser` 协议断层）。

---

## 0. 阻塞与就绪矩阵总览 (Spec 0 ~ Spec 5)

| 上层阶段 | 依赖底座项 | 阻塞性质 | 规划期可推进工作 | 编码开工解锁条件 |
| :--- | :--- | :---: | :--- | :--- |
| **Spec 1**（公共原语/事件/骨架） | `ateng-boot-core`（已就绪） | 🟢 无新增缺口 | 公共常量、错误码、`DomainEventPublisher` 详设 | 规划确认后即可落实公共原语 |
| **Spec 2**（认证会话/动态路由/基础壳） | **B1** (`#1076`)、**B2** (`#1077`)、**B4** (`#1079`)、**B5** (`ateng-boot-flyway` 发版)、**U0** (`#362~#364` 发版)、**U1** (`#365`) | 🔴 **硬停工阻塞** | 完整 DDL、接口/时序详设文档 | `ateng-boot:1.2.1+` 与 `ateng-ui:1.0.1+` 正式发布并锁版 |
| **Spec 3**（RBAC/数据权限/可开关多租户） | **B2** (`#1077`)、**B3** (`#1078`)、**B7** (`#1093`，开启多租户时)、**U0** (`#362~#364`) | 🔴 **硬停工阻塞** | 业务边界与测试用例设计 | 同上（开启多租户前须含 `#1093`） |
| **Spec 4**（字典/参数/Excel批注/审计） | **B5**（`EnumDictionaryController`/`OperateLogModel` 已就绪）、**U0** (`#362`) | 🔴 随 **U0** 阻塞 | 协议详设与字典规划 | `ateng-ui:1.0.1+` 正式发版 |
| **Spec 5**（`ateng-cloud` 双态并存挂壳） | **B6** (`#1080`)、**C1~C6** (`#198~#205`) | 🔴 仅阻塞 Cloud 阶段 | 不影响单体阶段文档 | `ateng-cloud` 修复对齐并正式发布 |

---

## 1. `ateng-boot` (`1.2.0` ➔ 目标 `1.2.1+` / `1.3.0+`)

### [B1] 高优先级（硬停工等待）：Sa-Token 注解鉴权与多账号路由 (`loginType`) 自动联动

- **现状与源码锚点**：
  - `LoginHelper.getStpLogic(loginType)`（`ateng-boot-satoken/.../util/LoginHelper.java`）已动态拼接生成 `satoken-admin` 请求头；`AtengSaTokenInterceptor` 已支持按 `login-type-routes` 对 `/admin/**` 执行登录检查。
  - **缺口**：`AtengSaTokenAutoConfiguration` 未接管 Sa-Token 原生注解校验策略。Controller 若直接标注 `@SaCheckPermission(...)` / `@SaCheckRole(...)` 而不传 `type = "admin"`，默认走 `StpUtil.stpLogic`（读取 `satoken` 头）导致后台接口 401。
- **目标通用改造**：
  - 在 `ateng-boot-satoken` 增加开关/动态 `StpLogic` 路由解析（注解未显式指定 `type` 时，按命中路由 `login-type-routes` 或 `primary-login-type` 自动路由到对应 `StpLogic`）。
- **准入纪律**：**严禁在上层 Controller 重复手写 `type = "admin"` 绕过**，等待底座完成并发版后直接采用标准 `@SaCheckPermission` / `@SaCheckRole`。
- **状态**：- [ ] 已提 Issue 待底座改造与双轴验收（[atengk/ateng-boot#1076](https://github.com/atengk/ateng-boot/issues/1076)）

---

### [B2] 高优先级（硬停工等待）：超管角色可配置化收敛与 `@DataScope` 上下文自动桥接

- **现状与源码锚点**：
  - `LoginHelper.isSuperAdmin()`（`LoginHelper.java`）硬编码放行 `"admin"` 与 `"super_admin"`，存在多租户普通角色误命名越权风险；
  - `AtengSaTokenInterceptor` 在 `preHandle` / `afterCompletion` 未与 `DataPermissionContextHolder` 自动同步和清理超管标记。
- **目标通用改造**：
  1. 在 `SaTokenProperties` 增加可配置超管角色集合 `superAdminRoles`（默认保持向后兼容，允许上层配置覆盖为 `["super_admin"]`）及通配符开关；
  2. 在 `AtengSaTokenInterceptor` 通过 `@ConditionalOnClass(DataPermissionContextHolder.class)` 弱依赖自动桥接与 `finally` 清理。
- **准入纪律**：**严禁在上层自写后置拦截器补丁同步 `DataPermissionContextHolder`**，必须待底座解决并发版后恢复 Spec 2/3 开发。
- **状态**：- [ ] 已提 Issue 待底座改造与双轴验收（[atengk/ateng-boot#1077](https://github.com/atengk/ateng-boot/issues/1077)）

---

### [B3] 中优先级（硬停工等待）：未登录租户请求头解析与超管受控切租户 SPI 钩子

- **现状与源码锚点**：
  - `AtengSaTokenInterceptor.applyContextForLoginType` 与 `SaTokenCurrentTenantProvider` 仅在已登录时从 `LoginUser.getTenantId()` 写入 `TenantContextHolder`，导致免登录入口无法通过拦截器识别候选租户头，且平台超管合法切换 `X-Tenant-Id` 时会被会话租户覆盖。
- **目标通用改造**：
  - 在 `ateng-boot-satoken` / `ateng-boot-web` 提供默认关闭的可配置策略与 `TenantHeaderResolver` SPI 钩子（保留既有普通租户强锁定默认行为，允许上层注入超管切换校验策略）。
- **准入纪律**：**严禁在上层注册低优先级拦截器绕过覆盖**，待底座提供标准 SPI 后通过薄适配器接入。
- **状态**：- [ ] 已提 Issue 待底座改造与双轴验收（[atengk/ateng-boot#1078](https://github.com/atengk/ateng-boot/issues/1078)）

---

### [B4] 中优先级（硬停工等待）：`LoginFailureLockService` 多租户与多账号作用域隔离键

- **现状与源码锚点**：
  - `LoginFailureLockService` 仅接收单一 `account` 字符串拼接 `ateng:satoken:login-fail:<account>`，跨租户同名账号会产生误锁定。
- **目标通用改造**：
  - 增加带 `(tenantId, loginType, account, clientIp)` 的重载方法（或自动按作用域隔离），原方法保留向后兼容。
- **准入纪律**：**严禁在上层手动拼串降级调用**，待底座新增标准重载后直接调用。
- **状态**：- [ ] 已提 Issue 待底座改造与双轴验收（[atengk/ateng-boot#1079](https://github.com/atengk/ateng-boot/issues/1079)）

---

### [B5] 已就绪 / 待随新版发布（纯配置接入，无需改底座功能）

- **`EnumDictionaryController`（`ateng-boot-web`）**：已就绪，在 `application.yml` 显式配置 `ateng.boot.web.enum.enabled=true`、`path-prefix=/admin/system/enums`、`scan-packages=io.github.atengk.solid` 即可（受 `/admin/**` 登录态保护）。
- **`OperateLogModel`（`ateng-boot-core`）**：已就绪，上层实现 `OperateLogStorageProvider` SPI 解析 UA 写入 `extra` 并异步落库 `sys_oper_log`。
- **`PasswordUtil`（`ateng-boot-core`）**：已就绪，直接复用 `PasswordUtil.hash(...)` / `PasswordUtil.matches(...)`。
- **`ateng-boot-flyway`（待随 `ateng-boot` 下一递进正式版发布）**：已在 `ateng-boot` `dev` 实现（含生产 `clean` 物理熔断、与 MyBatis-Plus 初始化顺序屏障及 H2 兼容），待 `ateng-boot:1.2.1+` 发布至 Maven Central 后取消 `ateng-solid-bootstrap/pom.xml` 中注释并启用迁移。

---

### [B6] 中优先级（阻塞 Spec 5）：`BusinessException` 支持可选 `traceId` 字段

- **现状与源码锚点**：`BusinessException` 当前无 `traceId` 字段，跨进程 RPC 恢复异常时无法携带下游 `Result.traceId`。
- **目标通用改造**：增量增加可选 `traceId` 与兼容方法 `withTraceId`，并在 `GlobalExceptionHandler` 中兜底回填。
- **状态**：- [ ] 已提 Issue 待底座改造与双轴验收（[atengk/ateng-boot#1080](https://github.com/atengk/ateng-boot/issues/1080)）

---

### [B7] 高优先级（阻塞多租户模式运行）：`CachedStpInterface` 与 `PermissionCacheService` 可选租户维度角色缓存键隔离

- **现状与源码锚点**：
  - `CachedStpInterface#getPermissionsByRole(roleCode, loginType)` 固定使用 `PermissionCacheService.buildRolePermsKey(roleCode, loginType)`，未包含租户维度；开启多租户时不同租户同名角色会触发跨租户权限缓存串味越权。
- **目标通用改造**：
  - 在 `SaTokenProperties.PermissionCacheProperties` 新增默认关闭的 `tenantScoped` 开关（`ateng.boot.satoken.permission-cache.tenant-scoped`，默认 `false` 保持向后兼容），开启后在缓存键、定向失效与集群广播中按租户隔离。
- **发版纪律提醒**：`ateng-boot` 下一正式发版须采用递进版本号（如 `1.2.1` 或 `1.3.0`，包含 `ateng-boot-flyway` 与 `#1076~#1080`、`#1093` 修复），避免继续复用已本地安装过的 `1.2.0` 造成缓存覆盖冲突。
- **状态**：- [ ] 已提 Issue 待底座改造与双轴验收（[atengk/ateng-boot#1093](https://github.com/atengk/ateng-boot/issues/1093)）

---

## 2. `ateng-cloud` (`1.0.0` · 阻塞 Spec 5 微服务并存挂壳)

> 除 C1–C6 外，同步追踪既有基础对齐单 [`atengk/ateng-cloud#198`](https://github.com/atengk/ateng-cloud/issues/198) 与 [`atengk/ateng-cloud#199`](https://github.com/atengk/ateng-cloud/issues/199)。

### [C1] 高优先级（P0）：`ateng-cloud-feign` 与 `ateng-cloud-sentinel` 共存构建崩溃
- **源码锚点**：`AtengSentinelEnvironmentPostProcessor` 注入 `feign.sentinel.enabled=true` 创建 `SentinelFeign$Builder`，而 `AtengFeignAutoConfiguration#atengFeignBuilderCustomizer` 无条件调用 `invocationHandlerFactory(...)` 触发崩溃。
- **状态**：- [ ] 已提 Issue 待底层修复与验证（[atengk/ateng-cloud#200](https://github.com/atengk/ateng-cloud/issues/200)）

### [C2] 高优先级（P0）：`ateng-cloud-gateway` 支持平台超管受控切换目标 `X-Tenant-Id`
- **源码锚点**：网关安全链当前物理剥离或无条件覆写 `X-Tenant-Id`，需增加默认关闭的可配超管切换策略与下游防覆盖协同。
- **状态**：- [ ] 已提 Issue 待底层改造与验证（[atengk/ateng-cloud#201](https://github.com/atengk/ateng-cloud/issues/201)）

### [C3] 高优先级（P1）：`SaTokenGatewayFilter` 与 `FeignContextPropagationInterceptor` 补全注入 `SA-SAME-TOKEN`
- **源码锚点**：网关与 Feign 出站目前仅写 `"Same-Token"` 遗漏 `"SA-SAME-TOKEN"`，与 `@CheckSameToken` 默认头名不一致。
- **状态**：- [ ] 已提 Issue 待底层修复与验证（[atengk/ateng-cloud#202](https://github.com/atengk/ateng-cloud/issues/202)）

### [C4] 中优先级（P1）：Feign / Dubbo 远端异常 `traceId` 回传与 HTTP `409`/`504` 映射补齐
- **源码锚点**：`FeignErrorSupport.mapHttpStatusToResultCode` 遗漏 `409/504`，且跨端消费未回填 `Result.traceId`（联动 `ateng-boot#1080`）。
- **状态**：- [ ] 已提 Issue 待底层改造与验证（[atengk/ateng-cloud#203](https://github.com/atengk/ateng-cloud/issues/203)）

### [C5] 中优先级（P2）：`AtengDubboExceptionFilter` 转译未知异常剥离非白名单 `cause` 开关
- **源码锚点**：`AtengDubboExceptionFilter`（L74/87/130）保留未知原始异常作 `cause`，跨进程序列化易触发类缺失与白名单拦截。
- **状态**：- [ ] 已提 Issue 待评估（[atengk/ateng-cloud#204](https://github.com/atengk/ateng-cloud/issues/204)）

### [C6] 中优先级（P2）：`AtengSentinelEnvironmentPostProcessor` 尊重总开关及限流口径对齐
- **源码锚点**：未判断 `ateng.cloud.sentinel.enabled=false`；Gateway 与 MVC 侧限流状态码口径存在差异。
- **状态**：- [ ] 已提 Issue 待评估（[atengk/ateng-cloud#205](https://github.com/atengk/ateng-cloud/issues/205)）

---

## 3. `ateng-ui` (`1.0.0` ➔ 目标 `1.0.1+` / `1.1.0+`)

### [U0] 高优先级（硬停工等待发版）：等待 `ateng-ui` `dev` 已合入修复发布正式版至 npm

- **现状与实测锚点**：
  - 当前 npm 最新 `1.0.0` 存在三项核心不兼容与安全隐患，均已在 `ateng-ui` `dev` 修复但尚未发布至 npm：
    1. **[`atengk/ateng-ui#362`](https://github.com/atengk/ateng-ui/issues/362)**（分页契约不兼容）：npm `1.0.0` 的 `PageQuery`/`PageResult` 仍为 `pageNum`/`pageSize`/`list`；`dev`（`ea2e643`）已净切对齐 `ateng-boot-core` 的 `current`/`size`/`sorts` 与 `records`/`total`/`pages`（同时 `AtengVueOptions.defaultPageSize` 更名为 `defaultSize`）；
    2. **[`atengk/ateng-ui#363`](https://github.com/atengk/ateng-ui/issues/363)**（指令隔离缺陷）：npm `1.0.0` 的 `v-permission`/`v-role` 在自定义 `AuthManager` 实例（`satoken-admin`）下上下文隔离失效；`dev`（`1e90cd7`）已通过 `resolveAtengConfig` 修复；
    3. **[`atengk/ateng-ui#364`](https://github.com/atengk/ateng-ui/issues/364)**（超管角色收口）：`dev`（`48105c4`）已支持 `createAtengVue({ superAdminRoles: ['super_admin'] })` 覆写默认含 `'admin'` 的集合。
- **准入纪律**：`ateng-ui` 发布递进正式版至 npm 前，**前端停止编写业务分页、权限指令与布局编码**；发版后立即升级 `package.json` 并启用 `superAdminRoles: ['super_admin']`。
- **状态**：- [ ] 上游 `dev` 已合入（`#362`、`#363`、`#364`），待 npm 发布正式递进版本后升级锁定

---

### [U1] 中优先级（硬停工等待）：`AtengProLayout / ProMenuItemNode` 原生字符串图标解析扩展点

- **现状与源码锚点**：
  - `ProMenuItemNode.vue`（`packages/element-plus/src/components/pro-layout/ProMenuItemNode.vue`）遇到 `string` 类型 `icon` 时仅渲染 `<i :class="itemIcon" />`；在以 `@element-plus/icons-vue` 或其它图标库构建的后端动态路由菜单中，后端通常下发图标名称字符串（如 `"User"`、`"Setting"`）。
- **目标通用改造**：
  - 在 `AtengProLayoutProps` 提供通用的字符串图标解析扩展点（如 `iconResolver?: (name: string) => Component | string | undefined` 回调或透传插槽支持），不把 `@element-plus/icons-vue` 强绑定写死进无耦合的菜单渲染器，同时外部任意项目接入即开箱可用。
- **准入纪律**：**严禁在上层提前编写把菜单树字符串属性硬改成组件对象的绕过适配器**，待 `ateng-ui#365` 在底座完成优雅扩展点并随新版发布后，上层仅通过配置式 `iconResolver` 回调接入。
- **状态**：- [ ] 已提 Issue 待底座改造与双轴验收（[atengk/ateng-ui#365](https://github.com/atengk/ateng-ui/issues/365)）

---

### [U2] 纯配置集成：`AtengVue` 显式覆写 `superAdminRoles: ['super_admin']`
- 依托 `U0`（`#364`）发版后，在 `src/main.ts` 配置 `createAtengVue({ httpClient, authManager: adminAuthManager, tenantManager, superAdminRoles: ['super_admin'] })`，与后端 B2 保持一致。

### [U3] 纯布局集成：`KeepAlive` 多标签缓存联动
- `AtengProLayout` 与 `AtengTabsNav` 负责 UI 布局与页签派发，`ateng-solid-admin-web` 在 `AdminLayout.vue` 组合 `useTabsNav`（`@atengk/vue`）与 `<KeepAlive :include="cachedViews">` 属于标准应用层布局装配，无需改底座。
