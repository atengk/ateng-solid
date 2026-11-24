# `ateng-boot:1.2.0` 一手源码调研与约束基线报告

> **调研目的**：为 `ateng-solid`（Issue #3 及后续 PRD / Spec 编写与开发）提供严格对齐 Maven Central 锁定版本 **`ateng-boot:1.2.0`** 的底座类签名、字段结构、默认配置、异常语义与运行边界的一手源码证据。  
> **信源基线**：
> - 上游底座仓库：`d:\source\ateng-boot`
> - Git Tag：`v1.2.0`（Tag 对象 `b867b1e6453d42c60a74e7cc3962543d6ecdae5c`，指向提交 `fd4ed2cebdde41c56be28f4a7b0d73a779e8c1d1`，即 `Merge pull request #1169 from atengk/dev`）
> - 树一致性核验：`v1.2.0^{tree}` 与 `HEAD^{tree}`（`dev` 分支 `eeb3ad4e`）哈希完全一致（`257492bb032191d5aecb31bd7039d11dc14fb0af`），工作区干净；以下全部源码路径、类名、方法签名、字段与默认值均基于 `v1.2.0` 实测确认。
> - 下游消费仓对照：`d:\source\ateng-solid\ateng-solid-server\pom.xml`（已锁定 `<ateng-boot.version>1.2.0</ateng-boot.version>`、`<spring-boot.version>3.3.13</spring-boot.version>`）、`ateng-solid-bootstrap/src/main/resources/application.yml`、`application-test.yml` 与 `ateng-solid-server/docs/specs/*`。

---

## 0. 高价值偏差与边界预警摘要（对照 `ateng-solid` 现有 Spec 与配置）

在深入各模块源码细节前，以下 **8 项实测发现**直接影响 PRD 契约与实现方案，须在需求/设计文档中提前对齐：

| 编号 | 核查对象 | 现有 Spec / 常见认知偏差 | `ateng-boot:1.2.0` 实测真相 | 对 `ateng-solid` PRD/设计的约束影响 |
| :---: | :--- | :--- | :--- | :--- |
| **F1** | `CaptchaTemplate` 模块归属、方法名与错误码 | 误以为位于 `satoken`、方法为 `verifyAndThrow`，或期望直抛 `101001` | 位于 **`ateng-boot-web`**；真实方法名为 **`verifyOrThrow(key, code)`**（无 `verifyAndThrow`）；对空值/失效/错误统一抛 `BusinessException(400, ...)` | PRD 需写明基于 `verify(...)` 自抛 `AuthResultCode(101001)` 或捕获 `verifyOrThrow` 转译；切勿写死 `verifyAndThrow` |
| **F2** | `LoginFailureLockService` 锁定时错误码 | 期望 `checkLocked` 抛出 `101004` | IP 熔断抛 `BusinessException(403)`；账号封禁调用 `StpLogic.checkDisable` 抛 `DisableServiceException`，由 `SaTokenExceptionHandler` 映射为 **`code = 403`**（`"当前账号已被封禁至 <剩余秒数>"`） | 若登录接口需返回 `101004` 与友好分钟提示，须用 `isLocked(...)` + `getDisableTime(...)` 前置拦截并自抛 `101004` |
| **F3** | `PermissionCacheService` 多租户键清理传参 | 仅传 `clearUserCache("admin", userId)` 或 `clearRoleCache("admin", roleKey)` | 复合 `loginId`（`tenantId_userId`）或 `tenantScoped=true` 会写入带 `tenantId` 的隔离键；仅传裸 `userId`/`roleCode` 不会失效带租户后缀的键 | 涉及用户角色/角色菜单变更时，**必须优先使用三参重载** `clearUserCache("admin", tenantId, userId)` 与 `clearRoleCache("admin", tenantId, roleKey)` |
| **F4** | `DataScopeType` 枚举归属 | 假设底座 `ateng-boot-mybatis-plus` 内置了 `DataScopeType` | 底座 **不存在 `DataScopeType` 枚举**；仅提供 `@DataScope`、`AtengDataPermissionInnerInterceptor` 与 `DataPermissionHandler` SPI（默认透传返回 `null`） | `DataScopeType`（`1=ALL..5=SELF`）属于 `ateng-solid` 业务层枚举（建议实现 `IBaseEnum<Integer>`），由上层实现 `DataPermissionHandler` |
| **F5** | `BaseLogicEntity` / `BaseFullEntity` 与 `DefaultMetaObjectHandler` | 假设 `MetaObjectHandler` 会填充 `deleted=0` 与 `version=0` | `DefaultMetaObjectHandler#insertFill` **只填充 `createTime`/`updateTime`/`createBy`/`updateBy`/`tenantId`**，**不填充 `deleted` 与 `version`**（仅 `BatchUtil.autoHeal` 会补 `0L`/`0`） | 单条 `Mapper.insert` 依赖 DDL `DEFAULT 0`（Flyway 必须显式声明 `NOT NULL DEFAULT 0`）或构造期初始化 |
| **F6** | `ateng-boot-excel` 模型与行数限额 | 误以为存在 `ImportResult` 模型，或以为所有读取方法都校验 `maxSyncRows` | 底座无 `ImportResult`（对应模型为 `ExcelReadResult<T>`）；**`ExcelUtil.readWithResult` 未校验 `maxSyncRows`**（仅 `read` 和 `readWithValidation` 检查） | 上层接口自行定义 `ImportResultVO`（剔除 `ExcelErrorRow.rowData` 防大对象/敏感信息外泄），且导入入口须自行校验行数或字节上限 |
| **F7** | `@OperateLog` 与 `OperateLogModel` UA 采集 | `auth-rbac-and-datascope-spec.md` 写 `@OperateLog(operateType = ...)` 且 UA 放 `extra` | 注解真实属性名为 **`type`**（非 `operateType`）；`OperateLogAspect` 已在请求线程**直接填充 `OperateLogModel.userAgent`/`browser`/`os`**；`userId`/`userName` 默认均取自 `UserContextHolder`（用户 ID） | 代码须用 `@OperateLog(module = "...", type = OperateTypeEnum.XXX)`；`sys_oper_log` 落库 `userName` 建议从 `LoginHelper.getLoginUser()` 补充账号/昵称 |
| **F8** | `ateng-boot-storage` 头像安全与访问边界 | 假设启用 `ateng-boot-storage` 默认带大小/后缀限制或上传即可直接访问 | `StorageGuardProperties.enabled` **默认 `false`**、`maxFileSize` 默认 `null`；`LocalDriver` 预签名下载端点 `/storage/local/download` 受 `SaTokenInterceptor(includes="/**")` 拦截 | 头像上传 PRD 须显式配置 `guard.enabled=true`、`allowed-extensions`、`max-file-size` 与固定 `secret-key`，并明确头像 URL 访问方案（白名单直链/签名 URL/接口代理） |

---

## 1. 认证与安全底座（`ateng-boot-web` Captcha + `ateng-boot-satoken`）

### 1.1 `CaptchaTemplate`（图形验证码）

> **模块归属纠正**：`CaptchaTemplate` 属于 **`ateng-boot-web`**，并非 `ateng-boot-satoken`。

- **核心类路径**：
  - 门面类：`io.github.atengk.boot.web.captcha.template.CaptchaTemplate`（`ateng-boot-web/src/main/java/io/github/atengk/boot/web/captcha/template/CaptchaTemplate.java`）
  - 配置类：`io.github.atengk.boot.web.captcha.properties.CaptchaProperties`（`ateng-boot-web/src/main/java/io/github/atengk/boot/web/captcha/properties/CaptchaProperties.java`，前缀 `ateng.boot.web.captcha`）
  - 结果模型：`io.github.atengk.boot.web.captcha.model.CaptchaResult`（`ateng-boot-web/src/main/java/io/github/atengk/boot/web/captcha/model/CaptchaResult.java`）
  - 枚举：`io.github.atengk.boot.web.captcha.enums.CaptchaType`、`CaptchaCharType`、`CaptchaRendererType`
  - 自动装配：`io.github.atengk.boot.web.captcha.autoconfigure.AtengCaptchaAutoConfiguration`

- **默认配置与参数边界**：

