# 第一阶段组织架构与 RBAC 权限管理 PRD (`02-org-and-rbac.md`)

- **所属阶段**：第一阶段（MVP 最小稳定内核）
- **关联工单**：[确定组织架构与 RBAC（部门/岗位/菜单/角色/用户与导入导出）PRD 与原型](https://github.com/atengk/ateng-solid/issues/6)（路线图：[第一阶段（MVP 内核）需求文档（PRD）与高保真交互原型路线图](https://github.com/atengk/ateng-solid/issues/1)）
- **前置真源**：
  - [设计系统规范](./design-system.md) | [第一阶段总览与全站交互规范](./00-overview-and-ux-standards.md) | [认证会话与工作台 PRD](./01-auth-and-workspace.md)
  - [跨端通信协议与数据契约](../../agents/contracts.md) | [底层缺口即停工规范](../../agents/foundation-first-gate.md)
  - [Boot 1.2.0 一手源码调研](./_research/boot-1.2.0-constraints.md) | [UI 1.1.0 一手源码调研](./_research/ui-1.1.0-capabilities.md)
  - [底层基础设施待增强清单](../foundation-enhancements-checklist.md)
- **交互参考原型**：[组织架构与 RBAC 交互原型 (`org-and-rbac.html`)](../../prototypes/phase1/org-and-rbac.html) | [定稿方案 A 基础壳 (`shell-accepted.html`)](../../prototypes/phase1/shell-accepted.html)

---

## 1. 域范围、Specs 增量对齐与底座约束

### 1.1 纳入模块与路由权限矩阵
| 菜单路径 | 路由名称 | 组件路径 (`src/views/`) | 核心权限码 | 租户与平台边界 |
| :--- | :--- | :--- | :--- | :--- |
| `/system/dept` | `SysDept` | `system/dept/index.vue` | `system:dept:{list,create,update,delete}` | 租户行级隔离；含部门树与负责人选择 |
| `/system/post` | `SysPost` | `system/post/index.vue` | `system:post:{list,create,update,delete}` | 租户行级隔离 |
| `/system/menu` | `SysMenu` | `system/menu/index.vue` | `system:menu:{list,create,update,delete}` | **平台专属（仅平台租户 `"0"` 可见与维护）** |
| `/system/role` | `SysRole` | `system/role/index.vue` | `system:role:{list,create,update,delete}` | 租户行级隔离；含菜单树与 5 级 `@DataScope` |
| `/system/user` | `SysUser` | `system/user/index.vue` | `system:user:{list,create,update,delete,import,export}` | 租户行级隔离；含左部门树、重置密码与 Fesod 导入导出 |

### 1.2 对既有 Specs 的增量修正备忘（将于工单 `#10` 统一同步子仓文档）
1. **`sys_menu` 增补 `platform_only TINYINT NOT NULL DEFAULT 0`**：由数据字段直接标记平台专属菜单（种子将`租户管理`、`租户套餐`、`菜单管理`、`数据字典`及其全部子菜单与 `F` 按钮置为 `1`），用于租户套餐菜单树过滤与超管切租户菜单自动隐藏，杜绝代码硬编码路径。
2. **`sys_role` 增补树关联模式开关**：增加 `menu_check_strictly TINYINT NOT NULL DEFAULT 1`（菜单树默认父子联动）与 `dept_check_strictly TINYINT NOT NULL DEFAULT 0`（`@DataScope` 自定部门树默认独立勾选），彻底解决联动模式下编辑回显误全选兄弟节点的问题。
3. **`sys_post`、`sys_role`、`sys_user` 增补 `remark VARCHAR(500) NULL`**：统一承载岗位、角色与用户的管理备注说明。
4. **补充部门负责人轻量下拉端点 `GET /admin/system/user/options`**：仅返回当前租户正常状态用户的 `{ userId, username, nickname }`，使部门编辑无需强依赖 `system:user:list` 表格权限。
5. **补充 Excel 导入模板端点 `GET /admin/system/user/import/template`**，并明确各模块状态切换均走标准 `PUT /admin/system/{resource}/{id}/status` 端点；个人头像上传已收敛至 `POST /admin/auth/profile/avatar`（移除冗余的 `POST /admin/system/user/avatar`）。

### 1.3 底座 `v1.2.0` / `v1.1.0` 实测边界与未解锁项对齐
| 底座组件 / 工具 | 实测约束与工程落地方案 | 门禁与调研锚点 |
| :--- | :--- | :--- |
| **`PermissionCacheService`** | 涉及用户角色变动、用户停用/删除、角色菜单变动时，**必须调用 3 参租户隔离重载** `clearUserCache("admin", tenantId, userId)` 与 `clearRoleCache("admin", tenantId, roleKey)` | `boot-1.2.0-constraints.md` `F3` / `B10` |
| **`DataScopeType` & `@DataScope`** | 底座无内置 `DataScopeType` 枚举；由 `ateng-solid-system-api` 定义 `DataScopeType`（`1=ALL..5=SELF`）并由 `ateng-solid-system` 实现 `SolidDataPermissionHandler` SPI（配合 `B16` `#1173` `failure-strategy: DENY_ALL`）；`DEPT_AND_CHILD` 通过 `sys_dept.ancestors` 服务端预解析为有界 `IN (...)`（上限 `1000`） | `boot-1.2.1-engineering-constraints.md` / `auth-rbac` §3.2 |
| **`ExcelUtil.readWithResult` & `ExcelFeedbackUtil`** | `B14`（`#1171`）与 `B17`（`#1174` 按次 `maxSyncRows` 重载）已在上游 `dev` 闭环并接入本地 `1.2.1-SNAPSHOT` 联调（合入前须锁正式版）；返回模型为 `ExcelReadResult<T>`，转译 `ImportResultVO` 时**必须剥离 `ExcelErrorRow.rowData`** 防止实体敏感字段外泄 | `boot-1.2.1-engineering-constraints.md` / `B13`/`B14`/`B17` |
| **`AtengTable` 树形模式** | 透传 `:tree-props="{ children: 'children', hasChildren: 'hasChildren' }"`、`:show-pagination="false"` 与 `row-key="id"` 渲染 `/system/dept`、`/system/menu` | `ui-1.1.0-capabilities.md` `D8` |
| **`AtengDrawer` & `AtengIconSelect` & `AtengExcelExport`** | 菜单图标通过 `:custom-icons` 注入全量 `@element-plus/icons-vue` 映射（`D6`）；自定义抽屉页脚作用域参数待 `U6` (`#370`)、图标插槽扩展待 `U7` (`#371`)、导出直读 `Content-Disposition` 待 `U8` (`#372`) 发版后于 `Spec 3` 升级锁定 | `ui-1.1.0-capabilities.md` `D6` / `D7` / `D9` & `U6~U8` |

---

## 2. 部门管理（`/system/dept`）

### 2.1 列表与树形交互
- **检索区（`AtengQueryForm`，单行）**：`deptName`（部门名称模糊检索）、`status`（部门状态：`正常`/`停用`）。存在筛选条件时按树结构保留命中节点及其祖先链路（或平面高亮展示命中节点），清空后恢复完整树。
- **工具栏**：左侧 `+ 新增部门`（`system:dept:create`）、`展开全部 / 折叠全部` 切换按钮；右侧保留刷新、密度、斑马纹、列配置。
- **默认展开策略**：默认展开全部部门节点（支持大型租户在切换折叠按钮后一键收拢至顶级节点）；无分页条（`:show-pagination="false"`）。
- **展示列**：`部门名称`（树形缩进 + 顶级部门标识）、`排序`（`tabular-nums`）、`部门负责人`（展示昵称与账号）、`联系电话`（`formatMaskPhone` 脱敏）、`状态`（行内 Switch 开关，受 `system:dept:update` 控制并二次确认）、`创建时间`、固定右侧操作列（`新增下级`、`编辑`、`删除`）。

### 2.2 新增 / 编辑弹窗（`AtengDialog` `640px`）与 `ancestors` 维护
- **字段清单**：
  1. `parentId`（上级部门）：树形单选（`GET /admin/system/dept/tree`）；顶级节点选 `"0"`（无上级 / 顶级部门）。**防自环铁律**：编辑时在树选择器中**自动禁用自身及全部子孙节点**；后端校验 `parentId != id` 且新 `parentId` 不在当前部门子孙链中（否则抛 `100001`）。新建子部门点击行内 `[新增下级]` 时自动预填 `parentId` 为该行部门 ID。不允许选择已停用（`status = 1`）部门作为新上级。
  2. `deptName`（部门名称）：必填，`2~50` 字符，同一父部门（同 `tenant_id`、`parent_id`、`deleted = 0`）下名称唯一。
  3. `sort`（显示排序）：必填整数 `0~9999`，默认 `0`。
  4. `leaderUserId`（部门负责人）：选填，远程检索下拉框消费 `GET /admin/system/user/options?keyword=...`，支持按昵称/账号模糊检索并可清空。
  5. `phone`（联系电话）、`email`（电子邮箱）：选填，编辑态加载**内存真明文**并校验格式。
  6. `status`（部门状态）：`0-正常` / `1-停用`。
- **事务内 `ancestors` 级联重算**：新增时 `ancestors = parentId == 0 ? "0" : parent.ancestors + "," + parentId`；修改上级部门导致 `parentId` 变化时，在事务内同步更新当前部门的 `ancestors` 及所有子孙部门前缀（如原 `0,100` 批量替换为 `0,200`）。

### 2.3 停用与删除防误触护栏
- **停用校验（`PUT /admin/system/dept/{id}/status` 或编辑保存）**：存在任意未软删且处于正常状态（`status = 0`）的子部门时，**禁止停用**并提示 `"该部门存在未停用的下级部门，请先停用下级部门"`；已有归属用户的部门停用后，禁止在新增/编辑用户时再选择该已停用部门。
- **删除校验（`DELETE /admin/system/dept/{id}`，仅单节点删除）**：
  1. 存在未删除子部门 ➔ 拦截抛出 `SystemResultCode(102005, "存在下级部门，禁止删除")`；
  2. 该部门下仍存在未删除用户（`sys_user.dept_id = id`）➔ 拦截抛出 `SystemResultCode(102005, "该部门下仍有关联用户，请先调整部门后再删除")`；
  3. 删除前同步清理失效的 `sys_role_dept` 关联记录。

---

## 3. 岗位管理（`/system/post`）

### 3.1 列表检索与展示列
- **检索区（`AtengQueryForm`，单行）**：`postCode`（岗位编码）、`postName`（岗位名称）、`status`（岗位状态）。
- **工具栏**：`+ 新增岗位`（`system:post:create`）、`批量删除`（`system:post:delete`）+ 标准 5 工具；默认分页 `10` 条。
- **表格列**：多选框、`岗位编码`（`mono`）、`岗位名称`、`排序`（`tabular-nums`）、`状态`（Switch 确认切换）、`备注`、`创建时间`、操作列（`编辑`、`删除`）。

### 3.2 表单校验、停用与删除规则
- **新增 / 编辑弹窗（`AtengDialog` `480px` / `640px`）**：
  - `postCode`（岗位编码）：必填，`2~64` 位字母/数字/下划线/短横线，租户内唯一（`uk_tenant_post_code_deleted`，冲突抛 `102002`）；
  - `postName`（岗位名称）：必填，`2~50` 位，租户内唯一；
  - `sort`（显示排序）：必填 `0~9999`；
  - `status`（状态）：`0-正常` / `1-停用`；
  - `remark`（备注）：选填 `<= 500` 字符。
- **停用影响**：岗位停用后，已绑定该岗位的存量用户不受影响（详情照常显示历史岗位名），但用户新增/编辑表单的岗位选择器禁用或过滤已停用岗位（编辑存量用户若原绑岗位已停用，保留回显标示 `(已停用)`）。
- **删除校验（`DELETE /admin/system/post/{ids}`）**：批量或单条删除前检查 `sys_user_post` 是否存在未删除用户引用；若任一待删岗位仍被用户占用，整批拦截并明确点名岗位名称（如 `"岗位【高级工程师】已分配给用户，请先解除关联后再删除"`）。

---

## 4. 菜单管理（`/system/menu` · 平台专属）

### 4.1 权限归属与树表展示
- **严格平台隔离**：菜单管理页面与 `/admin/system/menu/**` 写接口仅允许平台默认租户（`tenantId = "0"`）且拥有 `system:menu:*` 的账号访问；禁止任何租户套餐勾选菜单管理本身，普通租户及超管切换至他租户视角时均不可见。
- **检索区**：`title`（菜单名称）、`status`（状态）、`platformOnly`（是否平台专属：全部 / 仅平台专属 / 通用可分发）。
- **树表结构**：支持`+ 新增菜单`、`展开全部 / 折叠全部`；展示列包括`菜单名称`（含图标预览）、`类型`（`M 目录`/`C 菜单`/`F 按钮` 语义标签）、`排序`、`权限标识 (perms)`（`mono`）、`组件路径`（`mono`）、`平台专属`徽标（`platformOnly = true` 标注）、`可见 / 状态`、操作列（`新增下级`、`编辑`、`删除`）。

### 4.2 `M` / `C` / `F` 三类型动态表单字段矩阵
新建/编辑采用 `AtengDrawer`（`500px`），切换 `menuType`（`M` / `C` / `F`）时实时动态显隐及调整校验规则（编辑已存在节点且其下已有子菜单时，禁止直接将 `M`/`C` 降级切换为 `F`）：

| 字段名 | `M`（目录） | `C`（页面菜单） | `F`（按钮权限） | 校验与业务规则 |
| :--- | :---: | :---: | :---: | :--- |
| `parentId`（上级菜单） | 可选 `0` 或 `M` | 可选 `0` 或 `M` | **仅限选 `C` 类型** | 树形选择；编辑时禁止选自身及子孙 |
| `title`（菜单/权限名称） | 必填 | 必填 | 必填 | `1~50` 字符 |
| `sort`（显示排序） | 必填 | 必填 | 必填 | `0~9999` 整数 |
| `icon`（图标） | 选填 | 选填 | 隐藏 | `<AtengIconSelect>` 注入全量 `@element-plus/icons-vue`（依赖 `D6`/`U7`） |
| `isExternal`（是否外链） | 隐藏 (`false`) | 可选（默认 `false`） | 隐藏 (`false`) | 开启后新浏览器标签页打开外链 |
| `path`（路由/外链地址） | 必填 | 必填 | 隐藏 | 非外链：以 `/` 开头（目录）或相对路径（如 `/system/user`）；外链：必须匹配 `^https?://` |
| `name`（路由组件名） | 隐藏 | 非外链必填 | 隐藏 | PascalCase（如 `SysUser`），全树唯一，供 `<KeepAlive :include>` 精确匹配 |
| `component`（视图组件） | 隐藏 | 非外链必填 | 隐藏 | 相对 `src/views/` 路径（如 `system/user/index`） |
| `redirect`（重定向） | 选填 | 隐藏 | 隐藏 | 目录默认跳转的子路由地址 |
| `perms`（权限标识） | 隐藏 | 选填 | **必填** | 非空时强制匹配三段式 `^[a-z][a-z0-9-]*:[a-z][a-z0-9-]*:[a-z][a-z0-9-*]*$`（如 `system:user:create`） |
| `keepAlive`（是否缓存） | 隐藏 (`false`) | 非外链可选 | 隐藏 (`false`) | 控制是否纳入 `useTabsNav.cachedViews` |
| `visible`（侧栏显隐） | 可选（默认显示） | 可选（默认显示） | 隐藏 | **隐藏态**：仅不渲染在左侧导航菜单，仍注册路由并允许通过路径/快捷按钮跳转 |
| `status`（菜单状态） | 可选（默认正常） | 可选（默认正常） | 可选（默认正常） | **停用态**：彻底从 `/admin/auth/routes` 与 `permissions` 剥离（父停用时子树一并失效） |
| `platformOnly`（平台专属） | 可选（默认 `false`） | 可选（默认 `false`） | 可选（默认 `false`） | 设为 `true` 时，禁止在租户套餐中勾选且非 `"0"` 租户不可见；父目录设 `true` 时新增子项默认继承 `true` |

### 4.3 初始平台专属菜单标记清单与删除护栏
- **第一阶段种子（`V1.0.1__system_init_seed.sql`）中 `platform_only = 1` 的菜单及下属全量 `F` 按钮**：
  1. `多租户治理` 目录（或对应上级）及下属 `租户管理 (/system/tenant)`、`租户套餐 (/system/tenant-package)`；
  2. `菜单管理 (/system/menu)`；
  3. `数据字典 (/system/dict)`。
  - 注：组织架构（用户/角色/部门/岗位）、系统参数（`/system/config`）、日志与在线会话（`/system/oper-log`、`/system/login-log`、`/system/online`）默认 `platform_only = 0`，可分配入租户套餐。
- **删除护栏（`DELETE /admin/system/menu/{id}`）**：
  1. 若存在子菜单/子按钮 ➔ 拦截抛 `SystemResultCode(102005, "存在子菜单或按钮权限，禁止删除")`；
  2. 若当前叶子菜单/按钮已被 `sys_role_menu`（角色授权）或 `sys_tenant_package_menu`（租户套餐）引用 ➔ 拦截抛 `102005` 并提示具体被引用数量（`"该菜单已被 X 个角色或 Y 个租户套餐引用，请先解除授权后再删除"`），防止误删线上权限；
  3. 修改菜单（尤其是 `perms`/`status`/`platformOnly`）成功后全量清理权限缓存（`PermissionCacheService.clearAll()`）。

---

## 5. 角色管理（`/system/role`）与 5 级 `@DataScope`

### 5.1 表格展示与保护护栏
- **检索区**：`roleName`（角色名称）、`roleKey`（角色编码）、`status`（角色状态）。
- **表格列**：多选框、`角色名称`、`角色编码`（`mono`，`super_admin` 标注 `[平台内置]` 主色胶囊）、`数据范围`（展示 `DataScopeType` 标签，如 `全部数据权限`、`自定部门`）、`排序`、`状态`（Switch 确认切换）、`创建时间`、操作列（`编辑`、`数据权限`、`删除`）。
- **绝对保护规则**：
  - 平台超级管理员角色 `roleKey = "super_admin"`：表格复选框、状态开关、`编辑`、`数据权限`与`删除`全部置灰禁用并悬停说明 `"平台内置超级管理员角色受系统保护，不可编辑、停用或删除"`；后端写接口遇到 `super_admin` 主键直接硬拦截抛 `SystemResultCode(102004 / 102007)`；
  - 新增/编辑任何其他角色时，**禁止使用 `"super_admin"` 或 `"admin"` 作为 `roleKey`**（触发 `102004: "禁止使用保留角色编码 super_admin 或 admin"`）。

### 5.2 新增 / 编辑角色抽屉（`AtengDrawer` `500px`/`720px`）与菜单树联动契约
- **基本字段**：`roleName`（必填 `2~30`）、`roleKey`（必填 `2~64` 仅限字母/数字/下划线/短横线，租户内唯一，禁保留词）、`sort`（`0~9999`）、`status`（`0/1`）、`remark`（选填 `<= 500`）。
- **菜单权限树（`menuIds`）与防误全选机制**：
  - **数据源范围**：
    - 在平台租户（`tenantId = "0"`）编辑角色时，加载全量启用菜单树；
    - 在开启多租户的普通租户（`tenantId != "0"`）编辑角色时，**后端仅返回该租户当前绑定 `sys_tenant_package` 允许的菜单交集（且天然剔除 `platform_only = 1` 菜单）**，提交时后端亦再次校验 `menuIds` 不得越界（越界抛 `102006`）。
  - **树交互工具栏**：`[展开 / 折叠]`、`[全选 / 全不选]`、`[父子联动]`复选框（对应 `menuCheckStrictly`，默认 `true` 开启联动）：
    - **提交态**：当 `menuCheckStrictly = true` 时，收集 `treeRef.getCheckedKeys().concat(treeRef.getHalfCheckedKeys())` 一并写入 `sys_role_menu`（保证目录 `M` 随子菜单被保存，用户登录能正常拿到完整路由树）；当 `menuCheckStrictly = false` 时仅提交 `getCheckedKeys()`；
    - **编辑回显态**：读取 `GET /admin/system/role/{id}` 返回的 `menuIds` 与 `menuCheckStrictly`：若 `menuCheckStrictly = true`，**仅将其中“属于树末端叶子节点（无子孙菜单）”的 ID 设为 `checkedKeys`**，交由 Element Plus 自动反推半选父节点，彻底避免把父目录 ID 直接传入导致全部兄弟权限被自动全选；若 `menuCheckStrictly = false` 则原样全量匹配。
  - **缓存失效**：角色修改、菜单权限变更、停用或删除完成后，后端必须调用 3 参 **`PermissionCacheService.clearRoleCache("admin", tenantIdStr, roleKey)`**（且停用或删除角色前校验 `sys_user_role` 无未删除用户引用，否则抛 `102xxx` 阻止删除）。

### 5.3 5 级 `@DataScope` 数据权限分配弹窗（`PUT /admin/system/role/{id}/data-scope`）
- **交互入口**：点击角色行 `[数据权限]` 打开 `AtengDialog`（`520px`）：
  - 只读回显 `角色名称` 与 `角色编码`；
  - 选择 `dataScope`（下拉消费静态枚举 `DataScopeType`）：
    - `1 / ALL`：全部数据权限（不追加 SQL 过滤）
    - `2 / CUSTOM`：自定部门数据权限（基于 `sys_role_dept`）
    - `3 / DEPT`：本部门数据权限（`dept_id = currentDeptId`）
    - `4 / DEPT_AND_CHILD`：本部门及以下数据权限（服务端按 `ancestors` 预解析有界 `IN (...)`）
    - `5 / SELF`：仅本人数据权限（`user_id = currentUserId`）
  - **动态部门树联动**：仅当选中 **`2 / CUSTOM`** 时，在下方滑出/展示本租户部门权限树与工具条（`[展开/折叠]`、`[全选/全不选]`、`[父子联动]` `deptCheckStrictly` 默认 `false` 独立勾选），**提交前强制校验至少勾选 `1` 个部门**（`deptIds.length >= 1`），否则阻断提交并在树上方提示 `"选择自定部门数据权限时，至少需勾选 1 个部门"`；选其他 4 级时隐藏部门树并由后端事务清理旧 `sys_role_dept` 关联。

---

## 6. 用户管理（`/system/user`）

### 6.1 `AtengSplitLayout` 分栏与左部门树联动
- **左侧部门树面板（默认宽 `230px`，支持折叠、拖拽调整与 `storageKey` 记忆）**：
  - 顶部部门关键词即时过滤框；
  - 点击任意部门节点时，右表默认**按“当前部门及全部子孙部门”递归过滤用户**，同时在右表工具栏/筛选区显示 `"筛选部门：{deptName}（含下级）[×]"` 胶囊以便一键恢复全租户视图。
- **右侧检索区与表格（`storageKey: 'solid:table:sys-user'`）**：
  - 检索区（`defaultCollapsed: true, collapsedRows: 1`）：第一行 `username`（账号/昵称模糊）、`phone`（**完整手机号精确匹配**，因持久层启用确定性 `@FieldEncrypt`，占位提示 `"请输入完整手机号（精确查询）"`）、`status`（账号状态）；展开行：`createTime`（创建时间范围）。
  - 工具栏左区：`+ 新增用户`、`批量删除`（置灰计数）、`[导入]`、`AtengExcelExport`（下拉：`导出全部筛选结果` / `导出已选用户 (N)`）；右侧标准 5 工具。
  - 表格列：多选框、`用户ID`（`mono`）、`用户账号`（`mono` + 超管 `[内置]` 标签）、`用户昵称`、`头像`（缩略圆标，失败降级首字）、`归属部门`、`手机号码`（`formatMaskPhone`）、`电子邮箱`（`formatMaskEmail`）、`状态`（Switch 确认切换）、`创建时间`、固定右侧操作列（`编辑`、`重置密码`、`删除`）。

### 6.2 新增 / 编辑抽屉（`AtengDrawer` `500px`/`720px`）与配额护栏
- **新增用户字段**：
  1. `username`（登录账号）：必填 `2~30` 位字母/数字/下划线，同租户内唯一（冲突 `102002`）；**仅新增时可输入，编辑时强制只读禁改**；
  2. `nickname`（用户昵称）：必填 `2~30` 位；
  3. `password`（初始密码 · 仅新增时出现）：打开新增抽屉时异步读取 `GET /admin/system/config/key/sys.user.initPassword` 自动预填（支持切换显隐并可由管理员修改）；**统一执行 `8~20` 位无空白且至少含 3 类字符复杂度校验**；新建落库 `pwd_update_time` 置 `NULL`（触发 `#5` 工作台提醒）；
  4. `deptId`（归属部门）：单选部门树（禁止选择已停用部门）；
  5. `postIds`（所属岗位）：多选下拉（`GET /admin/system/post/options`，仅可选正常状态岗位）；
  6. `roleIds`（分配角色）：多选下拉（`GET /admin/system/role/options`，**普通租户及非超管视角彻底隐藏 `super_admin`；后端校验禁止普通租户绑定 `super_admin` 越权**）；
  7. `phone`（手机号码，选填同租户唯一）、`email`（电子邮箱，选填同租户唯一）、`gender`（`AtengDictRadio` 消费 `sys_user_gender`）、`status`（`0/1`）、`remark`（选填 `<= 500`）。
- **编辑态内存真明文**：点击`编辑`先请求 `GET /admin/system/user/{id}` 加载未脱敏 `phone` 与 `email` 真明文回填表单；不展示密码输入框；角色变化时后端调用 3 参 `PermissionCacheService.clearUserCache("admin", tenantId, userId)`。
- **租户套餐账号配额校验（`ADR-0003`）**：当 `tenantEnabled = true` 且租户 `account_count > 0` 时，在**新增用户**与**停用转启用用户**两处检查当前租户有效用户总数（`deleted = 0`），达到上限时立即抛出 `SystemResultCode(102006, "当前租户用户数已达套餐上限，请联系平台管理员扩容")`。

### 6.3 重置密码与双重保护护栏
- **重置密码弹窗（`AtengDialog` `480px`、`PUT /admin/system/user/{id}/reset-password`）**：
  - 只读点名目标用户账号与昵称；预填 `sys.user.initPassword`（支持明文显隐查看与手动调整，校验同款 `8~20` 位 3 类强口令）；
  - 确认重置后：后端更新 PBKDF2 慢哈希、**置空 `pwd_update_time = NULL`**，并立即调用 `LoginHelper.logout("admin", compositeLoginId)` 强制踢出该用户所有在线会话。
- **内置与自身硬保护（表格操作列 + 复选框 + 后端校验）**：
  - **超管账号保护**：平台内置超级管理员用户禁止编辑敏感归属、禁止停用、禁止删除与多选（`102007`）；
  - **当前登录用户自身保护**：`row.userId === currentLoginUserId` 时，行内状态开关、`删除`按钮与多选框一律置灰禁用并悬停说明 `"当前登录账号不可停用或删除"`；
  - **停用 / 删除连带强退**：成功停用或删除其他用户后，后端立即清理其权限缓存并强制注销其全部在线会话。

---

## 7. Fesod Excel 导出与“整批原子导入 + 批注回写”全链路契约

### 7.1 导出协议（`POST /admin/system/user/export`）
- 前端通过 `<AtengExcelExport mode="dropdown" />` 挂载：
  - 未勾选行或主动点`导出全部筛选结果`：透传当前检索区参数（`username`, `phone`, `status`, `deptId`, `createTimeRange`）按当前 `@DataScope` 数据权限流式分页导出；
  - 勾选行后点`导出已选用户 (N 条)`：透传 `{ ids: selectedIds }` 导出指定行（后端仍施加租户与 `@DataScope` 校验）。
- 导出列：`用户ID`、`用户账号`、`用户昵称`、`归属部门`、`手机号码`（`@ExcelSensitive` 脱敏为 `138****5678`）、`电子邮箱`（`@ExcelSensitive` 脱敏）、`性别`、`状态`、`创建时间`；**绝不导出密码哈希列**。
- 响应采用 `ExcelWebUtil` 流式输出带 RFC 5987 文件名响应头（如 `用户数据_20261124173000.xlsx`），前端配合 `U8` (`ateng-ui#372`) 与 `Blob-JSON` 双态嗅探落地。

### 7.2 模板下载与纯新增整批原子导入规则
- **前置门禁提示**：`B14`（`ateng-boot#1171`）与 `B17`（`ateng-boot#1174` 按次 `maxSyncRows` 重载）已在上游 `dev` 修复关单并刷新至本地 `1.2.1-SNAPSHOT`，可直接开展编码与离线测试，**正式合入 `dev`/`main` 前须锁回递进正式版**。
- **模板下载（`GET /admin/system/user/import/template`）**：后端生成带批注示例行与表头样式的 `.xlsx` 模板，包含以下 **9 列**：

| 列序 | 表头名称 | 必填 | 格式与业务解析规则 |
| :---: | :--- | :---: | :--- |
| `0` | `用户账号` | **是** | `2~30` 位字母/数字/下划线；文件内不可重复；库内当前租户不可已存在 |
| `1` | `用户昵称` | **是** | `2~30` 字符，非全空白 |
| `2` | `归属部门` | 否 | 支持填唯一部门名称（如 `财务合规部`）或 `/` 分隔层级路径（如 `总部/研发中心/后端组`）；未匹配、已停用或存在多个同名歧义节点时报错并提示改用 `/` 全路径 |
| `3` | `岗位编码` | 否 | 英文逗号 `,` 分隔一个或多个 `post_code`；任一编码不存在或已停用时报错 |
| `4` | `角色编码` | 否 | 英文逗号 `,` 分隔一个或多个 `role_key`；**禁填 `super_admin`**；任一编码不存在、已停用或越权时报错 |
| `5` | `手机号码` | 否 | `^1[3-9]\d{9}$`；文件内与库内同租户不可重复 |
| `6` | `电子邮箱` | 否 | 标准邮箱且 `<= 64` 位；文件内与库内同租户不可重复 |
| `7` | `性别` | 否 | `男` / `女` / `未知`（留空默认 `未知`） |
| `8` | `状态` | 否 | `正常` / `停用`（留空默认 `正常`） |

- **安全阈值与 4 阶段整批原子校验流水线**：
  1. **文件与行数前置拦截**：仅接受 `.xlsx`（`<= 2MB`），单次同步原子导入上限 **`500` 行**（考虑 `PasswordUtil` 310,000 次 PBKDF2 单用户哈希耗时，500 行内保障同步事务稳定不超时；超限 Fail-Fast 返回 `100005` 提示拆批导入）。
  2. **表头契约与 JSR-303 校验（`ExcelUtil.readWithResult` + `HeaderValidationStrategy.STRICT` / `LOOSE`）**：缺失必填表头立即报错 `100005`；通过 `BatchValidationListener` 保留 1-based 物理行号 `rowIndex`（`B13`）并收集全部字段格式错误。
  3. **文件内查重、关联解析、库内唯一性与配额校验**：基于全量有效行收集批内重复键、批量 `IN` 查询库内冲突与部门/岗位/角色映射（**严禁循环 N+1 查 DB**），并校验 `tenantEnabled = true` 时 `现有用户数 + 导入行数 <= account_count`（配额不足生成整表或首数据行错误提示）。
  4. **三段式事务解耦提交或生成批注反馈**：
     - **零错误（`errors.isEmpty()`）**：① 在**无事务阶段**通过进程内 `Semaphore`（默认并发度 `2`，超限返 `429`）与独立有界平台线程池 `ateng.boot.async.pools.password-hash`（`mode: platform`，**禁虚拟线程**）并行计算 500 个独立随机盐 `PasswordUtil.hash(initPassword)`（严禁共享同一哈希）；② 随后开启极短 `@Transactional`（`< 100ms`），通过 `PessimisticLockUtil.forUpdate` 锁租户行复核配额并调用 `BatchUtil.insertBatch` 一次性批量落库 `sys_user`（`pwd_update_time = NULL`）、`sys_user_post`、`sys_user_role`，返回 `ImportResultVO { totalCount, successCount, failCount: 0, errors: [], feedbackToken: null }`（前端导入接口 Axios 超时专项放宽至 `120_000 ms`）。
     - **存在任一行错误（`!errors.isEmpty()`）**：**零哈希计算、零写事务（`successCount = 0`）**；基于单次缓冲的 `byte[]` 二次构造 `ByteArrayInputStream` 调用 `ExcelFeedbackUtil.renderErrorFeedback(...)` 生成原表标红+批注 `.xlsx`，以 Redis 双 Key（`meta` + `bin`，TTL **`15` 分钟**，绑定 `{ tenantId, operatorUserId }`；无 Redis 时本地有界降级）暂存，返回 `ImportResultVO`（**剔除 `ExcelErrorRow.rowData`**，每条错误映射为 `{ rowNum, columnName, errorMessage, rawValue }`）。

### 7.3 前端 `<AtengExcelFeedback>` 交互与防越权下载
1. 打开“导入用户”弹窗（`AtengDialog` `560px`）：提供 `[下载导入模板]` 链接、清晰规则摘要（`最多 500 行 · 2MB · 默认初始密码 · 任一行错误整批不入库`）与 `<AtengUpload accept=".xlsx" :max-size="2*1024*1024" :http-request="importUsersRequest" />`。
2. 导入返回 `failCount > 0` 时：关闭上传弹窗，自动打开 `<AtengExcelFeedback>`（`720px`）：
   - 顶部汇总提示：`共解析 {totalCount} 行，校验失败 {failCount} 条（整批未入库，请修正后重新导入）`；
   - 中间展示 3 列分页明细表（`行号`、`列名/字段`、`错误原因`，每页 10 条）；
   - 底部操作：`[下载标红批注文件 (.xlsx)]`（调用 `downloadFeedback` 请求 `GET /admin/system/user/import/feedback/{feedbackToken}`，服务端核对 `tenantId` 与 `userId` 一致性，过期或越权报 `404`/`403` 并提示重新执行一次导入获取最新批注）+ `[复制错误清单]` + CSV 兜底导出。

---

## 8. API 契约与错误码汇总

### 8.1 本域核心端点汇总（`/admin/system/**`）
| 模块 | 关键端点 | 权限码 | 说明 |
| :--- | :--- | :--- | :--- |
| **部门** | `GET /dept/tree`、`GET /dept/{id}`、`POST /dept`、`PUT /dept`、`PUT /dept/{id}/status`、`DELETE /dept/{id}` | `system:dept:*` | 含 `ancestors` 事务重算与自环拦截 |
| **岗位** | `GET /post/page`、`GET /post/options`、`GET /post/{id}`、`POST /post`、`PUT /post`、`PUT /post/{id}/status`、`DELETE /post/{ids}` | `system:post:*` | 选项接口供用户表单消费；被引用禁删 |
| **菜单** | `GET /menu/tree`、`GET /menu/{id}`、`POST /menu`、`PUT /menu`、`PUT /menu/{id}/status`、`DELETE /menu/{id}` | `system:menu:*` | 严格限平台租户 `0`；含 `platformOnly` |
| **角色** | `GET /role/page`、`GET /role/options`、`GET /role/{id}`、`POST /role`、`PUT /role`、`PUT /role/{id}/status`、`PUT /role/{id}/data-scope`、`DELETE /role/{ids}` | `system:role:*` | 含租户套餐裁剪、树联动开关与 3 参清缓存 |
| **用户** | `GET /user/page`、`GET /user/options`、`GET /user/{id}`、`POST /user`、`PUT /user`、`PUT /user/{id}/status`、`PUT /user/{id}/reset-password`、`DELETE /user/{ids}` | `system:user:*` | `user/options` 供部门负责人选择 |
| **Excel** | `GET /user/import/template`、`POST /user/import`、`GET /user/import/feedback/{feedbackToken}`、`POST /user/export` | `system:user:{import,export}` | 500 行原子校验、15 分钟归属隔离批注下载 |

### 8.2 本域核心业务错误码（`102xxx` & `100xxx`）
| 错误码 | 触发场景 | 前端交互响应 |
| :---: | :--- | :--- |
| `100001` | 部门/菜单上级设置为自身或子孙、自定部门权限未勾选任何部门、`F` 按钮挂接非 `C` 节点 | 表单弹窗原位错误提示 |
| `100005` | Excel 文件非 `.xlsx`、超 `500` 行 / `2MB` 或表头缺失 | 上传弹窗明确报错并引导下载模板核对 |
| `102001` | 目标部门/岗位/菜单/角色/用户记录不存在（含越权租户不可见） | 提示并刷新列表 |
| `102002` | 同租户内账号、手机号、邮箱、岗位编码、角色编码或同级部门名重复 | 保留表单现场并高亮冲突字段 |
| `102004` | 试图新增/修改使用保留角色编码 `super_admin` 或 `admin` | 表单字段精确提示禁用保留编码 |
| `102005` | 存在子部门/关联用户禁删部门、存在子菜单或被角色/套餐引用禁删菜单、被用户占用禁删岗位/角色、存在未停用子部门禁停用 | 明确给出当前阻断原因及引用关联提示 |
| `102006` | 新增/启用/导入用户超出租户套餐 `account_count` 上限，或角色菜单超出套餐边界 | 拦截保存并提示租户套餐配额/范围限制 |
| `102007` | 试图编辑保护字段、停用或删除内置 `super_admin` 账号/角色或当前登录用户自身 | 前端已前置置灰禁点，后端接口兜底硬拒绝 |

---

## 9. UX 与反模板自检清单（对齐 `ux-and-copy-checklist.md`）

- [x] **无死状态按钮与不可点击盲区**：`super_admin`、登录用户自身行在表格多选框/Switch/删除列全部提前置灰禁用并带明确 Hover Tooltip，避免点后才报错。
- [x] **编辑真明文与列表脱敏一致**：用户与部门列表手机号/邮箱采用 `formatMask*` 展示，打开编辑抽屉读取完整真明文，绝不回填掩码。
- [x] **树形回显与状态一致**：角色菜单权限区分联动态叶子回显与独立态全量回显，防止误选；自定部门权限强校验至少 1 个部门。
- [x] **Excel 导入反馈可恢复**：失败整批零脏数据入库，错误明细 3 列可读，支持下载标红批注 `.xlsx`、复制清单及 UTF-8 BOM CSV 降级导出。
