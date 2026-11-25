# `ateng-boot` 最新 `dev`（准 `1.2.1`，含 `#1171`/`#1172`）深水区工程约束与实测调研报告

> **工单来源**：`atengk/ateng-solid` Wayfinder 调研工单 `#12`  
> **前置基线**：[`docs/specs/prd/_research/boot-1.2.0-constraints.md`](../prd/_research/boot-1.2.0-constraints.md)（本文不重复抄写 `v1.2.0` 已覆盖的 Captcha / 防爆破 / `PermissionCacheService` / 实体基类 / `@OperateLog` / `IBaseEnum` 常规契约，仅聚焦 `v1.2.0` → `dev@0c172a12` 的增量特性与 5 个高风险工程深水区的一手源码与实测证据）  
> **一手信源基线**：
> - 上游底座仓库：`atengk/ateng-boot` `dev` 分支 `HEAD = 0c172a12f2d310ebe71ce700eb892aa442411b9e`（工作区干净；含 `8e7bef82` `Closes #1171` 与 `0c172a12` `Closes #1172`）
> - 关键底层三方依赖版本（源自 `pom.xml`）：`mybatis-plus = 3.5.17`、`jsqlparser = 5.2`、`fesod = 2.1.0-incubating`
> - 性能实测环境：OpenJDK `21.0.13` LTS（Temurin 64-Bit Server VM）、Intel Xeon Gold 5218R CPU @ 2.10GHz、`availableProcessors = 12`、Windows 10 amd64（零污染单文件临时脚本运行并即刻清理）

---

## 0. 五维核心结论与工程红线速查表

| 维度 | 核心实测真相 | 对 `ateng-solid` PRD / Spec / 编码的强制约束 | 是否触发底座新缺口 |
| :--- | :--- | :--- | :--- |
| **① `@FieldEncrypt` 加密与检索边界** | 归属 **`ateng-boot-mybatis-plus`**（非 `ateng-boot-encrypt`）；**无 MyBatis `ParameterInterceptor`/`ResultSetInterceptor`**，纯靠 `BaseTypeHandler<String>` + `@TableName(autoResultMap = true)`。默认 `EncryptTypeHandler` 为随机 IV 不可检索；`DeterministicEncryptTypeHandler`（HMAC-SHA256 SIV）支持精确等值与唯一索引，但标准 `LambdaQueryWrapper.eq/in` **不会自动触发 TypeHandler**；`email`（64 字符）加密后长达 **131 字符** | `sys_user.phone`/`email` 若加密且需同租户唯一索引与检索，须采用 `@FieldEncrypt(deterministic = true)` + `DeterministicEncryptTypeHandler` + `autoResultMap = true`；DDL 列宽须放大（`phone >= VARCHAR(128)`、`email >= VARCHAR(255)`）；空串归一化为 `null`、邮箱转小写；查询框 `phone` 必须收敛为**精确匹配**并显式调 `EncryptTypeHandler.encryptDeterministic(...)`（或经 `DynamicQueryHelper`） | 否（能力完备，属上层契约对齐） |
| **② `PasswordUtil.hash` 500 行导入吞吐** | PBKDF2-HMAC-SHA256 `310,000` 次迭代单次实测 **`avg = 369.57 ms`**（`p50 = 361.12 ms`、`p95 = 423.21 ms`）；500 行串行推算 **`191.52 s`**；12 核固定池 **`17.59 s`**、6 核 **`32.71 s`**、4 核 **`49.31 s`**、2 核 **`99.26 s`**；500 虚拟线程 **`15.36 s`** 但会饿死 Carrier 线程 | **严禁**按现 PRD `02-org-and-rbac.md` §7.2 在 `@Transactional` 事务内串行哈希！必须改用**“先无事务在独立有界 `PLATFORM` 线程池并行算完 500 个独立盐哈希 ➔ 再开 `< 100ms` 短事务 `BatchUtil.insertBatch` 落库”**；禁止复用虚拟线程执行器；前端导入超时须拉高（如 `120s`）并使单批行数上限可配置 | 否（`ateng-boot-core` 已原生支持 `ateng.boot.async.pools.<name>.mode=PLATFORM`） |
| **③ `@DataScope` 与 AST 拼接机制** | 真实签名 `DataPermissionHandler#getSqlSegment(Table, Expression, String, DataScope)`。字节码实证 MyBatis-Plus 3.5.17 `BaseMultiTableInnerInterceptor` **仅对已有 `WHERE` 为 `OrExpression` 加括号，不对返回的 `OrExpression` 加括号**；且 `AtengDataPermissionInnerInterceptor` 捕获处理器异常后 **`return null`（Fail-Open）** | 上层多角色并集返回 `OR` 时**必须手动包裹 `new ParenthesedExpressionList<>(orExpr)`**，否则发生 `AND/OR` 优先级穿透导致越权！无任何可见部门时**必须返回 `1 = 0`（`new EqualsTo(new LongValue(1), new LongValue(0))`）而非 `null`**；`LEFT JOIN` 场景 `@DataScope(alias = "u")` 必须绑主表；处理器内部不得抛未受检异常 | **是（2 项安全加固候选）**：见 §6 `C1`（Fail-Open 异常兜底）与 `C2`（裸 `OrExpression` 自动套括号） |
| **④ Storage 白名单与预签名头像 (`#1172`)** | `LocalStorageProperties` 新增 4 开关，默认开启双端点、默认关闭双白名单；`LocalStorageSaTokenWhitelistConfiguration` 通过 `@AutoConfigureBefore` + 类加载隔离注入 `SaTokenWhitelistProvider`，并对同路径不对称白名单启动期 Fail-Fast 抛 `IllegalStateException`；预签名默认 15 分钟且默认 `Content-Disposition: attachment` | `ateng-solid` 推荐 `upload-endpoint-enabled: false` + `download-endpoint-enabled: true` + `whitelist-presigned-download: true` + 固定 `local.secret-key`；**`sys_user.avatar` 数据库仅存相对对象键（如 `avatar/0/1001/<uuid>.png`），绝不存短效预签名 URL**；VO 组装时动态签发带 `.responseContentDisposition("inline")` 的预签名 URL；换头像采用 `uploadWithRollbackDelete` + `deleteAfterCommit` 实现事务级防孤儿/防误删 | 仅微观察（不阻断）：`LocalDriver.java:694` `?path=` 未 URL 编码（纯 ASCII 头像键零影响） |
| **⑤ Excel `maxSyncRows` (`#1171`) 与流复用** | `BatchValidationListener#invoke` 在 JSR-303 校验前对所有非空行计数，达 `maxSyncRows + 1` 即 Fail-Fast 抛 `BusinessException(400)`；但 **`ExcelUtil.readWithResult` 无单次调用级 `maxSyncRows` 重载**（仅读全局静态值），且 `ExcelReaderBuilder#maxRows` 丢失 `validRowRecords` 物理行号视图；读取与批注渲染均消费完整 `InputStream` | `<= 2MB` 场景对 `MultipartFile` 执行一次 `file.getBytes()`，分别构造 `new ByteArrayInputStream(bytes)` 喂给 `ExcelUtil.readWithResult` 与 `ExcelFeedbackUtil.renderErrorFeedback`（天然支持 `mark/reset` 且峰值 XSSF DOM 仅约 `2~45 MB`）；`> 2MB` 改走 `ExcelUtil.createTempFile` 磁盘暂存；单次 500 行上限建议结合配置或显式 `BatchValidationListener` 9 参构造 | **是（1 项轻度增强候选）**：见 §6 `C3`（`ExcelUtil.readWithResult` 缺少单次 `maxSyncRows` 重载） |

---

## 1. `@FieldEncrypt` 加密与检索边界

### 1.1 模块归属澄清：`ateng-boot-encrypt` vs `ateng-boot-mybatis-plus`

- **`ateng-boot-encrypt` 不包含 `@FieldEncrypt`**：该模块（`ateng-boot-encrypt/README.md:1-33`）专职解决 Spring Boot 配置文件 / 配置中心（`ENC(...)`、`EncryptTemplate`、`ConfigEncryptor`）属性加解密，支持 `AES-GCM`、`AES-CBC`、`SM4-CBC/ECB`、`SM2`、`RSA` 等，不介入数据库持久层。
- **持久层字段透明加解密完整归属 `ateng-boot-mybatis-plus`**：
  - 注解：`ateng-boot-mybatis-plus/src/main/java/io/github/atengk/boot/mybatisplus/annotation/FieldEncrypt.java:22-33`
  - 随机 IV 处理器：`ateng-boot-mybatis-plus/src/main/java/io/github/atengk/boot/mybatisplus/handler/EncryptTypeHandler.java:29-236`
  - 确定性 SIV 处理器：`ateng-boot-mybatis-plus/src/main/java/io/github/atengk/boot/mybatisplus/handler/DeterministicEncryptTypeHandler.java:17-23`
  - 密钥装配配置：`ateng-boot-mybatis-plus/src/main/java/io/github/atengk/boot/mybatisplus/properties/MybatisPlusProperties.java:430-444`（配置键 `ateng.boot.mybatis-plus.crypto.secret-key`），由 `AtengMybatisPlusAutoConfiguration#initGlobalConfig`（`AtengMybatisPlusAutoConfiguration.java:93-96`）静态注入 `EncryptTypeHandler.setGlobalSecretKey(...)`。

