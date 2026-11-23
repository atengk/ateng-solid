# 底层基础设施待增强清单 (Foundation Enhancements Checklist)

本文档基于对同级目录 `ateng-boot`、`ateng-cloud`、`ateng-ui` 源码、Git 提交记录及 GitHub Issues 状态核查整理，受 [底层缺口即停工规范](../../.agents/rules/foundation-first-gate.md) 硬门禁约束：**凡标为“硬停工等待项”的缺口，上层严禁编写临时降级/绕过补丁，必须待底座完成通用改造、通过独立性验收并发布递进正式版后，再升级恢复上层开发**。

> **2026-11-23 双轴验收与解封结论（`Spec 0` 已通过并锁版解锁）**：
> - `ateng-boot`（已发布 **`v1.2.0`**至 Maven Central，含 `#1076~#1080`、`#1093`、`#1094`、`#1134~#1137`、`ateng-boot-flyway` 及新闭环的 **`#1163~#1167`**，GitHub `Java CI` 与 `Release v1.2.0` 全绿）、`ateng-cloud`（已发布 **`v1.1.0`** 至 Maven Central，对齐 `<ateng-boot.version>1.2.0</ateng-boot.version>`，含 `#198~#206`）、`ateng-ui`（已发布 `@atengk/core`/`vue`/`element-plus` **`1.1.0`** 至官方 npm，含 `#362~#367`）全部完成递进正式发版；
> - 经四项双轴验收审计（① 底座源码与 diff 零 `ateng-solid` 专属命名污染；② 向后兼容与 CI 独立全绿；③ Maven Central / npm 正式版本闭环；④ 上层已解锁 `ateng-boot-flyway` 与 `@atengk/*@1.1.0` 且无临时降级补丁），**`Spec 0` 正式解锁，可进入 `Spec 1 ~ Spec 4` 正式编码**。

---

## 0. 阻塞与就绪矩阵总览 (Spec 0 ~ Spec 5)

| 上层阶段 | 依赖底座项 | 当前状态 | 规划期可推进工作 | 编码开工解锁条件 |
| :--- | :--- | :---: | :--- | :--- |
| **Spec 1**（公共原语/事件/骨架） | `ateng-boot-core:1.2.0`（含 **B9** `#1163`） | 🟢 **已发版并锁版验收通过** | 公共常量、错误码、`DomainEventPublisher`、`AuthGrantHandler` 接口与骨架 | 已解锁（`ateng-boot:1.2.0` + `ateng-ui:1.1.0`） |
| **Spec 2**（认证会话/动态路由/基础壳） | **B1** (`#1076`)、**B2** (`#1077`)、**B4** (`#1079`)、**B5** (`flyway`/`#1094`)、**B9** (`#1163`)、**B10** (`#1164`)、**B12** (`#1166`)、**U0** (`#362~#364`)、**U1** (`#365`) | 🟢 **已发版并锁版验收通过** | 认证中心、验证码、防爆破、动态路由与在线会话治理 | 已解锁（`ateng-boot:1.2.0` + `ateng-ui:1.1.0`） |
| **Spec 3**（RBAC/数据权限/可开关多租户） | **B2** (`#1077`)、**B3** (`#1078`)、**B7** (`#1093`)、**B8** (`#1134`)、**B9** (`#1163`)、**B10** (`#1164`)、**U0** (`#362~#364`) | 🟢 **已发版并锁版验收通过** | DDL 与实体映射（`BaseLogicEntity`/`TenantAware<Long>`）、RBAC 与 `@DataScope` | 已解锁（`ateng-boot:1.2.0` + `ateng-ui:1.1.0`） |
| **Spec 4**（枚举/字典/参数/Excel批注/头像/审计） | **B5** (`#1094`)、**B8** (`#1134`)、**B9** (`#1163`)、**B11** (`#1165`)、**B13** (`#1167`)、**U0** (`#362`)、**U4** (`#367`) | 🟢 **已发版并锁版验收通过** | 枚举接管、字典/参数、头像直传、Excel 精确批注与审计日志 | 已解锁（`ateng-boot:1.2.0` + `ateng-ui:1.1.0`） |
| **Spec 5**（`ateng-cloud` 双态并存挂壳） | **B6** (`#1080`)、**C1~C6** (`#198~#205`) | 🟢 **`ateng-cloud:1.1.0` 已随 `1.2.0` 发版**（按规划排期在单体稳固后实施） | 双装配桥接设计与目录规划 | 已解锁（`ateng-cloud:1.1.0` 已发布至 Maven Central） |

