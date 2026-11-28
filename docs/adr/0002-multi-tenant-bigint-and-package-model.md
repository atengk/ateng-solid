# ADR-0002: 行级多租户 `tenant_id BIGINT` 与租户套餐边界模型

- **状态**：`Accepted`
- **日期**：2026-11-18
- **作者**：Ateng
- **影响范围**：全库 DDL 规范、`ateng-solid-server`、`ateng-solid-admin-web`、`contracts.md`

---

## 1. 背景与源码核查发现

在梳理 `ateng-boot:1.2.0` 底层 `ateng-boot-mybatis-plus` 源码时发现：
1. `DefaultTenantLineHandler.getTenantId()` 对上下文中的租户字符串做自适应解析：**若字符串全为 ASCII 数字（如 `"000000"`），会转换为 `LongValue(0)`** 生成 SQL 条件 `WHERE tenant_id = 0`；
2. 若数据库业务表继续沿用传统字符串列 `tenant_id VARCHAR(32) DEFAULT '000000'`，在 MySQL 下执行 `tenant_id = 0` 会触发**列级隐式类型转换**，导致 B+Tree 索引彻底失效并引发跨字符串数值误匹配隐患（例如 `"000000"` 与 `"0"` 语义混淆）；而选用 `BIGINT` 亦使多租户复合索引（`(tenant_id, ...)`）体积显著小于 `VARCHAR(32)` 并与 64 位雪花主键保持对称；
3. `DefaultMetaObjectHandler.fillTenantIdIfNull()` 原生支持向实体的 `Long tenantId` 属性自动填充解析后的长整型租户 ID；但原 `TenantEntity` 接口写死 `String getTenantId()` 导致 `Long` 实体无法接入 `BatchUtil.autoHeal`，已通过 [`atengk/ateng-boot#1134`](https://github.com/atengk/ateng-boot/issues/1134) 将其重构为泛型能力接口 `TenantAware<T extends Serializable>` 彻底打通 `Long` 实体自愈。

---

## 2. 核心决策

1. **数据库主键与请求头对齐策略**：
   - 全库受租户隔离的业务/组织/配置表 `tenant_id` 统一定义为 **`BIGINT NOT NULL DEFAULT 0`**；
   - 平台内置默认租户主键固定为 **`0`**，新建租户主键采用 64 位雪花 `BIGINT`；
   - 传统编码 **`000000`** 收敛为平台默认租户的业务编码字段 `sys_tenant.tenant_code`；
   - 对外 JSON 响应与请求头 `X-Tenant-Id` 遵循雪花大数防失真规范统一传输字符串（默认租户传 `"0"`）。
2. **租户套餐模型（`sys_tenant_package`）首期纳入**：
   - 首期即建立 `sys_tenant_package` 租户套餐与菜单绑定关系表，新建/编辑租户时收敛该租户可见菜单能力上限，避免二期再拆权限模型引起结构返工。
3. **免过滤共享表白名单（`ignore-tables`）**：
   - 平台级元数据表列入行级拦截白名单：`sys_tenant`、`sys_tenant_package`、`sys_menu`、`sys_dict_type`、`sys_dict_data`、`flyway_schema_history`。
   - 首期数据字典设为平台全局共享，保证新建租户开箱即用。
4. **超管动态切换租户安全边界**：
   - 仅当登录态属于平台租户（`tenant_id = 0`）且持有 `super_admin` 身份时，后端才允许采信请求头 `X-Tenant-Id` 临时切换数据视角；其余普通租户请求强制锁定会话内归属租户并忽略客户端伪造头。
5. **租户软删除逻辑隔离归档边界与跨租户引用过滤不变量（2026-11-27 增量明确，关联 `#49` / `#69`）**：
   - **仅软删主表逻辑归档**：删除租户仅对 `sys_tenant` 主表执行逻辑删除，不在 HTTP 请求事务内级联软删业务子表或物理删除关联表（保障 `O(1)` 耗时无大租户长事务锁表、与 `ADR-0005` 扩展业务表 `biz_*` 边界一致、保留操作/登录审计溯源及 DBA 秒级误删可恢复性，且事务提交后游标强退在线会话依赖未软删的 `sys_user` 记录）；
   - **跨租户引用校验强不变量**：任何在 `TenantContextHolder.runWithoutTenant` 下跨租户统计或校验子表引用的查询（如平台删除菜单前统计角色引用 `SysRoleMenuMapper#countActiveRoleReferencesByMenuId`），**必须显式关联 `sys_tenant` 并过滤 `deleted = 0`**，避免已逻辑删除租户的归档子记录阻塞平台治理操作。

---

## 3. 后果与权衡

- **优点**：100% 原生复用 `ateng-boot-mybatis-plus` `DefaultTenantLineHandler` 与 `DefaultMetaObjectHandler` 且保证 B+Tree 索引命中；前端无需额外维护两套类型。
- **代价**：登录界面若按租户编码（如 `000000`）登录，需先将 `tenantCode` 解析映射为 `tenantId`（`"0"`）再执行租户上下文绑定与会话签发。