### 1.2 算法、IV 策略、密文长度与密钥边界

| 维度 | 默认模式：`EncryptTypeHandler`（`@FieldEncrypt`） | 确定性模式：`DeterministicEncryptTypeHandler`（`@FieldEncrypt(deterministic = true)`） | 源码锚点 |
| :--- | :--- | :--- | :--- |
| **底层算法** | `AES/CBC/PKCS5Padding`（纯 JDK `CryptoUtil.encryptCbc`） | `AES/CBC/PKCS5Padding` | `CryptoUtil.java:27,191-205` |
| **IV 生成策略** | 每次写入调用 `CryptoUtil.generateIv()` 生成 16 字节 `SecureRandom` **随机 IV** | 基于 `HMAC-SHA256(keyBytes, plainBytes)` 截取前 16 字节作为**合成固定 IV（SIV）** | `EncryptTypeHandler.java:118-126, 150-161` |
| **密文存储格式** | `"v1:" + Base64(16B IV \|\| cipherBytes)` | `"v1:" + Base64(16B SIV \|\| cipherBytes)` | `EncryptTypeHandler.java:50,126,161` |
| **同明文幂等性** | 每次密文均不同（抵御词频分析，**不支持唯一索引与等值查询**） | 相同密钥 + 相同字节明文**恒定生成同一密文**（支持数据库唯一索引与 `=` / `IN` 查询） | `DeterministicEncryptTypeHandler.java:20-22` |
| **空值 / 空串语义** | `null` → `null`；`""` → `""`（**不加密原样返回**） | `null` → `null`；`""` → `""`（**不加密原样返回**） | `EncryptTypeHandler.java:113-115, 142-144` |
| **双向解密与明文兼容** | `decrypt(...)` 剥离可选 `"v1:"`（兼容无前缀旧密文）；若 Base64 解码后长度 `<= 16` 或解密抛出任何异常（如历史明文），记 `WARN` 日志并**安全原样返回原始值** | 直接继承父类 `EncryptTypeHandler#decrypt`，与随机 IV 密文、历史无前缀密文、历史明文 100% 双向兼容 | `EncryptTypeHandler.java:174-198` |
| **密钥派生与默认风险** | 支持 16/24/32 字节原串、Base64 编码密钥或任意字符串（SHA-256 派生 32 字节）；⚠️ **未配置时静默回退内置硬编码默认密钥** `SHA-256("io.github.atengk.boot.mybatisplus.crypto.default")` | 共用同一全局 `cachedSecretKeyBytes` | `EncryptTypeHandler.java:36-45, 209-235` |

> **关键 DDL 列宽公式（AES-CBC-PKCS5Padding + 16B IV + Base64 + `v1:`）**：  
> 设明文 UTF-8 字节长度为 $L$，填充后密文块长为 $P = (\lfloor L/16 \rfloor + 1) \times 16$，总字节 $C = 16 + P$，最终密文字符串长度为：
> $$\text{Len} = 3 + \left\lceil \frac{16 + (\lfloor L/16 \rfloor + 1) \times 16}{3} \right\rceil \times 4$$
> - **11 位手机号（$L = 11$）**：$P=16, C=32 \Rightarrow$ 密文定长 **`47` 字符**（国际号 20 位 $L=20 \Rightarrow$ **`67` 字符**）
> - **64 位邮箱（$L = 64$，对齐 PRD `02-org-and-rbac.md` §7.2 上限）**：64 恰好为 16 整数倍，PKCS5Padding 追加整块 16 字节，$P=80, C=96 \Rightarrow$ 密文长达 **`131` 字符**！
> - **硬警告**：若 `sys_user.email` 沿用传统 `VARCHAR(64)` 或 `VARCHAR(128)`，64 字符邮箱写入时在 MySQL 严格模式下会直接触发 `Data too long for column 'email'`！`sys_user` / `sys_dept` 若开启加密，建议 DDL 列宽固定为 **`phone VARCHAR(128)`**、**`email VARCHAR(255)`**。

### 1.3 拦截器实测真相与 `WHERE` / `UPDATE` / 批量插入边界

经全仓检索 `ateng-boot-mybatis-plus/src/main`（含 `AtengMybatisPlusAutoConfiguration.java:220-275`），**底座不存在任何 MyBatis `ParameterInterceptor` 或 `ResultSetInterceptor` 自动拦截 `@FieldEncrypt`**。所有加密与解密完全依赖以下 4 条机制协同：

1. **实体写入与出库解密（`TypeHandler` + `autoResultMap = true`）**：
   - 实体类**必须**同时声明 `@TableName(value = "sys_user", autoResultMap = true)` 与字段级 `@TableField(typeHandler = DeterministicEncryptTypeHandler.class)`（参见 `ateng-boot-mybatis-plus/README.md:470` 与 `ateng-boot-samples/ateng-boot-sample-mybatis-plus/.../UserEntity.java:26,44-52`）。若漏写 `autoResultMap = true`，`insert`/`updateById` 会加密入库，但 `selectById`/`selectList`/`selectPage` 将**原样返回 `"v1:..."` 密文**。
   - `@FieldEncrypt` 注解本身**不触发加解密**，它的作用是作为元数据标记服务于 4 个外围能力：`DynamicQueryHelper`（`DynamicQueryHelper.java:939-968`）、`PageUtil` 排序黑名单拦截（`PageUtil.java:245`）、`SlowSqlInterceptor` 参数掩码（`SlowSqlInterceptor.java:305,370`）与 `SqlParameterFormatter` 日志脱敏（`SqlParameterFormatter.java:360,671`）。
2. **原生批量插入（`BatchUtil.insertBatch` / `InsertBatchSomeColumn`）**：
   - 经对 MyBatis-Plus `3.5.17` `InsertBatchSomeColumn` 字节码核验，其内部通过 `TableFieldInfo#getInsertSqlProperty("et.")` 生成 `#{et.phone, typeHandler=...}`，**100% 透传执行 `EncryptTypeHandler` / `DeterministicEncryptTypeHandler`**，因此 `BatchUtil.insertBatch` 批量导入用户时可透明加密入库。
3. **普通 `LambdaQueryWrapper` / `QueryWrapper` / `LambdaUpdateWrapper` 的隐蔽盲区**：
   - MyBatis-Plus 不会对 `LambdaQueryWrapper.eq(SysUser::getPhone, plainPhone)`、`.in(SysUser::getPhone, plainPhones)` 或 `LambdaUpdateWrapper.set(SysUser::getPhone, plainPhone)` 自动附加 `TypeHandler`！直接传明文会导致 SQL 发送 `WHERE phone = '13800138000'`，与库中 `'v1:...'` 密文**永远不命中**，且 `LambdaUpdateWrapper.set(...)` 会把**裸明文**写进加密列！
   - **唯一合法检索路径**：
     - **路径 A（推荐，与手写 Wrapper 兼容）**：在 Service/Mapper 查询封装中显式调用 `EncryptTypeHandler.encryptDeterministic(normalizedPlain)` 传入 `.eq(...)` / `.in(...)`；更新加密列统一走 `updateById(entity)` 或在 `set` 中显式加密（清空为 `null` 时可直接 `.set(SysUser::getPhone, null)`）。
     - **路径 B（`DynamicQueryHelper` 驱动）**：`DynamicQueryHelper.java:171-174, 402-407, 501-510, 741-773` 自动识别 `@FieldEncrypt(deterministic = true)` 或 `DeterministicEncryptTypeHandler`：
       - 对 `EQ`、`NE`、`IN`、`NOT_IN` 自动调用 `EncryptTypeHandler.encryptDeterministic(...)` 转密文，`IS_NULL`、`IS_NOT_NULL` 原样放行；
       - 对 `LIKE`、`LIKE_LEFT`、`LIKE_RIGHT`、`BETWEEN`、`GT`、`GE`、`LT`、`LE` 及 `ORDER BY` 排序立即抛出 **`IllegalArgumentException`**（注意：`GlobalExceptionHandler` 未单独拦截 `IllegalArgumentException`，若未捕获将落入 `500`！）。
       - 对非确定性 `@FieldEncrypt(deterministic = false)` 字段则在构建 Wrapper 时静默忽略该条件。