| 配置键（前缀 `ateng.boot.web.captcha.`） | 字段类型 | 默认值 | 代码级边界与说明 |
| :--- | :--- | :--- | :--- |
| `enabled` | `boolean` | `true` | 控制 `AtengCaptchaAutoConfiguration` 自动装配 |
| `key-prefix` | `String` | `"captcha:"` | 存储 Key 前缀，最终键为 `prefix + captchaKey`（`IdUtil.fastSimpleUUID()`） |
| `renderer` | `CaptchaRendererType` | `SVG` | `SVG`（零系统字体依赖纯 `<path>` 轮廓）或 `PNG` |
| `type` | `CaptchaType` | `CHAR` | `CHAR`（随机字符）或 `MATH`（1~9 个位数加减乘算术，减法自动交换保非负） |
| `char-type` | `CaptchaCharType` | `ALPHANUMERIC_SAFE` | 默认字符表 `"23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz"`（剔除 `0/O/o/1/I/l`）；另有 `NUMERIC`、`ALPHA`、`ALPHANUMERIC` |
| `length` | `int` | `4` | 允许范围 `[1, 20]`（`MAX_CHAR_LENGTH = 20`），超范围抛 `IllegalArgumentException` |
| `math-operators` | `String` | `"+-*"` | 仅识别 `+`、`-`、`*`；无有效运算符时抛 `IllegalArgumentException` |
| `width` / `height` | `int` | `130` / `44` | 图像宽高（像素） |
| `expire` | `Duration` | `Duration.ofMinutes(2)` | 默认 **120 秒**；返回 `CaptchaResult.expireSeconds = Math.max(1L, expire.toSeconds())`；非正数抛 `IllegalArgumentException` |
| `ignore-case` | `boolean` | `true` | 校验时忽略大小写 |
| `noise-line-count` / `noise-dot-count` | `int` | `4` / `30` | 干扰线与噪点数量 |
| `fail-open` | `boolean` | `false` | 默认 Fail-Closed；为 `true` 时主存储异常才降级 `InMemoryCaptchaStore` |
| `in-memory.max-capacity` | `int` | `100_000` | 单机内存存储容量软上限 |
| `in-memory.clean-interval` | `Duration` | `Duration.ofSeconds(60)` | 惰性清理触发周期 |

- **返回模型 `CaptchaResult`**：
  - `public record CaptchaResult(String captchaKey, String imageBase64, long expireSeconds)`
  - `imageBase64` 为完整 Data URL（如 `data:image/svg+xml;base64,...` 或 `data:image/png;base64,...`）。
- **三级存储自适应**：`RedissonCaptchaStore`（`RBucket.getAndDelete()`）→ `RedisCaptchaStore`（Lua 原子 `GET+DEL`）→ `InMemoryCaptchaStore`（`ConcurrentHashMap.remove()`）。
- **`verifyOrThrow`（非 `verifyAndThrow`）行为与错误码**：
  - **方法签名**：`public void verifyOrThrow(String captchaKey, String code)`、`public boolean verify(String captchaKey, String code)`、`public void invalidate(String captchaKey)`。
  - **严格一次一密原子消耗**：无论校验成功或失败，均先执行 `getAndDeleteWithFallback(...)` 从存储读取并立即删除该 `captchaKey`（开启 `failOpen=true` 且主存储未命中时回查内存兜底）。
  - **异常与错误码映射**（`CaptchaTemplate.java:123-134`）：
    - `captchaKey` 或 `code` 为 `null`/blank：抛 `BusinessException(CommonResultCode.BAD_REQUEST, "图形验证码不能为空")`（**`code = 400`**，不删存储）。
    - `stored == null`（不存在或已过期）：抛 `BusinessException(CommonResultCode.BAD_REQUEST, "图形验证码已失效，请刷新重试")`（**`code = 400`**）。
    - `!matches(code.trim(), stored)`：抛 `BusinessException(CommonResultCode.BAD_REQUEST, "图形验证码错误，请刷新重试")`（**`code = 400`**，原验证码已被原子烧毁）。
    - 存储底层故障且 `failOpen = false`：`RedisCaptchaStore`/`RedissonCaptchaStore`/`CaptchaTemplate` 抛 `BusinessException(CommonResultCode.INTERNAL_SERVER_ERROR.getCode(), ...)`（**`code = 500`**）。
  - **PRD 对齐提示**：`CaptchaTemplate.verifyOrThrow` 仅抛 `400`，若 `ateng-solid` 业务错误码要求返回 `101001`（`AuthResultCode`），建议调用 `boolean verify(captchaKey, code)` 自行判错抛 `101001`。

---

### 1.2 `LoginFailureLockService`（登录防暴力破解）

- **核心类路径**：
  - 服务类：`io.github.atengk.boot.satoken.defense.LoginFailureLockService`（`ateng-boot-satoken/src/main/java/io/github/atengk/boot/satoken/defense/LoginFailureLockService.java`）
  - 配置类：`io.github.atengk.boot.satoken.properties.SaTokenProperties.LoginDefenseProperties`（`ateng-boot-satoken/src/main/java/io/github/atengk/boot/satoken/properties/SaTokenProperties.java`）
  - 自动装配：`AtengSaTokenAutoConfiguration#loginFailureLockService`

- **启用条件与默认配置**（前缀 `ateng.boot.satoken.login-defense`）：
  - **装配条件**：`@ConditionalOnProperty(prefix = "ateng.boot.satoken.login-defense", name = "enabled", havingValue = "true", matchIfMissing = false)`（默认 **关闭 `false`**；`ateng-solid` `application.yml` 已显式设为 `true`，未装配时注入 `LoginFailureLockService` 会报错，建议可选注入或保持 `enabled: true`）。

| 配置键（`ateng.boot.satoken.login-defense.`） | 类型 | 默认值 | 源码说明 |
| :--- | :--- | :--- | :--- |
| `enabled` | `boolean` | `false` | 是否装配 `LoginFailureLockService`（`application.yml` 已设为 `true`） |
| `max-retry-count` | `int` | `5` | 账号维度连续失败阈值，达到即封禁账号 |
| `lock-time` | `Duration` | `Duration.ofMinutes(15)` | 账号维度锁定时长（15 分钟） |
| `window-time` | `Duration` | `Duration.ofMinutes(15)` | 账号失败计数窗口 TTL（15 分钟） |
| `ip-max-retry-count` | `int` | `30` | 客户端 IP 维度连续失败阈值 |
| `ip-lock-time` | `Duration` | `Duration.ofMinutes(30)` | 客户端 IP 维度熔断锁定时长（30 分钟） |
| `ip-window-time` | `Duration` | `Duration.ofMinutes(15)` | 客户端 IP 失败计数窗口 TTL（15 分钟） |
| `ip-white-list` | `List<String>` | `["127.0.0.1", "0:0:0:0:0:0:0:1", "::1"]` | 豁免 IP 熔断的白名单，支持精确 IP 与 CIDR（`matchCidr`） |

- **多租户与多账号体系重载方法全量签名**：
  - 作用域防碰撞键构造：`public String buildScopedAccountKey(String tenantId, String loginType, String account)`
    - 编码格式：`"scoped:" + normTenant.length() + ":" + normTenant + "|" + normType.length() + ":" + normType + "|" + normAccount.length() + ":" + normAccount`（长度前缀定界，防 `:` / `|` / 空租户碰撞；`loginType` 为空回退 `"login"`；`account` 为空返回 `null`）。
  - 失败累计（同时累计 IP 与账号两维，达阈值触发锁定并返回剩余次数 `0`）：
    - `public int recordFailure(String tenantId, String loginType, String account)`
    - `public int recordFailure(String tenantId, String loginType, String account, String clientIp)`（`clientIp == null` 时自动从 `SaHolder.getRequest()` / `RequestContextHolder` 提取反向代理头并规范化 `::1` → `127.0.0.1`）
  - 成功清零：
    - `public void clearFailure(String tenantId, String loginType, String account)`
    - `public void clearAllFailure(String tenantId, String loginType, String account, String clientIp)`
  - 状态与剩余次数/时间查询：
    - `public int getRemainRetryCount(String tenantId, String loginType, String account)`
    - `public int getFailureCount(String tenantId, String loginType, String account)`
    - `public boolean isLocked(String tenantId, String loginType, String account)`
    - `public boolean isLocked(String tenantId, String loginType, String account, String clientIp)`
    - `public long getDisableTime(String tenantId, String loginType, String account)`（剩余封禁秒数，未锁定返回 `0`）
    - `public long getLockTime(String tenantId, String loginType, String account)`（等价委托 `getDisableTime`）
  - Fail-Fast 前置校验：
    - `public void checkLocked(String tenantId, String loginType, String account)`
    - `public void checkLocked(String tenantId, String loginType, String account, String clientIp)`
  - 内存降级与测试清理：`clearLocalMemory()`（单机内存容器硬上限 `MAX_LOCAL_FAIL_ENTRIES = 10_000`）。

