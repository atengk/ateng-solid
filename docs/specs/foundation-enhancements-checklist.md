# 底层基础设施待增强清单 (Foundation Enhancements Checklist)

本文档基于对同级目录 `ateng-boot:1.2.0`、`ateng-cloud:1.0.0` 与 `ateng-ui:1.0.0` 源码及字节码的实测核查整理，受 [底层缺口即停工规范](../../.agents/rules/foundation-first-gate.md) 硬门禁约束，**精确追踪所有向上游底座仓提报的 GitHub Issues、源码锚点、改造方案与验收闭环状态**。

> 注：同时需关注上游已有开放基础对齐单 [`atengk/ateng-cloud#198`](https://github.com/atengk/ateng-cloud/issues/198)（升级对齐 `ateng-boot-bom`）与 [`atengk/ateng-cloud#199`](https://github.com/atengk/ateng-cloud/issues/199)（Gateway 多账号体系与 `LoginUser` 协议断层修复）。

---

## 1. `ateng-boot` (`1.2.0`) 待增强项

### [B1] 高优先级：Sa-Token 注解鉴权与多账号路由 (`loginType`) 自动联动

- **现状与源码锚点**：
  - `LoginHelper.getStpLogic(loginType)`（`ateng-boot-satoken/.../util/LoginHelper.java`）已动态覆盖 `splicingKeyTokenName()` 拼接 `-" + loginType`（生成 `satoken-admin` 请求头）；
  - `AtengSaTokenInterceptor`（`ateng-boot-satoken/.../interceptor/AtengSaTokenInterceptor.java`）能根据 `ateng.boot.satoken.interceptor.login-type-routes` 对 `/admin/**` 执行 `LoginHelper.checkLogin("admin")`；
  - **缺口**：`AtengSaTokenAutoConfiguration` 未接管 Sa-Token 原生注解校验策略（如 `SaStrategy.instance` / 注解切面）。Controller 上若直接书写标准 `@SaCheckPermission("system:user:create")` 或 `@SaCheckRole(...)` 而不传 `type = "admin"`，Sa-Token 默认走 `StpUtil.stpLogic`（`loginType = "login"`，读取请求头 `satoken`），导致后台请求携带 `satoken-admin` 时直接报 401。
- **目标改造**：
  - 在 `ateng-boot-satoken` 增加开关或动态 `StpLogic` 路由解析（当注解未显式指定 `type` 时，按当前请求命中的 `login-type-routes` 或 `primary-login-type` 自动路由到对应 `StpLogic`，而非固定死绑 `"login"`）；
  - 当业务工程未来存在多端（`/admin/**` ➔ `admin`、`/app/**` ➔ `app`）时，同一微服务或网关均无需在每个方法重复手写 `type = "..."`。
- **上层临时降级（若暂不改底层）**：后台所有 `@SaCheckPermission` / `@SaCheckRole` 均须显式写 `type = "admin"`，或全部改由 `DynamicPathPermissionProvider` 配置驱动。
- **状态**：- [ ] 已提 Issue 待底层改造与验证（[atengk/ateng-boot#1076](https://github.com/atengk/ateng-boot/issues/1076)）

---

### [B2] 高优先级：超管角色可配置化收敛与 `@DataScope` 上下文自动桥接

- **现状与源码锚点**：
  - **硬编码超管名隐患**：`LoginHelper.isSuperAdmin()` / `isSuperAdmin(loginType)`（`LoginHelper.java`）目前写死判断角色集合包含 `"admin"` 或 `"super_admin"`，或权限包含 `"*"` / `"*:*:*"`。在多租户业务系统中，普通租户管理员极易配置名为 `"admin"` 的角色编码，会导致其意外获得平台超级管理员特权，直接绕过 `AtengSaTokenInterceptor` 与 `SaCheckDataOwnerAspect` 防线；
  - **上下文脱节隐患**：`AtengDataPermissionInnerInterceptor.shouldIgnore()`（`ateng-boot-mybatis-plus/.../permission/AtengDataPermissionInnerInterceptor.java`）依赖 `DataPermissionContextHolder.isSuperAdmin()` 执行短路放行，但 `AtengSaTokenInterceptor` 在 `preHandle` 未同步写入 `DataPermissionContextHolder.setSuperAdmin(...)`，在 `afterCompletion` 也未调用 `DataPermissionContextHolder.clear()`。
- **目标改造**：
  1. 在 `SaTokenProperties` 增加可配置的超管角色列表（如 `superAdminRoles`，建议默认仅含 `["super_admin"]` 或保持兼容同时允许上层显式配置覆盖去除 `"admin"`）及超管权限通配符开关；
  2. 在 `AtengSaTokenInterceptor` 中通过 `@ConditionalOnClass(DataPermissionContextHolder.class)` 弱依赖自适应桥接：鉴权上下文同步时同步设置 `DataPermissionContextHolder.setSuperAdmin(...)`，并在 `afterCompletion` 的 `finally` 块强制执行 `DataPermissionContextHolder.clear()`。
- **上层临时降级（若暂不改底层）**：① 后端与前端严格禁止创建角色编码 `"admin"`（强制命名为 `tenant_admin`），仅平台超管使用 `super_admin`；② 在 `ateng-solid-server` 自写后置 `HandlerInterceptor` 同步与清理 `DataPermissionContextHolder`。
- **状态**：- [ ] 已提 Issue 待底层改造与验证（[atengk/ateng-boot#1077](https://github.com/atengk/ateng-boot/issues/1077)）

---

### [B3] 中优先级：未登录租户请求头解析与平台超管受控切租户钩子

- **现状与源码锚点**：
  - `AtengSaTokenInterceptor.applyContextForLoginType` 与 `SaTokenCurrentTenantProvider`（`ateng-boot-satoken/.../provider/SaTokenCurrentTenantProvider.java`）仅在用户已登录时从 `LoginUser.getTenantId()` 注入 `TenantContextHolder`；
  - 对于免登录接口（如 `@Anonymous` 登录接口），客户端传入的 `X-Tenant-Id` 不会进入 `TenantContextHolder`；
  - 当平台超管（会话 `tenantId = "0"`）携带 `X-Tenant-Id` 请求头切换到指定租户视角时，会被 `AtengSaTokenInterceptor` 使用会话中的 `"0"` 覆盖。
- **目标改造**：
  - 可选在 `ateng-boot-satoken` / `ateng-boot-web` 提供可配置的多租户解析策略或 `TenantHeaderResolver` SPI（如登录前从指定头解析候选租户，登录后允许校验通过的超管身份采信目标 `X-Tenant-Id`，普通用户强制锁定会话租户并清理）。
- **上层可承接方案**：在 `ateng-solid-server` 注册排在 `AtengSaTokenInterceptor` 之后的低优先级 `TenantResolveInterceptor`，同样可安全实现该逻辑（`afterCompletion` 注意一并兜底清理）。
- **状态**：- [ ] 已提 Issue 待评估分诊（[atengk/ateng-boot#1078](https://github.com/atengk/ateng-boot/issues/1078)）

---

### [B4] 中优先级：`LoginFailureLockService` 多租户与多账号隔离键

- **现状与源码锚点**：
  - `LoginFailureLockService`（`ateng-boot-satoken/.../defense/LoginFailureLockService.java`）的 `checkLocked(account, clientIp)`、`recordFailure(account, clientIp)`、`clearFailure(account)` 仅接收单个 `account` 字符串拼接 `ateng:satoken:login-fail:<account>`。
  - 不同租户下若存在同名账号（例如租户 A 与租户 B 均有 `zhangsan`），直接传用户名会产生跨租户误锁定。
- **目标改造**：
  - 在 `LoginFailureLockService` 增加带 `(tenantId, loginType, account, clientIp)` 的重载方法（或自动读取当前 `TenantContextHolder` 拼装作用域前缀），保留原签名向后兼容。
- **上层临时降级**：调用 `LoginFailureLockService` 时统一传入组合键 `tenantId + ":" + loginType + ":" + username`。
- **状态**：- [ ] 已提 Issue 待评估分诊（[atengk/ateng-boot#1079](https://github.com/atengk/ateng-boot/issues/1079)）

---

### [B5] 已验证就绪、仅需上层显式适配的底座细节（无需改底层）

- **`EnumDictionaryController`（`ateng-boot-web`）**：默认 `enabled = false`、默认路径 `/api/system/enums`；在 `ateng-solid-server` 显式配置 `ateng.boot.web.enum.enabled=true`、`path-prefix=/admin/system/enums`、`scan-packages=io.github.atengk.solid` 即可；另需注意若登录前需要读取枚举字典则配置白名单，否则自动受 `/admin/**` 登录守卫保护。
- **`OperateLogModel`（`ateng-boot-core`）**：包含 18 项通用审计字段与扩展字段 `Map<String, Object> extra`；无独立 `browser` / `os` 属性，可在上层 `OperateLogStorageProvider` 实现中解析 User-Agent 并存入 `extra` 或入库映射列。
- **`PasswordUtil`（`ateng-boot-core`）**：原生内置 `PBKDF2WithHmacSHA256`（310,000 次迭代 + 16 字节随机盐），可直接调用 `PasswordUtil.hash(...)` / `PasswordUtil.matches(...)`。
- **`ateng-boot-flyway`（`dev` 待随新版发布）**：原生内置生产 Profile `clean` 物理熔断、与 MyBatis-Plus 的启动初始化顺序屏障及 H2（`MODE=MySQL`）兼容支持；实测尚未随 `1.2.0` 发布至 Maven Central，`ateng-solid-bootstrap/pom.xml` 已预留占位，待 `ateng-boot` 下一正式版发版后直接启用。

---

### [B6] 中优先级：`BusinessException` 支持可选 `traceId` 字段（联动 Cloud 异常追踪）

- **现状与源码锚点**：
  - `BusinessException`（`ateng-boot-core/.../exception/BusinessException.java`）目前仅携带 `code`、`msg`、`resultCode`、`writableStackTrace`，未定义可选 `traceId` 字段，导致 Feign / Dubbo 消费端在恢复跨进程业务异常时无法将下游真实 `Result.traceId` 绑定至异常对象。
- **目标改造**：
  - 增量增加可选 `traceId` 字段及兼容读写方法（如 `withTraceId`），保持既有全量构造重载 100% 向后兼容，并在 `ateng-boot-web` `GlobalExceptionHandler` 中兜底回填。
- **状态**：- [ ] 已提 Issue 待底层改造与验证（[atengk/ateng-boot#1080](https://github.com/atengk/ateng-boot/issues/1080)）

---

## 2. `ateng-cloud` (`1.0.0`) 待增强与并存契合项

> 除本清单新增提交的 C1–C6 外，需同步跟进上游既有关联单：[`atengk/ateng-cloud#198`](https://github.com/atengk/ateng-cloud/issues/198)（升级对齐 `ateng-boot-bom`）与 [`atengk/ateng-cloud#199`](https://github.com/atengk/ateng-cloud/issues/199)（修复 `SaTokenGatewayFilter` 多账号与 `LoginUser` 协议断层）。

### [C1] 高优先级（P0 阻塞）：`ateng-cloud-feign` 与 `ateng-cloud-sentinel` 共存构建崩溃

- **现状与源码锚点**：
  - `AtengSentinelEnvironmentPostProcessor`（L40-42）检测到 `FeignClient` 即默认注入 `feign.sentinel.enabled=true`，创建 `SentinelFeign$Builder`（其 `invocationHandlerFactory` 方法直接抛 `UnsupportedOperationException`）；
  - 但 `AtengFeignAutoConfiguration#atengFeignBuilderCustomizer`（L204）无条件调用 `builder.invocationHandlerFactory(...)`，导致一旦同时引入 `ateng-cloud-all`（或 `feign + sentinel`）并声明任何 `@FeignClient` 即启动崩溃。
- **目标改造**：在 `AtengFeignAutoConfiguration` 中安全识别 `SentinelFeign.Builder` 避免非法调用 `invocationHandlerFactory(...)`，并确保熔断与自适应解包/异常转译兼容；在 `sample-cloud-smoke-test` 增加真实 `@FeignClient` 冒烟测试。
- **状态**：- [ ] 已提 Issue 待底层修复与验证（[atengk/ateng-cloud#200](https://github.com/atengk/ateng-cloud/issues/200)）

---

### [C2] 高优先级（P0 契约）：`ateng-cloud-gateway` 支持平台超管受控切换目标 `X-Tenant-Id`

- **现状与源码锚点**：
  - `GatewayHeaderSanitizeFilter`、`SaTokenGatewayFilter` 与 `GatewayTenantFilter` 三段链路当前在开启安全默认配置（`allow-header=false`）时会物理剥离入站 `X-Tenant-Id`，且登录后无条件用会话 `tenantId` 覆盖出站头，尚未支持平台租户（`"0"`）+ 角色 `super_admin` 切换目标租户。
- **目标改造**：新增默认关闭的受控配置（`allowSuperAdminSwitch=false`、`platformTenantIds`、`superAdminRoles`）与校验钩子，同时维持普通租户强锁定与匿名流量隔离，并明确下游微服务 MVC 拦截器防覆盖协同方式。
- **状态**：- [ ] 已提 Issue 待底层改造与验证（[atengk/ateng-cloud#201](https://github.com/atengk/ateng-cloud/issues/201)）

---

### [C3] 高优先级（P1 协议）：`SaTokenGatewayFilter` 与 `FeignContextPropagationInterceptor` 补全注入 `SA-SAME-TOKEN`

- **现状与源码锚点**：
  - `SaSameUtil.SAME_TOKEN` 与 `ateng-boot-satoken` 原生 `@CheckSameToken` 默认读取 `"SA-SAME-TOKEN"`，`DubboSameTokenFilter` 已双头兼容；但 `SaTokenGatewayFilter.injectSameTokenHeaders` 与 `FeignContextPropagationInterceptor.apply` 出站均遗漏写入 `"SA-SAME-TOKEN"`（仅写了 `"Same-Token"`）。
- **目标改造**：在网关与 Feign 出站注入逻辑中同步补充 `"SA-SAME-TOKEN"` 头（保留原 `"Same-Token"` 向后兼容）。
- **状态**：- [ ] 已提 Issue 待底层修复与验证（[atengk/ateng-cloud#202](https://github.com/atengk/ateng-cloud/issues/202)）

---

### [C4] 中优先级（P1 链路）：Feign / Dubbo 远端异常 `traceId` 回传与 HTTP `409`/`504` 映射补齐

- **现状与源码锚点**：
  - `FeignErrorSupport.mapHttpStatusToResultCode` 遗漏 `409 -> CONFLICT` 等映射；且 `AtengFeignDecoder`、`AtengFeignErrorDecoder`、`AtengDubboExceptionFilter` 尚未将下游 `Result.traceId` 绑定回异常对象。
- **目标改造**：补齐 `409` / `504` 状态码映射，并在联动 `ateng-boot#1080` 后支持将远端 `traceId` 回填至 `BusinessException`。
- **状态**：- [ ] 已提 Issue 待底层改造与验证（[atengk/ateng-cloud#203](https://github.com/atengk/ateng-cloud/issues/203)）

---

### [C5] 中优先级（P2 安全）：`AtengDubboExceptionFilter` 转译未知异常剥离非白名单 `cause` 开关

- **现状与源码锚点**：`AtengDubboExceptionFilter`（L74/87/130）直接保留未知原始异常作 `cause`，跨进程序列化若遇消费端缺失第三方类或超出 `SerializeSecurityManager` 白名单会触发反序列化异常。
- **目标改造**：提供可配置剥离开关（保留本地完整日志堆栈，出站安全收敛摘要与 `BusinessException`）。
- **状态**：- [ ] 已提 Issue 待评估（[atengk/ateng-cloud#204](https://github.com/atengk/ateng-cloud/issues/204)）

---

### [C6] 中优先级（P2 治理）：`AtengSentinelEnvironmentPostProcessor` 尊重总开关及限流口径对齐

- **现状与源码锚点**：`AtengSentinelEnvironmentPostProcessor` 未检测 `ateng.cloud.sentinel.enabled=false` 即注入 `feign.sentinel.enabled=true`；另 Gateway 限流降级返回 `429/503 + Retry-After: 1`，而 MVC 侧 `AtengBlockExceptionHandler` 返回 `4201~4205`。
- **目标改造**：前置检查 `ateng.cloud.sentinel.enabled`，并评估提供 Sentinel 错误码与 `Retry-After` 口径对齐选项。
- **状态**：- [ ] 已提 Issue 待评估（[atengk/ateng-cloud#205](https://github.com/atengk/ateng-cloud/issues/205)）

---

## 3. `ateng-ui` (`1.0.0`) 待增强与上层适配项

### [U1] 轻度增强：`ProMenuItemNode` 对字符串图标（Element Plus 图标名）的原生解析

- **现状与源码锚点**：
  - `ProMenuItemNode.vue`（`packages/element-plus/src/components/pro-layout/ProMenuItemNode.vue`）渲染菜单图标时：当 `icon` 为 Vue 组件对象/函数时使用 `<component :is="itemIcon" />`；当 `icon` 为 `string` 时直接渲染 `<i :class="itemIcon" />`（仅适配 CSS 字体图标类名）。
  - 后端菜单表 `sys_menu.icon` 通常存储图标名称字符串（如 `"User"`、`"Setting"` 或 `"ep:setting"`）。
- **可选底层改造 vs 上层方案**：
  - **可选改底层**：在 `AtengProLayoutProps` 增加 `iconRenderer` 或在内置支持按注册表解析图标名字符串；
  - **上层零改底层方案（推荐直接采用）**：前端在将后端菜单树转换为 `ProMenuItem[]` 时，通过本地图标映射表将 `icon` 字符串转为对应 `@element-plus/icons-vue` 组件对象（或使用 `AtengProLayout` 已暴露的 `#menuItem` 插槽渲染）。
- **状态**：- [ ] 已提 Issue 待评估改造（[atengk/ateng-ui#365](https://github.com/atengk/ateng-ui/issues/365)；上层亦可通过字段映射兼容，不阻塞开发）

---

### [U2] 上层必须显式覆写：`AtengVue` 默认 `superAdminRoles` 去 `"admin"`

- **现状与源码锚点**：
  - `packages/vue/src/context/context.ts` 中 `DEFAULT_OPTIONS.superAdminRoles` 默认为 `['admin', 'super_admin']`；
  - 当 `useAuth` / `v-permission` / `v-role` 运行时，凡角色列表含 `'admin'` 会自动跳过前端按钮权限校验。
- **上层处理方式（待 `@atengk/vue` 1.0.1+ 发版生效）**：
  - `atengk/ateng-ui#364` 已在 `ateng-ui` `dev` 分支合入全局 `superAdminRoles`，实测尚未随 `1.0.0` 发布至 npm；待 `ateng-ui` 下一正式版发布后，立即在 `src/main.ts` 显式覆写：`app.use(createAtengVue({ authManager: adminAuthManager, superAdminRoles: ['super_admin'] }))`，与后端 B2 保持完全对齐。

---

### [U3] 上层业务集成职责：`KeepAlive` 多标签缓存联动

- **现状与说明**：
  - `AtengProLayout` 与 `AtengTabsNav` 负责 UI 布局与标签页状态派发，不直接内置 `vue-router` 与 `<KeepAlive>` 缓存列表绑定（符合 UI 组件库解耦原则）。
- **上层处理方式**：在 `ateng-solid-admin-web` 布局壳中配合 `@atengk/vue` `useTabsNav` 与路由 `meta.keepAlive` 自行封装 `<router-view v-slot="{ Component, route }">` + `<keep-alive :include="cachedViews">`。