### 1.4 与 `ateng-solid` `sys_user.phone` / `email` 的真实冲突边界与落地方案

对照 `docs/specs/prd/02-org-and-rbac.md`（§6.1、§6.2、§7.2）与 `ateng-solid-server/docs/specs/database-and-flyway-spec.md`（§2.2）：

1. **选型决策**：由于 `sys_user.phone` 与 `sys_user.email` 同时要求**同租户唯一性约束**（新建、编辑、个人资料、500 行批量导入 `IN` 查重）及**列表按手机号检索**，**绝对不可使用默认的随机 IV `EncryptTypeHandler`**；若启用持久层加密，两者均必须采用 **`@FieldEncrypt(deterministic = true)` + `@TableField(typeHandler = DeterministicEncryptTypeHandler.class)`** + `@TableName(value = "sys_user", autoResultMap = true)`。
2. **唯一索引与空值/大小写冲突防卫**：
   - 空串陷阱：`EncryptTypeHandler.encryptDeterministic("")` 返回 `""`（非 `null`）。MySQL/H2 联合唯一索引 `(tenant_id, phone, deleted)` 允许多个 `NULL`，但**两个 `""` 会触发唯一键冲突**！因此在 DTO → Entity 转换与查询入口，必须强制 `StringUtils.hasText(v) ? v.trim() : null`。
   - 大小写陷阱：确定性 HMAC-SHA256 对大小写字节敏感，MySQL `utf8mb4_unicode_ci` 不区分大小写但密文区分！`email` 入库与查询前**必须统一 `.trim().toLowerCase(Locale.ROOT)`**，否则 `Admin@Ateng.com` 与 `admin@ateng.com` 将生成不同密文并绕过唯一校验。
3. **搜索框交互冲突（须在 PRD `#10` 同步明确）**：
   - 无论随机 IV 还是确定性 SIV，加密列均**绝对不支持 `LIKE '%138%'` 模糊检索**与 `ORDER BY`。
   - `/system/user` 列表搜索框 `phone` 必须明确定义为**完整手机号精确匹配**（前端 placeholder 标注 `"请输入完整手机号（精确查询）"`，后端 `eq(SysUser::getPhone, EncryptTypeHandler.encryptDeterministic(phone.trim()))`）；仅 `username`/`nickname` 保留模糊检索。
4. **种子脚本与混合明文陷阱**：
   - 虽 `decrypt` 兼容历史明文读取，但 `WHERE phone = 'v1:...'` 查不到数据库里存的明文记录。因此 `V1.0.1__system_init_seed.sql` 严禁写入明文 `phone`/`email`（超管初始化留 `NULL` 或统一经 Java 启动引导器走 MyBatis-Plus 实体写入）。
   - 生产环境必须在 `application-local.yml` 或环境变量注入固定 `ateng.boot.mybatis-plus.crypto.secret-key`，禁止依赖内置默认密钥或上线后无迁移计划地随意变更密钥。

---

## 2. `PasswordUtil.hash`（PBKDF2 310,000 次迭代）500 行导入吞吐实测

### 2.1 `PasswordUtil` 源码参数核实

源码路径：`ateng-boot-core/src/main/java/io/github/atengk/boot/core/util/PasswordUtil.java`

- **算法与默认常量**（`lines 21-33`）：
  - `ALGORITHM_PBKDF2_SHA256 = "PBKDF2WithHmacSHA256"`
  - `DEFAULT_ITERATIONS = 310_000`（允许自定义范围 `MIN_ITERATIONS = 10_000` ~ `MAX_ITERATIONS = 5_000_000`）
  - `DEFAULT_SALT_LENGTH = 16` 字节（通过共享 `private static final SecureRandom SECURE_RANDOM = new SecureRandom()` 逐次生成独立随机盐）
  - `DEFAULT_KEY_LENGTH_BITS = 256`（32 字节），输出格式 `$pbkdf2-sha256$<iterations>$<urlB64Salt>$<urlB64Hash>`（默认定长 **`88` 字符**）
- **关键重载与升级探针**（`lines 44-145`）：
  - `public static String hash(CharSequence rawPassword)`（默认 `310_000`）
  - `public static String hash(CharSequence rawPassword, int iterations)`（支持受控自定义迭代次数）
  - `public static boolean matches(CharSequence rawPassword, String encodedPassword)`（`MessageDigest.isEqual` 常量时间比对）
  - `public static boolean needsUpgrade(String encodedPassword)` / `needsUpgrade(String encodedPassword, int targetIterations)`（检测是否低于目标迭代次数，支持登录时平滑重哈希升级）

### 2.2 Java 21 零污染实测数据

> 测试方法：完全复现 `PasswordUtil.java:147-211` 逻辑（同算法、同 `310,000` 次迭代、同 16 字节共享 `SecureRandom` 盐、同 URL-safe Base64 无填充与 `char[]` 擦除），先执行 10 次 JIT 预热，再执行单次 30 轮采样与 500 行多并发模式实测。测试环境：OpenJDK `21.0.13` LTS、Intel Xeon Gold 5218R @ 2.10GHz、`availableProcessors = 12`。

| 实测场景 | 样本量 | 实测总墙钟耗时 | 折算单行墙钟耗时 | 独立哈希数校验 | 工程可用性评估 |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **单次调用采样**（预热 10 次后） | 30 次 | `min = 333.54 ms`<br>**`avg = 369.57 ms`**<br>`p50 = 361.12 ms`<br>`p95 = 423.21 ms`<br>`max = 431.11 ms` | `369.57 ms` | 30 / 30 | 单次登录/新建/改密体验无感（`< 0.4s`） |
| **单线程串行** | 50 行实测 → 500 行推算 | 50 行实测 **`19,152.4 ms` (`19.15 s`)**<br>500 行推算 **`191,524.3 ms` (`191.52 s` ≈ 3.2 min)** | `383.05 ms` | 50 / 50 | ❌ **不可用**：必然触发前端 Axios（30s）/ Nginx（60s）超时与 DB 事务/锁超时 |
| **`FixedThreadPool(2)`**（模拟 2C 容器） | 500 行实测 | **`99,260.8 ms` (`99.26 s`)** | `198.52 ms` | 500 / 500 | ❌ 2C 节点 500 行同步导入超 60s 网关红线 |
| **`FixedThreadPool(4)`**（模拟 4C 容器） | 500 行实测 | **`49,310.8 ms` (`49.31 s`)** | `98.62 ms` | 500 / 500 | ⚠️ 4C 节点逼近 60s 网关红线且 100% 占满 CPU |
| **`FixedThreadPool(6)`**（12C 留 50% 余量） | 500 行实测 | **`32,706.2 ms` (`32.71 s`)** | `65.41 ms` | 500 / 500 | ⚠️ 超默认 30s 前端超时，需专项拉高导入请求超时 |
| **`FixedThreadPool(12)`**（满 `availableProcessors`） | 500 行实测 | **`17,593.8 ms` (`17.59 s`)** | `35.19 ms` | 500 / 500 | ⚠️ 墙钟可接受，但持续 17.6s 打满 100% CPU |
| **`VirtualThreadPerTaskExecutor(500)`** | 500 行实测 | **`15,361.3 ms` (`15.36 s`)** | `30.72 ms` | 500 / 500 | ❌ **虚拟线程反模式**：见 §2.3 严重 Carrier 饿死分析 |

### 2.3 虚拟线程陷阱与事务边界工程建议（须修订 PRD `02-org-and-rbac.md` §7.2）

1. **必须纠偏现 PRD 的长事务反模式**：
   - 现有 `docs/specs/prd/02-org-and-rbac.md` §7.2（第 226 行）描述“在同一事务内为每位用户调用 `PasswordUtil.hash(initPassword)` 并调用 `BatchUtil` 批量落库”。
   - 即使在 12 核并发下，500 行哈希也需 **`17.6s ~ 32.7s`**（串行更是 **`191.5s`**）。在 `@Transactional` 内执行纯 CPU 慢哈希将导致 JDBC 连接被长期占用（触发 HikariCP `leakDetectionThreshold` 与连接池耗尽）并直接违背 `coding-and-architecture.md` §4.2 事务克制铁律。