- **异常与错误码实测行为**：
  1. 若客户端 IP 被熔断：`checkIpLocked` 抛出 `BusinessException(CommonResultCode.FORBIDDEN, "客户端 IP 连续登录失败次数超限，已被临时锁定")`（**`code = 403`**）。
  2. 若账号被封禁：`LoginHelper.checkDisableByLoginType(loginType, scopedKey)` 触发 Sa-Token 原生 `DisableServiceException`，被 `SaTokenExceptionHandler#handleDisableServiceException`（`ateng-boot-satoken/.../handler/SaTokenExceptionHandler.java:96-100`）拦截，返回 **`Result.fail(403, "当前账号已被封禁至 " + e.getDisableTime())`**（其中 `e.getDisableTime()` 为**剩余秒数**而非日期时间戳，且状态码为 `403` 非 `101004`）。
  3. Redis Key 前缀：`ateng:satoken:login-fail:`（账号计数）、`ateng:satoken:login-fail-ip:`（IP 计数）、`ateng:satoken:login-lock-ip:`（IP 锁定）；账号锁定直接复用 Sa-Token `disable` 机制。无 Redis 时自动降级本地内存映射。

---

### 1.3 `TenantHeaderSwitchValidator`（租户请求头与切租户 SPI）

- **接口定义**：`io.github.atengk.boot.satoken.spi.TenantHeaderSwitchValidator`（`ateng-boot-satoken/src/main/java/io/github/atengk/boot/satoken/spi/TenantHeaderSwitchValidator.java`）
  ```java
  @FunctionalInterface
  public interface TenantHeaderSwitchValidator {
      boolean validate(String targetTenantId, String currentTenantId, String loginType, boolean anonymous);
  }
  ```
  - `targetTenantId`：请求头提取并 `trim()` 后的目标租户 ID
  - `currentTenantId`：当前会话归属租户 ID（匿名请求为 `null`）
  - `loginType`：当前路由关联的账号体系标识（匿名且未命中路由时可能为 `null`）
  - `anonymous`：`true` 表示匿名未登录请求，`false` 表示已登录平台超管切租户请求
  - 默认兜底 Bean（`AtengSaTokenAutoConfiguration#tenantHeaderSwitchValidator`，`@ConditionalOnMissingBean`）：`(targetTenantId, currentTenantId, loginType, anonymous) -> true`。

- **配套配置（`SaTokenProperties.TenantProperties`，前缀 `ateng.boot.satoken.tenant`）**：
  - `header-name`：`"X-Tenant-Id"`
  - `allow-anonymous-header`：`false`
  - `allow-super-admin-switch`：`false`
  - `platform-tenant-ids`：`[]`（为空时不额外限制超管会话所属租户；非空时超管会话 `tenantId` 必须命中该集合才允许切换）

- **拦截器执行链路与前置校验（`AtengSaTokenInterceptor`）**：
  1. **普通已登录用户**（`!superAdmin`）：绝对忽略请求头 `X-Tenant-Id`，强制绑定会话 `LoginUser.getTenantId()`。
  2. **跨端防伪造**：请求虽访问白名单路由，但只要携带了任何其他账号体系有效 Token（`hasAnyActiveLoginSession()`），**禁止**走匿名头解析。
  3. **前置正则校验**：若允许匿名解析或超管切换且请求头非空，先校验 `TENANT_ID_PATTERN = ^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$` 且禁止包含 `..` 或以 `.` 结尾；不合法直接抛出 `BusinessException(CommonResultCode.BAD_REQUEST, "非法租户标识格式")`（`code = 400`）。
  4. **SPI 校验**：调用 `TenantHeaderSwitchValidator.validate(...)`；返回 `false` 时抛出 `BusinessException(CommonResultCode.FORBIDDEN, "无权切换或访问目标租户")`（`code = 403`）。
  5. **上下文同步与清理**：通过校验后写入 `TenantContextHolder.setTenantId(...)`、`UserContextHolder.set(userId)` 并通过 `DataPermissionBridge` 同步 `DataPermissionContextHolder.setSuperAdmin(superAdmin)`；请求结束在 `afterCompletion` 全部强制清理。

---

### 1.4 `PermissionCacheService`（权限缓存与 `tenantScoped`）

- **核心类路径**：
  - `io.github.atengk.boot.satoken.cache.PermissionCacheService`
  - `io.github.atengk.boot.satoken.cache.CachedStpInterface`
  - `io.github.atengk.boot.satoken.cache.UserRolePermissionLoader`
  - `io.github.atengk.boot.satoken.cluster.listener.SaTokenClusterSyncListener`
  - `io.github.atengk.boot.satoken.properties.SaTokenProperties.PermissionCacheProperties`（前缀 `ateng.boot.satoken.permission-cache`）

- **默认配置**：
  - `enabled` = `true`
  - `timeout` = `Duration.ofSeconds(300)`（实际写入附加 `10% ~ 20%` 随机 Jitter 防雪崩）
  - `empty-ttl` = `Duration.ofSeconds(60)`（空列表写哨兵值 `"__EMPTY__"` 防穿透）
  - **`tenant-scoped` = `false`**（默认关闭）

- **缓存结构、自适应适配器与清理粒度**：
  - 三级适配器自适应：`TwoLevelCacheManager`（空间名 `CACHE_SPACE_NAME = "satoken:permissions"`）→ 单层 `StringRedisTemplate`（带 5s 本地 LRU 微缓存）→ JVM 有界 `InMemoryPermissionCacheAdapter`（上限 `10_000`）。
  - 缓存键生成规则（基础前缀 `CACHE_PREFIX = "ateng:satoken:cache:"`；默认体系 `null`/blank/`"login"` 省略 `<loginType>:` 段；非默认体系如 `"admin"` 拼接 `<loginType>:`）：
    - 用户角色：`ateng:satoken:cache:[<loginType>:]user-roles:[<tenantId>:]<userId>`
    - 用户直属权限：`ateng:satoken:cache:[<loginType>:]user-perms:[<tenantId>:]<userId>`
    - 角色权限：`ateng:satoken:cache:[<loginType>:]role-perms:[<tenantId>:]<roleCode>`
  - **`tenantScoped` 开关作用与 `CachedStpInterface` 回源保护**：
    - 当 `LoginHelper.login(...)` 传入含 `tenantId` 的 `LoginUser` 时，底层生成复合 `loginId = "<tenantId>_<userId>"`。`CachedStpInterface` 通过 `LoginHelper.parseCompositeLoginId(loginId, loginType)` 拆出纯 `userId` 与 `ownerTenantId`（无论 `tenantScoped` 开闭，只要是复合 `loginId` 或开启了 `tenantScoped`，`user-roles` 与 `user-perms` 都会使用 `ownerTenantId` 隔离键），并在回源 `UserRolePermissionLoader` 期间使用 `TenantContextHolder.runWithTenant(ownerTenantId, ...)` 锁定主体租户（防止超管切租户时回源查错工作租户 DB）。
    - **`tenantScoped` 开关本身专门控制 `role-perms` 缓存键是否按 `tenantId` 隔离**（开启时调用 `loader.loadPermissionsByRole(roleCode, loginType, tenantId)` 并将 `tenantId` 拼入 `role-perms` 键；关闭时跨租户共享 `role-perms:<roleCode>` 键）。
  - **清理粒度全量方法**（同步清理 Redis + 本地 L1，并通过 `SaTokenClusterBroadcaster` 广播 Pub/Sub `ateng:satoken:cluster-sync` 驱动集群节点清除 L1）：
    - **用户粒度**：`refreshUserPermissions` / `clearUserCache`
      - `(userId)` / `(Long)` / `(loginType, userId)` / `(loginType, Long)`：清理无租户键；若传入为复合 `"{tenantId}_{userId}"` 则拆解并**连带清理**带租户隔离键。
      - `(loginType, tenantId, userId)` / `(loginType, tenantId, Long)`：**精准清理指定租户下的 `user-roles` 与 `user-perms` 键**。
    - **角色粒度**：`refreshRolePermissions` / `clearRoleCache`
      - `(roleCode)` / `(loginType, roleCode)`：清理无租户 `role-perms` 键。
      - `(loginType, tenantId, roleCode)`：**精准清理指定租户下的 `role-perms` 键**（开启 `tenantScoped=true` 时必须调用此三参版本！）。
    - **全局粒度**：`clearAll()` / `clearAllCache()`：扫描清理全空间（Redis `SCAN` 游标匹配 `ateng:satoken:cache:*` 或 `TwoLevelCache.clear()`）并广播 `ALL_CACHE_CLEAR`。

