# ADR-0006: 首期最小技术栈裁剪与后端对象映射策略 (`BeanUtil` vs `MapStruct`)

- **状态**：`Accepted`
- **日期**：2026-11-20
- **作者**：Ateng
- **影响范围**：`ateng-solid-server`、`ateng-solid-admin-web`、[`.agents/rules/coding-and-architecture.md`](../../.agents/rules/coding-and-architecture.md)

---

## 1. 背景与决策问题

在首期 MVP 准备落盘代码前，工程依赖面临两项典型过度设计诱惑：
1. **过早预装可观测/监控与重型扩展包**：虽配置开关默认关闭，但提前将 `ateng-boot-observability`、`@atengk/monitor` 等非首期核心业务模块写入构建依赖，会拉高首期依赖体积、CI 编译成本与心智噪音；
2. **后端模型转换方案选型**：随着 `Entity`、`DTO`、`VO` 强制隔离（Controller 零 Entity 泄漏），`ateng-solid-server` 需要在以下三类对象映射方案中做出清晰取舍：
   - **方案 1**：`ateng-boot-core` 内置 `BeanUtil`（封装 Spring `BeanUtils`）+ 显式静态工厂转换；
   - **方案 2**：`MapStruct`（编译期 APT 生成零反射强类型 Mapper）；
   - **方案 3**：`MapStruct-Plus`（基于 `MapStruct` 自动生成通用 `Converter`，免写大量 `Mapper` 接口，支持与 Spring/MyBatis-Plus 联动）。

---

## 2. 核心决策

### 2.1 首期最小核心技术栈裁剪（砍除辅助增强包）
- **后端首期核心保留**（7+1 模块）：`ateng-boot-{core,web,mybatis-plus,redis,satoken,excel,storage,flyway}`；外部堆栈严格限定 `Java 21` + `Spring Boot 3.3.13` + `MySQL 8.x` + `Lombok` + `jakarta.validation`（测试期 `H2` + `Spring Boot Test` + `ArchUnit`）。**首期移除 `ateng-boot-observability`**，留待二期按运维诉求按需引入。
- **前端首期核心保留**（3 个包）：`@atengk/core`、`@atengk/vue`、`@atengk/element-plus`；外部堆栈严格限定 `Node 22+` + `pnpm 11+` + `Vue 3.5` + `Vue Router` + `Pinia` + `TypeScript 5.6 Strict` + `Vite 6` + `Element Plus` + `@element-plus/icons-vue` + `TailwindCSS v4（禁 Preflight）` + `Sass`。**首期移除 `@atengk/monitor`**（同步清理 `.env.example` 中的监控配置项），与 L2 重型图表/流程/富文本包一同留待后续扩展按需接入。

### 2.2 对象映射方案评估与首期结论

| 对比维度 | 方案 1：`ateng-boot-core` `BeanUtil` + 显式静态工厂（**首期采用**） | 方案 2：`MapStruct` | 方案 3：`MapStruct-Plus` |
| :--- | :--- | :--- | :--- |
| **依赖与构建复杂度** | **零新增依赖**（`ateng-boot-core` 已内置 `BeanUtil.copy/copyList/copyIgnoreNull`），无 APT 处理器 | 需引入 `mapstruct` + `mapstruct-processor` 与 `lombok-mapstruct-binding`，Maven 编译需严格对齐处理器顺序 | 在方案 2 基础上额外引入 `mapstruct-plus-spring-boot-starter`，侵入全局自动配置与类型扫描 |
| **编译期字段校验** | 弱（运行期同名属性浅拷贝，易受敏感字段误覆盖风险） | **强**（编译期报错漏映射与类型不匹配） | 中强（自动推导 `@AutoMapper`，复杂字段仍需配置） |
| **运行期性能** | 反射属性拷贝（对百万级吞吐非瓶颈，常规管理后台微秒级可忽略） | **极高**（纯方法直接调用，零反射） | **极高**（编译期生成，兼顾免手写接口便利性） |
| **适用阶段** | **首期内核阶段（CRUD 为主、模型结构精简、追求零额外框架）** | 复杂领域聚合、嵌套多层级 DTO/VO 频繁转换 | **二期/规模化业务扩张期**（上百张业务表且希望兼得编译期性能与低样板代码） |

- **首期明确决策**：
  1. 首期统一使用 `ateng-boot-core` **`BeanUtil`** 配合**显式静态工厂/转换方法**（如 `UserVO.from(entity)` 或独立组装器），**不引入 `MapStruct` 或 `MapStruct-Plus`**；
  2. 为弥补浅拷贝的安全性短板，强制执行**受管敏感字段禁无过滤覆盖红线**：在更新接口中禁止直接 `BeanUtil.copy(dto, entity)` 覆盖 `id`、`tenantId`、`password`、`version`、`deleted`、`createBy`/`createTime` 等受管字段，敏感赋值或状态流转必须走显式受控方法。
  3. **二期升级触发条件**：当未来 `biz-*` 行业扩展模块引入大量深层嵌套转换、大批量数据导出高频转换，或团队需要编译期字段级强契约检查时，优先评估在 `ateng-boot` 底座或上层统一以 **MapStruct-Plus**（避免为每张表手写冗余 `Mapper` 接口）或 **MapStruct** 渐进替代热点转换，替换期不影响任何 `Controller`/`*-api` 对外签名。

---

## 3. 后果与权衡

- **优点**：首期依赖树高度克制，零额外注解处理器编译冲突（Lombok + APT 在 IDE 与 Maven 下的常见坑），管理台核心表字段直观易排查。
- **代价**：`BeanUtil` 无法在编译期捕捉 DTO 与 Entity 重命名导致的漏映射，需通过单元测试（如集成测断言 VO 全字段回显）和显式 `from()` 静态转换弥补。
