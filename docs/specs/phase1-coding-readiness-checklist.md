# 第一阶段（`Spec 1 ~ Spec 4`）编码开工准入检查表与 1:1 终审报告

- **关联路线图**：[第一阶段（MVP 内核）需求文档（PRD）与高保真交互原型路线图](https://github.com/atengk/ateng-solid/issues/1)
- **收口工单**：[第一阶段 PRD 与技术 Specs / 术语表 1:1 终审与签收归档](https://github.com/atengk/ateng-solid/issues/10)
- **终审范围**：
  - 根仓真源：`docs/agents/contracts.md`、`docs/specs/mvp-architecture-and-domain-blueprint.md`、`docs/specs/foundation-enhancements-checklist.md`、`docs/specs/prd/{design-system,00..04}.md`、`docs/prototypes/phase1/*`、`docs/adr/0001~0006`
  - 后端仓：`ateng-solid-server/docs/specs/*`、`ateng-solid-server/*/CONTEXT.md`、`ateng-solid-bootstrap/src/main/resources/application.yml`
  - 前端仓：`ateng-solid-admin-web/docs/specs/*`、`ateng-solid-admin-web/CONTEXT.md`、`ateng-solid-admin-web/docs/agents/styling-and-ateng-ui.md`、`ateng-solid-admin-web/docs/adr/0001-*`

---

## 1. 跨端 1:1 一致性终审结论

经逐项比对，`docs/agents/contracts.md`（响应信封 `Result<T>`、6 位分段错误码 `100xxx`/`101xxx`/`102xxx`、雪花 `string` 主键、`tenant_id BIGINT NOT NULL DEFAULT 0`、`super_admin`、`satoken-admin`、`X-Tenant-Id`、`X-Trace-Id`、三段式权限码、Fesod 批注回执）与第一阶段 PRD（`00~04`）保持 **100% 协议一致**，无需修改跨端契约。

在本次 `#10` 终审中，已将 PRD 阶段调研与决策确立的以下增量与纠偏 **1:1 同步回写至前后端子仓 Specs、Rules 与 ADR**：

| 目标文档 | 同步修正核心内容 |
| :--- | :--- |
| `ateng-solid-server/docs/specs/database-and-flyway-spec.md` | 补齐 `sys_user.pwd_update_time`、`sys_menu.platform_only`、`sys_role.{menu_check_strictly, dept_check_strictly, remark}`、`sys_tenant_package.{menu_check_strictly, remark}`、`sys_{tenant,post,user,dict_type,dict_data,config}.remark`、`sys_oper_log.{browser, os}`（`operate_type INT`）；注明 `F5`（`DefaultMetaObjectHandler` 不填 `deleted`/`version`，须 DDL `DEFAULT 0`）；增补第一阶段种子数据完整初始化核对表 |
| `ateng-solid-server/docs/specs/api-and-error-codes-spec.md` | 新增 `GET /admin/auth/profile`、`POST /admin/auth/profile/avatar`；在线强退改用不透明句柄 `DELETE /admin/auth/online/{sessionId}`（`tokenMask` 防泄漏）；移除冗余 `/admin/system/user/avatar`；补齐 `user/options`、`user/import/template`、`tenant/options`、`tenant-package/{id,status,shrink-preview}`、`dict/{type,data}/...`、`config/{id}` 及全量 `PUT /{id}/status` 端点与 `100001`/`100004`/`100005` 错误码 |
| `ateng-solid-server/docs/specs/auth-rbac-and-datascope-spec.md` | 纠偏 `CaptchaTemplate.verify`（`101001`）、`LoginFailureLockService.isLocked` + `getDisableTime`（`101004`）、4 步登录校验链、3 参 `PermissionCacheService`、显式收敛 `super-admin-roles: ["super_admin"]`、`@OperateLog(type = ...)` 与 `OperateLogModel.{userAgent, browser, os}`、`DataScopeType` 归属及改密/重置/停删全端踢出 |
| `ateng-solid-server/docs/specs/configuration-and-archunit-spec.md` | 补充 `super-admin-roles`、`tenant.allow-super-admin-switch`、`storage.guard` 等配置基线及 `B14`/`B15` 增量门禁标注 |
| `ateng-solid-server/ateng-solid-auth/CONTEXT.md` | 补充 `不透明会话句柄 (Opaque Session Handle)` 术语，并明确防爆破锁定覆盖 IP 熔断维度 |
| `ateng-solid-admin-web/docs/specs/views-and-routes-spec.md` | 对齐定稿 **方案 A + `Precision Slate & Cobalt`**、`AdminLayout` 尺寸与 `U5` 约束、`/dashboard` 初始口令提醒、`/profile` 独立读写与头像上传、`/403` 零菜单退出兜底、`/system/online` 不透明会话句柄及 `/system/dict` 同屏双面板 |
| `ateng-solid-admin-web/docs/specs/frontend-architecture-and-conventions.md` | 对齐 `src/styles/` 自定义 `Precision Slate & Cobalt` 令牌入口、`src/api/` 映射与 `/403`/`/404` 自适应布局 |
| `ateng-solid-admin-web/docs/agents/styling-and-ateng-ui.md` & `docs/adr/0001-*` | 正式修订为“脱离 `theme-pro.css` 默认靛紫皮肤、以 `Precision Slate & Cobalt` 自有令牌覆写或独立挂载（保留 TailwindCSS v4 无 Preflight 与 `@atengk/element-plus/style.css`）”；更新 `ateng-ui#365` 为已就绪状态，补充 `AtengCaptcha` `:refresh`、`AtengQueryForm` 防双重重置、`DictManager` `'default'` 归一化与 `U5~U8` 编码提示 |

---

## 2. 底座缺口再审计结论（`ateng-boot` / `ateng-ui`）

经核对 `docs/specs/prd/_research/boot-1.2.0-constraints.md`、`ui-1.1.0-capabilities.md` 与上游仓库最新 `dev` 提交及 GitHub Issues 状态：**本次终审未发现新的未登记底座缺口**；且先前登记的 **6 项增量门禁均已在上游 `dev` 修复验收并关闭 Issue**（尚未发布 Maven Central / npm 正式版，已按 `docs/agents/foundation-first-gate.md` 第 4 节 SOP 切入本地联调态供先行开发验证，**正式提交合入 `dev`/`main` 前须待发版并还原正式锁版**）：

| 门禁编号 | 上游 Issue & `dev` 提交 | 当前状态 | 本地联调方式 | 正式合入红线 |
| :---: | :--- | :---: | :--- | :--- |
| **B14** | [`atengk/ateng-boot#1171`](https://github.com/atengk/ateng-boot/issues/1171) (`8e7bef82`) | `CLOSED`（待发版） | `ateng-boot:1.2.1-SNAPSHOT` | `pre-commit` 拦截 `-SNAPSHOT` 提交；正式合入前锁版 `1.2.1+` |
| **B15** | [`atengk/ateng-boot#1172`](https://github.com/atengk/ateng-boot/issues/1172) (`0c172a12`) | `CLOSED`（待发版） | `ateng-boot:1.2.1-SNAPSHOT`（新增 `whitelist-presigned-download: true` 与 `upload-endpoint-enabled: false`） | `pre-commit` 拦截 `-SNAPSHOT` 提交；正式合入前锁版 `1.2.1+` |
| **U5** | [`atengk/ateng-ui#369`](https://github.com/atengk/ateng-ui/issues/369) (`36da58c`) | `CLOSED`（待发版） | `pnpm pack + yalc` 接入 `@atengk/element-plus` | `pre-commit` 拦截 `file:.yalc` 提交；发版后执行 `yalc remove --all && pnpm up @atengk/*` |
| **U6** | [`atengk/ateng-ui#370`](https://github.com/atengk/ateng-ui/issues/370) (`36da58c`) | `CLOSED`（待发版） | `pnpm pack + yalc` 接入 `@atengk/element-plus` | 同上 |
| **U7** | [`atengk/ateng-ui#371`](https://github.com/atengk/ateng-ui/issues/371) (`36da58c`) | `CLOSED`（待发版） | `pnpm pack + yalc` 接入 `@atengk/element-plus` | 同上 |
| **U8** | [`atengk/ateng-ui#372`](https://github.com/atengk/ateng-ui/issues/372) (`36da58c`) | `CLOSED`（待发版） | `pnpm pack + yalc` 接入 `@atengk/element-plus` | 同上 |

---

## 3. 第一阶段种子数据完整初始化核对表（`V1.0.1__system_init_seed.sql`）

> 对应路线图 `#1` `Not yet specified` 收口项：迁移 SQL 仅写入非敏感元数据；平台超管用户（`super_admin`）及初始 PBKDF2 口令由 `ateng-solid-bootstrap` 的 `SuperAdminBootstrapper` 动态落库，**严禁在 SQL 脚本中硬编码密码哈希**。

### 3.1 基础元数据种子（`V1.0.1__system_init_seed.sql`）

| 表名 | 确定性种子记录 | 关键字段与业务约束 |
| :--- | :--- | :--- |
| **`sys_tenant`** | `id = 0`（平台默认租户） | `tenant_code = '000000'`、`tenant_name = '平台默认租户'`、`package_id = NULL`、`account_count = -1`、`expire_time = NULL`、`status = 0`、`deleted = 0` |
| **`sys_dept`** | `id = 100`（平台默认顶级部门） | `tenant_id = 0`、`parent_id = 0`、`ancestors = '0'`、`dept_name = '平台总部'`、`sort = 1`、`status = 0`、`deleted = 0` |
| **`sys_role`** | `id = 1`（平台内置超管角色） | `tenant_id = 0`、`role_name = '超级管理员'`、`role_key = 'super_admin'`、`data_scope = 1` (`ALL`)、`menu_check_strictly = 1`、`dept_check_strictly = 0`、`sort = 1`、`status = 0`、`deleted = 0` |
| **`sys_dict_type`** | 2 组核心动态字典 | ① `sys_user_gender`（`用户性别`、`status = 0`）；② `sys_yes_no`（`系统是否`、`status = 0`） |
| **`sys_dict_data`** | 5 条动态字典明细 | `sys_user_gender`：`0=男 (primary)`、`1=女 (warning)`、`2=未知 (info, is_default=1)`；`sys_yes_no`：`Y=是 (primary)`、`N=否 (info, is_default=1)` |
| **`sys_config`** | `sys.user.initPassword` | `tenant_id = 0`、`config_name = '用户管理-初始默认密码'`、`config_key = 'sys.user.initPassword'`、`config_value = 'Ateng@2026'`、`config_type = 'Y'`、`deleted = 0` |

### 3.2 初始菜单与按钮权限树（`sys_menu` · 共 4 个 `M` 目录 + 12 个 `C` 菜单 + 35 个 `F` 按钮）

> `/dashboard`（工作台）与 `/profile`（个人中心）为前端静态路由，不强制写入动态菜单表（或由 `/dashboard` 作为静态固定页签兜底）。平台专属标记 `platform_only = 1` 的菜单及下属全部 `F` 按钮，严禁入选任何租户套餐。

| 域目录 (`M`) | 菜单页面 (`C` · 路径 / 组件 / 路由名) | `platform_only` | `keep_alive` | 归属 `F` 按钮权限标识 (`perms`) |
| :--- | :--- | :---: | :---: | :--- |
| **组织权限** (`/system`, `platform_only=0`) | 用户管理 (`/system/user`, `system/user/index`, `SysUser`) | `0` | `1` | `system:user:{list,create,update,delete,import,export}` |
| 同上 | 角色管理 (`/system/role`, `system/role/index`, `SysRole`) | `0` | `1` | `system:role:{list,create,update,delete}` |
| 同上 | 菜单管理 (`/system/menu`, `system/menu/index`, `SysMenu`) | **`1`** | `1` | `system:menu:{list,create,update,delete}` |
| 同上 | 部门管理 (`/system/dept`, `system/dept/index`, `SysDept`) | `0` | `1` | `system:dept:{list,create,update,delete}` |
| 同上 | 岗位管理 (`/system/post`, `system/post/index`, `SysPost`) | `0` | `1` | `system:post:{list,create,update,delete}` |
| **基础配置** (`/config`, `platform_only=0`) | 数据字典 (`/system/dict`, `system/dict/index`, `SysDict`) | **`1`** | `1` | `system:dict:{list,create,update,delete}` |
| 同上 | 系统参数 (`/system/config`, `system/config/index`, `SysConfig`) | `0` | `1` | `system:config:{list,create,update,delete}` |
| **多租户治理** (`/tenant`, **`platform_only=1`**) | 租户管理 (`/system/tenant`, `system/tenant/index`, `SysTenant`) | **`1`** | `1` | `system:tenant:{list,create,update,delete}` |
| 同上 | 租户套餐 (`/system/tenant-package`, `system/tenant-package/index`, `SysTenantPackage`) | **`1`** | `1` | `system:tenant-package:{list,create,update,delete}` |
| **审计安全** (`/audit`, `platform_only=0`) | 操作日志 (`/system/oper-log`, `system/oper-log/index`, `SysOperLog`) | `0` | `0` | `system:oper-log:list` |
| 同上 | 登录日志 (`/system/login-log`, `system/login-log/index`, `SysLoginLog`) | `0` | `0` | `system:login-log:list` |
| 同上 | 在线会话 (`/system/online`, `system/online/index`, `OnlineSession`) | `0` | `0` | `auth:online:{list,kickout}` |

### 3.3 启动引导器初始化（`SuperAdminBootstrapper`）
- 仅当平台默认租户（`tenant_id = 0`）下不存在任何绑定 `super_admin` 角色的有效用户时触发：
  - 创建默认超级管理员账号（`username = 'superadmin'` 或读取 `ateng.solid.init.super-admin-username`，归属 `dept_id = 100`、`pwd_update_time = NULL`）；
  - 口令来源：读取 `ateng.solid.init.super-admin-password`（未配置则自动生成 16 位符合全站复杂度基线的强口令并仅在启动日志脱敏打印一次；`application-test.yml` 配置测试桩口令）；
  - 绑定 `sys_user_role`（`tenant_id = 0`、`role_id = 1`）。

---

## 4. `Spec 1 ~ Spec 4` 编码开工准入检查表

### Spec 1：工程骨架、公共原语、配置基线与前端设计令牌
- [ ] **高危配置前置收敛（必改）**：在 `ateng-solid-bootstrap/src/main/resources/application.yml` 显式配置 `ateng.boot.satoken.super-admin-roles: ["super_admin"]`（覆盖底座默认 `["admin", "super_admin"]`，严防 `"admin"` 免检绕过）；
- [ ] 在 `application.yml` 补充配置 `ateng.boot.satoken.tenant`（`header-name: X-Tenant-Id`、`allow-super-admin-switch` 与 `platform-tenant-ids: ["0"]`）及 `ateng.solid.*` 强类型 `@ConfigurationProperties`；
- [ ] `ateng-solid-common` 落地分段错误码（`CommonBizResultCode`、`AuthResultCode`、`SystemResultCode`）、`DataScopeType`（`1~5` `IBaseEnum`）、`CommonStatusEnum`、`MenuTypeEnum`、`LogStatusEnum`、`ConfigTypeEnum`、`VisibleStatusEnum`、`DomainEventPublisher` 与 `AuthGrantHandler` SPI；
- [ ] `ateng-solid-bootstrap` 落地 `ArchitectureGuardTest`（ArchUnit 5 项守卫，离线 `mvn clean test` 通过）；
- [ ] `ateng-solid-admin-web` 落地 `src/styles/tokens.css`（`Precision Slate & Cobalt` Light/Dark 变量映射至 `--el-*` 与 Tailwind v4 `@theme`，禁用 Preflight），并在 `src/utils/http.ts` 绑定 `httpClient`、`adminAuthManager`、`tenantManager`（`createAtengVue` 补齐 `httpClient` 与 `tenantManager`）。

### Spec 2：认证会话、工作台、个人中心、在线会话与布局壳
- [ ] 登录链路严格执行“图形验证码（`CaptchaTemplate.verify` ➔ `101001`）➔ 租户解析（`101005`）➔ 防爆破锁定（`LoginFailureLockService.isLocked`/`getDisableTime` ➔ `101004`）➔ 账密防枚举统一计数（`101002`/`101003`）”；
- [ ] 登录接口返回 `AdminLoginVO`（含 `tenantId`/`tenantName`）；`/admin/auth/captcha` 返回 `expireSeconds`；`/admin/auth/info` 返回 `passwordNeedsChange`（由 `pwd_update_time IS NULL` 计算）；
- [ ] 个人中心拆出 `GET /admin/auth/profile`、`PUT /admin/auth/profile` 与 `POST /admin/auth/profile/avatar`；修改密码 `PUT /admin/auth/password` 成功后写入 `pwd_update_time` 并全端下线；
- [ ] 在线会话 `/admin/auth/online/page` 仅下发 `tokenMask` 与不可认证句柄 `sessionId`，强退走 `DELETE /admin/auth/online/{sessionId}` 并校验 `101007` 自保与同租户隔离；
- [ ] 前端落地定稿 **方案 A `AdminLayout`**（`228px/60px` 侧栏 + `48px` 顶栏 + `36px` `AtengTabsNav` + `<KeepAlive>` + 跨租户观察横幅）；若需支持 `'mix'` 模式切换，须先确认 **`U5` (`ateng-ui#369`)** 发版并升级锁版；
- [ ] `/login`（`AtengCaptcha` `:refresh` Prop、CapsLock 提示、`redirect` 白名单）、`/dashboard`、`/profile`、`/403`（零菜单退出兜底）、`/404` 通过 `pnpm 四合一` 测试。

### Spec 3：组织架构、RBAC、`@DataScope` 与可开关 SaaS 多租户
- [ ] **增量底座联调与正式合入锁版检查**：
  - `B14`（`#1171`）与 `U6~U8`（`#370~#372`）均已在底座 `dev` 关单，本地已分别通过 `1.2.1-SNAPSHOT` 与 `yalc` 接入可直接开展开发与自测；**正式向 `dev`/`main` 提交合入前**须待底座发布递进正式版并还原锁版；
- [ ] Flyway `V1.0.0__system_init_schema.sql` 与 `V1.0.1__system_init_seed.sql` 对齐第 3 节清单与全部 `NOT NULL DEFAULT 0` 约束，H2 (`MODE=MySQL`) 与 MySQL 8.x 双模兼容；
- [ ] 实现 `DataPermissionHandler` SPI（`DEPT_AND_CHILD` 预解析 `sys_dept.ancestors` 禁写 `FIND_IN_SET`）与 `TenantHeaderSwitchValidator` SPI；
- [ ] 角色/用户/菜单权限变动全部调用 3 参 `PermissionCacheService.clearUserCache`/`clearRoleCache`；角色菜单回显遵循“联动态仅传叶子 ID”；
- [ ] 租户套餐严格过滤 `platform_only = 1`、实现 `shrink-preview` 与原子裁剪 `sys_role_menu`；新建租户执行 4 步原子初始化；停用/删除租户同步强退全部在线会话；
- [ ] 用户导入实现 9 列模板下载（`import/template`）、500 行原子校验、剥离 `ExcelErrorRow.rowData` 及 15 分钟归属隔离批注下载（`import/feedback/{feedbackToken}`）。

### Spec 4：静态枚举、动态字典、系统参数、头像直链与只读审计日志
- [ ] **增量底座联调与正式合入锁版检查**：`B15`（`#1172`）已在 `ateng-boot` `dev` 关单并接入本地 `1.2.1-SNAPSHOT`，配置 `ateng.boot.storage.local.whitelist-presigned-download=true`、`upload-endpoint-enabled=false`、`guard.enabled=true`、`strict-magic-check=true` 与固定 `secret-key` 即可本地验证；**正式提交合入前**须待 `ateng-boot` 发布正式版并还原锁版；
- [ ] `SysEnumController` 接管 `/admin/system/enums/**` 并配置 `@SaCheckLogin`；前端枚举适配层将 `OptionItem` 映射为 `DictItem` 并把 `'default'` 归一化为 `''`；
- [ ] `/system/dict` 平台专属双面板管理支持 `dictType` 编辑锁定与 `isDefault` 同类型事务互斥；`sys_config` 对内置 `Y` 禁止删改键名且对 `sys.user.initPassword` 强制执行全站口令复杂度校验；
- [ ] `@OperateLog` 统一使用 `type = OperateTypeEnum.XXX`；`OperateLogStorageProvider` 补充真实 `userName` 与 `browser`/`os` 落库；登录日志消费领域事件并复用 `UserAgentUtil.parse`；两日志模块保持严格只读。
