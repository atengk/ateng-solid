# 第一阶段认证登录、工作台、个人中心、在线会话与异常页 PRD (`01-auth-and-workspace.md`)

- **所属阶段**：第一阶段（MVP 最小稳定内核）
- **关联工单**：[确定认证登录、工作台、个人中心与在线会话域 PRD 与原型](https://github.com/atengk/ateng-solid/issues/5)（路线图：[第一阶段（MVP 内核）需求文档（PRD）与高保真交互原型路线图](https://github.com/atengk/ateng-solid/issues/1)）
- **前置真源**：
  - [设计系统规范](./design-system.md) | [第一阶段总览与全站交互规范](./00-overview-and-ux-standards.md)
  - [跨端通信协议与数据契约](../../agents/contracts.md) | [底层缺口即停工规范](../../agents/foundation-first-gate.md)
  - [Boot 1.2.0 一手源码调研](./_research/boot-1.2.0-constraints.md) | [UI 1.1.0 一手源码调研](./_research/ui-1.1.0-capabilities.md)
  - [底层基础设施待增强清单](../foundation-enhancements-checklist.md)
- **交互参考原型**：[认证会话与工作台交互原型 (`auth-and-workspace.html`)](../../prototypes/phase1/auth-and-workspace.html) | [定稿方案 A 基础壳 (`shell-accepted.html`)](../../prototypes/phase1/shell-accepted.html)

---

## 1. 域范围、技术规格增量对齐与底座边界

### 1.1 纳入本域页面与功能范围
| 路由路径 | 路由名称 | 组件路径 (`src/views/`) | 核心权限码 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `/login` | `Login` | `login/index.vue` | 公开 (`@Anonymous`) | 双态管理端登录、图形验证码、防爆破倒计时与 `redirect` 守卫 |
| `/dashboard` | `Dashboard` | `dashboard/index.vue` | 登录后全员可见 | 固定页签（`affix: true`）、身份摘要、初始口令提醒、动态快捷导航与系统引导 |
| `/profile` | `Profile` | `profile/index.vue` | 登录后全员可见 | 左栏脱敏概览+真明文复制、右栏基本资料编辑、个人头像上传与修改密码 |
| `/system/online` | `OnlineSession` | `system/online/index.vue` | `auth:online:list` / `auth:online:kickout` | 当前工作租户在线会话检索、当前会话标注、脱敏安全强退 |
| `/403` | `Forbidden` | `error/403.vue` | 自适应 | 权限不足提示页（已登录态优先嵌套在 `AdminLayout` 内） |
| `/:pathMatch(.*)*` (`/404`) | `NotFound` | `error/404.vue` | 自适应 | 页面不存在与未匹配动态视图降级页 |

### 1.2 对既有 Specs 的增量修正备忘（将于工单 `#10` 统一同步子仓文档）
经本域调研与评审确认，以下 4 项对既有技术 Spec 的增量修正作为本域权威口径（编码时优先以本 PRD 为准，并在工单 `#10` 终审回写 `ateng-solid-server/docs/specs/` 与 `ateng-solid-admin-web/docs/specs/`）：
1. **`sys_user` 增补 `pwd_update_time DATETIME NULL`**：新建用户、超管启动引导及管理员重置密码时保持为 `NULL`；用户本人通过 `PUT /admin/auth/password` 改密成功后写入当前时间。`/admin/auth/info` 返回 `passwordNeedsChange: boolean`（`pwdUpdateTime == null` 时为 `true`），驱动工作台顶部非阻塞改密提醒条。
2. **拆出独立个人资料读取接口 `GET /admin/auth/profile`**：保持 `/admin/auth/info`（`AdminProfileVO`）仅返回高频鉴权身份与轻量摘要（追加 `tenantName`、`passwordNeedsChange`、`loginIp`、`loginDate`），`/profile` 页面装载完整只读与编辑字段（含 `email`、`phone`、`gender`、`deptName`、`postNames`、`createTime`）统一请求 `GET /admin/auth/profile`（`PersonalProfileVO`，仅需 `@SaCheckLogin`）。
3. **拆出个人中心专属头像上传端点 `POST /admin/auth/profile/avatar`**：避免复用需 `system:user:*` 管理权限的 `/admin/system/user/avatar` 导致普通登录用户无权更换本人头像；`POST /admin/auth/profile/avatar` 仅需 `@SaCheckLogin`，上传即更新本人 `sys_user.avatar` 并返回最新可访问头像 URL。
4. **在线会话防真实 Token 泄漏改造**：禁止 `/admin/auth/online/page` 向前端直接下发原始 `satoken-admin` `tokenValue`。列表改返回脱敏展示串 `tokenMask`（如 `a1b2c3****9x8y`）与不可用于请求鉴权的不透明句柄 `sessionId`（服务端对称加密或签密映射），强退接口调整为 `DELETE /admin/auth/online/{sessionId}`；列表展示列严格对齐 `ateng-boot:1.2.0` `OnlineUser` 原生字段，不额外读取 `browser`/`os`。

### 1.3 `ateng-boot:1.2.0` 与 `ateng-ui:1.1.0` 实测约束对齐
| 底座能力 | 实测约束与本域落地规范 | 对应门禁 / 调研锚点 |
| :--- | :--- | :--- |
| **`CaptchaTemplate`** | 位于 `ateng-boot-web`；`verifyOrThrow` 仅抛 `400` 且原子烧毁，本域使用 `boolean verify(key, code)` 在失败时自抛 `AuthResultCode(101001)`；配置保持 `SVG`、`4` 位安全字符、有效期 `120s` | [boot-1.2.0-constraints.md](./_research/boot-1.2.0-constraints.md) `F1` |
| **`LoginFailureLockService`** | `checkLocked` 抛出 `403`（`DisableServiceException` 或 IP 熔断），为统一向前端返回 `101004` 与剩余秒数，登录入口前置调 `isLocked(...)` + `getDisableTime(...)` 自抛 `101004`（带剩余分钟/秒）；均传 `(tenantId, "admin", username, clientIp)` 作用域重载；IP 熔断亦转译提示 | `boot-1.2.0-constraints.md` `F2` / `B4` |
| **`PasswordUtil`** | 采用 PBKDF2-SHA256（310,000 次迭代，输出约 88 字符，DDL `VARCHAR(128)`）；**底座不提供密码复杂度校验**，本域由 `ateng-solid` 统一实施“8~20 位 + 无空白 + 至少 3 类字符”强校验 | `boot-1.2.0-constraints.md` §4.3 |
| **`LoginHelper` 在线会话** | 列表复用 `searchOnlineUserPage("admin", query, page, size)`（最大扫描上限 `2000`，单页 `size <= 100`，支持 `tenantId` 与 `loginIp` CIDR 匹配）；强退前置校验自身会话抛 `101007`，随后调 `kickoutByTokenForTenant("admin", realToken, expectedTenantId)` 防止跨租户越权 | `boot-1.2.0-constraints.md` §1.5 / `B12` |
| **`ateng-boot-storage`** | 头像上传显式开启 `guard.enabled=true`、`strict-magic-check=true`、固定 `local.secret-key`；本地模式预签名头像 URL 的无 Cookie 直链放行依赖 **`B15` (`ateng-boot#1172`)** 在 `Spec 4` 发版锁版后闭环 | `foundation-enhancements-checklist.md` `B15` / `F8` |
| **`AtengCaptcha` (`@atengk/element-plus`)** | `type="image"` 的刷新绑定属性为 **Prop `:refresh="loadCaptcha"`**（非 `@refresh` 事件） | `ui-1.1.0-capabilities.md` `D10` |
| **`AtengUpload` & `AtengDescriptions`** | 上传透传 `:http-request` 对接 `@atengk/core` `http`（自动携带 `satoken-admin` / `X-Tenant-Id`）；详情页展示使用 `formatMaskPhone`/`formatMaskEmail` 脱敏，`copyable` 复制内存真明文 | `ui-1.1.0-capabilities.md` §2.7 / §2.10 / `U4` |

---

## 2. 管理端登录页（`/login`）

### 2.1 布局构图与响应式适配
- **桌面端（`>= 960px`）**：居中非对称双栏工程登录卡（总宽 `920px`，1px 结构边框 `--solid-border`，圆角 `--solid-radius-lg`）：
  - **左栏（约 `42%` 宽，深岩钴蓝 `#0F172A` 底 / Dark 态 `#0B1120`）**：品牌标识 `ateng-solid`、平台副标题“企业级多租户管理后台核心框架”、3 条简洁内核基线说明（无修饰性英文眉标、无发光渐变或虚构统计数字）、底部版本基线与单/多租户运行态微徽标。
  - **右栏（约 `58%` 宽，`--solid-bg-surface`）**：标题“登录管理后台”、双态动态表单、登录按钮与系统级错误 alert 槽位（固定预留警报渲染区防表单跳动）。
- **窄屏与移动端（`< 960px`）**：隐藏左栏特性面板，折叠为顶部精简品牌行 + 居中单卡表单（最大宽 `420px`）。
- **Theme 支持**：右上角提供轻量 Light / Dark 切换按钮（同步至 `useAppStore` 偏好）。

### 2.2 挂载初始化与 `GET /admin/auth/captcha` 双态加载
1. 进入 `/login` 立即调用 `GET /admin/auth/captcha`（`@Anonymous`）。
2. 响应模型 `CaptchaVO`：
   ```ts
   interface CaptchaVO {
     enabled: boolean;        // 后端 ateng.solid.auth.captcha-enabled
     tenantEnabled: boolean;  // 后端 ateng.solid.tenant.enabled
     captchaKey: string;      // enabled=false 时为空串
     imageBase64: string;     // data:image/svg+xml;base64,...；enabled=false 时为空串
     expireSeconds: number;   // 默认 120
   }
   ```
3. **容错与重试**：
   - 若 `/admin/auth/captcha` 请求失败（网络断开或 `500`）：
     - 表单顶部展示可操作提示：`"获取登录安全配置失败，请检查服务连接后点击重试"` + `[重新获取]`；
     - 若处于加载失败态且未取得 `tenantEnabled`/`enabled` 初始配置，登录按钮保持禁用状态（防止盲提交）。
   - 若 `enabled = false`：隐藏验证码输入行（但页面挂载仍必须拉取该接口以获知 `tenantEnabled`）。

### 2.3 表单字段规则、辅助交互与记住账号
| 字段 | 组件 / 控件 | 显示条件 | 校验规则与默认值 | 特殊交互约束 |
| :--- | :--- | :--- | :--- | :--- |
| `tenantCode` | `ElInput`（前缀图标） | **`tenantEnabled === true`** | 必填，去首尾空格，`1~32` 位合法租户编码字符；`tenantEnabled = false` 时隐藏字段，请求固定传 `'000000'` | 多租户开启时，优先读取 `localStorage` 中上次成功登录的 `tenantCode`，无记录时**默认预填 `'000000'`**；若人工清空则行内报 `"请输入租户编码"`，不静默回退 |
| `username` | `ElInput` | 始终显示 | 必填，`2~64` 位，去首尾空格 | 支持读取本地记住的 `username` 自动回填；清空时提供 `clearable` |
| `password` | `ElInput` (`show-password`) | 始终显示 | 必填，`1~64` 位（登录页不拦截历史弱口令格式，交由服务端统一校验） | 支持密码显隐切换；监听 `keyup`/`keydown` `getModifierState('CapsLock')` 在输入框下方提示 `"大写锁定 (Caps Lock) 已开启"` |
| `captchaCode` | `ElInput` + `<AtengCaptcha type="image" />` | **`captchaEnabled === true`** | 必填，去首尾空格 | 点击 `<AtengCaptcha>` 图片容器触发 `:refresh="loadCaptcha"` 刷新并清空已填 `captchaCode`；输入框按 `Enter`（非 IME `isComposing`）直接触发表单提交 |
| 记住账号 | `ElCheckbox` | 始终显示 | 默认勾选或按上次用户选择持久化 | **安全铁律**：仅向 `localStorage` 持久化 `{ remember: true, tenantCode, username }`，**绝对禁止**存储明文或可逆加密密码 |

### 2.4 登录校验链顺序、防爆破锁定（`101001~101005`）与 `redirect` 守卫

#### 后端执行顺序（`POST /admin/auth/login`）
严格按以下顺序串行校验，防止未过验证码即枚举租户或账号锁定状态：
1. **图形验证码校验**：若 `captcha-enabled = true`，调用 `CaptchaTemplate.verify(captchaKey, captchaCode)`（原子读取并烧毁该 `captchaKey`）；返回 `false` 立即抛出 `AuthResultCode(101001, "图形验证码无效或已过期，请重新输入")`。
2. **租户解析与可用性校验**：
   - 若 `tenantEnabled = false`，固定解析为平台默认租户（`tenantId = 0L`、`tenantCode = "000000"`）；
   - 若 `tenantEnabled = true`，按 `tenantCode` 查询 `sys_tenant`：不存在、已停用（`status != 0`）或已超过 `expireTime` 时，统一抛出 `AuthResultCode(101005, "所属租户不存在、已停用或已过期")`（**此步不计入账号密码防爆破次数**）。
3. **防爆破锁定前置检查**：
   - 调用 `LoginFailureLockService.isLocked(tenantIdStr, "admin", username, clientIp)`：
     - 若 IP 已被熔断锁定（30 次/30 分钟），抛出 `AuthResultCode(101004, "当前网络连续失败次数过多，IP 已被临时锁定，请稍后再试")`（可附带剩余秒数）；
     - 若当前账号作用域已锁定（5 次/15 分钟），读取 `remainSec = LoginFailureLockService.getDisableTime(tenantIdStr, "admin", username)`，抛出 `AuthResultCode(101004, "连续登录失败次数过多，账号已锁定，请在 X 分 Y 秒后重试")` 并在 `extra` 或结构化消息中携带剩余秒数供前端倒计时。
4. **账号与口令校验（防枚举统一计数）**：
   - 在 `TenantContextHolder.runWithTenant(tenantId, ...)` 下按 `username` 查询用户：
     - **用户不存在** 或 **`PasswordUtil.matches(password, user.password)` 为 `false`**：
       - 调用 `LoginFailureLockService.recordFailure(tenantIdStr, "admin", username, clientIp)` 返回 `remainCount`（0 表示刚触发锁定）；
       - 若 `remainCount <= 0`：读取锁定时间，立即抛出 `101004`；
       - 若 `remainCount > 0`：抛出 `AuthResultCode(101002, "用户名或密码错误，还剩 " + remainCount + " 次尝试机会（连续失败 5 次将锁定 15 分钟）")`（无论账号是否存在均走统一失败计数与同一报错，杜绝用户名枚举）。
     - **账号已停用**（`status != 0`）：抛出 `AuthResultCode(101003, "账号已被停用，请联系管理员处理")`（不计入密码失败次数）。
5. **登录签发与清零审计**：
   - 调用 `LoginFailureLockService.clearAllFailure(tenantIdStr, "admin", username, clientIp)` 清零失败计数；
   - 构造 `LoginUser` 并调用 `LoginHelper.login(loginUser, ...)` 签发 `satoken-admin` Token；
   - 通过 `DomainEventPublisher` 异步发布登录审计事件（含 `UserAgentUtil.parse(rawUa)`、IP、租户与成功状态）写入 `sys_login_log`；
   - 更新 `sys_user.login_ip` 与 `sys_user.login_date`。

#### 前端登录失败自动联动与倒计时规则
- **任意登录接口报错（`101001~101005` 等）**：只要 `captchaEnabled = true`，**必须立即清空 `captchaCode` 并重新调用 `loadCaptcha()` 刷新图片**（防止携带已被后端一次一密烧毁的 `captchaKey` 再次提交），同时保留用户已输入的 `username` 与 `tenantCode`。
- **锁定倒计时（`101004`）**：在登录表单上方高亮展示 `error` 警报框并启动秒级倒计时（如 `04分52秒`），倒计时期间禁用“登录”主按钮（按钮文案提示 `已锁定 (04:52)`）；一旦用户修改了 `username` 或 `tenantCode`（非 IP 熔断场景），立即清除当前账号维度的客户端倒计时恢复可提交态，归零时亦自动解锁。
- **登录中防重**：点击登录后通过 `v-idempotent` / `loading` 锁死按钮与输入提交（按钮显示 `"登录中..."`）。

#### 登录成功与 `redirect` 跳回兜底规则
1. 将 `tokenValue` 写入 `AuthManager`（`satoken-admin`）；将服务端返回的真实 `tenantId`（单租户为 `"0"`）写入 `TenantManager`（更新 `X-Tenant-Id`）。
2. 并行拉取 `GET /admin/auth/info` 与 `GET /admin/auth/routes`，注册动态路由至 Vue Router。
3. 解析 URL Query 中的 `redirect`：
   - **安全白名单校验**：必须是解码后以单个 `/` 开头且不以 `//` 或 `/\` 开头的站内相对路径（阻断开放重定向 `Open Redirect`），且路径前缀不属于 `/login`、`/403`、`/404`；
   - **权限可达校验**：在已加载的静态业务路由（`/dashboard`、`/profile`）或动态路由表中确能匹配且当前用户有权访问；
   - **兜底跳转**：满足以上全部条件时跳回 `redirect`，否则一律跳转 `/dashboard`（防止切换低权限账号后直接落入 `/403`）。

---

## 3. 轻量工作台（`/dashboard`）

### 3.1 页面定位与三区结构
遵循本路线图定稿基线：不新增 `/admin/system/dashboard` 聚合接口，不堆砌虚构数字 KPI 大块与装饰性英文眉标，100% 复用 `GET /admin/auth/info` 与 `GET /admin/auth/routes`。

1. **初始口令安全提醒横幅（条件渲染 · 非阻塞）**：
   - **触发条件**：`AdminProfileVO.passwordNeedsChange === true`（即 `sys_user.pwd_update_time IS NULL`，首次引导初始化、管理员新建或重置密码后尚未自主改密），且用户本次会话未点击“暂不提醒”。
   - **展示样式**：工作台最顶部克制的琥珀警告信息条（`--solid-warning-soft` + `--solid-warning-border`）：`"当前账号仍在使用初始或管理员重置口令，为保障账号安全建议尽快修改密码。"`
   - **交互动作**：右侧提供 `[立即修改密码]`（跳转 `/profile?tab=password`）与 `[本次不再提醒]`（关闭当前横幅，写入 `sessionStorage` 会话内暂隐；下次重新登录若仍未改密则再次提醒；用户完成改密后 `pwd_update_time` 落库非空，横幅永久消失）。

2. **第一区：欢迎头与会话身份摘要卡**：
   - 左侧：用户头像（未设或加载失败降级为昵称首字色块圆框）+ 按时段问候语（`早上好/下午好/晚上好，{nickname}`）+ 账号与所属部门信息。
   - 中/右侧摘要网格（紧凑 `1px` 细线栅格，等宽数字 `tabular-nums`）：
     - `当前账号`（`username`）与 `拥有角色`（渲染角色名标签，`super_admin` 高亮钴蓝主色标签）；
     - `当前工作租户`：单租户展示 `平台默认租户 (0)`；多租户开启展示当前 `X-Tenant-Id` 对应的租户名称与 ID（超管处于他租户视角时同步标示提示）；
     - `最近登录记录`：最近登录 IP 与最近登录时间（首次登录显示 `"首次登录管理台"`）。
   - 右上快捷按钮：`[个人中心]`（跳转 `/profile`）。

3. **第二区：按权限动态过滤的快捷导航网格**：
   - 数据源：从 `usePermissionStore` 持有的 `/admin/auth/routes` 扁平化提取当前用户可访问的叶子菜单（`menuType === 'C'`），默认展示最多 8~12 个入口卡片（3 列桌面网格 / 2 列平板 / 1 列窄屏）。
   - 卡片内容（零冗余装饰）：菜单图标 + 中文菜单标题 + 所属域名称（如 `组织权限`、`多租户治理`）+ 单行等宽路由路径（`/system/user`）；平台专属菜单标注克制的 `平台专属` 中性标签。
   - **受限空态（0 动态路由场景）**：若当前账号未被分配任何业务菜单权限，网格区展示友好引导卡：`"当前账号暂未分配业务模块访问权限，请联系管理员在【角色管理】中授予菜单权限"`，并提供 `[前往个人中心]` 按钮。

4. **第三区：系统运行基线与安全引导卡（轻量双栏说明）**：
   - 左卡（`框架运行态概要`）：展示当前多租户模式状态（`单租户默认态` vs `SaaS 多租户已开启`）、会话体系（`satoken-admin`）与多页签快捷操作提示（右键页签支持组件级刷新与批量关闭、右上支持工作区最大化）。
   - 右卡（`账号与安全规范指引`）：摘要提示敏感字段脱敏查看/编辑真明文规则、密码强度要求及在线会话自查入口（有 `auth:online:list` 权限时提供 `[查看在线会话]` 快捷链接）。

---

## 4. 个人中心（`/profile`）

### 4.1 路由入口与左右分栏布局
- 路由 `/profile` 不出现在左侧动态菜单中（`hidden: true`），统一通过顶栏右上角用户头像下拉菜单中的 `个人中心`（跳转 `/profile`）与 `修改密码`（跳转 `/profile?tab=password`）进入，并作为普通可关闭页签出现在 `AtengTabsNav`。
- **桌面端双栏布局**（左栏固定宽 `340px`，右栏自适应 `flex: 1`；`< 960px` 上下堆叠）：

#### 左栏：只读身份概览卡（`AtengDescriptions` 契约）
- **顶部头像与角色区**：
  - `72×72` 圆形头像预览 + 悬浮/下方按钮 `[更换头像]`（仅支持 `jpg/jpeg/png/webp`、`<= 2MB`）；头像图片 `onerror` 自动降级渲染为昵称首字钴蓝底头像，绝不显示浏览器裂图图标；
  - 展示 `nickname`（主标题）、`username`（等宽辅助字）及角色胶囊列表。
- **只读属性列表（`1px` 细分割线列表）**：
  - `所属租户`（多租户开启时显示 `tenantName (tenantId)`，单租户显示 `平台默认租户`）；
  - `所属部门`（`deptName`，无部门显示 `--`）；
  - `所属岗位`（`postNames.join(' / ')`，无岗位显示 `--`）；
  - `手机号码`：使用 `formatMaskPhone` 渲染脱敏串（如 `138****5678`），右侧提供 `v-copy` 复制按钮——**点击复制完整内存真明文**；未设置显示 `--`；
  - `电子邮箱`：使用 `formatMaskEmail` 渲染脱敏串，右侧提供一键复制真明文按钮；
  - `账号创建时间` 与 `最近登录`（IP + 时间，全等宽 `tabular-nums`）。

#### 右栏：双页签维护区（`基本资料` | `修改密码`）

##### 页签 1：基本资料（`PUT /admin/auth/profile`）
- **内存真明文铁律**：进入页面加载 `GET /admin/auth/profile` 返回的**完整未脱敏字段**填入表单输入框，绝不允许把 `138****5678` 回填进 `<el-input>`。
- **可改 vs 禁改范围**：
  - **禁止自助修改**（左栏只读展示或置灰禁用并说明原因）：`username`（登录账号）、所属租户、所属部门、所属岗位、分配角色、账号状态。
  - **允许修改字段**：
    1. `nickname`（用户昵称）：必填，`2~30` 字符，去首尾空格；
    2. `phone`（手机号码）：选填，留空允许清空手机号；非空时校验正则 `^1[3-9]\d{9}$`，后端校验同租户内未软删用户唯一性（冲突抛 `102002: "手机号码已被其他账号使用"`）；
    3. `email`（电子邮箱）：选填，留空允许清空邮箱；非空时校验标准邮箱格式并限长 `<= 64`，后端校验同租户内唯一性（冲突抛 `102002: "电子邮箱已被其他账号使用"`）；
    4. `gender`（性别）：使用 `<AtengDictRadio dict-code="sys_user_gender" />` 消费动态字典（`0=男`、`1=女`、`2=未知`）。
- **提交动作**：主按钮 `[保存基本资料]`（接入 `v-idempotent` + 异步 loading 锁）与 `[重置还原]`（将表单恢复为最近一次服务端拉取的初始值）。保存成功后弹出 `"已保存个人资料"` 并同步更新 `useAuthStore`（顶栏昵称即时生效）及左栏只读概览卡。

##### 头像直传（`POST /admin/auth/profile/avatar`）
- 使用 `<AtengUpload>`（`chunk: false`、`accept=".jpg,.jpeg,.png,.webp"`、`:max-size="2 * 1024 * 1024"`、`:show-file-list="false"`、`:http-request="uploadAvatarRequest"`）。
- **前置拦截与后端魔数双防线**：
  - 前端选择文件后先校验扩展名/MIME 与 `2MB` 体积上限，不合规则通过 `type-reject` / `size-exceed` 原位提示 `"仅支持 JPG、PNG、WEBP 格式且大小不超过 2MB 的图片"`，不发起请求；
  - 后端开启 `ateng.boot.storage.guard.enabled=true` 与 `strict-magic-check=true` 校验文件头魔数防伪装扩展名（非法报 `100004`），上传至路径 `avatar/{tenantId}/{userId}/{uuid}.{ext}`，更新 `sys_user.avatar` 并返回新 URL；
  - 上传期间头像框显示 loading 态，失败时保持原头像不变并给出明确错误提示（不清空旧头像）；成功后立即刷新本地 `useAuthStore.avatar` 与顶栏头像。

##### 页签 2：修改密码（`PUT /admin/auth/password`）
- **表单字段与统一口令复杂度基线**（与后台新建用户、重置密码口径保持 100% 一致）：
  1. `oldPassword`（当前密码）：必填，支持显隐切换；错误时后端抛 `AuthResultCode(101006, "当前密码输入有误，请核对后重试")`，前端保持页签现场并高亮当前密码字段；
  2. `newPassword`（新密码）：必填，实时展示 4 项规则达成指示器：
     - 长度 `8~20` 个字符；
     - 不得包含空格或制表符等空白字符；
     - 至少包含“大写字母（A-Z）、小写字母（a-z）、数字（0-9）、特殊字符（`!@#$%^&*()_+-=[]{}|;':",./<>?`）”中的 **3 类**；
     - 不能与当前密码完全一致；
  3. `confirmPassword`（确认新密码）：必填，前端实时校验与 `newPassword` 一致（后端 `UpdatePasswordRequest` 不传此冗余字段，仅由前端做双写防呆）。
- **改密后强制全端下线重登**：
  1. 后端校验旧密码通过并确认新密码合规后，使用 `PasswordUtil.hash(newPassword)` 更新 `sys_user.password` 并同步写入 `pwd_update_time = now`；
  2. 后端立即注销该用户当前登录态及同一用户下的全部活跃 `admin` 会话（`LoginHelper.logout("admin", compositeLoginId)`），保障旧令牌及历史未注销端彻底失效；
  3. 前端收到 `200` 后清空本地 `AuthManager`、`TenantManager`（重置回 `"0"`）、Pinia 权限与页签缓存，弹出明确提示 `"密码已修改，请使用新密码重新登录"` 后自动跳转 `/login`。

---

## 5. 在线会话（`/system/online`）与异常页（`/403`、`/404`）

### 5.1 在线会话（`/system/online`）

#### 权限与多租户视角边界
- 访问页面与检索：`auth:online:list`；执行强退：`auth:online:kickout`。
- **强租户隔离**：后端强制从上下文取当前生效 `tenantId` 构造 `OnlineUserQuery.setTenantId(effectiveTenantId)`：
  - 单租户模式：固定只查询 `"0"` 租户会话；
  - 多租户开启：普通租户管理员只查归属租户会话；平台超管默认看 `"0"` 租户会话，当且仅当超管在顶栏切换 `X-Tenant-Id` 至租户 `T` 时查看租户 `T` 的在线会话。
- **不透明会话句柄防泄漏**：列表接口 `GET /admin/auth/online/page` **禁止下发原始 `tokenValue`**，由服务端生成仅可用于展示的 `tokenMask`（如 `f9a2c1****7e3b`）与不可用于 `satoken-admin` 认证的服务端加密句柄 `sessionId`；`DELETE /admin/auth/online/{sessionId}` 在后端解密/反查还原出真实 `tokenValue` 后：
  1. 若 `realToken.equals(StpLogic.getTokenValue())`，硬拦截抛出 `AuthResultCode(101007, "当前会话正在使用中，不可强退自身会话")`；
  2. 调用 `LoginHelper.kickoutByTokenForTenant("admin", realToken, effectiveTenantId)`，确保不可跨租户踢人（越权抛 `403`）；
  3. 同步触发操作审计 `@OperateLog(module = "在线会话", type = OperateTypeEnum.FORCE)`（或 `LOGOUT` 对齐 `OperateTypeEnum` 11 常量，见下表注）——注：`ateng-boot` `OperateTypeEnum` 常量为 `LOGOUT` / `DELETE` / `OTHER`，本强退操作统一标注 `type = OperateTypeEnum.LOGOUT, description = "强退在线会话"`。

#### 检索区、表格列与操作保护（严格对齐 `OnlineUser` 原生字段）
- **检索区（`AtengQueryForm`，`defaultCollapsed: true, collapsedRows: 1`）**：
  - `username`（登录账号，模糊包含匹配）；
  - `clientIp`（客户端 IP / CIDR 网段，如 `192.168.1.10` 或 `10.10.2.0/24`，提供占位提示说明支持 CIDR）；
  - 操作按钮：`[查询]`、`[重置]`（接入 `v-idempotent`；输入框按 `Enter` 忽略 IME 选词触发查询）。
- **表格区（`AtengTable`，默认每页 `10` 条，`storageKey: 'solid:table:online-session'`）**：
  - 工具栏右侧标准 5 工具（刷新、密度、斑马纹、列配置、表格全屏）；左侧可展示轻量说明徽标（当 `total >= 2000` 时提示 `"当前仅展示最近扫描的 2000 条活跃会话，请通过账号或 IP 缩小范围"`）。
  - 表格列清单（无复选框，仅保留单行强退）：
    1. `会话标识`：`tokenMask` 等宽字显示；若 `currentSession === true`，紧跟主色标签 `[当前会话]`；
    2. `登录账号`：`username`（等宽字）；
    3. `用户昵称`：`nickname`；
    4. `登录终端`：`loginDevice`（如 `PC` / `default` 格式化徽标）；
    5. `客户端 IP`：`clientIp`（`tabular-nums`）；
    6. `登录时间`：`loginTime`（后端已格式化或前端转 `yyyy-MM-dd HH:mm:ss`，`tabular-nums`）；
    7. `剩余有效期`：`tokenTimeout`（秒转为易读时长如 `23小时18分`，`<= 300s` 时琥珀色提示即将过期，`-1` 显示 `长期有效`）；
    8. `操作`（固定右侧 `fixed="right"`，受 `v-permission="'auth:online:kickout'"` 控制）：
       - 动作按钮 `[强退]`（危险文字链按钮）；
       - **自身会话硬护栏**：当 `row.currentSession === true` 时，按钮直接置灰禁用（`disabled`）并悬停提示 `"不可强退当前正在使用的会话"`；
       - 点击其他会话 `[强退]` 弹出二次确认框（`AtengDialog` `480px`）：`"确认将账号【{username}】（IP: {clientIp}）强制下线？下线后该会话需重新登录。"`，按钮文案 `[确认强退]`；确认后调用 `DELETE /admin/auth/online/{sessionId}`，成功后刷新表格并提示 `"已强退在线会话"`（若目标已自然过期，幂等返回 `200` 并刷新列表）。
- **三态缺省页**：区分网络加载失败（`[重试]`）、按账号/IP 未查到（`[清空筛选条件]`）与当前租户暂无其他在线会话。

### 5.2 异常页（`/403`、`/404`）

| 页面 | 触发条件 | 渲染容器与视觉规范 | 引导动作 |
| :--- | :--- | :--- | :--- |
| **`/403`（权限不足）** | 已登录访问未授权动态路由，或手动跳转 `/403` | 已登录态嵌入 `AdminLayout` 工作区居中展示；未挂载布局直接访问时自适应居中全屏卡。大号等宽状态码 `403` + 清晰标题 `"暂无当前页面访问权限"` + 引导说明 `"当前账号未获授予该模块访问权限，请联系系统管理员或租户管理员分配对应角色菜单"` | 主按钮 `[返回工作台]`（跳 `/dashboard`）；次按钮 `[返回上一页]`；若检测当前账号动态菜单为空（无可用导航），追加 `[退出登录]` 兜底切换账号 |
| **`/404`（页面不存在）** | 访问不存在路径，或后端菜单配置 `component` 在 `import.meta.glob` 中未命中真实文件 | 未登录访问未知路径直接由前置守卫重定向至 `/login?redirect=...`；已登录态在 `AdminLayout` 工作区内渲染，大号等宽状态码 `404` + 标题 `"页面不存在或菜单组件未配置"` + 等宽展示当前未命中路径 | 主按钮 `[返回工作台]`；次按钮 `[返回上一页]`（且自动提供 `[关闭当前页签]` 若当前位于多页签中） |

---

## 6. 本域 API 契约与错误码完整速查表

### 6.1 后端接口契约（`/admin/auth/**`）

| 端点 | 方法 | 鉴权 | 入参模型 | 出参模型 (`Result<T>`) |
| :--- | :---: | :---: | :--- | :--- |
| `/admin/auth/captcha` | `GET` | `@Anonymous` | 无 | `CaptchaVO` (`enabled`, `tenantEnabled`, `captchaKey`, `imageBase64`, `expireSeconds`) |
| `/admin/auth/login` | `POST` | `@Anonymous` | `AdminLoginRequest` (`tenantCode`, `username`, `password`, `captchaKey`, `captchaCode`, `grantType?`) | `AdminLoginVO` (`tokenName`, `tokenValue`, `expireIn`, `tenantId`, `tenantName`) |
| `/admin/auth/logout` | `POST` | `@SaCheckLogin` | 无 | `Void` |
| `/admin/auth/info` | `GET` | `@SaCheckLogin` | 无 | `AdminProfileVO` (`userId`, `tenantId`, `tenantName`, `username`, `nickname`, `avatar`, `roles`, `permissions`, `passwordNeedsChange`, `loginIp`, `loginDate`) |
| `/admin/auth/routes` | `GET` | `@SaCheckLogin` | 无 | `List<RouteMenuVO>` |
| `/admin/auth/profile` | `GET` | `@SaCheckLogin` | 无 | `PersonalProfileVO` (`userId`, `tenantId`, `tenantName`, `username`, `nickname`, `email`, `phone`, `gender`, `avatar`, `deptName`, `postNames`, `roles`, `loginIp`, `loginDate`, `createTime`, `passwordNeedsChange`) |
| `/admin/auth/profile` | `PUT` | `@SaCheckLogin` | `UpdateProfileRequest` (`nickname`, `email`, `phone`, `gender`) | `Void` |
| `/admin/auth/profile/avatar` | `POST` | `@SaCheckLogin` | `MultipartFile file` (`<=2MB`, `jpg/jpeg/png/webp`) | `AvatarUploadVO` (`avatarUrl`, `objectPath`) |
| `/admin/auth/password` | `PUT` | `@SaCheckLogin` | `UpdatePasswordRequest` (`oldPassword`, `newPassword`) | `Void` |
| `/admin/auth/online/page` | `GET` | `@SaCheckPermission("auth:online:list")` | `OnlineSessionQuery` (`username?`, `clientIp?`, `current`, `size`) | `PageResult<OnlineSessionVO>` (`sessionId`, `tokenMask`, `currentSession`, `userId`, `username`, `nickname`, `tenantId`, `loginDevice`, `clientIp`, `loginTime`, `tokenTimeout`) |
| `/admin/auth/online/{sessionId}` | `DELETE` | `@SaCheckPermission("auth:online:kickout")` | 路径参数 `sessionId` | `Void` |

### 6.2 错误码与前端可操作反馈矩阵

| 错误码 | 常量语义 | 触发场景 | 前端交互响应 |
| :---: | :--- | :--- | :--- |
| `101001` | `CAPTCHA_INVALID` | 图形验证码为空、错误或过期 | 表单顶/字段提示具体原因，自动清空 `captchaCode` 并刷新图片 |
| `101002` | `BAD_CREDENTIALS` | 账号不存在或密码错误（防枚举统一计数） | 提示 `"用户名或密码错误，还剩 X 次尝试机会"`，刷新验证码并清空 `captchaCode` |
| `101003` | `ACCOUNT_DISABLED` | 用户状态已停用 | 提示 `"账号已被停用，请联系管理员处理"`，刷新验证码 |
| `101004` | `LOGIN_LOCKED` | 账号连续失败 `>=5` 次或 IP 连续失败 `>=30` 次 | 表单警报区展示锁定剩余分/秒并启动实时倒计时禁用提交，刷新验证码 |
| `101005` | `TENANT_UNAVAILABLE` | 租户不存在、已停用或已过有效期 | 提示 `"所属租户不存在、已停用或已过期"` 并聚焦租户编码框，刷新验证码 |
| `101006` | `OLD_PASSWORD_MISMATCH` | 修改密码旧密码验证失败 | 保留当前改密表单现场，在旧密码下方/顶部提示 `"当前密码输入有误"` |
| `101007` | `CANNOT_KICKOUT_SELF` | 尝试强退当前自身会话（兜底拦截） | 列表按钮已前置置灰禁点；若并发触发接口报错则弹窗提示 `"不可强退当前正在使用的会话"` |
| `100004` | `FILE_GUARD_REJECTED` | 头像文件非图片魔数或超 `2MB` | 上传框原位提示允许格式与体积限制，保留既有头像 |
| `102002` | `DUPLICATE_CONTACT` | 个人资料修改后的手机号/邮箱同租户内冲突 | 保持编辑表单不清空，在对应字段旁明确提示重复项 |

---

## 7. UX 与反模板自检验收清单（对齐 `ux-and-copy-checklist.md`）

- [x] **对比度与焦点环**：登录页双栏、工作台卡片、个人中心表单与错误页全部沿用 `design-system.md` Light/Dark 语义变量，所有文本满足 `>= 4.5:1`，任意控件保留 `:focus-visible` 双层钴蓝焦点环。
- [x] **等宽防抖与真明文**：会话 ID、IP、时间戳、倒计时、剩余秒数全部启用 `tabular-nums`；`/profile` 左栏脱敏展示、复制真明文、编辑表单加载真明文。
- [x] **无虚构 KPI 与冗余噪声**：`/dashboard` 零假大统计数字方块、零修饰性英文眉标、零无关卡片渐变阴影；动作动词全链路一致（`登录`、`保存基本资料`、`修改密码`、`强退` -> `确认强退` -> `已强退在线会话`）。
- [x] **高危与防重护栏**：登录/保存/改密/强退均接入异步防连点锁；强退当前自身会话置灰不可点；修改密码成功后强制清空全部会话并重登。