### 1.5 `SaTokenProperties` 其他与 `ateng-solid` 强关联默认值

| 配置键 | 默认值 | `ateng-solid` 核对状态 |
| :--- | :--- | :--- |
| `ateng.boot.satoken.primary-login-type` | `"login"` | `application.yml` 已覆盖为 `"admin"` |
| `ateng.boot.satoken.super-admin-roles` | `["admin", "super_admin"]` | ⚠️ `application.yml` **尚未配置**，须显式收口为 `["super_admin"]`（对齐 `contracts.md` 禁止 `"admin"` 绕过） |
| `ateng.boot.satoken.super-admin-permissions` | `["*", "*:*:*"]` | 默认匹配 `*:*:*`，可在 `application.yml` 保持默认或收敛为 `["*:*:*"]` |
| `ateng.boot.satoken.interceptor.auto-route-annotation-type` | `true` | `@SaCheckPermission`/`@SaCheckRole` 等未写 `type` 时自动按路由 `loginType`（`"admin"`）→ `primary-login-type` 路由 |
| `ateng.boot.satoken.token.timeout` / `active-timeout` | `24h` / `30m` | `token-style` 默认 `"uuid"`，`is-concurrent=true`，`is-share=true`，`max-login-count=12` |
| `ateng.boot.satoken.online-session.max-scan-limit` | `2000` | `LoginHelper.searchOnlineUserPage(loginType, OnlineUserQuery, page, size)` 单页最大 `size` 截断为 `100`；支持 `tenantId` 精确隔离与 `loginIp` CIDR 匹配；提供 `kickoutByTokenForTenant` / `logoutByTokenValueForTenant`（越权抛 `403`） |

---

## 2. 持久层底座（`ateng-boot-mybatis-plus`）

### 2.1 `@DataScope` 与 `DataScopeType`

- **`@DataScope` 注解定义**：`io.github.atengk.boot.mybatisplus.annotation.DataScope`（`ateng-boot-mybatis-plus/src/main/java/io/github/atengk/boot/mybatisplus/annotation/DataScope.java`）
  - `@Target({ElementType.TYPE, ElementType.METHOD})`，`@Retention(RetentionPolicy.RUNTIME)`

| 属性 | 类型 | 默认值 | 行为约束（配合 `AtengDataPermissionInnerInterceptor`） |
| :--- | :--- | :--- | :--- |
| `alias` | `String` | `""` | 多表 JOIN 时指定目标表别名；非空时拦截器仅对 `table.getAlias().getName()`（无别名时 `table.getName()`）忽略大小写匹配该别名的表追加条件 |
| `deptColumn` | `String` | `"dept_id"` | 部门字段列名，透传给 `DataPermissionHandler` |
| `userColumn` | `String` | `"user_id"` | 用户字段列名，透传给 `DataPermissionHandler` |
| `ignore` | `boolean` | `false` | 为 `true` 时豁免权限过滤；方法级注解优先于接口类级注解 |
| `type` | `String` | `""` | 自定义业务范围标识，供 `DataPermissionHandler` 区分业务策略 |

- **拦截器与 SPI 机制**（`AtengDataPermissionInnerInterceptor` / `DataPermissionHandler` / `DataPermissionContextHolder`）：
  - 开关配置：`ateng.boot.mybatis-plus.data-permission.enabled`（**默认 `false`**，`application.yml` 已置 `true`）。
  - 拦截链顺序（`AtengMybatisPlusAutoConfiguration#mybatisPlusInterceptor`）：`AtengTenantLineInnerInterceptor` → `AtengDataPermissionInnerInterceptor` → `AtengLogicDeleteInnerInterceptor` → `PaginationInnerInterceptor` → `BlockAttackInnerInterceptor` → `OptimisticLockerInnerInterceptor`。
  - 派生语句穿透：`MybatisInterceptorUtil.resolveMapperAnnotation` 自动剥离 `_mpCount` 与 `$dynamicAdaptive` 后缀，确保分页 `COUNT(*)` 同等生效。
  - 秒级短路放行：`DataPermissionContextHolder.isIgnore()`（`runWithoutPermission`）或 `DataPermissionContextHolder.isSuperAdmin()`（`runAsSuperAdmin` 或 `AtengSaTokenInterceptor` 自动同步）直接跳过。
  - **兜底行为**：当业务层未注册自定义 `DataPermissionHandler` Bean 时，自动装配 `DefaultDataPermissionHandler`（`getSqlSegment` 恒返回 `null`，不追加任何过滤条件）。
- **`DataScopeType` 枚举实测结论**：
  - **全仓检索确认：`ateng-boot:1.2.0`（含 `ateng-boot-mybatis-plus` 及全部模块与示例工程）中不存在 `DataScopeType` 枚举**。
  - `auth-rbac-and-datascope-spec.md` 中定义的 `DataScopeType`（`1=ALL`, `2=CUSTOM`, `3=DEPT`, `4=DEPT_AND_CHILD`, `5=SELF`）属于 **`ateng-solid` 应用框架自有枚举**（实现 `IBaseEnum<Integer>`），供角色表 `sys_role.data_scope` 与上层自定义 `DataPermissionHandler` Bean 消费。

### 2.2 实体继承阶梯、正交能力接口与默认填充规则

- **5 个正交能力接口与 1 个主键契约**（`io.github.atengk.boot.mybatisplus.entity.*`）：
  - `Identifiable<ID extends Serializable>`：`getId()` / `setId(ID)`
  - `TimeAuditable`：`LocalDateTime getCreateTime()` / `setCreateTime` / `getUpdateTime()` / `setUpdateTime`
  - `Auditable extends TimeAuditable`：`String getCreateBy()` / `setCreateBy` / `String getUpdateBy()` / `setUpdateBy`
  - `LogicDeletable<T extends Serializable>`：`T getDeleted()` / `setDeleted(T)`
  - `Versioned`：`Integer getVersion()` / `setVersion(Integer)`
  - `TenantAware<T extends Serializable>`：`T getTenantId()` / `setTenantId(T)`（注意：**仅接口契约**，业务实体须自行声明 `private Long tenantId;` 字段；`DefaultTenantLineHandler` 会将纯数字 `tenantId` 转为 JSqlParser `LongValue` 避免索引失效）

- **雪花主键标准实体基类链（按继承自底向上）**：

| 基类全限定名 | 继承/实现 | 字段与 MyBatis-Plus 注解 | 说明 |
| :--- | :--- | :--- | :--- |
| `BaseGenericEntity<ID>` | `implements Identifiable<ID>, Serializable` | 抽象 `getId`/`setId` | 顶层泛型主键抽象基类 |
| **`BaseIdEntity`** | `extends BaseGenericEntity<Long>` | `@TableId(type = IdType.ASSIGN_ID) private Long id;` | 关联表、流水日志表首选 |
| `BaseTimeEntity` | `extends BaseIdEntity implements TimeAuditable` | `@TableField(fill = FieldFill.INSERT) private LocalDateTime createTime;`<br>`@TableField(fill = FieldFill.INSERT_UPDATE) private LocalDateTime updateTime;` | 仅时间审计表 |
| `BaseEntity` | `extends BaseTimeEntity implements Auditable` | `@TableField(fill = FieldFill.INSERT) private String createBy;`<br>`@TableField(fill = FieldFill.INSERT_UPDATE) private String updateBy;` | 物理删除四要素审计表 |
| **`BaseLogicEntity`** | `extends BaseEntity implements LogicDeletable<Long>` | `@TableLogic(value = "0", delval = "id") @JsonIgnore private Long deleted;` | 常规软删主表默认首选（无乐观锁） |
| **`BaseFullEntity`** | `extends BaseLogicEntity implements Versioned` | `@Version private Integer version;` | 高并发 CAS 状态表按需继承 |