2. **禁止使用虚拟线程（`Executors.newVirtualThreadPerTaskExecutor()` 或默认 `taskExecutor`）执行批量 PBKDF2**：
   - `ateng-solid-bootstrap/src/main/resources/application.yml:11-13` 已全局开启 `spring.threads.virtual.enabled: true`，`AtengAsyncAutoConfiguration`（`AtengAsyncAutoConfiguration.java:94-104`）默认装配的 `taskExecutor` 是虚拟线程 `SimpleAsyncTaskExecutor`。
   - PBKDF2 310,000 次迭代是 **100% 纯 CPU 密集、零 I/O 阻塞**的计算循环。提交 500 个虚拟线程会让 JVM 共享 `ForkJoinPool` Carrier 线程池全部被占满长达 `15.4s`，导致同一进程内所有 Tomcat 虚拟线程 HTTP 请求、心跳探针与异步审计任务出现大面积卡顿/饿死。
   - **正确解法（100% 复用 `ateng-boot-core` 原生多池能力）**：利用 `AsyncProperties.pools` + `AsyncExecutorFactory`（`AsyncExecutorFactory.java:55-106`），在 `application.yml` 声明独立受管 **`PLATFORM` 平台线程池**（如 `ateng.boot.async.pools.password-hash`，配置 `mode: platform`、合理有界并发数如 `core-pool-size: 4` / `max-pool-size: 6` 或 `Math.max(2, availableProcessors() / 2)`、`queue-capacity: 1000`、`rejected-policy: caller_runs`），并将同进程并发批量导入通过信号量或分布式锁限制并发度（如单节点同时仅允许 `1~2` 个批量导入执行哈希），彻底隔离 Web 流量与 CPU 突发负载。
3. **强制采用“三段式事务解耦流水线”**：
   - **阶段 1（无事务，只读校验，`< 100ms`）**：解析 Excel（校验表头与 JSR-303）→ 批内查重 → 批量 `IN` 查询 DB 校验账号/加密手机/加密邮箱唯一性、部门/岗位/角色合法性与租户套餐配额。存在任一错误立即渲染批注并返回 `ImportResultVO`，**零哈希计算、零写事务**。
   - **阶段 2（无事务，有界 `PLATFORM` 线程池并行哈希）**：通过 `CompletableFuture.supplyAsync(() -> PasswordUtil.hash(initPassword), passwordHashExecutor)` 为每行用户并行生成**各自独立 16 字节随机盐的 PBKDF2 哈希**，统一 `join()` 汇总（不持有任何 DB 连接！）。
   - **阶段 3（极短 `@Transactional(rollbackFor = Exception.class)`，`< 100ms`）**：将已算好哈希的 `SysUser`、`SysUserPost`、`SysUserRole` 集合在短事务内复核租户配额并调用 `BatchUtil.insertBatch(...)` 一次性批量落库；捕获并发写入引发的 `DuplicateKeyException` 转译为 `102002`。
4. **安全底线与低核容器（2C/4C）部署调优矩阵**：
   - **绝对禁止“500 个用户共享同一个预先算好的 PBKDF2 哈希串”**：同一盐值 + 同一哈希不仅违反每账号独立随机盐密码学铁律，拖库即可暴露“500 个用户密码完全相同”，极易诱发连带撞库。
   - **配置化护栏与超时对齐**：
     - 将用户导入单批最大行数抽取为配置项 `ateng.solid.user.import-max-rows`（`>= 8C` 环境默认 `500`；`4C` 容器建议 `200` → 约 `19.7s`；`2C` 容器建议 `100` → 约 `19.8s`）；
     - 前端 `POST /admin/system/user/import` 请求显式覆盖 Axios 超时（`timeout: 120_000`），Nginx 对应路径配置 `proxy_read_timeout 120s`，界面上传期间显示明确提示（`"正在校验与安全加密口令，最多可能需要数十秒，请勿刷新页面"`）；
     - **可选兜底杠杆（仅低核 2C/4C 硬要求同步 500 行 `< 20s` 且未建异步任务队列时评估）**：可预留 `ateng.solid.user.import-hash-iterations`（**默认 `310_000` 不降级**），若运维针对初始临时口令（`pwd_update_time IS NULL`）显式下调至如 `100_000`（3.1 倍提速，4C 约 `15.9s`），须在登录成功路径配合 `PasswordUtil.needsUpgrade(user.getPassword())`（`PasswordUtil.java:130-132`）自动触发 `310_000` 次平滑升级重哈希。

---

## 3. `AtengDataPermissionInnerInterceptor` 与 `DataPermissionHandler` AST 拼接机制

### 3.1 真实接口签名与核心执行链

- **SPI 真实签名**（注意与工单提问中的推测参数顺序不同！）：  
  `ateng-boot-mybatis-plus/src/main/java/io/github/atengk/boot/mybatisplus/permission/DataPermissionHandler.java:15-27`
  ```java
  @FunctionalInterface
  public interface DataPermissionHandler {
      Expression getSqlSegment(Table table, Expression where, String mappedStatementId, DataScope dataScope);
  }
  ```
  - `table`：JSqlParser `5.2` `net.sf.jsqlparser.schema.Table`（含 `getName()` 与 `getAlias()`）
  - `where`：当前 `SELECT`/`UPDATE`/`DELETE` 节点已有的 `WHERE`（或 `JOIN ON`）AST 表达式（可能为 `null`）
  - `mappedStatementId`：MyBatis `MappedStatement.getId()` 字符串（注意是 `String`，不是 `MappedStatement` 对象！）
  - `dataScope`：经 `ConcurrentHashMap` 缓存解析出的 `@DataScope` 注解实例
  - **返回值**：JSqlParser `Expression`；返回 **`null`** 表示**对当前表不追加任何过滤条件（放行全量）**！

- **拦截器完整执行链**（`AtengDataPermissionInnerInterceptor.java:51-156`）：
  1. 构造期将自身 `buildTableExpression` 桥接为 MyBatis-Plus 的 `MultiDataPermissionHandler`（`lines 55-60`），激活父类 `DataPermissionInterceptor` → `BaseMultiTableInnerInterceptor` 的全表 AST 遍历。
  2. `beforeQuery`（拦截 `SELECT`）与 `beforePrepare`（拦截 `UPDATE` / `DELETE`）首先调用 `shouldIgnore(MappedStatement ms)`（`lines 64-79, 123-145`）：
     - 短路顺序：① `DataPermissionContextHolder.isIgnore()` → ② `DataPermissionContextHolder.isSuperAdmin()`（由 `AtengSaTokenInterceptor` 经 `MyBatisPlusDataPermissionBridge` 自动同步） → ③ `ms == null || ms.getId() == null` → ④ `scopeCache` 查询 `@DataScope`（未标注或 `ignore = true` 则直接跳过 SQL AST 解析）。
  3. 注解解析委派 `MybatisInterceptorUtil.resolveMapperAnnotation(mappedStatementId, DataScope.class)`（`MybatisInterceptorUtil.java:148-180`）：
     - 先调用 `normalizeStatementMethodName`（`lines 112-133`）循环剥离尾部 `_mpCount` 与 `$dynamicAdaptive` 后缀；
     - **方法级优先于 Mapper 接口类级**（`lines 165-174`）。
  4. `buildTableExpression(Table table, Expression where, String whereSegment)`（`lines 82-115`）：
     - **表别名匹配规则**（`lines 99-105`）：
       ```java
       String targetAlias = dataScope.alias();
       if (targetAlias != null && !targetAlias.isBlank()) {
           String currentAlias = table.getAlias() != null ? table.getAlias().getName() : table.getName();
           if (!targetAlias.equalsIgnoreCase(currentAlias)) {
               return null;
           }
       }
       ```
       - 当 `alias` 非空时：优先取 `table.getAlias().getName()`，无别名时退回 `table.getName()`，**大小写不敏感匹配**；未命中直接返回 `null`。
       - 当 `alias` 为空串（默认 `""`）时：SQL 中 **FROM / JOIN 出现的每一张物理表都会触发一次 `getSqlSegment`**！因此在多表 JOIN 查询中**必须显式指定 `@DataScope(alias = "u")`**，否则右表/关联表也会被盲目拼接 `dept_id`/`user_id` 导致 `Unknown column` 报错。

### 3.2 致命陷阱 1：已有 `WHERE` 拼接 `AND` 的括号包裹细节（字节码实证）

通过对实际依赖包 `mybatis-plus-jsqlparser:3.5.17` 中 `BaseMultiTableInnerInterceptor#builderExpression` 与 `#andExpression` 的字节码反编译验证（与 `jsqlparser:5.2` 对齐）：

