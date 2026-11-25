# 第一阶段 SaaS 多租户与租户套餐管理 PRD (`03-tenant-and-package.md`)

- **所属阶段**：第一阶段（MVP 最小稳定内核 · `tenantEnabled = true` 激活域）
- **关联工单**：[确定 SaaS 多租户与租户套餐管理域 PRD 与原型](https://github.com/atengk/ateng-solid/issues/7)（路线图：[第一阶段（MVP 内核）需求文档（PRD）与高保真交互原型路线图](https://github.com/ateng/ateng-solid/issues/1)）
- **前置真源**：
  - [设计系统规范](./design-system.md) | [第一阶段总览与全站交互规范](./00-overview-and-ux-standards.md) | [组织架构与 RBAC PRD](./02-org-and-rbac.md)
  - [ADR-0002 行级多租户模型](../../adr/0002-multi-tenant-bigint-and-package-model.md) | [ADR-0003 多租户开关与隔离边界](../../adr/0003-tenant-toggle-auth-boundary-and-seed-strategy.md)
  - [跨端通信协议与数据契约](../../agents/contracts.md) | [Boot 1.2.0 调研](./_research/boot-1.2.0-constraints.md)
- **交互参考原型**：[多租户与租户套餐交互原型 (`tenant-and-package.html`)](../../prototypes/phase1/tenant-and-package.html) | [定稿方案 A 基础壳 (`shell-accepted.html`)](../../prototypes/phase1/shell-accepted.html)

---

## 1. 域范围、双态开关边界与 Specs 增量对齐

### 1.1 纳入模块与严格激活门禁
| 菜单路径 | 路由名称 | 组件路径 (`src/views/`) | 核心权限码 | 激活条件 |
| :--- | :--- | :--- | :--- | :--- |
| `/system/tenant-package` | `SysTenantPackage` | `system/tenant-package/index.vue` | `system:tenant-package:{list,create,update,delete}` | **`tenantEnabled === true` 且当前归属/生效租户为 `"0"`（`platform_only = 1`）** |
| `/system/tenant` | `SysTenant` | `system/tenant/index.vue` | `system:tenant:{list,create,update,delete}` | **`tenantEnabled === true` 且当前归属/生效租户为 `"0"`（`platform_only = 1`）** |

> **关闭态防穿透铁律**：当 `ateng.solid.tenant.enabled = false`（默认关闭）时，前端菜单隐藏上述两模块，后端 `SysTenantController` 与 `SysTenantPackageController` 对上述路径统一硬拒绝（`403` / `102xxx: "当前系统未开启多租户模式"`）；开启多租户后若平台超管切至非 `"0"` 工作租户，前后端同样隐藏并拒绝访问两模块。

### 1.2 对既有 Specs 的增量修正备忘（将于工单 `#10` 统一同步子仓文档）
1. **`sys_tenant_package` 增补 `menu_check_strictly TINYINT NOT NULL DEFAULT 1` 与 `remark VARCHAR(500) NULL`**：对齐 `sys_role` 菜单树父子联动与叶子回显防误全选契约。
2. **`sys_tenant` 增补 `remark VARCHAR(500) NULL`**：保持极简表结构，不引入重型商业/税务字段。
3. **补充接口端点**：
   - `GET /admin/system/tenant/options`：供平台超管顶栏租户切换器消费（仅返回 `status = 0` 且未过期的活跃租户）；
   - `GET /admin/system/tenant-package/{id}`、`PUT /admin/system/tenant-package/{id}/status`、`POST /admin/system/tenant-package/shrink-preview`（缩减菜单影响租户数与受影响角色权限预览）；
   - `POST /admin/system/tenant` 返回 `CreateTenantVO`（含初始化完成的 `tenantId`、`tenantCode`、`tenantName`、`adminUsername`），驱动前端初始化凭据指引回显弹窗。

### 1.3 `ateng-boot:1.2.0` 底层机制对接
- **长整型零隐式转换**：`DefaultTenantLineHandler` 将纯数字 `tenantId` 字符串转为 `LongValue`，与所有租户表 `tenant_id BIGINT NOT NULL DEFAULT 0` 对齐；跨租户维护操作（套餐裁剪角色菜单、新建租户初始化）分别使用 `TenantContextHolder.runWithoutTenant(...)` 与 `TenantContextHolder.runWithTenant(newTenantId, ...)` 显式定界并在退出块内自动恢复原上下文。
- **切租户 SPI（`TenantHeaderSwitchValidator`）**：在 `ateng-solid-bootstrap` / `ateng-solid-system` 注册自定义 Bean，当 `anonymous = false` 时校验 `currentTenantId == "0"`、会话含 `super_admin` 且目标租户 `targetTenantId` 存在且未软删、正常可用；否则抛 `403`。

---

## 2. 租户套餐管理（`/system/tenant-package`）

### 2.1 列表、检索与停用/删除保护
- **检索区（`AtengQueryForm`）**：`packageName`（套餐名称）、`status`（状态：`正常`/`停用`）。
- **表格列**：多选框、`套餐名称`、`包含菜单数`（`tabular-nums`）、`绑定租户数`（`tabular-nums`）、`状态`（Switch 确认切换）、`备注`、`创建时间`、固定右侧操作列（`编辑`、`删除`）。
- **停用与删除约束**：
  - **停用套餐（`PUT /admin/system/tenant-package/{id}/status`）**：不影响已绑定该套餐的存量租户继续运行，仅在后续**新建租户**或**变更租户套餐**时禁止新选已停用套餐（编辑已绑定该停用套餐的老租户时回显标注 `(已停用)`）；
  - **删除套餐（`DELETE /admin/system/tenant-package/{ids}`）**：任一待删套餐仍被未软删租户（`sys_tenant.package_id = id AND deleted = 0`）引用时，整批拦截抛 `SystemResultCode(102005, "套餐【{packageName}】已被 {count} 个租户绑定，请先变更租户套餐后再删除")`。

### 2.2 新增 / 编辑抽屉（`AtengDrawer` `520px`/`720px`）与平台菜单严格排除
- **表单字段**：
  1. `packageName`（套餐名称）：必填 `2~50` 字符，全局未删除唯一（冲突抛 `102002`）；
  2. `status`（状态）：`0-正常` / `1-停用`；
  3. `menuIds`（套餐包含菜单树）：
     - **平台专属排除铁律**：菜单树数据源严格过滤剔除 **`sys_menu.platform_only === 1`** 的全部目录/菜单/按钮（即租户管理、租户套餐、菜单管理、数据字典不可在树中出现）；后端保存接口二次校验传入的 `menuIds` 绝不允许含任何 `platform_only = 1` 或已停用节点（否则抛 `102006: "禁止将平台专属菜单分配给租户套餐"`）；
     - 树交互支持 `[展开 / 折叠]`、`[全选 / 全不选]` 与 `[父子联动]`（`menuCheckStrictly`，默认 `true`），采用与 `02-org-and-rbac.md` 一致的“联动态提交 `checked + halfChecked`、编辑仅勾选叶子回显”防误全选协议；
  4. `remark`（备注）：选填 `<= 500` 字符。

### 2.3 缩减套餐菜单与联动裁剪 `sys_role_menu` 确认流（重要交互）
当管理员编辑已有套餐并点击 `[保存套餐]` 时：
1. 前端调用前置接口（`POST /admin/system/tenant-package/shrink-preview`）对比新旧 `menuIds` 是否存在**被移除的菜单 ID**：
   - 若**无菜单移除**，或该套餐当前**绑定租户数为 `0`**：直接保存并提示 `"已保存租户套餐"`；
   - 若**移除了 `>= 1` 项菜单且绑定租户数 `> 0`**：**弹出二次确认预警弹窗（`AtengDialog` `520px`）**，明确列出：
     - 本次被移除的菜单名称清单（超出 6 项折叠摘要计数）；
     - 当前受影响的关联租户数量与租户名称列表（如：`星辰智能科技`、`云港物流集团`）；
     - 明确影响说明：`"保存后将在事务内同步裁剪上述租户下全部角色的越界菜单权限（sys_role_menu），并立即刷新相关租户权限缓存，确认继续保存？"`；
     - 按钮文案：`[取消]` / `[确认缩减并裁剪权限]`。
2. **后端原子裁剪事务（`PUT /admin/system/tenant-package`）**：
   - 更新 `sys_tenant_package` 与 `sys_tenant_package_menu`；
   - 仅当本次存在相对旧集合减少的菜单（或以最新 `newMenuIds` 作为上限集）时，查询全部 `package_id = id AND deleted = 0` 的租户 ID 集合；
   - 在 `TenantContextHolder.runWithoutTenant(...)` 下执行批量清理：`DELETE FROM sys_role_menu WHERE tenant_id IN (:tenantIds) AND menu_id NOT IN (:newMenuIds)`（新套餐为空集时删除该批租户全量 `sys_role_menu`）；
   - 调用 `PermissionCacheService` 刷新对应租户权限缓存（并同步发送集群广播）。
   - **扩展菜单边界**：若此次操作为**新增**菜单进套餐，仅扩宽对应租户角色管理页的可分配菜单上限，**不主动自动勾选写入存量租户角色**，保证最小权限原则。

---

## 3. 租户管理（`/system/tenant`）

### 3.1 列表、配额与有效期直观展示
- **检索区（`AtengQueryForm`）**：`tenantCode`（租户编码）、`tenantName`（租户名称）、`status`（状态）、`packageId`（所属套餐，折叠行）。
- **表格列**：多选框、`租户ID`（`mono`）、`租户编码`（`mono`，`000000` 标注 `[平台默认]`）、`租户名称`、`关联套餐`、`用户配额`（展示如 `2 / 4` 或 `3 / 不限` 并用预警色标识已满额）、`过期时间`（`NULL` 展示 `永久有效`，已过期在旁加注红色 `[已过期]` 标签）、`状态`（Switch 确认切换）、`创建时间`、固定右侧操作列（`编辑`、`删除`）。
- **平台默认租户 `0` (`000000`) 绝对保护**：
  - 表格中 `tenantId === "0"` 行的复选框、状态 Switch 开关与`删除`按钮一律**置灰禁用**并悬停说明 `"平台内置默认租户不可停用或删除"`；
  - 点击`编辑`打开 `0` 号租户表单时，**仅允许修改 `tenantName` 与 `remark`**，`tenantCode`、关联套餐、用户配额、过期时间与状态全部锁定只读（后端同步兜底校验禁止篡改 `0` 号租户状态与编码，`102003`）。

### 3.2 新建租户与原子初始化流程（`POST /admin/system/tenant`）
新建抽屉（`AtengDrawer` `520px`）分区采集“租户基础配置”与“默认租户管理员初始化凭据”：

1. **租户基础字段**：
   - `tenantCode`（租户编码）：必填，`4~32` 位字母/数字/下划线/短横线，禁填保留码 `000000`，全局未删除唯一（冲突 `102002`）；右侧提供 `[随机生成]` 快捷按钮生成 6 位数字编码；**编辑态下 `tenantCode` 强制只读不可修改**；
   - `tenantName`（租户名称）：必填 `2~50` 字符；
   - `packageId`（租户套餐）：必填单选（`GET /admin/system/tenant-package/options`，仅列正常启用套餐）；
   - `accountCount`（账号配额）：提供 `[不限制]` 开关（勾选传 `-1`），不勾选时必填正整数 `>= 1`（严禁输入 `0` 制造歧义）；
   - `expireTime`（过期时间）：提供 `[永久有效]` 开关（勾选传 `null`），不勾选时必填日期时间（`yyyy-MM-dd HH:mm:ss`）；
   - `status`（状态）：`0-正常` / `1-停用`（默认 `0`）；
   - `remark`（备注）：选填 `<= 500` 字符。
2. **默认管理员初始化字段（仅新建态显示）**：
   - `adminUsername`（租户管理员账号）：必填 `2~30` 位字母/数字/下划线（占位提示 `"默认如 admin"`）；
   - `adminPassword`（初始密码）：打开弹窗读取 `sys.user.initPassword` 自动预填（支持切换显隐与手动更改），**强制执行 `8~20` 位无空白且至少含 3 类字符复杂度校验**。
3. **后端四步原子初始化事务**：
   - **Step 1**：插入 `sys_tenant` 获取雪花主键 `newTenantId`；
   - **Step 2**：在 `TenantContextHolder.runWithTenant(newTenantIdStr, ...)` 下创建默认顶级部门（`parent_id = 0`、`ancestors = "0"`、`dept_name = tenantName`、`status = 0`）；
   - **Step 3**：创建默认租户管理员角色（`role_name = "租户管理员"`、`role_key = "tenant_admin"`、`data_scope = 1 (ALL)`、`menu_check_strictly = 1`、`dept_check_strictly = 0`），并将所选 `packageId` 的全部有效菜单写入 `sys_role_menu`；
   - **Step 4**：创建默认管理员用户（`dept_id` 指向顶级部门、`username = adminUsername`、`password = PasswordUtil.hash(adminPassword)`、`pwd_update_time = NULL`），并绑定 `sys_user_role`；
   - 全部成功返回 `CreateTenantVO { tenantId, tenantCode, tenantName, adminUsername }`。
4. **创建后初始化回显弹窗**：前端自动弹出“租户初始化完成”提示框，清晰列明新租户的`租户名称`、`登录租户编码 (tenantCode)`、`管理员账号`与“初始密码按您刚才设置的值生效（首次登录工作台将提示修改密码）”，提供 `[一键复制登录信息]` 按钮。

### 3.3 编辑租户换套餐联动与停用/删除强退
- **编辑更换套餐**：当编辑非 `0` 租户并将 `packageId` 变更为新套餐时，后端在事务内比对新套餐菜单集，批量清除该租户下所有角色的越界 `sys_role_menu` 记录并清理该租户权限缓存（若原绑定套餐已停用且未变动原值允许保存其他字段，若变动选择则拦截禁选已停用套餐）。
- **下调 `account_count`**：允许将配额下调至小于当前存量用户数（**绝不强停或删除存量用户**），仅在后续新增、启用或导入用户时按新配额拦截（`102006`）。
- **停用与删除租户**：
  - 表格行内切换 Switch 停用或删除租户时，二次确认明确提醒：`"停用/删除租户【{tenantName}】后，该租户下所有在线账号将被立即强制下线且无法再登录，确认执行？"`；
  - 确认执行后，后端事务落库并在事务提交后调用 `LoginHelper` **踢出该租户下全部管理端在线会话**（`tenantId` 过滤扫描强退）。

---

## 4. 跨租户运行时隔离与拦截体验

### 4.1 已登录会话遇到租户停用/过期时的拦截口径
| 场景 | 后端处置 | 前端用户体验 |
| :--- | :--- | :--- |
| **登录入口校验** | `POST /admin/auth/login` 解析租户后发现已停用或 `expire_time < now` ➔ 抛出 `101005` | 登录页警报区提示 `"所属租户已停用或已过期，请联系平台管理员"` 并刷新验证码 |
| **平台主动停用/删除租户** | 立即强退目标租户所有活跃 `admin` Token；下次请求触发 `NotLoginException` (`401`) | `AuthManager` 清空凭据、重置 `TenantManager("0")`、跳转 `/login` 并提示重新登录 |
| **租户到期（`expire_time` 自然越过）** | `TenantAvailabilityInterceptor`（`order = 10`，多租户开启时激活）读取零漂移 `TenantAuthDTO` 缓存并实时比对 `now`；发现普通租户已停用/删除/到期立即 `LoginHelper.logout("admin")` 并抛出 `101005` | 前端响应拦截器将已登录态收到的 `101005` 视同会话终止，清空 `AuthManager`、将 `TenantManager` 复位为 `"0"`、跳至 `/login` 并清晰提示 `"当前所属租户已停用或已过期"` |
| **平台超管 `X-Tenant-Id` 切换拦截** | `TenantHeaderSwitchValidator` 校验切换目标租户可用性，失效时直接抛出 `100002`（**绝不注销超管自身 `"0"` 号租户会话**） | 顶栏切换列表 `GET /admin/system/tenant/options` 已前置过滤仅展示正常未过期租户；若运行中遇 `100002` 则自动将 `TenantManager` 复位回 `"0"` 并刷新工作台 |

### 4.2 平台超管视角切换（`super_admin` in `"0"` ➔ `T != "0"`）互斥规则
1. 切回/切出触发动作严格执行 [00-overview-and-ux-standards.md](./00-overview-and-ux-standards.md) §2.3：更新 `X-Tenant-Id` ➔ 关闭除 `/dashboard` 外所有页签 ➔ 重拉 `/admin/auth/info` 与 `/admin/auth/routes`。
2. `T !== "0"` 视角下：
   - 左侧栏隐藏全部 `platform_only = 1` 菜单（`租户管理`、`租户套餐`、`菜单管理`、`数据字典`）；
   - 顶栏下方展示琥珀色跨租户提示横幅，明确展示当前租户名、`X-Tenant-Id` 与 `[切回平台默认租户 (0)]` 快捷按钮；
   - 访问租户业务模块（用户/角色/部门/岗位/配置/日志/在线会话）全部透明作用于目标租户 `T`，且自动享受 `super_admin` 数据范围放行。

---

## 5. API 契约与错误码汇总

| 端点 | 方法 | 鉴权 | 核心模型与说明 |
| :--- | :---: | :---: | :--- |
| `/admin/system/tenant-package/page` | `GET` | `system:tenant-package:list` | 分页列表（含 `menuCount`、`tenantCount`） |
| `/admin/system/tenant-package/options` | `GET` | `system:tenant-package:list` / `system:tenant:*` | 正常启用套餐下拉选项 |
| `/admin/system/tenant-package/{id}` | `GET` | `system:tenant-package:list` | 详情（含 `menuIds`、`menuCheckStrictly`） |
| `/admin/system/tenant-package/shrink-preview` | `POST` | `system:tenant-package:update` | 入参 `{ packageId, newMenuIds }`；出参 `{ removedMenuTitles, affectedTenants: [{ id, tenantName }] }` |
| `/admin/system/tenant-package` | `POST` / `PUT` | `system:tenant-package:create/update` | 保存套餐，缩减菜单时事务裁剪关联租户 `sys_role_menu` |
| `/admin/system/tenant-package/{id}/status` | `PUT` | `system:tenant-package:update` | 停用/启用切换 |
| `/admin/system/tenant-package/{ids}` | `DELETE` | `system:tenant-package:delete` | 删除（被租户引用禁删 `102005`） |
| `/admin/system/tenant/page` | `GET` | `system:tenant:list` | 分页列表（含已用账号数、过期标识） |
| `/admin/system/tenant/options` | `GET` | `@SaCheckLogin`（超管且 `"0"`） | 顶栏切换器选项（仅正常且未过期租户） |
| `/admin/system/tenant/{id}` | `GET` | `system:tenant:list` | 租户详情（编辑表单使用） |
| `/admin/system/tenant` | `POST` | `system:tenant:create` | 原子初始化（租户+部门+`tenant_admin`+管理员），返回 `CreateTenantVO` |
| `/admin/system/tenant` | `PUT` | `system:tenant:update` | 编辑租户（`0` 仅可改名称/备注；更换套餐若缩窄则裁剪 `sys_role_menu`） |
| `/admin/system/tenant/{id}/status` | `PUT` | `system:tenant:update` | 停用立即强退该租户在线会话；`0` 号租户禁止 `102003` |
| `/admin/system/tenant/{ids}` | `DELETE` | `system:tenant:delete` | 删租户并强退在线会话；`0` 号租户禁止 `102003` |

### 5.2 核心错误码
- `101005`：租户不存在、已停用或已过期
- `102002`：租户编码或套餐名称已存在
- `102003`：禁止停用、删除或篡改平台默认租户 `0`（`000000`）
- `102005`：套餐仍被未删除租户引用，禁止删除
- `102006`：禁止为套餐勾选平台专属菜单（`platform_only = 1`），或新增/启用用户超出 `account_count`

---

## 6. UX 与反模板自检清单（对齐 `ux-and-copy-checklist.md`）

- [x] **零不可预知连锁删权**：缩减租户套餐菜单前显式弹出影响租户与移除菜单预览，避免管理员误裁线上业务租户角色权限。
- [x] **平台租户 `"0"` 与停用套餐防呆**：`0` 号租户禁删禁停用且锁定核心字段；已停用套餐不可被新建选用，同时不误伤存量已绑定租户。
- [x] **数字与状态视觉一致性**：用户配额 `已用 / 上限`、租户 ID、编码与过期时间全部启用 `tabular-nums` 等宽排版。