- **默认填充规则实测约束**：
  1. **`DefaultMetaObjectHandler`**（`io.github.atengk.boot.mybatisplus.handler.DefaultMetaObjectHandler`，受 `ateng.boot.mybatis-plus.audit.enabled=true` 控制，默认值 `defaultOperator = "SYSTEM"`）：
     - **`insertFill`**：
       - `createTime` / `updateTime`：仅当原字段为 `null` 时填充 `LocalDateTime.now()`（保留显式赋值）。
       - `createBy` / `updateBy`：仅当原字段为 `null` 时填充 `resolveCurrentUser()`（解析顺序：`CurrentUserProvider.getCurrentUser()` → `UserContextHolder.get()` → `"SYSTEM"`）。注意在 `Auditable` 快路径下仅判 `== null`，若实体字段被初始化为空串 `""` 不会触发填充。
       - `tenantId`：仅当原字段为 `null` 且 `TenantContextHolder.getTenantId()` 非空时填充；`EntityContractHelper.convertTenantId` 遇到 `Long` 类型字段配非数字上下文字符串时立即抛 `IllegalArgumentException`（Fail-Fast）。
       - **关键约束**：`DefaultMetaObjectHandler#insertFill` **不会填充 `deleted` 和 `version`**！普通单条 `insert` 必须依赖数据库 DDL `NOT NULL DEFAULT 0`（注意 H2/MySQL 建表语句不得遗漏 `DEFAULT 0`）或业务构造期赋初值 `0L`/`0`。
     - **`updateFill`**：
       - **无条件强制刷新** `updateTime = LocalDateTime.now()` 与 `updateBy = resolveCurrentUser()`，不受实体原值阻碍；不修改 `createTime`/`createBy`/`tenantId`。
  2. **`BatchUtil.autoHeal`**（`io.github.atengk.boot.mybatisplus.util.BatchUtil`，批量插入/Upsert 前置自愈）：
     - 除上述 `createTime`/`updateTime`/`createBy`/`updateBy`（此处判 `== null || isBlank()`）与 `tenantId` 外，还自动分配雪花 `id`（若 `id == null`）、自动补 `version = 0`（`Versioned`）和 `deleted = 0L`（`LogicDeletable<Long>`）。

---

## 3. Apache Fesod Excel 导入校验与批注反馈（`ateng-boot-excel`）

> **模型名称核对**：底座 **`ateng-boot-excel` 不存在 `ImportResult` 类**（`ateng-boot-excel/CONTEXT.md` 明确禁用该名称），对应聚合模型为 **`ExcelReadResult<T>`**。上层 `ImportResultVO` 由 `ateng-solid` 自行定义与转换。

### 3.1 核心模型字段与行/列号索引基准

1. **`ExcelReadResult<T>`**（`io.github.atengk.boot.excel.model.ExcelReadResult`）：
   - `List<T> data`（默认空 `ArrayList`，`getData()` 返回不可变列表）：通过 JSR-303 校验的实体列表。
   - `List<ExcelRowData<T>> rowRecords`（默认空 `ArrayList`，`getRowRecords()` 返回不可变列表）：保留 **1-based** 物理行号的合法行视图。
   - `List<ExcelErrorRow> errors`（默认空 `ArrayList`，`getErrors()` 返回不可变列表）：全部错误条目。
   - `boolean circuitBroken`（默认 `false`）：是否触发错误行数熔断。
   - 辅助方法：`hasErrors()`、`isSuccess()`、`getErrorCount()`（**返回 `errors.size()` 即错误明细条数，单行多列报错会计多次**）、`getFailedData()`（按 `rowIndex` 去重返回失败实体列表）。

2. **`ExcelRowData<T>`**（`io.github.atengk.boot.excel.model.ExcelRowData`）与 **`ExcelRowAware`**（`io.github.atengk.boot.excel.model.ExcelRowAware`）：
   - `public record ExcelRowData<T>(int rowIndex, T data)`：`rowIndex` 为 **1-based** 物理行号（构造器校验 `rowIndex >= 1`）。
   - `ExcelRowAware`：`void setRowIndex(Integer rowIndex)` / `default Integer getRowIndex()`；`BatchValidationListener#invoke` 在执行 JSR-303 校验前即回填物理行号（实体需在该字段加 `@ExcelIgnore` 防止被 Fesod 当作导入导出列）。

3. **`ExcelErrorRow`**（`io.github.atengk.boot.excel.model.ExcelErrorRow`）：

| 字段 | 类型 | 基准 / 说明 |
| :--- | :--- | :--- |
| `rowIndex` | `Integer` | **从 1 开始（1-based）**；例如单行表头占第 1 行时，首行数据为 `2` |
| `columnIndex` | `Integer` | **从 0 开始（0-based）**；由 `ExcelColumnMetadataResolver` 解析；未匹配列或整行级错误时为 `null` |
| `columnName` | `String` | `@ExcelProperty` 最末级叶子表头名；未匹配列时回退 Java 属性名；`ofRow` 整行级工厂固定填 `"整行"` |
| `fieldName` | `String` | Java 属性名（如 `"mobile"`）；整行级错误为 `null` |
| `invalidValue` | `Object` | 校验失败时的原始字段值；整行级错误为 `null` |
| `message` | `String` | 校验失败提示信息 |
| `rowData` | `Object` | 校验失败行的原始 Java Bean 实例（**警告**：向前端返回 JSON 时须剔除或脱敏 `rowData`，避免实体内部字段或大载荷外泄） |

- **业务校验错误便捷构建工厂**（`ExcelErrorRow`）：
  - 列级（按属性名）：`ExcelErrorRow.of(Class<?> modelClass, int rowIndex, String fieldName, Object invalidValue, String message[, Object rowData])`
  - 列级（Lambda 安全引用）：`ExcelErrorRow.of(Class<T> modelClass, int rowIndex, PropertyFunc<T, R> fieldGetter, Object invalidValue, String message[, T rowData])`（未解析到 `@ExcelProperty` 列元数据或 `rowIndex < 1` 时抛 `IllegalArgumentException`）
  - 整行级：`ExcelErrorRow.ofRow(int rowIndex, String message[, Object rowData])`（`columnIndex = null`，`columnName = "整行"`）

### 3.2 `BatchValidationListener` 与 `ExcelFeedbackUtil` 实测行为

- **`BatchValidationListener<T>`**（`io.github.atengk.boot.excel.listener.BatchValidationListener`）：
  - **行号计算**：`int rowIndex = (context != null && context.readRowHolder() != null) ? context.readRowHolder().getRowIndex() + 1 : 1;`（Fesod 原生 `rowIndex` 从 0 开始，监听器统一 `+ 1` 转 1-based）。
  - **默认参数**：`DEFAULT_BATCH_SIZE = 1000`、`DEFAULT_MAX_ERROR_ROWS = 500`、`headerStrategy = HeaderValidationStrategy.DISABLED`（直接构造监听器时默认关闭；**通过 `ExcelUtil.readWithResult` / `readWithValidation` 调用时默认读取 `ExcelValidationProperties` 即 `LOOSE`**）。
  - **计数与熔断语义**：单行若多个字段同时违反 JSR-303 约束，会向 `errorList` 追加多条 `ExcelErrorRow`，但 `errorRowCount` 仅 `+1`；当 `errorRowCount >= maxErrorRows` 时置 `circuitBroken = true` 并通过 `hasNext()` 中止解析。
  - **分批清理陷阱**：仅当传入非空 `dataConsumer` 时，满 `batchSize` 会执行 `validDataList.clear()` 与 `validRowRecords.clear()`；`ExcelUtil.readWithResult` 传入 `dataConsumer = null`，保留全量记录。
  - **JSR-303 Validator 解析**：优先取 Spring 容器中的 `Validator` Bean，未取到时降级 `Validation.buildDefaultValidatorFactory()`。

- **`ExcelFeedbackUtil`**（`io.github.atengk.boot.excel.util.ExcelFeedbackUtil`）：
  - `renderErrorFeedback(InputStream originalExcelStream, OutputStream outputStream, List<ExcelErrorRow> errorRows)`：
    - 仅渲染首个工作表 `workbook.getSheetAt(0)`。
    - 坐标转换：`r = error.getRowIndex() - 1`（转回 POI 0-based 行索引）；`c = (error.getColumnIndex() != null && error.getColumnIndex() >= 0) ? error.getColumnIndex() : 0`（`columnIndex` 为空或负值时默认标红并批注于第 `0` 列/A 列）。
    - 同单元格多错聚合：自动按序号换行拼接（`1. ...\n2. ...`），无错文案兜底 `"数据格式有误"`，批注作者固定 `"校验系统"`。
    - 样式渲染：无损克隆原单元格样式后填充 `IndexedColors.ROSE` 浅粉红纯色前景（并移除已有批注防 POI 冲突）。