```java
// BaseMultiTableInnerInterceptor.builderExpression(Expression currentExpression, List<Table> tables, String whereSegment)
// 1. 若多表均有返回表达式，逐个用 AndExpression 串联为 append
// 2. 与已有 WHERE (currentExpression) 合并：
if (currentExpression == null) {
    return append;
}
if (currentExpression instanceof OrExpression) {
    // 仅当“已有 WHERE”为 OrExpression 时，给已有 WHERE 套括号！
    return appendExpression(new ParenthesedExpressionList<>(currentExpression), append);
}
// ⚠️ 当 append 本身是裸 OrExpression 时，MyBatis-Plus 不会给 append 套括号！
return appendExpression(currentExpression, append); // 默认 ExpressionAppendMode.LAST -> new AndExpression(currentExpression, append)
```

同时，`AtengDataPermissionInnerInterceptor.java:109` 直接 `return customHandler.getSqlSegment(...)`，**亦未对返回的 `OrExpression` 做自动套括号防卫**！

- **严重后果示例**：若业务 SQL 已有 `WHERE u.deleted = 0 AND u.tenant_id = 1`（顶层是 `AndExpression`），而上层 `DataPermissionHandler` 直接返回未套括号的 `new OrExpression(deptInExpr, selfEqExpr)`，最终拼接出的 SQL 为：
  ```sql
  WHERE u.deleted = 0 AND u.tenant_id = 1 AND u.dept_id IN (100, 101) OR u.id = 2001
  ```
  因 SQL 中 `AND` 优先级高于 `OR`，该语句等价于 `(u.deleted = 0 AND u.tenant_id = 1 AND u.dept_id IN (100, 101)) OR (u.id = 2001)` —— **彻底穿透逻辑删除、多租户隔离与所有列表筛选条件**！
- **正确做法（`jsqlparser 5.2`）**：对照底座样例 `ateng-boot-samples/ateng-boot-sample-mybatis-plus/.../SampleDataPermissionHandler.java:62-64`，只要返回复合 `OrExpression`（或任意复合条件），**必须显式包裹为 `new ParenthesedExpressionList<>(new OrExpression(deptExpr, selfExpr))`**，从而确保输出：
  ```sql
  WHERE u.deleted = 0 AND u.tenant_id = 1 AND (u.dept_id IN (100, 101) OR u.id = 2001)
  ```

### 3.3 致命陷阱 2：拦截器异常 Fail-Open 与 `LEFT JOIN` 位置约束

1. **异常兜底 Fail-Open 风险（`AtengDataPermissionInnerInterceptor.java:108-114`）**：
   ```java
   try {
       return customHandler.getSqlSegment(table, where, whereSegment, dataScope);
   } catch (Exception ex) {
       log.error("数据权限 AST 条件生成异常，安全跳过当前表拦截: ...", ...);
       return null; // ⚠️ Fail-Open：返回 null 等同于跳过全部数据权限过滤！
   }
   ```
   - 上层实现的 `SolidDataPermissionHandler` **必须做到内部异常自闭环**：遇到登录上下文异常、角色权限加载异常或无效数据范围值时，**严禁向上抛出异常让拦截器吞掉回退 `null`**，应明确返回 Fail-Closed 的 `1 = 0` 表达式（或阻断在进入 Mapper 之前）。
2. **`LEFT JOIN` 表绑定约束**：
   - 经对 `BaseMultiTableInnerInterceptor#processJoins` 字节码核验，对于 `LEFT JOIN` 右侧表，拦截器生成的表达式会被拼入 **`ON` 子句**而非 `WHERE` 子句（不会过滤左表行）。因此在 `sys_user u LEFT JOIN sys_dept d ON ...` 查询中，`@DataScope(alias = "u")` **必须绑定在驱动主表 `u` 上**。

### 3.4 `COUNT(*)` 分页派生查询行为

在 `AtengMybatisPlusAutoConfiguration.java:227-262` 中，插件注册顺序严格固定为：
`AtengTenantLineInnerInterceptor` (1) → `AtengDataPermissionInnerInterceptor` (2) → `AtengLogicDeleteInnerInterceptor` (3) → `PaginationInnerInterceptor` (4) → `BlockAttackInnerInterceptor` (5) → `OptimisticLockerInnerInterceptor` (6)。

- **自动分页 `COUNT(*)` 生效机理**：`MybatisPlusInterceptor#intercept` 按注册顺序遍历每个插件的 `willDoQuery` + `beforeQuery`。当执行到第 4 个 `PaginationInnerInterceptor#willDoQuery` 时，`boundSql.getSql()` **已经被前两个插件改写完毕**（同时携带 `tenant_id = ?` 与 `AND (<dataScope>)`）。`PaginationInnerInterceptor#autoCountSql` 直接基于这条已改写 SQL 构造 `SELECT COUNT(*) ...` 并用底层未代理的 `Executor` 执行，因此：
  - 既保证分页 `total` 与 `records` **100% 受同等 `@DataScope` 过滤约束**；
  - 又不会对自动生成的 `COUNT(*)` 语句重复拼接两次条件；
  - 若业务手动使用了 `IPage.setCountId("customCountStatement")` 独立 XML 统计语句，则该 `customCountStatement` 对应的 Mapper 方法**也必须标注相同的 `@DataScope`**（或遵循 `<method>_mpCount` 命名规则以命中 `MybatisInterceptorUtil#normalizeStatementMethodName`）。

### 3.5 多角色并集（`OR`）与空可见集（`1 = 0`）标准 JSqlParser 5.2 写法

在 `ateng-solid` 5 级数据权限体系（`1=ALL`, `2=CUSTOM`, `3=DEPT`, `4=DEPT_AND_CHILD`, `5=SELF`）下，给定当前用户有效角色集合与合并出的可见部门 ID 集合 `visibleDeptIds` 及 `includeSelf` 标志：

```java
// 1. 任意角色为 ALL（或已由拦截器在 super_admin/ignore 短路）：返回 null（不追加条件）
if (hasAllScope) {
    return null;
}

// 2. 确定列前缀（注意：若 SQL 为单表无别名则 table.getAlias() 为 null，切勿盲拼 dataScope.alias()）
String colPrefix = table.getAlias() != null
        ? table.getAlias().getName() + "."
        : "";

Expression deptExpr = null;
if (!visibleDeptIds.isEmpty()) {
    ParenthesedExpressionList<LongValue> idList = new ParenthesedExpressionList<>();
    for (Long deptId : visibleDeptIds) {
        idList.add(new LongValue(deptId));
    }
    InExpression inExpr = new InExpression();
    inExpr.setLeftExpression(new Column(colPrefix + dataScope.deptColumn()));
    inExpr.setRightExpression(idList);
    deptExpr = inExpr;
}

Expression selfExpr = null;
if (includeSelf && currentUserId != null && !dataScope.userColumn().isBlank()) {
    EqualsTo eq = new EqualsTo();
    eq.setLeftExpression(new Column(colPrefix + dataScope.userColumn()));
    // 注意字段类型：sys_user.id / user_id 为 BIGINT 用 LongValue；若 userColumn="create_by" 为 VARCHAR 须用 StringValue
    eq.setRightExpression(new LongValue(currentUserId));
    selfExpr = eq;
}

// 3. 无任何可见部门且无本人权限（如未分配角色、CUSTOM 未绑部门、DEPT 但用户 deptId 为 null）：
//    严禁返回 null（那会变成放行全表！），必须返回 Fail-Closed 恒假条件 1 = 0！
if (deptExpr == null && selfExpr == null) {
    return new EqualsTo(new LongValue(1L), new LongValue(0L));
}

// 4. 多角色并集同时含部门与本人：必须用 ParenthesedExpressionList 包裹 OrExpression 防优先级穿透！
if (deptExpr != null && selfExpr != null) {
    return new ParenthesedExpressionList<>(new OrExpression(deptExpr, selfExpr));
}
return deptExpr != null ? deptExpr : selfExpr;
```

> **列前缀防踩坑提醒**：当注解写了 `@DataScope(alias = "sys_user")` 匹配无别名表 `SELECT * FROM sys_user` 时，`table.getAlias()` 为 `null`，用 `table.getAlias() != null ? table.getAlias().getName() + "." : ""`（或 `table.getName() + "."`）比盲取 `dataScope.alias()` 更稳健；同时 `sys_user` 表中“本人”列是主键 `id`（`@DataScope(alias = "u", deptColumn = "dept_id", userColumn = "id")`），而非不存在的 `user_id` 列！

---

## 4. `LocalStorageSaTokenWhitelistConfiguration` 与 `StorageSecurityUtil`（`#1172`，提交 `0c172a12`）

