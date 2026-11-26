# 底层基础设施待增强清单 (Foundation Enhancements Checklist)

本文档基于对同级目录 `ateng-boot`、`ateng-cloud`、`ateng-ui` 源码、Git 提交记录及 GitHub Issues 状态核查整理，受 [底层零补丁与跨仓联调规范](../agents/foundation-first-gate.md) 约束：**上层严禁编写临时降级/绕过补丁；经本地 `-SNAPSHOT` / `yalc` 调通且底座改动已提交至底座 `dev` 后，上层可在 `dev` 正常提交并关闭对应业务/缺陷 Issue，合入 `main` 与发版前须待底座发布递进正式版并锁回正式版本号**。

> **最新修订（2026-11-26 · 同步 `ADR-0004` 双阶门禁与后继底座项 `B20`/`U13~U16`）**：
> - **首轮基础底座锁版（`Spec 0` ✅ 解封）**：`ateng-boot:1.2.0`、`ateng-cloud:1.1.0`、`ateng-ui:1.1.0`（`@atengk/{core,vue,element-plus}`）已完成双轴验收并锁版；
> - **一阶段全部增量增强（`B14~B18` & `U5~U12` · 🟢 上游 `dev` 均已修复 · 🔵 本地联调包已刷新 · ⏳ 合入 `main` 前待发版锁版）**：
>   - `ateng-boot`：`#1171` (`8e7bef82`)、`#1172` (`0c172a12`)、`#1173` (`11457a6d`)、`#1174` (`e701cc34`)、`#1175` (`900bd9c9`) 均已在上游 `dev` 修复并重新安装本地 `1.2.1-SNAPSHOT`；
>   - `ateng-ui`：`#369`–`#372` (`36da58c`)、`#373` (`758b4c2`)、`#374` (`cdab8c3`)、`#375` (`3434c86`)、`#376` (`3cb4d48`) 均已关单并经 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`；
>   - 上述 13 项均可在 `dev` 携带 `1.2.1-SNAPSHOT` / `file:.yalc` 直接完成编码、本地全量验证、提交与关单；**合入 `main` 与正式发版前须待底座发布递进正式版（`1.2.1` / `1.1.1`）并还原锁版（由 `main` `pre-commit`、`pre-push`、`main` CI 与 `release.yml` 硬拦截守护）**。
> - **全功能走查后继增强（2026-11-26 · 🟢 上游 `dev` 均已闭环 · 🔵 本地联调包已刷新 · ⏳ 合入 `main` 前待发版锁版）**：
>   - `ateng-boot`：**`B20`**（[`#1177`](https://github.com/atengk/ateng-boot/issues/1177)，提交 `fc329ec2`，已安装本地 `1.2.1-SNAPSHOT`，关联 [`atengk/ateng-solid#47`](https://github.com/atengk/ateng-solid/issues/47)）；
>   - `ateng-ui`：**`U13`**（[`#377`](https://github.com/atengk/ateng-ui/issues/377)）、**`U14`**（[`#378`](https://github.com/atengk/ateng-ui/issues/378)），均于上游 `dev` 提交 `a9616d0` 闭环并经 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`（分别关联 [`atengk/ateng-solid#53`](https://github.com/atengk/ateng-solid/issues/53) 与 [`atengk/ateng-solid#50`](https://github.com/atengk/ateng-solid/issues/50)）；**`U15`**（[`#379`](https://github.com/atengk/ateng-ui/issues/379)，上游提交 `ee55b3b` / `d255cd8` 已关单并经 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`，关联 `admin-web` [ADR-0004](../../ateng-solid-admin-web/docs/adr/0004-dual-card-table-and-adaptive-pagination.md)）；**`U16`**（[`#380`](https://github.com/atengk/ateng-ui/issues/380)，上游提交 `19f79a7` / `1365732` 已关单并经 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`，关联 `admin-web` [ADR-0005](../../ateng-solid-admin-web/docs/adr/0005-tiered-query-collapse-and-max-auto-height-table.md)）；**`U17`**（[`#381`](https://github.com/atengk/ateng-ui/issues/381)，上游提交 `934135a` 已关单并经 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`，关联 [`atengk/ateng-solid#57`](https://github.com/atengk/ateng-solid/issues/57)）。

---

## 0. 阻塞与就绪矩阵总览 (Spec 0 ~ Spec 5)

| 上层阶段 | 依赖底座项 | 当前状态 | 规划期/本地联调可推进工作 | 正式提交合入解锁条件 |
| :--- | :--- | :---: | :--- | :--- |
| **第一阶段 PRD & HTML 原型** | 已完成 `#2`/`#3` 调研 | 🟢 **已完结待签收** | 按 `atengk/ateng-solid#1` 路线图已完成全套 PRD、总装原型与跨仓 1:1 终审 | 已完结 |
| **Spec 1**（公共原语/事件/骨架/令牌） | `ateng-boot-core:1.2.0`（含 **B9** `#1163`）；**增量**：**B16** (`#1173`)、**U9** (`#373`)、**U10** (`#374`) | 🟢 **`dev` 已放行** / ⏳ **合 `main` 待锁版** | 公共原语、`system-api` 契约、双模配置（`DENY_ALL`）、17 表 DDL/种子、9 条 ArchUnit 与前端无 `theme-pro` 令牌/三单例/Vitest 基线 | `ateng-boot` 发布含 `#1173`、`ateng-ui` 发布含 `#373~#374` 的递进正式版并还原锁版 |
| **Spec 2**（认证会话/动态路由/方案 A 壳） | **B1** (`#1076`)、**B2** (`#1077`)、**B4** (`#1079`)、**B5** (`flyway`/`#1094`)、**B9** (`#1163`)、**B10** (`#1164`)、**B12** (`#1166`)、**U0** (`#362~#364`)、**U1** (`#365`)；**增量**：**U5** (`#369`)、**U12** (`#376`) | 🟢 **`dev` 已放行** / ⏳ **合 `main` 待锁版** | 认证中心、验证码、防爆破 `101004`、不透明句柄、超管引导器、租户运行时拦截、动态路由与方案 A `AdminLayout`（本地通过 `yalc` 接入 `#369`/`#376`） | `ateng-ui` 发布含 `#369`/`#376` 的递进正式版并还原锁版 |
| **Spec 3**（RBAC/数据权限/可开关多租户/导入） | **B2** (`#1077`)、**B3** (`#1078`)、**B7** (`#1093`)、**B8** (`#1134`)、**B9** (`#1163`)、**B10** (`#1164`)、**B13** (`#1167`)、**U0** (`#362~#364`)；**增量**：**B14** (`#1171`)、**B16** (`#1173`)、**B17** (`#1174`)、**U6~U8** (`#370~#372`)、**U11** (`#375`) | 🟢 **`dev` 已放行** / ⏳ **合 `main` 待锁版** | 5 级 `@DataScope`、组织与 RBAC、可开关多租户与套餐裁剪、500 行三段式 Fesod 并发导入与批注回写（本地通过 `1.2.1-SNAPSHOT` 与 `yalc` 联调验证） | `ateng-boot` 发布含 `#1171/#1173/#1174`、`ateng-ui` 发布含 `#370~#372/#375` 的递进正式版并还原锁版 |
| **Spec 4**（枚举/字典/参数/头像/审计） | **B5** (`#1094`)、**B8** (`#1134`)、**B9** (`#1163`)、**B11** (`#1165`)、**U0** (`#362`)、**U4** (`#367`)；**增量**：**B15** (`#1172`)、**B18** (`#1175`)、**U11** (`#375`) | 🟢 **`dev` 已放行** / ⏳ **合 `main` 待锁版** | 7 项静态枚举接管、字典/参数多租户缓存、操作/登录只读审计与 S3/RustFS（含 `local` `#1172` 回退）预签名 `inline` 头像直链 | `ateng-boot` 发布含 `#1172`/`#1175`、`ateng-ui` 发布含 `#375` 的递进正式版并还原锁版 |
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

### [B14] 高优先级（上游 `dev` 已闭环 · 本地 `1.2.1-SNAPSHOT` 联调中 · 正式合入待发版锁版）：`ExcelUtil.readWithResult` 强制执行 `maxSyncRows` 安全上限防御

- **现状与源码锚点**：`ateng-boot-excel` 中 `ExcelUtil.read`（`ExcelUtil.java:940`）与 `ExcelUtil.readWithValidation`（`ExcelUtil.java:1221`）均校验 `maxSyncRows`（默认 `100_000`）；但 `ExcelUtil.readWithResult`（`ExcelUtil.java:1314-1342`）在无流式消费器（`dataConsumer = null`）全量驻留内存聚合法定数据与错误行时，完全未检查 `maxSyncRows`，存在大文件触发 OOM 的风险。
- **目标通用改造**：在 `BatchValidationListener`（非流式全量聚合场景）与 `ExcelUtil.readWithResult` 中纳管 `maxSyncRows` 上限检查，超过即 Fail-Fast 抛出 `BusinessException(400, ...)`，100% 向后兼容。
- **准入纪律**：**严禁在上层放弃 `ExcelUtil.readWithResult` 或自写全量计数监听器绕过**；`dev` 阶段消费 `1.2.1-SNAPSHOT` 联调提交，合入 `main` 与发版前须待底座发布正式版并还原锁版。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-boot#1171`](https://github.com/atengk/ateng-boot/issues/1171)，`dev` 提交 `8e7bef82`），本地已接入 `1.2.1-SNAPSHOT` 联调，待发布正式版后锁版勾选

---

### [B15] 中优先级（上游 `dev` 已闭环 · 本地 `1.2.1-SNAPSHOT` 联调中 · 正式合入待发版锁版）：本地存储预签名只读下载端点与 Sa-Token 可选白名单协同开关

- **现状与源码锚点**：`ateng-boot-storage` 自动装配了 `LocalStorageDownloadController`（默认 `/storage/local/download`，内置 HMAC-SHA256 签名与 `expires` 时效防盗链）；但当宿主启用 `ateng-boot-satoken` 全局拦截（`check-login=true`、`includes=["/**"]`）时，浏览器 `<img>` / `<el-avatar>` 直接加载预签名链接会因无法携带自定义 Token 头返回 `401`。
- **实际落地通用改造**：`LocalStorageProperties` 新增细粒度开关 `download-endpoint-enabled` / `upload-endpoint-enabled`（默认 `true`）与 `whitelist-presigned-download` / `whitelist-presigned-upload`（默认 `false`），在 `ateng-boot-storage` 中通过 `LocalStorageSaTokenWhitelistConfiguration`（类加载隔离）按需注册精确路径白名单。
- **准入纪律**：**严禁在业务配置硬编码绕过内部下载端点或自写冗余转发代理控制器**；`dev` 阶段消费 `1.2.1-SNAPSHOT` 联调提交，合入 `main` 与发版前须待底座发布正式版并还原锁版。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-boot#1172`](https://github.com/atengk/ateng-boot/issues/1172)，`dev` 提交 `0c172a12`），本地已接入 `1.2.1-SNAPSHOT` 联调，待发布正式版后锁版勾选

---

### [B16] 高优先级（上游 `dev` 已闭环 · 本地 `1.2.1-SNAPSHOT` 已更新 · 正式合入待发版锁版）：`AtengDataPermissionInnerInterceptor` 自动对 `OrExpression` 加括号与 Fail-Closed 可配失败策略

- **现状与源码锚点**：`AtengDataPermissionInnerInterceptor.java:108-114` 原先存在两处数据权限安全防卫缺口：① 透传返回 `DataPermissionHandler` 生成的裸 `OrExpression`；② 捕获处理器异常后直接 `return null`（Fail-Open）。
- **实际落地通用改造**：新增 `DataPermissionFailureStrategy` 枚举与 `ateng.boot.mybatis-plus.data-permission.failure-strategy`（默认 `DENY_ALL`，支持 `THROW`/`FAIL_OPEN`）；写时复制包裹顶层及嵌套 `OrExpression`，并显式透传 `BusinessException`。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-boot#1173`](https://github.com/atengk/ateng-boot/issues/1173)，`dev` 提交 `11457a6d`），已更新本地 `1.2.1-SNAPSHOT`，待发布正式版后锁版勾选

---

### [B17] 中优先级（上游 `dev` 已闭环 · 本地 `1.2.1-SNAPSHOT` 已更新 · 正式合入待发版锁版）：`ExcelUtil.readWithResult` 支持按次覆写 `maxSyncRows` 重载并完善 `ExcelReaderBuilder` 行号保留

- **现状与源码锚点**：`ExcelUtil.java:1239-1341` 缺少按单次调用覆写 `maxSyncRows` 的重载；`ExcelReaderBuilder` 聚合监听器丢失 `validRowRecords`。
- **实际落地通用改造**：`ExcelUtil.readWithResult` 新增 4 个无歧义 `int maxSyncRows` 重载；`ExcelReaderBuilder` 与 `ExcelMultiSheetResult` 同步保留 1-based `ExcelRowData` 物理行号视图。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-boot#1174`](https://github.com/atengk/ateng-boot/issues/1174)，`dev` 提交 `e701cc34`），已更新本地 `1.2.1-SNAPSHOT`，待发布正式版后锁版勾选

---

### [B18] 高优先级（上游 `dev` 已修复 · 本地 `1.2.1-SNAPSHOT` 已更新 · 正式合入待发版锁版）：`OperateTypeEnum` 实现 `IBaseEnum<Integer>` 契约

- **现状与源码锚点**：
  - `ateng-boot-core/src/main/java/io/github/atengk/boot/core/audit/OperateTypeEnum.java:19` 原未实现 `IBaseEnum<Integer>`（缺少 `getLabel()`）；
  - `EnumDictionaryRegistry.java:168,207` 扫描过滤与注册校验均要求 `IBaseEnum.class.isAssignableFrom(clazz)`，此前导致 `scan-packages: [io.github.atengk.boot.core.audit]` 无法注册 `operateType`。
- **实际落地通用改造**：上游提交 `900bd9c9` 已让 `OperateTypeEnum` 实现 `IBaseEnum<Integer>` 并新增 `getLabel()` 返回 `description`（完整保留 `getCode()`、`getDescription()`、`of(...)`、`@JsonCreator` 向后兼容），并补齐 Core/Web/Sample 单测；本地已重新安装 `1.2.1-SNAPSHOT` 并解锁通过 `ateng-solid-server` 全量离线测试与 `operateType` 静态枚举全量验证。
- **核实状态**：- [ ] 上游 `dev` 已提交修复（[`atengk/ateng-boot#1175`](https://github.com/atengk/ateng-boot/issues/1175)，`dev` 提交 `900bd9c9`），已更新本地 `1.2.1-SNAPSHOT`，待上游推送并发布正式版后锁版勾选

---

### [B19] 中/高优先级（上游 `dev` 已修复 · 关联 `atengk/ateng-solid#38`）：`AtengSaTokenAutoConfiguration` 与 `SaBeanInject` 初始化顺序竞态导致 `TokenProperties` 被覆盖

- **现状与源码锚点**：`AtengSaTokenAutoConfiguration.@PostConstruct initFirewallStrategy()` 将 `ateng.boot.satoken.token.timeout`（`24h`）与 `active-timeout` 写入 `SaManager.getConfig()` 后，后初始化的 `sa-token-spring-boot3-starter` `SaBeanInject` 构造函数调用 `SaManager.setConfig(SaBeanRegister.getSaTokenConfig())`，将全局配置覆盖回 Sa-Token 默认 `2592000s`（30 天）与 `-1`。
- **准入纪律**：**严禁在上层 `ateng-solid-server` 编写自定义 `SaTokenConfig` Bean 或后置补丁绕过**；已在上游 `dev` 通用修复并可随 `dev` 提交闭环 `#38`，合入 `main` 前锁回正式版。
- **核实状态**：- [ ] 上游 `dev` 已提交修复（[`atengk/ateng-boot#1176`](https://github.com/atengk/ateng-boot/issues/1176)，`dev` 提交 `193a7713`），已更新本地 `1.2.1-SNAPSHOT` 并完成 [`atengk/ateng-solid#38`](https://github.com/atengk/ateng-solid/issues/38) 端到端回归验证（`/admin/auth/online/page` 返回 `tokenTimeout=86388` / 页面显示 `23小时59分`），待上游推送并发布正式版后锁版勾选

---

### [B20] 中优先级（上游 `dev` 已闭环 · 本地 `1.2.1-SNAPSHOT` 已更新 · 正式合入待发版锁版）：`OperateLogAspect` 支持请求路由模板采集或路径参数脱敏配置

- **现状与源码锚点**：`ateng-boot-web` 的 `OperateLogAspect.java:132,208` 原固定采集 `request.getRequestURI()` 并写入 `OperateLogModel.requestUrl`。
- **实际落地通用改造**：上游提交 `fc329ec2` 新增 `OperateLogUrlStrategy`（`DEFAULT` / `RAW_URI` / `BEST_MATCHING_PATTERN`），并在 `@OperateLog` 与 `WebProperties.OperateLogProperties` 增加 `urlStrategy` 与 `templateUrls` 配置能力（100% 向后兼容 `RAW_URI` 默认行为）；配合既有 `excludeParams` 即可同时脱敏路径路由与敏感参数。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-boot#1177`](https://github.com/atengk/ateng-boot/issues/1177)，提交 `fc329ec2`），已更新本地 `1.2.1-SNAPSHOT` 并由 [`atengk/ateng-solid#47`](https://github.com/atengk/ateng-solid/issues/47) 消费联调，待上游发布正式版并锁版后勾选

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

### [U5] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 联调中 · 正式合入待发版锁版）：`AtengProLayout` `'mix'` 模式 `headerRight` 补充 `#headerActions` / `#user` 默认兜底

- **现状与源码锚点**：`AtengProLayout.vue` 在 `'side'`（lines 473–480）与 `'top'`（lines 553–560）模式下均于 `#headerRight` 内提供 `#headerActions` 与 `#user` 默认兜底插槽，但 `'mix'` 模式（lines 625–627）仅渲染 `<slot name="headerRight" />`，导致切至 `'mix'` 模式时顶栏右侧操作区与用户信息消失。
- **目标通用改造**：在 `'mix'` 模式补齐与 `'side'`/`'top'` 完全一致的 `#headerActions` 与 `#user` 默认兜底，100% 向后兼容。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#369`](https://github.com/atengk/ateng-ui/issues/369)，`dev` 提交 `36da58c`），本地已通过 `pnpm pack + yalc` 接入验证，待 npm 发版后还原锁版勾选

---

### [U6] 低/中优先级（上游 `dev` 已闭环 · 本地 `yalc` 联调中 · 正式合入待发版锁版）：`AtengDrawer` `#footer` 插槽透传 `{ confirm, cancel, loading }` 作用域参数

- **现状与源码锚点**：`AtengDialog.vue:310` 向 `#footer` 透传 `{ confirm, cancel, loading }` 作用域参数，而 `AtengDrawer.vue:247` 与 `drawer/types.ts:156` 未透传任何作用域参数，不对称导致自定义抽屉页脚无法直接联动 `formRef` 校验与 `beforeConfirm` loading 锁。
- **目标通用改造**：新增 `AtengDrawerFooterScope` 并在 `AtengDrawer.vue` 透传 `{ confirm: handleConfirm, cancel: handleCancel, loading: isLoading }`，100% 向后兼容。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#370`](https://github.com/atengk/ateng-ui/issues/370)，`dev` 提交 `36da58c`），本地已通过 `pnpm pack + yalc` 接入验证，待 npm 发版后还原锁版勾选

---

### [U7] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 联调中 · 正式合入待发版锁版）：`AtengIconSelect` 实现 `types.ts` 已声明的 `#icon` 与 `#footer` 插槽透传

- **现状与源码锚点**：`icon-select/types.ts:148-157` 已公开声明 `icon` 与 `footer` 作用域插槽，但 `AtengIconSelect.vue` 与 `IconPanel.vue` 仅实现了 `#prefix`，`#icon` 与 `#footer` 均未透传及渲染。
- **目标通用改造**：在 `IconPanel.vue` 补齐 `<slot name="icon">` 与 `<slot name="footer">` 渲染并在 `AtengIconSelect.vue` 两个模式中透传，保持默认视图兜底。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#371`](https://github.com/atengk/ateng-ui/issues/371)，`dev` 提交 `36da58c`），本地已通过 `pnpm pack + yalc` 接入验证，待 npm 发版后还原锁版勾选

---

### [U8] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 联调中 · 正式合入待发版锁版）：`AtengExcelExport` 直传 `Blob` 时优先解析 `Content-Disposition` 服务端文件名

- **现状与源码锚点**：`AtengExcelExport.vue:106-111` 在未传 `props.filename` 时直接回退 `export_${Date.now()}.xlsx`，未像同库 `@atengk/vue` `useExcel` 一样优先读取 `@atengk/core` `getBlobDisposition` + `parseContentDispositionFilename` 提取的服务端文件名。
- **目标通用改造**：在 `AtengExcelExport.vue` 接入 `props.filename || parseContentDispositionFilename(getBlobDisposition(result)) || 'export_' + Date.now() + '.xlsx'`，100% 向后兼容。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#372`](https://github.com/atengk/ateng-ui/issues/372)，`dev` 提交 `36da58c`），本地已通过 `pnpm pack + yalc` 接入验证，待 npm 发版后还原锁版勾选

---

### [U9] 高优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 正式合入待发版锁版）：补齐 `@atengk/element-plus` `.vue.d.ts` 与 `GlobalComponents` 声明并修正查询/表格组件泛型约束

- **实际落地通用改造**：升级 `vite-plugin-dts@^4.3.0`，1:1 生成 43 个 `.vue.d.ts` 并导出 39 组 78 项 `GlobalComponents`；放宽 `AtengTable`/`AtengQueryForm`/`AtengDescriptions` 泛型至 `T extends object`，修正 `QueryFormPagination` 零 `any` 契约并引入 `vue-tsc` 门禁。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#373`](https://github.com/atengk/ateng-ui/issues/373)，`dev` 提交 `758b4c2`），已通过 `pnpm pack + yalc` 更新本地联调包，待 npm 发版后还原锁版勾选

---

### [U10] 高优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 正式合入待发版锁版）：将 `AtengLoadingBar`、`AtengLoading` 与 `html.is-theme-switching` 基础样式下沉至 `dist/index.css`

- **实际落地通用改造**：抽离 `_loading-base.scss` 与 `_theme-switch.scss` 共用 partial 由 `index.scss`（`dist/index.css`）与 `theme-pro.css` 共同复用（零 `!important`），补齐 `--el-color-primary-rgb` 等 CSS Fallback 与 `:root.dark` / `.dark` 兼容。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#374`](https://github.com/atengk/ateng-ui/issues/374)，`dev` 提交 `cdab8c3`），已通过 `pnpm pack + yalc` 更新本地联调包，待 npm 发版后还原锁版勾选

---

### [U11] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 正式合入待发版锁版）：修复 `AtengQueryForm` 嵌套防双发、`AtengExcelFeedback` 文件名解析与 `AtengDictTag` 空 `tagType` 告警

- **实际落地通用改造**：`AtengQueryForm` 支持 `tableContext.loading` 回退、嵌套防双发与重置重入守卫；`AtengExcelFeedback` 对齐显式参数 > `Content-Disposition` > 默认名三级优先级；`AtengDictTag` 经 `resolveElTagType` 将空串/非法 `tagType` 归一化为 `undefined`。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#375`](https://github.com/atengk/ateng-ui/issues/375)，`dev` 提交 `3434c86`），已通过 `pnpm pack + yalc` 更新本地联调包，待 npm 发版后还原锁版勾选

---

### [U12] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 正式合入待发版锁版）：完善 `AtengProLayout` 与 `AtengTabsNav` 未接线属性及定制扩展性

- **实际落地通用改造**：`AtengProLayout` 接入 `fixedHeader`/`fixedAside`/`tabsHeight`/`contentPadding`/`escExit` 并全量转发 `update:modelValue`/`batchClose` 与 4 插槽；`AtengTabsNav` 替换 Emoji 为可定制 SVG（`menuIcons`/`#menuIcon`），新增 `@batch-close`/`emitCloseOnBatch` 及 `iconResolver`/`#tabIcon`。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#376`](https://github.com/atengk/ateng-ui/issues/376)，`dev` 提交 `3cb4d48`），已通过 `pnpm pack + yalc` 更新本地联调包，待 npm 发版后还原锁版勾选

---

### [U13] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 正式合入待发版锁版）：修复 `AtengTabsNav` `role="tablist"` 作用域与嵌套 ARIA 角色违规

- **现状与源码锚点**：`AtengTabsNav.vue:151` 原将 `role="tablist"` 置于最外层容器，且 `TabsNavItem.vue:79-127` 在 `contextMenu=true` 时导致 `ElDropdown` / `role="tab"` / 关闭按钮触发 ARIA 违规。
- **实际落地通用改造**：上游提交 `a9616d0` 已收口 `role="tablist"` 至 `.at-tabs-nav__track` 并修正 `TabsNavItem` 的 `ElDropdown` / 语义按钮结构，100% 保持视觉与插槽兼容。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#377`](https://github.com/atengk/ateng-ui/issues/377)，提交 `a9616d0`），已通过 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`，待 npm 发版锁版后勾选

---

### [U14] 低/中优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 正式合入待发版锁版）：`AtengExcelFeedback` 透传底层 `AtengDialog` 的 `open`/`opened`/`closed` 生命周期事件

- **现状与源码锚点**：`AtengExcelFeedback.vue:275-287` 与 `excel-feedback/types.ts:113-119` 原未透传底层 `AtengDialog` 的 `open`、`opened`、`closed` 事件。
- **实际落地通用改造**：上游提交 `a9616d0` 已在 `AtengExcelFeedbackEmits` 补全并透传 `open`/`opened`/`closed` 事件，由 [`atengk/ateng-solid#50`](https://github.com/atengk/ateng-solid/issues/50) 接回 `UserImportDialog` 消费。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#378`](https://github.com/atengk/ateng-ui/issues/378)，提交 `a9616d0`），已通过 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`，待 npm 发版锁版后勾选

---

### [U15] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 合入 `main` 前待发版锁版）：优化 `AtengTable` 双卡表面容器与分页栏自适应布局能力

- **现状与源码锚点**：
  - `AtengTable.vue`（原 L974-L1242, L1245-L1336 `.at-table` / `.at-table__pagination`）原设白底且 `padding: 0`、无圆角边框，分页仅 `padding: 12px 0 0 0; justify-content: flex-end;` 且缺 `flex-wrap` / `tabular-nums` 与单页/空态自适应；
  - `AtengQueryForm.vue`（原 L411-L417）自带 `padding: 18px 18px 2px` 与 `margin-bottom: 16px`，嵌于 `AtengTable #query` 后导致白隙被吞并、下方工具栏/表格/分页（末字「页」及固定右操作列）左右下 `0px` 贴边，且与 `AtengPageSkeleton.vue` 左总右控分布及侧栏树卡片边框不一致；
  - `AtengExcelFeedback.vue`（原 L317-L325, L384-L388）缺少分页折行与 `tabular-nums` 内置保障。
- **实际落地通用改造**：上游提交 `ee55b3b` / `d255cd8` 已实现并关单：
  1. `AtengTable` 与 `AtengQueryForm` 新增 `surface?: 'card' | 'plain'`（默认 `'card'`）与 `--at-table-card-radius`、`--at-table-card-border`、`--at-table-surface-padding`、`--at-table-query-gap`、`--at-query-form-*` CSS 变量，工具栏+表格+分页收敛至 `.at-table__surface` 独立卡且全屏模式自动去重框；
  2. 新增 `paginationAlign`（默认 `'between'`：`共 N 条` 置左、其余控制置右）、`responsivePagination`（`<640px`/`<480px` 自适应降级与 `flex-wrap: wrap`）、`hidePaginationOnEmpty`（`total === 0` 自动隐藏）、`hideJumperOnSinglePage`（单页收敛 `jumper`），同步对齐 `AtengExcelFeedback` 的 `tabular-nums` 与换行；
  3. 上层 `admin-web` 已在 `tokens.css` / `main.css` 对接细边框/圆角/`12px` 间距与分页视觉令牌，并移除 `dict` 页面的局部 `pagination-layout` 覆盖。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#379`](https://github.com/atengk/ateng-ui/issues/379)，提交 `ee55b3b` / `d255cd8`），已通过 `pnpm pack + yalc` 更新本地 `@atengk/element-plus`，待 npm 发版锁版后勾选（关联 `admin-web` [ADR-0004](../../ateng-solid-admin-web/docs/adr/0004-dual-card-table-and-adaptive-pagination.md) 与 [00-overview-and-ux-standards.md](./prd/00-overview-and-ux-standards.md) §3.1–§3.2）

---

### [U16] 中优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 合入 `main` 前待发版锁版）：`AtengTable` 扩展 `autoHeightMode?: 'fixed' | 'max'` 弹性封顶滚动能力

- **现状与源码锚点**：
  - `@atengk/element-plus` `AtengTable` 原 `autoHeight?: boolean | number` 仅向 `<el-table>` 绑定固定 `:height="tableHeight"`（少数据或空态下仍会强制撑满视口并留下大片空白），而关闭 `autoHeight` 时大量数据（每页 50/100 条或全展开树表）会触发外层页面容器滚动导致表头与分页栏滚出视口；
  - `useTableAutoHeight` 计算可用高度时原未计入 `.at-table__surface` 底部 `borderBottomWidth`，当上层传入精确底部预留值（如 `:auto-height="16"`）时易产生 `1~2px` 外层滚动条溢出。
- **实际落地通用改造**：上游提交 `19f79a7` / `1365732` 已实现并关单（100% 向后兼容）：
  1. 在 `AtengTableProps` 新增 `autoHeightMode?: TableAutoHeightMode`（`'fixed' | 'max'`，默认 `'fixed'` 保留现有 `:height` 撑满行为）；`'max'` 模式下向 `<el-table>` 互斥绑定 `:max-height="tableHeight"`（`height: undefined`），实现“少数据随内容收缩、超出视口自动封顶并在表格体内部滚动锁定表头与分页栏”；
  2. 在 `useTableLayout` 计入 `.at-table__surface` 底部边框宽度、修正 `:auto-height="0"` 边界并补齐 `#query`/`toolbar`/`pagination`/`expand-change` 联动重算与单测覆盖；
  3. 上层 `admin-web` 已新增 `src/composables/useListTableLayout.ts` 并完成全站 12 个业务页（13 张表）接入与 `ListTableLayout.spec.ts` 全绿验收。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#380`](https://github.com/atengk/ateng-ui/issues/380)，提交 `19f79a7` / `1365732`），已通过 `pnpm pack + yalc` 更新本地 `@atengk/element-plus` 并完成上层全量改造与四合一校验，待 npm 发版锁版后勾选（关联 `admin-web` [ADR-0005](../../ateng-solid-admin-web/docs/adr/0005-tiered-query-collapse-and-max-auto-height-table.md) 与 [00-overview-and-ux-standards.md](./prd/00-overview-and-ux-standards.md) §3.1–§3.2）

---

### [U17] 低/中优先级（上游 `dev` 已闭环 · 本地 `yalc` 已更新 · 合入 `main` 前待发版锁版）：`AtengDictTag` 异步加载期间避免首帧直出原始编码值并实现字典套件同步缓存水合

- **现状与源码锚点**：`@atengk/element-plus` `AtengDictTag.vue` 在 `isLoading === true` 且 `dictItems` 尚未加载完成时，`matchingItems` 原回退构造 `{ label: String(value), value }`，且 `setup()` 未先同步读取 `DictManager.getCache(dictCode)`，导致冷缓存表格/详情组件首帧或微任务期先输出原始码值（如 `"0"`），异步请求返回后再跳变为映射标签。
- **实际落地通用改造**：上游提交 `934135a`（`feat(element-plus): 优化 AtengDictTag 冷加载占位策略并实现字典套件同步缓存水合`）已实现并关单：
  1. 命中 `DictManager.getCache(dictCode)` 时在 `setup()` 同步初始化选项；区分异步加载中与加载完成未命中，支持 `loadingMode?: 'placeholder' | 'raw'` 与 `#loading` 插槽；
  2. 上层 `admin-web` 已通过 `pnpm pack + yalc` 更新本地 `.yalc/@atengk/element-plus`，并结合 `withDictPreload` 与 `useDetailDialogState().detailReady` 骨架门控确保列表与编辑弹窗/抽屉零首帧跳变（关联 [`atengk/ateng-solid#57`](https://github.com/atengk/ateng-solid/issues/57)）。
- **核实状态**：- [ ] 上游 Issue 已修复关闭（[`atengk/ateng-ui#381`](https://github.com/atengk/ateng-ui/issues/381)，提交 `934135a`），已通过 `pnpm pack + yalc` 更新本地 `@atengk/element-plus` 并完成实机联调，待 npm 发版锁版后勾选

---

## 4. 发版前历史弃用写法净切清理追踪（`v1.2.0` / `v1.1.0` 已全部随正式版生效）

以下净切移除 `@Deprecated` 与旧版兼容包装的 Issue 已全部随三座底座本次正式版发布生效：

- [x] **`ateng-boot` (`v1.2.0`)**：[`#1135`](https://github.com/atengk/ateng-boot/issues/1135)（`core`/`web`/`mybatis-plus`/`excel`/`observability`/`openapi`，提交 `d7bd5a29`）、[`#1136`](https://github.com/atengk/ateng-boot/issues/1136)（`redis`/`satoken`，提交 `db051125`）、[`#1137`](https://github.com/atengk/ateng-boot/issues/1137)（`job`/`ai`/`notification`/`tcp`，提交 `3a9794a5`）
- [x] **`ateng-cloud` (`v1.1.0`)**：[`#206`](https://github.com/atengk/ateng-cloud/issues/206)（`dubbo`/`nacos`，提交 `f5e54848`）
- [x] **`ateng-ui` (`v1.1.0`)**：[`#366`](https://github.com/atengk/ateng-ui/issues/366)（`@atengk/vue` `superAdminRole`、`@atengk/element-plus` `filterColumnVNodes` 旧签名，提交 `96b7845a`）