### 3.3 默认文件、行数限制配置与 `readWithResult` 边界

- **`ExcelProperties`**（`io.github.atengk.boot.excel.properties.ExcelProperties`，前缀 `ateng.boot.excel`）：

| 配置键（`ateng.boot.excel.`） | 默认值 | 说明与实测边界 |
| :--- | :--- | :--- |
| `enabled` | `true` | 是否启用 Excel 自动装配 |
| `default-batch-size` | `1000` | 流式分批默认批次大小 |
| `max-sync-rows` | `100_000` | ⚠️ **实测陷阱**：仅 `ExcelUtil.read` 与 `ExcelUtil.readWithValidation` 在读取后校验超限并抛 `BusinessException(400)`；**`ExcelUtil.readWithResult` 未检查 `maxSyncRows`**，须由上层 PRD/Service 主动控制最大导入行数 |
| `validation.header-strategy` | `HeaderValidationStrategy.LOOSE` | 支持 `STRICT`（列名+顺序+列数全严控，多余列报错）、`LOOSE`（必填列全包含，允许乱序和多余列）、`DISABLED`；表头失配立即 Fail-Fast 抛 `ExcelHeaderValidationException(400)` |
| `validation.max-error-rows` | `500` | 单次校验允许最大错误物理行数（含表头校验后数据行） |
| `streaming-export.max-rows-per-sheet` | `1_000_000` | 流式分页导出单 Sheet 自动切分上限 |
| `streaming-export.default-page-size` | `1000` | 流式分页拉取默认页大小 |
| `security.formula-protection` | `true` | 默认防御 `= + - @ \t \r` 开头单元格公式注入 |
| `security.max-image-size` | `10MB` | `@ExcelImage` 单图上限 |

- **Excel 文件字节大小限制**：`ateng-boot-excel` 模块本身**无上传文件大小配置**；HTTP Multipart 文件上传大小由 Spring Boot 原生 `spring.servlet.multipart.max-file-size`（Spring Boot 默认 `1MB`）与 `max-request-size`（默认 `10MB`）限制，超限由 `GlobalExceptionHandler` 拦截 `MaxUploadSizeExceededException` 返回 **`code = 413`**（`CommonResultCode.PAYLOAD_TOO_LARGE`）。

---

## 4. Web 审计、枚举字典、口令与内置状态码（`ateng-boot-web` & `ateng-boot-core`）

### 4.1 `@OperateLog`、`OperateLogModel` 与 UA 识别

- **`@OperateLog`**（`io.github.atengk.boot.web.annotation.OperateLog`）：
  - `@Target({ElementType.METHOD, ElementType.TYPE})`，`@Retention(RetentionPolicy.RUNTIME)`
  - 属性清单：
    - `value()` / `module()`（`@AliasFor` 互为别名，默认 `""`）
    - `title()`（默认 `""`；`OperateLogAspect` 当 `module` 为空白时按 `title` → `value` 顺序回退取值填入 `OperateLogModel.module`）
    - **`type()`**（`OperateTypeEnum`，默认 `OperateTypeEnum.OTHER` —— **注意属性名为 `type`，不是 `operateType`**）
    - `description()`（默认 `""`）
    - `saveParams()`（默认 `true`）
    - `saveResult()`（默认 `true`）
    - `excludeParams()`（默认 `{}`）
- **`OperateTypeEnum`**（`io.github.atengk.boot.core.audit.OperateTypeEnum`）：
  - 全量 11 个常量：`OTHER(0, "其他")`、`INSERT(1, "新增")`、`UPDATE(2, "修改")`、`DELETE(3, "删除")`、`QUERY(4, "查询")`、`EXPORT(5, "导出")`、`IMPORT(6, "导入")`、`LOGIN(7, "登录")`、`LOGOUT(8, "登出")`、`GRANT(9, "授权")`、`CLEAN(10, "清空")`。

- **`OperateLogModel`**（`io.github.atengk.boot.core.audit.OperateLogModel`，共 **22 个字段**）：

| 字段 | 类型 | 切面填充方式与约束 |
| :--- | :--- | :--- |
| `traceId` | `String` | `TraceUtil.getTraceId()` |
| `tenantId` | `String` | `TenantContextHolder.getTenantId()` |
| `userId` | `String` | `UserContextHolder.getUserId()` |
| `originalUserId` | `String` | 仅 RunAs 模拟态非空（`UserContextHolder.getOriginalUserId()`） |
| `userName` | `String` | ⚠️ 切面取 `UserContextHolder.get()`（Sa-Token 下等于 `userId`），需业务 `OperateLogStorageProvider` 补充账号/昵称 |
| `module` | `String` | 注解 `module` → `title` → `value` |
| `operateType` | `OperateTypeEnum` | 注解 `type` |
| `description` | `String` | 注解 `description` |
| `requestMethod` | `String` | `request.getMethod()` |
| `requestUrl` | `String` | `request.getRequestURI()` |
| `clientIp` | `String` | `IpUtil.getClientIp(request)` |
| **`userAgent`** | `String` | 请求线程同步采集并净化（`WebProperties.OperateLogProperties.collectUserAgent=true`，最大长度 `512`） |
| **`browser`** | `String` | 请求线程同步通过 `UserAgentUtil.parse` 解析直接赋值（`parseUserAgent=true`） |
| **`os`** | `String` | 请求线程同步通过 `UserAgentUtil.parse` 解析直接赋值（`parseUserAgent=true`） |
| `operateLocation` | `String` | 切面**不填充**（恒 `null`） |
| `requestParams` | `String` | `AuditParamSanitizer` 递归排除敏感键（替换 `"[EXCLUDED]"`）并拦截循环引用与 `MultipartFile`/`Stream` |
| `responseResult` | `String` | 仅成功且 `saveResult=true` 时序列化；失败置 `null` |
| `status` | `Integer` | `0`-成功，`1`-失败 |
| `costTime` | `Long` | 毫秒耗时，标注 `@JsonSerialize(using = NumericLongSerializer.class)` |
| `errorMsg` | `String` | 异常消息，为 `null` 时回退异常简名 |
| `extra` | `Map<String, Object>` | RunAs 时注入 `isRunAs`/`originalUserId`/`targetUserId` |
| `operateTime` | `LocalDateTime` | `LocalDateTime.now()` |

- **默认脱敏排除清单**（`ateng.boot.web.operate-log.default-exclude-params`）：
  `["password", "passwd", "pwd", "oldPassword", "newPassword", "confirmPassword", "secret", "token", "accessToken", "refreshToken", "authorization"]`（大小写不敏感匹配，与 `@OperateLog.excludeParams` 合并）。
- **异步派发SPI**：`OperateLogStorageProvider#store(OperateLogModel)`，若容器中存在 `taskExecutor` Bean 则异步执行（默认走 `DefaultOperateLogStorageProvider` 输出 SLF4J 日志）。

- **UA 识别能力**（`io.github.atengk.boot.core.util.UserAgentUtil` & `io.github.atengk.boot.core.model.UserAgentInfo`）：
  - 纯 JDK 零第三方依赖有界线性扫描（无正则 ReDoS 风险），`DEFAULT_MAX_LENGTH = 512`，硬截断上限 `MAX_PARSE_LENGTH = 2048`，`sanitize` 过滤 ASCII `< 0x20` 与 `0x7F` 控制字符防日志注入。
  - `UserAgentInfo` Record 7 个组件：`(String browser, String browserVersion, String os, String osVersion, String deviceType, boolean mobile, String rawUserAgent)`；未知值统一保底 `"Unknown"`；`deviceType` 取值为 `Desktop` / `Mobile` / `Tablet` / `CLI` / `Bot` / `Unknown`。
  - 支持识别浏览器/工具（`WeChat`、`DingTalk`、`Edge`、`Opera`、`Samsung Browser`、`QQ Browser`、`UC Browser`、`Firefox`、`Chrome`、`Safari`、`IE`、`curl`、`Postman`、`OkHttp`、`Apache-HttpClient`、`Java`、`Python-Requests`、`Bot`）与 OS（`HarmonyOS`、`Android`、`iOS`、`Windows` NT 版本映射 `10/11`~`XP`、`macOS`、`Linux`）。**登录日志 `sys_login_log` 可直接复用 `UserAgentUtil.parse(rawUa)`**。

---