### 4.1 `LocalStorageProperties` 新增 4 开关与自动装配条件矩阵

源码锚点：`ateng-boot-storage/src/main/java/io/github/atengk/boot/storage/properties/LocalStorageProperties.java:42-62`、`AtengStorageAutoConfiguration.java:47-56, 223-268`、`LocalStorageEndpointCondition.java:21-61`、`LocalStorageSaTokenWhitelistConfiguration.java:32-106`。

| 配置键（`ateng.boot.storage.local.`） | 类型 | 默认值 | 生效前置条件（全部满足方装配对应 Bean） |
| :--- | :---: | :---: | :--- |
| `endpoint-enabled`（总开关） | `boolean` | `true` | `storage.enabled=true` + Servlet Web + `LocalStorageEndpointCondition`（单源默认/为 `local`，或 `sources` 中含任一 `local` 源） |
| **`download-endpoint-enabled`** | `boolean` | **`true`** | 满足总开关 + 本开关为 `true` → 装配 `LocalStorageDownloadController`（`@GetMapping` 默认 `/storage/local/download`） |
| **`upload-endpoint-enabled`** | `boolean` | **`true`** | 满足总开关 + 本开关为 `true` → 装配 `LocalStorageUploadController`（`@PutMapping` 默认 `/storage/local/upload`）；设为 `false` 彻底移除内置 PUT 直传接口 |
| **`whitelist-presigned-download`** | `boolean` | **`false`** | 类路径存在 `SaTokenWhitelistProvider` + 满足总开关 + **`@ConditionalOnBean(LocalStorageDownloadController.class)`** + 本开关为 `true` → 注册 `localStorageDownloadWhitelistProvider` |
| **`whitelist-presigned-upload`** | `boolean` | **`false`** | 类路径存在 `SaTokenWhitelistProvider` + 满足总开关 + **`@ConditionalOnBean(LocalStorageUploadController.class)`** + 本开关为 `true` → 注册 `localStorageUploadWhitelistProvider` |

- **类加载隔离与加载顺序保障**：
  - `ateng-boot-storage/pom.xml` 以 `<optional>true</optional>` 引入 `ateng-boot-satoken`；`LocalStorageSaTokenWhitelistConfiguration` 使用 `@ConditionalOnClass(name = "io.github.atengk.boot.satoken.spi.SaTokenWhitelistProvider")` 字符串隔离，无 `ateng-boot-satoken` 时零 `NoClassDefFoundError`（已由 `AtengStorageAutoConfigurationTest#testWithoutSaTokenClasspathIsolation` 覆盖）。
  - `AtengStorageAutoConfiguration` 新增 `@AutoConfigureBefore(name = "io.github.atengk.boot.satoken.autoconfigure.AtengSaTokenAutoConfiguration")`（`AtengStorageAutoConfiguration.java:48-51`），确保白名单 Provider Bean 先于 `AnonymousUrlProcessor`（`AnonymousUrlProcessor.java:80-94`）汇聚注入 `AtengSaTokenInterceptor`，并与业务自定义 `SaTokenWhitelistProvider` 及 `@Anonymous` 自动叠加去重。

### 4.2 同路径冲突 Fail-Fast 防穿透校验

`LocalStorageSaTokenWhitelistConfiguration#validateSamePathConflict`（`lines 85-105`）：
- 先通过 `StorageSecurityUtil.normalizeEndpointPath(...)`（`StorageSecurityUtil.java:420-436`）将 `download-endpoint` 与 `upload-endpoint` 统一归一化（反斜杠转正斜杠、折叠 `//`、补前导 `/`、剥尾 `/`）。
- 触发条件：**下载与上传两个内置 Controller 同时存在** + **`whitelistPresignedDownload != whitelistPresignedUpload`**（一开一关） + **归一化后路径完全相等**（如 `/storage/local/shared` 与 `/storage/local/shared/`）。
- 触发结果：启动期立即抛出 **`IllegalStateException`** 阻断启动（原因：Sa-Token 白名单仅按 URI Path 匹配而不区分 `GET`/`PUT` HTTP Method，同路径一开一关会导致未放行的写入端点被连带匿名放行）。
- 若已将 `upload-endpoint-enabled: false` 关闭上传端点，则不存在冲突可正常启动。

### 4.3 `StorageSecurityUtil` 新增对称签名载荷与路径工具

新增公共静态方法（`ateng-boot-storage/src/main/java/io/github/atengk/boot/storage/util/StorageSecurityUtil.java`）：
- `buildPresignedUploadSignaturePayload(String cleanPath, long expires, String contentType, long maxBytes[, String source])`（`lines 206-230`）：格式 `cleanPath:expires:ct:maxBytes[:source]`
- `buildPresignedUploadPartSignaturePayload(String cleanPath, long expires, String uploadId, int chunkIndex[, String source])`（`lines 241-264`）：格式 `cleanPath:expires:uploadId:chunkIndex[:source]`
- `normalizeEndpointPath(String endpoint, String defaultEndpoint)`（`lines 420-436`）：统一规范化 Web 端点路径

### 4.4 预签名下载 URL 格式、浏览器 `<img>` / `<el-avatar>` 渲染与过期边界

源码锚点：`LocalDriver.java:677-714, 805-837` 与 `LocalStorageDownloadController.java:115-193`。

1. **生成 URL 精确格式**：
   ```text
   [domain]/storage/local/download?path=<cleanPath>&expires=<unixEpochSec>&signature=<64位小写Hex>[&filename=...][&contentType=...][&disposition=...][&source=...]
   ```
   - **默认有效时长**：当传入 `duration` 为 `null`、`0` 或负数时，默认回退 **`Duration.ofMinutes(15)`**（`LocalDriver.java:805-809`）。
   - **过期响应**：请求时刻 `Instant.now().getEpochSecond() > expires` 返回 **HTTP `403 Forbidden`**（`LocalStorageDownloadController.java:138-142`）；签名不合法或 `secret-key` 启动随机变化亦返回 **`403`**。
   - **`Content-Disposition` 细节**：若未传 `responseContentDisposition`，`LocalStorageDownloadController`（`lines 170-178`）默认输出 `attachment; filename="..."; filename*=UTF-8''...`！对于头像 `<img>` / `<el-avatar>`，虽浏览器内嵌图像按 `Content-Type: image/*` 仍可渲染，但右键“新标签页打开图片”会触发文件下载弹窗；建议签发头像预签名 URL 时显式传 `.responseContentDisposition("inline")`：
     ```java
     PresignedUrl presigned = storageOperations.getPresignedUrl(
             PresignedDownloadRequest.builder()
                     .path(avatarObjectKey)
                     .duration(Duration.ofHours(2)) // 兼顾浏览器会话体验与防盗链时效
                     .responseContentDisposition("inline")
                     .build()
     );
     ```
   - **`domain` 与前后端同源代理注意**：前端 Vite 开发代理或 Nginx 若仅反代 `/api` 或 `/admin`，需确认 `local.domain`（如 `http://localhost:8080` 或留空返回 `/storage/local/download?...` 配合前端反向代理 `/storage`）能被浏览器 `<img>` 直接访问；若 `domain` 留空，生成的是相对路径 `/storage/local/download?...`。
   - **数据库存储铁律**：**`sys_user.avatar` 必须持久化纯净相对对象键**（如 `avatar/0/1001/<uuid>.png`），**绝对禁止**将带 `expires` 的临时预签名 URL 写入数据库！仅在 `/admin/auth/info`、`/admin/auth/profile`、`/admin/system/user/page`、`/admin/system/user/{id}` 与上传响应组装 VO 时动态签发预签名 URL（同时 `ateng.boot.storage.local.secret-key` 必须通过环境变量固定配置，禁止留空随机生成导致重启后在用 URL 全部 403）。

### 4.5 `ateng-solid` 推荐配置与旧头像安全替换/删除接口签名

1. **`ateng-solid` 本地存储安全最小暴露配置**：
   - 因 `ateng-solid` 头像上传走自建带 `@SaCheckLogin` 鉴权的 `POST /admin/auth/profile/avatar`，应**关闭内置 PUT 直传端点**，仅开放白名单只读预签名下载端点：
     ```yaml
     ateng:
       boot:
         storage:
           enabled: true
           type: local
           local:
             base-path: ${ATENG_STORAGE_LOCAL_PATH:./data/storage}
             domain: ${ATENG_STORAGE_LOCAL_DOMAIN:}
             secret-key: ${ATENG_STORAGE_LOCAL_SECRET_KEY:CHANGE_ME_32_CHARS_MIN}
             download-endpoint-enabled: true
             upload-endpoint-enabled: false        # 关闭内置 PUT 直传，统一走业务受控接口
             whitelist-presigned-download: true    # 仅放行带 HMAC 验签的 GET 下载端点，适配 <img>/<el-avatar>
             whitelist-presigned-upload: false
           guard:
             enabled: true
             strict-magic-check: true
             allowed-extensions: [jpg, jpeg, png, webp]
             max-file-size: 2MB
     ```