---

## 1. `ateng-boot`（已锁定正式版 **`1.2.0`**）

### [B1] 高优先级：Sa-Token 注解鉴权与多账号路由 (`loginType`) 自动联动

- **改造内容**：在 `ateng-boot-satoken` 增加开关/动态 `StpLogic` 路由解析（`@SaCheckPermission` / `@SaCheckRole` 等未显式指定 `type` 时，按命中路由 `login-type-routes` 或 `primary-login-type` 自动路由到对应 `StpLogic`）。
- **准入纪律**：**严禁在上层 Controller 重复手写 `type = "admin"` 绕过**。
- **核实状态**：- [x] `ateng-boot` `v1.2.0` 已发布并关闭 Issue（[`atengk/ateng-boot#1076`](https://github.com/atengk/ateng-boot/issues/1076)，提交 `e1182df3`） ➔ **Maven Central `1.2.0` 已锁版**

---

### [B2] 高优先级：超管角色可配置化收敛与 `@DataScope` 上下文自动桥接

- **改造内容**：
  1. `SaTokenProperties` 增加可配置超管角色集合 `superAdminRoles`（允许上层收敛覆盖为 `["super_admin"]`）及通配符开关；
  2. `AtengSaTokenInterceptor` 通过弱依赖桥接自动同步并清理 `DataPermissionContextHolder`。
- **准入纪律**：**严禁在上层自写后置拦截器补丁同步 `DataPermissionContextHolder`**。
- **核实状态**：- [x] `ateng-boot` `v1.2.0` 已发布并关闭 Issue（[`atengk/ateng-boot#1077`](https://github.com/atengk/ateng-boot/issues/1077)，提交 `e1182df3`） ➔ **Maven Central `1.2.0` 已锁版**

---

### [B3] 中优先级：未登录租户请求头解析与超管受控切租户 SPI 钩子

- **改造内容**：提供未登录请求头 `X-Tenant-Id` 解析策略与 `TenantHeaderSwitchValidator` SPI 钩子，支撑平台超管受控切换租户视角。
- **准入纪律**：**严禁在上层注册低优先级拦截器绕过覆盖**。
- **核实状态**：- [x] `ateng-boot` `v1.2.0` 已发布并关闭 Issue（[`atengk/ateng-boot#1078`](https://github.com/atengk/ateng-boot/issues/1078)，提交 `e1182df3`） ➔ **Maven Central `1.2.0` 已锁版**

---

### [B4] 中优先级：`LoginFailureLockService` 多租户与多账号作用域隔离键

- **改造内容**：新增带 `(tenantId, loginType, account, clientIp)` 的防碰撞定界重载方法，消除跨租户同名账号误锁。
- **准入纪律**：**严禁在上层手动拼串降级调用**。
- **核实状态**：- [x] `ateng-boot` `v1.2.0` 已发布并关闭 Issue（[`atengk/ateng-boot#1079`](https://github.com/atengk/ateng-boot/issues/1079)，提交 `298aaa95`） ➔ **Maven Central `1.2.0` 已锁版**

---

### [B5] `ateng-boot-web` 枚举端点自主接管开关、`ateng-boot-flyway` 与已就绪能力

- **枚举字典自主接管（`#1094`）**：`ateng-boot-web` 已内置 `ateng.boot.web.enum.endpoint-enabled`（默认 `true`，提交 `9a013643`）；`ateng-solid` 已配置 **`endpoint-enabled: false`**，仅注入 `EnumDictionaryRegistry` 并由 `ateng-solid-system` 自建 `SysEnumController` 挂载 `/admin/system/enums` 实施 `@SaCheckLogin` 及后续权限/租户管控；
- **`ateng-boot-flyway`**：已在 `ateng-boot:1.2.0` 发布（含高危 DDL 预检守卫、生产 `clean` 物理熔断、与 MyBatis-Plus 初始化顺序屏障及 H2 兼容），`ateng-solid-bootstrap/pom.xml` 已取消注释并启用；
- **`OperateLogModel` & `PasswordUtil` & `BeanUtil`**：`1.2.0` 已就绪。
- **核实状态**：- [x] `#1094`（[`atengk/ateng-boot#1094`](https://github.com/atengk/ateng-boot/issues/1094)）与 `ateng-boot-flyway` 已随 `v1.2.0` 发布 ➔ **Maven Central `1.2.0` 已锁版**

---

### [B6] 中优先级（阻塞 Spec 5）：`BusinessException` 支持可选 `traceId` 字段

- **改造内容**：`BusinessException` 新增可选 `traceId` 字段与 `withTraceId` 链式绑定，`Result.getOrThrow` 与 `GlobalExceptionHandler` 自动透传回填。
- **核实状态**：- [x] `ateng-boot` `v1.2.0` 已发布并关闭 Issue（[`atengk/ateng-boot#1080`](https://github.com/atengk/ateng-boot/issues/1080)，提交 `0df1c682`） ➔ **Maven Central `1.2.0` 已锁版**

---

### [B7] 高优先级（阻塞多租户模式运行）：`CachedStpInterface` 与 `PermissionCacheService` 可选租户维度隔离

- **改造内容**：`SaTokenProperties.PermissionCacheProperties` 新增 `tenantScoped` 开关，在缓存键、定向失效与集群同步广播中隔离租户维度角色权限缓存。
- **核实状态**：- [x] `ateng-boot` `v1.2.0` 已发布并关闭 Issue（[`atengk/ateng-boot#1093`](https://github.com/atengk/ateng-boot/issues/1093)，提交 `298aaa95`） ➔ **Maven Central `1.2.0` 已锁版**

---

### [B8] 高优先级（已验收解封）：`ateng-boot-mybatis-plus` 实体阶梯与正交能力接口净切重构

- **现状与源码锚点**：
  - 当前 `ateng-boot-mybatis-plus/.../entity/` 中 `BaseTimeEntity` 死锁继承 `BaseIdEntity`（`Long`），自定义主键 `BaseGenericEntity<ID>` 无法复用审计与软删；
  - `BaseFullEntity`（`Integer deleted 0/1` + `version`）与 `BaseDeleteIdEntity`（`Long deleted` `delval="id"` + `version`）双轨冗余、命名晦涩且将 `@Version` 乐观锁强绑于软删；
  - `TenantEntity` 写死 `String getTenantId()`，与 `tenant_id BIGINT`（`Long tenantId`）不兼容导致 `BatchUtil.autoHeal` 失效；`BatchUtil` 默认填 `version=1` 与 DDL `DEFAULT 0` 不一致。
- **目标通用改造（净切移除旧 `BaseDeleteIdEntity`、`TenantEntity` 与 `Integer deleted` 双轨模型）**：
  1. 提取 5 个正交能力接口：`Identifiable<ID>`、`TenantAware<T>`（兼容 `Long` 与 `String`）、`Auditable`、`Versioned`、`LogicDeletable<T>`；
  2. 落地泛型与雪花双阶梯：泛型链 `BaseGenericEntity<ID>` ➔ `BaseGenericTimeEntity<ID>` ➔ `BaseGenericAuditEntity<ID>` ➔ `BaseGenericLogicEntity<ID>`；雪花链 `BaseIdEntity` ➔ `BaseTimeEntity` ➔ `BaseEntity` ➔ `BaseLogicEntity`（统一 `Long deleted` `delval="id"`，**无锁**）➔ `BaseFullEntity`（追加 `@Version Integer version` 默认 `0`）；
  3. `DefaultMetaObjectHandler` 与 `BatchUtil` 全量面向正交接口自愈并统一 `version` 初始默认值为 `0`。
- **准入纪律**：**严禁在 `ateng-solid` 中基于旧 `BaseDeleteIdEntity` 或自写基类绕过提前编写持久层实体**；等待本单随 `ateng-boot` 下一递进正式版发布后，上层直接继承 `BaseLogicEntity` / `BaseFullEntity` 与 `TenantAware<Long>`。
- **核实状态**：- [x] `ateng-boot` `v1.2.0` 已发布并关闭 Issue（[`atengk/ateng-boot#1134`](https://github.com/atengk/ateng-boot/issues/1134)，提交 `90e67668`） ➔ **Maven Central `1.2.0` 已锁版**

---

### [B9] 高优先级（已验收解封）：`PageResult` 与 `Result` 数值字段保留 JSON 数字序列化

- **现状与源码锚点**：
  - `JacksonCustomizer`（`ateng-boot-web`）在默认 `WebProperties#longToString = true` 时同时将 `Long.class` 与基本类型 `Long.TYPE` 全局序列化为 JSON String；
  - `PageResult<T>`（`ateng-boot-core`）的 `total`/`size`/`current`/`pages` 与 `Result<T>` 的 `timestamp` 均为 `long` 且未声明数字序列化保护，导致返回 `"total": "25"`，触发 `ateng-ui` `@atengk/vue` `usePagination` 严格数字校验（`typeof res?.total === 'number'`）回退失真。
- **目标通用改造**：在 `PageResult` 计数/页码字段及 `Result.timestamp` 上显式强制按 JSON `number` 序列化（新增 `NumericLongSerializer` 与 `ContextualLongToStringSerializer`），保留普通业务实体的雪花 `Long`/`long` 防精度丢失转字符串行为，`ateng-ui` `usePagination` 维持强类型 `number` 契约不动。
- **准入纪律**：**严禁在上层自定义 Jackson 切面/Mixin 补丁或在前端强转字符串兜底绕过**。
- **核实状态**：- [x] 已随 `ateng-boot` `v1.2.0` 正式发布（提交 `763ab86f`，[`atengk/ateng-boot#1163`](https://github.com/atengk/ateng-boot/issues/1163)）并通过双轴验收

---

### [B10] 高优先级（已验收解封）：`CachedStpInterface` / `PermissionCacheService` 复合 `loginId` 对齐与切租户回源保护

- **现状与源码锚点**：
  - `LoginHelper#buildCompositeLoginId` 写入 Sa-Token 的 `loginId` 为 `<tenantId>_<userId>`（分隔符 `_`）；但 `CachedStpInterface` 直接将 `String.valueOf(loginId)` 原样当作 `userId` 生成缓存键并回调 `UserRolePermissionLoader#loadRolesByUserId` / `loadDirectPermissionsByUserId`，而 `PermissionCacheService#clearUserCache` 使用裸 `userId` 生成失效键，导致 DB Loader 收到带前缀 ID 且角色变更清缓存失效；
  - `AtengSaTokenAutoConfiguration` 设置 `saInterceptor.isAnnotation(false)`、`AtengSaTokenInterceptor#preHandle` 在 AOP 前已将 `TenantContextHolder` 切为目标工作租户；缓存未命中触发 Controller `@SaCheckPermission` DB 回源时，会以工作租户过滤归属用户角色表导致串租户。
- **目标通用改造**：新增 `ParsedLoginId` / `LoginHelper#parseCompositeLoginId`；`CachedStpInterface` 剥离出纯 `userId` 与归属 `tenantId` 传给三参加载器并在回源期间通过 `TenantContextHolder.runWithTenant` 锁定主体租户；`PermissionCacheService` 与集群广播同步支持租户维隔离清理。
- **准入纪律**：**严禁在上层重写自定义 `StpInterface` 绕过底座 `CachedStpInterface`**。
- **核实状态**：- [x] 已随 `ateng-boot` `v1.2.0` 正式发布（提交 `bad776a4`，[`atengk/ateng-boot#1164`](https://github.com/atengk/ateng-boot/issues/1164)）并通过双轴验收

---

### [B11] 中优先级（已验收解封）：`OperateLogAspect` 异步前采集 `User-Agent` 及通用轻量 UA 解析工具

- **现状与源码锚点**：`OperateLogAspect` 组装 `OperateLogModel` 后即提交线程池异步回调 `OperateLogStorageProvider#store`，同步阶段未读取 HTTP `User-Agent` 请求头，异步阶段无法再访问 `HttpServletRequest`；全 `ateng-boot` 亦缺零重型外部依赖的通用 UA 解析工具。
- **目标通用改造**：`ateng-boot-core` 新增纯 JDK 零依赖 `UserAgentUtil` / `UserAgentInfo` 并在 `OperateLogModel` 扩展 `userAgent`/`browser`/`os` 字段；`OperateLogAspect` 同步阶段限长采集并解析填充，供操作审计与登录日志直接复用。
- **准入纪律**：**严禁在上层新增额外的 Servlet Filter/AOP 补丁或在业务工程引入第三方 UA 重包**。
- **核实状态**：- [x] 已随 `ateng-boot` `v1.2.0` 正式发布（提交 `763ab86f`，[`atengk/ateng-boot#1165`](https://github.com/atengk/ateng-boot/issues/1165)）并通过双轴验收

---

### [B12] 中优先级（已验收解封）：`LoginHelper` 在线会话条件分页（租户/IP/扫描上限）及归属租户安全强退辅助

- **现状与源码锚点**：`LoginHelper#searchOnlineUserPage(String loginType, String keyword, int page, int size)` 仅支持单个 `keyword` 模糊匹配且硬编码 `MAX_KEYWORD_SCAN_LIMIT = 500`，缺乏按 `tenantId` 与 `loginIp` 条件过滤，且缺乏强退目标 `tokenValue` 归属租户校验辅助方法。
- **目标通用改造**：保留旧签名兼容，新增 `OnlineUserQuery`、`SaTokenProperties.OnlineSessionProperties`（默认扫描上限 `2000`）、精确 IP/CIDR 网段分页筛选及防越权强退注销辅助方法。
- **准入纪律**：**严禁在上层绕过 `LoginHelper` 直接遍历 Sa-Token 底层 Session Key**。
- **核实状态**：- [x] 已随 `ateng-boot` `v1.2.0` 正式发布（提交 `bad776a4`，[`atengk/ateng-boot#1166`](https://github.com/atengk/ateng-boot/issues/1166)）并通过双轴验收

---

### [B13] 高优先级（已验收解封）：`BatchValidationListener` 与 `ExcelReadResult` 保留有效行 1-based 物理行号

- **现状与源码锚点**：
  - `BatchValidationListener#invoke` 计算出了 1-based 物理行号 `rowIndex = context.readRowHolder().getRowIndex() + 1`，但在 JSR-303 校验通过后仅将 DTO 存入 `validDataList` 就直接 `return`，丢弃了 `rowIndex`；
  - `ExcelReadResult<T>` 仅返回纯 `List<T> data` 与 `List<ExcelErrorRow> errors`。一旦表内存在 Fesod 跳过的空白行、前面行格式报错或多行表头，`data` 下标无法反推物理 Excel 行号，后续数据库/业务唯一性校验报错无法准确定位，导致 `ExcelFeedbackUtil.renderErrorFeedback` 标红错行。
- **目标通用改造**：保持既有 `getData()` 100% 向后兼容；新增不可变 `ExcelRowData(rowIndex, data)`、`ExcelRowAware` 可选回填契约、`ExcelReadResult#getRowRecords()` 以及 `ExcelErrorRow.of(...)`/`ofRow(...)` 列元数据自动定位构造工厂。
- **准入纪律**：**严禁在上层弃用 `ExcelUtil.readWithResult` / `BatchValidationListener` 自写原生 Fesod `AnalysisEventListener` 绕过**。
- **核实状态**：- [x] 已随 `ateng-boot` `v1.2.0` 正式发布（提交 `8df76c2d`，[`atengk/ateng-boot#1167`](https://github.com/atengk/ateng-boot/issues/1167)）并通过双轴验收

---

## 2. `ateng-cloud`（已锁定正式版 **`1.1.0`** / 对齐 `ateng-boot:1.2.0`）

> 经核查，`ateng-cloud` 已于 `2026-11-23` 正式发布 **`v1.1.0`**（提交 `a8b9fe4`）至 Maven Central，锁定 `<ateng-boot.version>1.2.0</ateng-boot.version>`，以下全部 8 个关联 Issue 均已闭环发版：

- **BOM 基线升级对齐**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#198`](https://github.com/atengk/ateng-cloud/issues/198)，已对齐 `ateng-boot:1.2.0`）
- **`SaTokenGatewayFilter` 多账号与 `LoginUser` 协议修复**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#199`](https://github.com/atengk/ateng-cloud/issues/199)）
- **[C1] `ateng-cloud-feign` 与 `ateng-cloud-sentinel` 共存兼容**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#200`](https://github.com/atengk/ateng-cloud/issues/200)）
- **[C2] `ateng-cloud-gateway` 支持平台超管受控切换 `X-Tenant-Id`**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#201`](https://github.com/atengk/ateng-cloud/issues/201)）
- **[C3] 网关与 Feign 补全注入 `SA-SAME-TOKEN` 请求头**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#202`](https://github.com/atengk/ateng-cloud/issues/202)）
- **[C4] Feign / Dubbo 远端异常 `traceId` 回传与 HTTP `409`/`504` 映射**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#203`](https://github.com/atengk/ateng-cloud/issues/203)）
- **[C5] `AtengDubboExceptionFilter` 剥离非白名单 `cause` 开关**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#204`](https://github.com/atengk/ateng-cloud/issues/204)）
- **[C6] `AtengSentinelEnvironmentPostProcessor` 尊重总开关及限流口径对齐**：- [x] `v1.1.0` 已发布（[`atengk/ateng-cloud#205`](https://github.com/atengk/ateng-cloud/issues/205)）

---

## 3. `ateng-ui`（已锁定正式版 **`1.1.0`**）

> 经核查，`ateng-ui` 已于 `2026-11-23` 正式发布 `@atengk/core@1.1.0`、`@atengk/vue@1.1.0`、`@atengk/element-plus@1.1.0` 至官方 npm（标签 `v1.1.0`，提交 `c0be02b`），以下增强与修复均已在 `ateng-solid-admin-web/package.json` 升级锁定：

### [U0] `ateng-ui` 核心对齐与隔离修复

- **已发版关闭项（`1.1.0`）**：
  1. [`atengk/ateng-ui#362`](https://github.com/atengk/ateng-ui/issues/362)：分页契约对齐 `current`/`size`/`sorts` 与 `records`/`total`/`pages`（提交 `ea2e643`）；
  2. [`atengk/ateng-ui#363`](https://github.com/atengk/ateng-ui/issues/363)：修复 `v-permission`/`v-role` 在自定义 `AuthManager` 实例下上下文隔离失效（提交 `1e90cd7`）；
  3. [`atengk/ateng-ui#364`](https://github.com/atengk/ateng-ui/issues/364)：支持 `createAtengVue({ superAdminRoles: ['super_admin'] })` 覆写超管角色集合（提交 `48105c4`）。
- **核实状态**：- [x] 已随 `v1.1.0` 发布至 npm ➔ **`ateng-solid-admin-web` 已升级锁定 `1.1.0` 并启用 `superAdminRoles`**

---

### [U1] `AtengProLayout / ProMenuItemNode` 原生字符串图标解析扩展点

- **已发版改造**：`AtengProLayout` / `ProMenu` 支持字符串图标自定义解析回调 `iconResolver`（不写死绑定 `@element-plus/icons-vue`）。
- **核实状态**：- [x] 已随 `v1.1.0` 发布至 npm（[`atengk/ateng-ui#365`](https://github.com/atengk/ateng-ui/issues/365)，提交 `d72e0ba`）

---

### [U2] 纯配置集成：`AtengVue` 显式覆写 `superAdminRoles: ['super_admin']`
- 已于 `ateng-solid-admin-web/src/main.ts` 取消注释并激活 `superAdminRoles: ['super_admin']`，与后端 B2 保持一致。

### [U3] 纯布局集成：`KeepAlive` 多标签缓存联动
- `AtengProLayout` 与 `AtengTabsNav` 负责 UI 布局与页签派发，`ateng-solid-admin-web` 在 `AdminLayout.vue` 组合 `useTabsNav`（`@atengk/vue`）与 `<KeepAlive :include="cachedViews">` 属于标准应用层布局装配，无需改底座。

---

### [U4] 中优先级（已验收解封）：`AtengUpload` 非分片模式支持强类型 `httpRequest` 与 `inheritAttrs: false`

- **现状与源码锚点**：`AtengUploadProps` 未声明 `httpRequest`；`AtengUpload.vue` 模板写死 `:http-request="chunk ? handleCustomHttpRequest : undefined"` 后再接 `v-bind="$attrs"`，且未配置 `inheritAttrs: false`。后端统一返回 HTTP 200 + `Result` 信封，非分片文件上传必须通过 `:http-request` 走 `@atengk/core` `http` 客户端才能正确拦截 HTTP 200 业务失败/401 并自动携带管理端凭据。
- **目标通用改造**：在 `AtengUploadProps` 声明可选 `httpRequest` 类型属性，模板改为 `:http-request="chunk ? handleCustomHttpRequest : httpRequest"`，并在 `defineOptions` 补上 `inheritAttrs: false` 与 `uploaderAttrs` 隔离。
- **准入纪律**：**严禁在上层放弃 `AtengUpload` 退回裸写 `ElUpload` 或绕过类型声明强塞 `$attrs`**。
- **核实状态**：- [x] 已随 `v1.1.0` 正式发布至 npm（提交 `f8838c2`，[`atengk/ateng-ui#367`](https://github.com/atengk/ateng-ui/issues/367)）并通过双轴验收

---

## 4. 发版前历史弃用写法净切清理追踪（`v1.2.0` / `v1.1.0` 已全部随正式版生效）

以下净切移除 `@Deprecated` 与旧版兼容包装的 Issue 已全部随三座底座本次正式版发布生效：

- [x] **`ateng-boot` (`v1.2.0`)**：[`#1135`](https://github.com/atengk/ateng-boot/issues/1135)（`core`/`web`/`mybatis-plus`/`excel`/`observability`/`openapi`，提交 `d7bd5a29`）、[`#1136`](https://github.com/atengk/ateng-boot/issues/1136)（`redis`/`satoken`，提交 `db051125`）、[`#1137`](https://github.com/atengk/ateng-boot/issues/1137)（`job`/`ai`/`notification`/`tcp`，提交 `3a9794a5`）
- [x] **`ateng-cloud` (`v1.1.0`)**：[`#206`](https://github.com/atengk/ateng-cloud/issues/206)（`dubbo`/`nacos`，提交 `f5e54848`）
- [x] **`ateng-ui` (`v1.1.0`)**：[`#366`](https://github.com/atengk/ateng-ui/issues/366)（`@atengk/vue` `superAdminRole`、`@atengk/element-plus` `filterColumnVNodes` 旧签名，提交 `96b7845a`）