### 4.2 `IBaseEnum`、`EnumDictionaryRegistry` 与 `OptionItem`

- **`IBaseEnum<T extends Serializable>`**（`io.github.atengk.boot.core.enums.IBaseEnum`）：
  - 必实现：`T getCode()`、`String getLabel()`
  - 默认方法：`boolean matches(T code)`、`OptionItem<T> toOption()`、`Boolean getDisabled()`（默认 `false`）、`Map<String, Object> getExtra()`（默认 `Collections.emptyMap()`）、`T getValue()`（返回 `getCode()`，兼容 MyBatis-Plus `IEnum`）。
- **`OptionItem<T>`**（`io.github.atengk.boot.core.model.OptionItem`）：
  - 字段：`T code`、`String label`、`Boolean disabled`（默认 `false`）、`Map<String, Object> extra`（默认 `Collections.emptyMap()`）。
- **`EnumDictionaryProperties`**（`io.github.atengk.boot.web.properties.EnumDictionaryProperties`，前缀 `ateng.boot.web.enum`）：
  - `enabled`：`false`（`application.yml` 已置 `true`）
  - `endpoint-enabled`：`true`（`application.yml` 已置 `false`，关闭内置 `EnumDictionaryController` `/api/system/enums`，交由 `ateng-solid` `SysEnumController` 接管 `/admin/system/enums` 并施加 `@SaCheckLogin`）
  - `path-prefix`：`"/api/system/enums"`
  - `scan-packages`：`[]`（`application.yml` 已配置 `["io.github.atengk.solid"]`）
  - `naming-strategy`：`EnumNamingStrategy.LOWER_CAMEL_CASE`（剥离末尾 `Enum` 后转小驼峰，如 `UserStatusEnum` → `userStatus`；另有 `SNAKE_CASE`、`ORIGINAL`，并支持 `@EnumAlias` 显式覆盖，别名冲突在启动期 Fail-Fast 抛 `IllegalStateException`）。
- **`EnumDictionaryRegistry`**（`io.github.atengk.boot.web.dict.EnumDictionaryRegistry`）：
  - 公开查询方法：`getOptions(String name [, Locale])`（**未命中返回 `null`**）、`getBatchOptions(Collection<String> names [, Locale])`（忽略未找到的名称并返回不可变 Map）、`getAllOptions([Locale])`、`contains(String name)`、`getEnumClass(String name)`、`getAliases()`。
  - 多语言缓存：存在 `MessageSource` 时按 `enum.<SimpleClassName>.<CONSTANT_NAME>` 查找国际化标签并按 `Locale` 缓存（上限 `64` 个 `Locale`）。

---

### 4.3 `PasswordUtil`（口令哈希与强度边界）

- **核心类**：`io.github.atengk.boot.core.util.PasswordUtil`（`ateng-boot-core/src/main/java/io/github/atengk/boot/core/util/PasswordUtil.java`）
- **算法与默认参数**：
  - 派生算法：`ALGORITHM_PBKDF2_SHA256 = "PBKDF2WithHmacSHA256"`（纯 JDK `SecretKeyFactory` + `SecureRandom`）
  - 默认迭代次数：`DEFAULT_ITERATIONS = 310_000`（允许指定范围 `MIN_ITERATIONS = 10_000` ~ `MAX_ITERATIONS = 5_000_000`）
  - 默认随机盐长度：`DEFAULT_SALT_LENGTH = 16` 字节（校验下限 `MIN_SALT_LENGTH = 8` 字节）
  - 派生密钥长度：`DEFAULT_KEY_LENGTH_BITS = 256` 位（`32` 字节）
  - 存储格式：`"$pbkdf2-sha256$" + iterations + "$" + urlBase64NoPad(salt) + "$" + urlBase64NoPad(derived)`（默认参数下串长约 `88` 字符，DDL 建议 `VARCHAR(128)` 及以上）
  - 恒定时间比对：`MessageDigest.isEqual(...)` 防时序攻击；提供 `needsUpgrade(encodedPassword)` 检测是否低于 `310_000` 次以支持平滑升级。
- **空白/强度约束边界**：
  - `hash(...)` 仅拒绝 `null`、空串及全空白串（保留前后空格语义，内部 `Arrays.fill(chars, '\0')` 擦除明文数组）；
  - **底座 `PasswordUtil` 不提供密码复杂度/长度/字符集校验规则**！用户注册、重置密码、个人修改密码等密码强度规则须在 `ateng-solid` 业务层/DTO `@Pattern`/@`Size` 与系统参数中显式校验。

---

### 4.4 `CommonResultCode` 全部内置状态码与底座已占号段

- **`CommonResultCode`**（`io.github.atengk.boot.core.code.CommonResultCode`，全量 **14 个**内置常量）：

| 枚举常量 | `code` | `msg` | 典型触发场景 |
| :--- | :---: | :--- | :--- |
| `SUCCESS` | `200` | `"操作成功"` | `Result.success(...)` |
| `BAD_REQUEST` | `400` | `"参数校验失败"` | `@Validated` 参数异常、`CaptchaTemplate.verifyOrThrow`、`ExcelValidationException`、`ExcelHeaderValidationException`、非法租户头格式、`SaTokenException` 兜底 |
| `UNAUTHORIZED` | `401` | `"尚未登录或令牌已过期"` | `SaTokenExceptionHandler` 拦截 `NotLoginException` |
| `FORBIDDEN` | `403` | `"权限不足，拒绝访问"` | `NotRoleException` / `NotPermissionException` / `NotSafeException` / `DisableServiceException` / `SameTokenInvalidException` / `TenantHeaderSwitchValidator` 拒绝 / IP 防爆破锁定 |
| `NOT_FOUND` | `404` | `"请求资源不存在"` | `NoResourceFoundException` / `EnumDictionaryController` 未找到别名 |
| `METHOD_NOT_ALLOWED` | `405` | `"请求方法不支持"` | `HttpRequestMethodNotSupportedException` |
| `NOT_ACCEPTABLE` | `406` | `"不接受的媒体类型"` | `HttpMediaTypeNotAcceptableException` |
| `CONFLICT` | `409` | `"数据冲突或并发版本不一致"` | 并发/乐观锁冲突 |
| `PAYLOAD_TOO_LARGE` | `413` | `"上传文件大小超出限制"` | `MaxUploadSizeExceededException` |
| `UNSUPPORTED_MEDIA_TYPE` | `415` | `"不支持的媒体类型"` | `HttpMediaTypeNotSupportedException` |
| `TOO_MANY_REQUESTS` | `429` | `"访问过于频繁，请稍后再试"` | 限流拦截 |
| `INTERNAL_SERVER_ERROR` | `500` | `"系统繁忙，请稍后再试"` | 兜底未捕获异常、`CaptchaStore` 基础设施异常 |
| `SERVICE_UNAVAILABLE` | `503` | `"服务暂不可用或处理超时"` | `AsyncRequestTimeoutException` |
| `REPEAT_SUBMIT` | `40003` | `"操作过于频繁，请稍后再试"` | 幂等防重提交拦截 |

- **底座其他已占号段备忘（`ateng-solid` 避让核验）**：
  - `ResultCodeSegment` 建议业务/Starter 标准区间：`1000 ~ 9999`
  - `StorageResultCode`（`ateng-boot-storage`）：`40010 ~ 40013`、`40018 ~ 40024`、`50001 ~ 50008`
  - `FlywayResultCode`（`ateng-boot-flyway`）：`62001 ~ 62020`
  - **`ateng-solid` 规划的 `100xxx` / `101xxx` / `102xxx` 6 位分段号段与上述所有底座内置码零碰撞。**

---

## 5. 对象存储底座（`ateng-boot-storage` · 头像上传 PRD 边界对齐）

### 5.1 `StorageProperties` 与 `StorageGuardProperties` 默认配置

- **核心类路径**：
  - `io.github.atengk.boot.storage.properties.StorageProperties`（前缀 `ateng.boot.storage`）
  - `io.github.atengk.boot.storage.properties.LocalStorageProperties`
  - `io.github.atengk.boot.storage.properties.S3StorageProperties`
  - `io.github.atengk.boot.storage.properties.StorageGuardProperties`
  - `io.github.atengk.boot.storage.guard.StorageGuard` & `StorageFileType`
  - `io.github.atengk.boot.storage.template.StorageOperations` & `StorageTemplate`
  - `io.github.atengk.boot.storage.model.StorageObject`