2. **旧头像删除与防孤儿/防误删事务原子替换签名**（`StorageOperations.java:183, 209, 328, 343` & `StorageTemplate.java:275-301, 473-526`）：
   - `StorageObject uploadWithRollbackDelete(MultipartFile file, String path)`：上传新头像并自动向 Spring 事务注册回滚钩子（`TransactionUtil.executeAfterRollback`）——若后续 DB `updateById` 抛异常回滚，自动物理删除刚上传的新头像，零孤儿文件。
   - `void deleteAfterCommit(String path)`：在当前 Spring 事务**成功提交后**延迟物理删除旧头像（无活动事务时平滑降级立即删除），且异常被 `executeSafelyInTx` 隔离记录 `ERROR` 不影响主事务返回——若 DB 回滚，旧头像完好无损！
   - `boolean delete(String path)`：天然幂等（路径为空或文件本不存在均返回 `true`）。
   - **标准头像更换事务编排**（`POST /admin/auth/profile/avatar`）：
     1. 前置校验扩展名/体积/魔数；
     2. 读取用户原 `oldAvatarKey = user.getAvatar()`；
     3. 在 `@Transactional` 内调用 `storageOperations.uploadWithRollbackDelete(file, newKey)` 写入新头像；
     4. 更新 `sys_user.avatar = newKey`；
     5. 若 `oldAvatarKey` 非空且不等于 `newKey` 且不以外链 `http(s)://` 开头，调用 `storageOperations.deleteAfterCommit(oldAvatarKey)`；
     6. 动态签发新头像预签名 URL 返回前端。

---

## 5. `ExcelUtil.readWithResult`（`#1171`，提交 `8e7bef82`）与 `ExcelFeedbackUtil` 流复用边界

### 5.1 `maxSyncRows` 触发时机、异常码/消息与单次覆写盲区

源码锚点：`ateng-boot-excel/src/main/java/io/github/atengk/boot/excel/listener/BatchValidationListener.java:197-240`、`ExcelUtil.java:165-171, 1239-1341`、`ExcelValidationTest.java:209-345`。

1. **精确触发时机（前置流式 Fail-Fast）**：
   - 在 `BatchValidationListener#invoke(T data, AnalysisContext context)` 最顶部执行（`lines 231-240`）：
     ```java
     if (circuitBroken || data == null) {
         return;
     }
     totalReadRows++;
     if (dataConsumer == null && maxSyncRows > 0 && totalReadRows > maxSyncRows) {
         throw new BusinessException(CommonResultCode.BAD_REQUEST.getCode(),
                 "Excel 数据行数超出同步读取安全上限（" + maxSyncRows + " 行），当前已读取 " + totalReadRows
                 + " 行，请改用 readBatchWithValidation 进行分批流式消费以防内存溢出");
     }
     ```
   - **关键行为特征**：
     - **计数口径**：统计**所有非空数据行（合法行 + 非法行之和）**，在 JSR-303 校验之前即判定；
     - **精确边界**：恰好等于 `maxSyncRows`（如 `500` 行）允许完整通过；解析到第 `maxSyncRows + 1` 行（第 `501` 行）时**立刻中止解析**，不会读完整表也不会触发 `ExcelValidationException`；
     - **流式豁免**：仅在同步聚合模式（`dataConsumer == null`）生效，`readBatchWithValidation` 传入流式消费者时不受限；
     - **关闭修复**：`#1171` 同步修复了 `ExcelUtil.initProperties`（`line 170`），配置 `ateng.boot.excel.max-sync-rows <= 0` 时可真正关闭全局限制。
2. **精确抛出异常与 HTTP/Result 映射**：
   - 抛出 **`BusinessException`**（非 `ExcelValidationException`），`code = CommonResultCode.BAD_REQUEST.getCode()`（**`400`**），消息固定前缀 `"Excel 数据行数超出同步读取安全上限（{maxSyncRows} 行），当前已读取 {totalReadRows} 行，..."`。
   - **注意错误码对齐**：若 `ateng-solid` 导入接口要求超限返回业务错误码 **`100005`**（`docs/specs/prd/02-org-and-rbac.md` §7.2 / §8.2），导入 Service 需在 `catch (BusinessException ex)` 中识别超限（或捕获 `ExcelHeaderValidationException`）并转译为 `CommonResultCode / SolidResultCode(100005, ...)`！
3. **关键边界发现 —— `ExcelUtil.readWithResult` 无单次调用级 `maxSyncRows` 参数**：
   - `ExcelUtil.java:1239-1341` 的全部 6 个 `readWithResult` 重载均只读取全局静态 `ExcelUtil.maxSyncRows`（默认 `100_000`）。
   - 虽然 `ExcelReaderBuilder#maxRows(int)` 支持单次覆盖上限，但源码核实其内部 `ValidatedAggregatedListener#recordValidatedResult`（`ExcelReaderBuilder.java:1070-1072`）仅把 `delegate.getValidDataList()` 存入 `ExcelMultiSheetResult`，**未透出 `BatchValidationListener#getValidRowRecords()`（`List<ExcelRowData<T>>` 1-based 物理行号视图）**！
   - **对 `ateng-solid` 的工程方案**：
     - **方案 1（第一阶段最简）**：第一阶段仅用户导入使用同步聚合模式，直接配置 `ateng.boot.excel.max-sync-rows: 500` + 消费 `ExcelUtil.readWithResult(...)`；
     - **方案 2（若未来并存不同行数上限的同步导入）**：在 `ateng-boot` 为 `ExcelUtil.readWithResult` 补充带 `int maxSyncRows` 的重载（见 §6 `C3`），或对特定接口直接构造 `BatchValidationListener` 9 参构造器配合 `FesodSheet.read` + `ExcelUtil.registerEnumConverters`（同时保留 `getValidRowRecords()` 与 `toResult()`）。

### 5.2 `ExcelUtil.readWithResult` 与 `ExcelFeedbackUtil` 流复用最佳实践与内存估算

1. **双端流消费源码实证**：
   - `ExcelUtil.readWithResult`（`ExcelUtil.java:1335-1340, 2476-2489`）：
     1. 调用 `ExcelSecurityUtil.decryptIfEncrypted(inputStream, password, ...)`：若入参 `InputStream` 不支持 `mark()/reset()`，先包装 `new BufferedInputStream(in)` 执行 `FileMagic.valueOf(markable)` 嗅探是否加密；
     2. 调用 `FesodSheet.read(effectiveStream, clazz, listener).sheet().doRead()`：消费完整字节流且 Fesod 默认 `autoCloseStream = true` 会自动关闭流。
   - `ExcelFeedbackUtil.renderErrorFeedback(InputStream originalExcelStream, OutputStream outputStream, List<ExcelErrorRow> errorRows)`（`ExcelFeedbackUtil.java:36-108`）：
     - 调用 `WorkbookFactory.create(originalExcelStream)`，必须从**字节偏移 `0`** 读取完整 `.xlsx` ZIP 包并构建 Apache POI `XSSFWorkbook` DOM 树，仅修改 `sheetAt(0)` 标红并挂载批注后 `workbook.write(outputStream)`，在 `try-with-resources` 退出时关闭 `Workbook` 及底层流。
   - **结论**：绝不能将同一个 `MultipartFile.getInputStream()` 实例先后传给 `readWithResult` 与 `renderErrorFeedback`（第二次读取必报 EOF / `EmptyFileException` / `Stream closed`）。

2. **`MultipartFile` 流复用分层最佳实践**：

| 导入文件体积门槛 | 推荐复用模式 | 关键优势与资源释放要求 |
| :--- | :--- | :--- |
| **`<= 2MB`（`ateng-solid` 用户导入固定约束）** | **单次 `byte[] fileBytes = file.getBytes()` 内存缓冲** | ① 体积确定有界（`<= 2MB`）；② 每次用 `new ByteArrayInputStream(fileBytes)` 独立馈送给 `readWithResult` 与 `renderErrorFeedback`；③ `ByteArrayInputStream.markSupported() == true`，可免除 `ExcelSecurityUtil` 额外分配 `BufferedInputStream`；④ 校验全通过时根本不调用 `renderErrorFeedback`，零多余复制与零磁盘 I/O |
| **`> 2MB`（未来大表/多 Sheet 扩展场景）** | **受管临时文件 `Path tmp = ExcelUtil.createTempFile("solid-imp-", ".xlsx")`** | 通过 `file.transferTo(tmp)` 落盘一次，两次分别 `Files.newInputStream(tmp)` 读取，在 `finally` 中确定性执行 `Files.deleteIfExists(tmp)`，避免大文件常驻堆内存 |