| 配置键（`ateng.boot.storage.`） | 类型 | 默认值 | 头像上传对齐约束 |
| :--- | :--- | :--- | :--- |
| `enabled` | `boolean` | `true` | `application-test.yml` 已置 `false`；`application.yml` 尚未配置 |
| `type` | `String` | `"local"` | 单源默认使用本地磁盘驱动（可选 `local` / `s3`） |
| `primary` | `String` | `"primary"` | 多源主驱动名称 |
| `max-chunk-size` | `DataSize` | `100MB` | 单分片容量上限 |
| `local.base-path` | `String` | `null` | 未配置时 `StorageDriverFactory` 回退 `${java.io.tmpdir}/ateng-storage`（生产必须指定持久化目录） |
| `local.domain` | `String` | `null` | 用于 `getUrl(path)` 拼接及预签名 URL 域名；为空时生成相对路径 |
| `local.secret-key` | `String` | `null` | ⚠️ 未配置时每次启动随机生成 64 位 hex，重启将导致历史预签名链接失效 |
| `local.download-endpoint` | `String` | `"/storage/local/download"` | `LocalStorageDownloadController` 默认映射路径（`endpoint-enabled` 默认 `true`） |
| `local.upload-endpoint` | `String` | `"/storage/local/upload"` | `LocalStorageUploadController` 默认映射路径 |
| **`guard.enabled`** | `boolean` | **`false`** | ⚠️ **默认关闭**！未开启时 `StorageGuard` 既不校验大小也不校验后缀与魔数 |
| `guard.strict-magic-check` | `boolean` | `false` | 开启后已知二进制扩展名（`png`/`jpg`/`jpeg`/`gif`/`webp`/`bmp` 等）必须通过 512 字节头部魔数匹配（`StorageGuard.STRICT_CHECK_EXTENSIONS`） |
| `guard.allowed-extensions` | `Set<String>` | `Collections.emptySet()` | 空集表示不限白名单；头像上传需配置 `["jpg", "jpeg", "png", "webp", "gif"]` 或由上层单独约束 |
| `guard.disallowed-extensions` | `Set<String>` | `Collections.emptySet()` | 额外黑名单；即使未配，`StorageSecurityUtil.DANGEROUS_EXTENSIONS`（`sh/bat/cmd/exe/dll/vbs/ps1/scr/com/msi`）在 `guard.enabled=true` 时也一律拒绝 |
| **`guard.max-file-size`** | `DataSize` | **`null`** | ⚠️ **默认无限制**；仅在 `guard.enabled=true` 且配置正值后，超限抛 `StorageException(40020 /* STORAGE_SIZE_EXCEEDED */)`（`StorageException` 继承 `BusinessException`，会被 `GlobalExceptionHandler` 直接透传 `40020` / `40010` / `40011`） |

> **多类型上传边界提示**：`StorageGuardProperties` 是全局单套配置；若系统后续既有“头像上传（限 2MB，仅图片）”又有“普通附件/导入（限 20MB，支持 xlsx/pdf）”，建议**上层头像接口显式前置校验扩展名/MIME/体积（如 ≤ 2MB）与图片魔数校验（或调用 `StorageGuard.sniff`）**，避免全局配置互相挤压。

### 5.2 `StorageObject` 返回模型与对象键 / URL 访问边界

- **`StorageObject`**（`io.github.atengk.boot.storage.model.StorageObject`）：
  - `String path`：规范化后的纯净相对对象键（如 `"2026/11/23/<uuid>.png"` 或 `"avatar/0/1001/<uuid>.png"`）
  - `String filename`：基础文件名（如 `"<uuid>.png"`）
  - `Long size`：文件字节数
  - `String contentType`：MIME 类型（`guard.enabled=true` 且原类型为 `application/octet-stream` 时优先使用魔数嗅探出的 `detectedMimeType`）
  - `String etag`：摘要哈希（Local 驱动下为 MD5 十六进制串）
  - `Instant lastModified`：最后修改时间
  - `Map<String, String> userMetadata`：自定义元数据（默认空 Map）
  - `String storageClass` / `String serverSideEncryption` / `Boolean directory`（默认 `false`）
- **对象键生成策略**（`StorageTemplate`）：
  - `upload(MultipartFile file)`：自动按 `yyyy/MM/dd/<fastSimpleUUID>[.<ext>]` 生成唯一安全相对路径（`publicRead = false`、`overwrite = true`）。
  - `upload(String path, MultipartFile file)`：按业务指定路径写入（若 `path` 以 `/` 结尾则自动拼接清洗后的原始文件名）。
  - `uploadPublic(String path, MultipartFile file)`：赋予 `publicRead = true`（仅 S3 驱动生效 `ObjectCannedACL.PUBLIC_READ`；无单参 `uploadPublic(MultipartFile)` 重载）。
- **头像 URL 访问与鉴权碰撞边界（PRD 重点对齐）**：
  1. `StorageOperations#getUrl(String path)`：在 `LocalDriver` 下仅做字符串拼接 `domain + "/" + path`（或 `"/" + path`），**`ateng-boot-storage` 不会自动为 `local.basePath` 注册无鉴权静态文件映射**；直接返回 `getUrl(path)` 在纯 Local 模式无 Nginx/WebMvc 静态映射时无法 200 访问。
  2. `StorageOperations#getPresignedUrl(String path, Duration)`：在 `LocalDriver` 下生成指向 `LocalStorageDownloadController` 的带 HMAC-SHA256 签名 URL（`/storage/local/download?path=...&expires=...&signature=...`，`expires` 默认 15 分钟）。
  3. **Sa-Token 拦截碰撞警告**：`SaTokenWebMvcConfigurer` 默认拦截 `"/**"` 且 `application.yml` 已开启 `ateng.boot.satoken.interceptor.check-login: true`。浏览器 `<img>` / `ElAvatar` 直接请求 `/storage/local/download` **不会携带 `satoken-admin` 请求头**，若未放行该下载端点或未改走 Nginx/OSS 外链/专用白名单头像下载端点，将会触发 **`401 Unauthorized`**。

---

## 6. `ateng-solid-server` 现有配置对齐核查表

对照 `d:\source\ateng-solid\ateng-solid-server\ateng-solid-bootstrap\src\main\resources\application.yml` 与 `application-test.yml`：

| 检查项 | 当前状态 | 核查结论与后续动作建议 |
| :--- | :--- | :--- |
| `ateng.boot.web.enum.endpoint-enabled: false` + `scan-packages` | ✅ 已配置 | 已正确关闭底座内置 `/api/system/enums`，由 `SysEnumController` 注入 `EnumDictionaryRegistry` 接管 |
| `ateng.boot.satoken.primary-login-type: admin` + `login-type-routes.admin: [/admin/**]` | ✅ 已配置 | 配合默认开启的 `auto-route-annotation-type: true`，Controller 可裸写 `@SaCheckPermission` |
| `ateng.boot.satoken.login-defense.enabled: true` | ✅ 已配置 | 已激活 `LoginFailureLockService`（默认 5 次 / 锁 15m，IP 30 次 / 锁 30m） |
| `ateng.boot.satoken.super-admin-roles` | ⚠️ **缺失** | 默认为 `["admin", "super_admin"]`；须在 `application.yml` 显式收敛为 `["super_admin"]` |
| `ateng.boot.satoken.permission-cache.tenant-scoped` | ⚠️ **未配置** | 默认 `false`；多租户关闭时无影响，若多租户开启（`tenant.enabled=true`）须同步设为 `true` |
| `ateng.boot.satoken.tenant.*` | ⚠️ **未配置** | 默认 `allow-super-admin-switch=false`、`allow-anonymous-header=false`、`platform-tenant-ids=[]`；开启多租户切租户时须置 `allow-super-admin-switch: true` 与 `platform-tenant-ids: ["0"]` 并实现 `TenantHeaderSwitchValidator` Bean |
| `ateng.boot.storage.*` | ⚠️ **未配置** | 默认 `enabled=true`、`type=local`（`application-test.yml` 已设 `false`）；头像 PRD 落地时须显式配置 `base-path`、`secret-key`、`guard.enabled=true`、`guard.allowed-extensions`、`guard.max-file-size` 及静态/白名单访问策略 |
| `ateng.boot.mybatis-plus.data-permission.enabled: true` | ✅ 已配置 | 默认兜底 `DefaultDataPermissionHandler` 返回 `null`；待 Spec 3 注册自定义 `DataPermissionHandler` Bean 接管 5 级 `@DataScope` |