3. **500 行 × 9 列用户导入精确内存预算估算**：
   - **原始 `.xlsx` 压缩体积**：500 行 × 9 列纯文本含样式约 **`30 KB ~ 100 KB`**（受上传硬上限 `<= 2 MB` 兜底）。
   - **阶段 1（`readWithResult` 同步解析）**：
     - `byte[] fileBytes`：`<= 2 MB`（典型 `~60 KB`）；
     - Fesod SAX 流式解析器驻留缓冲：`~1~2 MB`；
     - `ExcelReadResult<UserImportDTO>`（500 个 DTO 对象 + 500 个 `ExcelRowData` + 最多 500 行错误）：`< 1 MB`。
   - **阶段 2（校验失败时 `ExcelFeedbackUtil.renderErrorFeedback` 瞬态堆峰值）**：
     - Apache POI `XSSFWorkbook` 属全量 DOM 解析，XML 解压比约 `5~10×`，Java 对象树膨胀约 `15~25×` 压缩包体积：
       - 典型 500 行文件（`60 KB`）：瞬态 XSSF DOM 约 **`1.5 ~ 3 MB`**；
       - 极端恶意/富样式满载 `2 MB` 文件：瞬态 XSSF DOM 峰值约 **`30 ~ 50 MB`**（在 `try (Workbook wb = ...)` 结束后立即释放可 GC）；
       - 生成的标红批注 `.xlsx` 输出字节流（`ByteArrayOutputStream`）：约 **`50 KB ~ 2.2 MB`**。
   - **阶段 3（批注反馈缓存 15 分钟 TTL 容量护栏）**：
     - 按 `docs/specs/prd/02-org-and-rbac.md` §7.2，错误批注文件缓存 15 分钟并绑定 `{ tenantId, operatorUserId }`：
     - 若存 Redis，单条最大 ~2.2 MB（建议校验 `feedbackBytes.length <= 4MB` 并复用 `ByteArrayOutputStream` 输出，或在有共享对象存储/本地受管目录时将大体积反馈文件落入 `StorageOperations` 短效前缀 + 缓存仅存对象键，防止高频错误导入打满 Redis 带宽与内存；单机/常规并发下 100 次并发失败导入存 Redis 典型约 `100 × 100 KB ≈ 10 MB`，极端满载需对单用户/租户限流）。

---

## 6. 新识别的 `ateng-boot` 底座增强候选与 `ateng-solid` 文档修正清单

### 6.1 新识别的 `ateng-boot` 底座候选增强（对照 `.agents/rules/foundation-first-gate.md`）

本次源码深挖共识别 **3 项**可提炼为通用、零项目绑定的底座增强候选（**均可通过上层规范写法避免阻断首期，但其中 `C1`/`C2` 属核心安全防卫缺陷，建议尽快立项回馈 `ateng-boot`**）：

| 编号 | 归属模块与源码锚点 | 问题描述与风险定级 | 通用向后兼容改造建议 | 对 `ateng-solid` 影响 |
| :---: | :--- | :--- | :--- | :--- |
| **`C1`** | `ateng-boot-mybatis-plus`<br>`AtengDataPermissionInnerInterceptor.java:108-114` | **【高 · 安全防卫】** `buildTableExpression` 捕获 `DataPermissionHandler#getSqlSegment` 任意 `Exception` 后仅记日志并 **`return null`（Fail-Open，静默放行全表数据）** | 新增可配置失败策略 `ateng.boot.mybatis-plus.data-permission.fail-open`（建议默认 `false` 改为 Fail-Closed 返回 `1 = 0` 或向上抛出安全异常，保留旧开关兼容） | 上层 `SolidDataPermissionHandler` 须确保自身永不抛未受检异常，异常态主动返回 `1 = 0` |
| **`C2`** | `ateng-boot-mybatis-plus`<br>`AtengDataPermissionInnerInterceptor.java:109` | **【高 · 安全防卫】** 透传 `DataPermissionHandler` 返回的裸 `OrExpression` 给 MyBatis-Plus `BaseMultiTableInnerInterceptor`，后者不对返回表达式加括号，导致 `AND/OR` 优先级穿透多租户与软删条件 | 在 `AtengDataPermissionInnerInterceptor#buildTableExpression` 返回前判断 `if (expr instanceof OrExpression)` 自动包裹 `new ParenthesedExpressionList<>(expr)`（100% 向后兼容、零破坏性） | 上层 `SolidDataPermissionHandler` 必须主动用 `ParenthesedExpressionList` 包裹多角色 `OR` |
| **`C3`** | `ateng-boot-excel`<br>`ExcelUtil.java:1239-1341`<br>`ExcelReaderBuilder.java:1070-1072` | **【中 · 扩展性】** `#1171` 后 `ExcelUtil.readWithResult` 仅读全局静态 `maxSyncRows`，缺少按单次调用覆写上限的重载；而 `ExcelReaderBuilder#maxRows` 虽支持单次覆写，但丢弃了 `validRowRecords`（`ExcelRowData<T>`） | 为 `ExcelUtil.readWithResult` 补充带 `int maxSyncRows` 参数的重载，并在 `ExcelMultiSheetResult` 同步保留 `rowRecords` 视图 | 第一阶段可先通过全局 `ateng.boot.excel.max-sync-rows: 500` 或显式 `BatchValidationListener` 9 参构造平稳落地 |

> **附：微观察（不建议立单）**：`LocalDriver.java:694` 拼装预签名下载 URL 时 `?path=` 未做 `URLEncoder.encode`，对纯 ASCII 对象键（如 `avatar/{tenantId}/{userId}/{uuid}.{ext}`）无影响；仅当未来对象键包含中文/空格/`#`/`&` 时需底座统一编码。

### 6.2 待回写 `ateng-solid` PRD / Spec 的具体工程纠偏项

1. **`docs/specs/prd/02-org-and-rbac.md` §7.2（用户导入事务与并发）**：将“在同一事务内为每位用户调用 `PasswordUtil.hash` 并批量落库”修正为**三段式事务解耦流水线**（无事务校验 → 独立有界 `PLATFORM` 线程池并行生成 500 独立盐哈希 → `< 100ms` 短事务 `BatchUtil.insertBatch` 落库），并补充 `ateng.solid.user.import-max-rows` 与前端 `120s` 超时配置。
2. **`docs/specs/prd/02-org-and-rbac.md` §6.1 & `database-and-flyway-spec.md` §2.2（`sys_user.phone`/`email` 加密检索与列宽）**：明确采用 `@FieldEncrypt(deterministic = true)` + `DeterministicEncryptTypeHandler` + `autoResultMap = true`；DDL 列宽放大至 `phone VARCHAR(128)`、`email VARCHAR(255)`；明确列表 `phone` 搜索为**精确匹配**、空串归一化 `null`、邮箱统一小写归一化；严禁在种子 SQL 写入明文手机/邮箱。
3. **`ateng-solid-server/docs/specs/auth-rbac-and-datascope-spec.md` §3.2（`@DataScope` 实现规范）**：补充 `DataPermissionHandler` 四参真实签名、`ParenthesedExpressionList` 强制套括号、空可见集返回 `1 = 0`（严禁返回 `null`）、`LEFT JOIN` 必须绑驱动主表别名及 `sys_user` 本人列为 `id`（非 `user_id`）。
4. **`docs/specs/prd/01-auth-and-workspace.md` §4.1（头像存储与 `#1172` 配置）**：明确 `sys_user.avatar` 仅存相对对象键、VO 组装动态签发 `responseContentDisposition("inline")` 预签名 URL、固定 `local.secret-key`、关闭 `upload-endpoint-enabled` + 开启 `whitelist-presigned-download`，以及 `uploadWithRollbackDelete` + `deleteAfterCommit` 原子替换模式。
5. **`ateng-solid-server/docs/specs/configuration-and-archunit-spec.md` §2**：新增 `ateng.boot.mybatis-plus.crypto.secret-key`、`ateng.boot.async.pools.password-hash`（`mode: platform`）、`ateng.boot.excel.max-sync-rows: 500` 及 `ateng.boot.storage.local.*` `#1172` 细粒度白名单配置基线。
