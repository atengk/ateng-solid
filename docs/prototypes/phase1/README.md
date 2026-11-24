# ateng-solid 第一阶段（MVP 内核）高保真可交互原型套件

> **关联路线图**：`atengk/ateng-solid#1`（PRD 与高保真交互原型路线图） · `atengk/ateng-solid#9`（全站原型总装与人机联调走查）
> **设计真源**：[Precision Slate & Cobalt 设计系统](../../specs/prd/design-system.md) · [全站交互规范总纲](../../specs/prd/00-overview-and-ux-standards.md) · [01~04 业务域 PRD](../../specs/prd/)
> **运行方式**：全部 HTML 文件均采用**单文件零外部依赖（Zero CDN）**实现，内联 SVG 与纯原生 HTML/CSS/JS，可直接离线双击在浏览器中打开交互。

---

## 1. 原型套件目录导航

| 文件 | 定位 | 关联工单 | 核心用途与适用走查场景 |
| :--- | :--- | :--- | :--- |
| **[index.html](./index.html)** | **全站一体化总装原型（主入口）** | `#9` | 串联 `/login`、`/dashboard`、`/profile`、12 个 `/system/*` 模块与 `/403`、`/404` 共 **17 条第一阶段路由**，内置跨模块实时联动（新建用户同步写操作日志、登录后写登录日志）、底部悬浮总控台、17 路由覆盖矩阵弹窗、多页签 6 指令右键菜单与工作区最大化 |
| **[shell-variants.html](./shell-variants.html)** | 布局方案 A/B/C 多方案比选原型 | `#4` | 用于对比经典左侧栏（A）、双栏折叠组（B）与紧凑顶栏混排（C）的视觉结构 |
| **[shell-accepted.html](./shell-accepted.html)** | **定稿基础壳原型（方案 A）** | `#4` | 锁定 `Precision Slate & Cobalt` Light/Dark 令牌与方案 A（`228px`/`60px` 左侧栏 + `48px` 单行顶栏 + `36px` 独立页签栏），作为全站基础壳与组件对齐参考基线 |
| **[auth-and-workspace.html](./auth-and-workspace.html)** | 认证、工作台、个人中心与会话切片 | `#5` | 深挖 `/login` SVG 验证码与防爆破倒计时、`redirect` 安全白名单测试、`/profile` 头像预览及 `/system/online` 多标签在线会话细节 |
| **[org-and-rbac.html](./org-and-rbac.html)** | 组织架构与 RBAC 专题切片 | `#6` | 深挖部门 `ancestors` 级联与 `user/options`、菜单 `M`/`C`/`F` 与外链校验、角色树父子联动与 `@DataScope` `CUSTOM` 自定部门树、Fesod Excel 500 行原子校验及标红批注下载全流程 |
| **[tenant-and-package.html](./tenant-and-package.html)** | SaaS 多租户与租户套餐专题切片 | `#7` | 深挖套餐自动剔除 `platform_only` 菜单与 `shrink-preview` 缩减裁剪预览、新建租户 4 步原子初始化凭据回显、`0` 号保护及停用/过期会话踢出联动 |
| **[enum-dict-config-audit.html](./enum-dict-config-audit.html)** | 枚举、字典、参数与审计日志切片 | `#8` | 深挖 7 项静态枚举 `/admin/system/enums` 只读调试、`/system/dict` 同屏双面板联动与 `dictType` 锁定/`isDefault` 互斥、`sys_config` 内置保护及只读审计日志 `720px` 脱敏详情抽屉 |

---

## 2. 一体化总装入口 (`index.html`) 操控说明

打开 [index.html](./index.html) 默认直接进入方案 A 工作台 `/dashboard`（`tenantEnabled` 初始为 `false`，匹配后端默认单租户开关），底部常驻 **全站原型总控台 (`.sim-bar`)**，支持一键切换状态：

| 总控按钮 | 功能说明 | 对应后端/前端契约 |
| :--- | :--- | :--- |
| `登录页` | 切换至全屏独立认证舞台 `/login`（含 SVG 图形验证码与单/多租户联动） | `/admin/auth/captcha` · `/admin/auth/login` |
| `工作台` | 跳转 `/dashboard`，展示初始口令提醒横幅与动态过滤后的快捷模块卡片 | `/admin/auth/info` · `/admin/auth/routes` |
| `用户/Excel` | 跳转 `/system/user`，支持左树按部门筛选、新增用户抽屉及 Fesod 批注弹窗演示 | `/admin/system/user*` · `AtengExcelFeedback` |
| `角色/@DataScope` | 跳转 `/system/role`，支持对非受保护角色分配 5 级 `@DataScope` 与自定部门勾选 | `/admin/system/role/{id}/data-scope` |
| `租户/套餐` | 跳转 `/system/tenant`，联动演示配额统计与租户-套餐关系（需开启多租户） | `/admin/system/tenant*` |
| `Light` / `Dark` | 一键在 `html` 与 `html.dark` 间切换 `Precision Slate & Cobalt` 全站令牌 | `design-system.md` §1~§2 |
| `多租户: 关/开` | 切换 `state.tenantEnabled`，同步隐藏/显现登录页租户输入、顶栏切换器与租户/套餐菜单 | `ateng.solid.tenant.enabled`（默认 `false`） |
| `超管 (0)` / `租户管理员` / `无菜单专员` | 循环切换 3 类典型操作者身份（含超级管理员切工作租户后隐藏 `platform_only=1` 菜单、无菜单用户自动导向 `/403` 兜底退出口） | `X-Tenant-Id` · `platform_only` |
| `覆盖矩阵 & 异常模拟` | 打开 720px 覆盖矩阵弹窗，支持点击直达全部 **17 条第一阶段路由** | `AtengProLayout` 完整路由表 |

---

## 3. 全站 17 路由覆盖与双载体映射

| # | 路由路径 | 页面名称 | 导航域 | 总装原型 (`index.html`) 覆盖点 | 专题切片深化覆盖 |
| :-: | :--- | :--- | :--- | :--- | :--- |
| 1 | `/login` | 管理端登录页 | 独立舞台 | SVG 验证码、单/多租户输入显隐、101001/101004/101005 报错与一键填密 | `auth-and-workspace.html` |
| 2 | `/dashboard` | 轻量工作台 | 首页（固定页签） | `pwdUpdateTime === null` 改密提醒、当前租户摘要、按权限/租户开关过滤的快捷导航卡片 | `auth-and-workspace.html` |
| 3 | `/profile` | 个人中心 | 顶栏用户下拉 | 左侧卡片脱敏展示 + 复制真明文；基本资料回写与动态字典性别；改密校验并重登 | `auth-and-workspace.html` |
| 4 | `/system/user` | 用户管理 | 组织权限 | 左树右表分栏、动态读 `sys.user.initPassword`、配额上限 `102006` 拦截、Excel 批注流、密度/斑马纹/全屏、`500`/`429` 模拟、内置/自己禁删 | `org-and-rbac.html` |
| 5 | `/system/role` | 角色管理 | 组织权限 | `super_admin` 内置只读护栏、非内置角色分配 5 级 `@DataScope` 与 `CUSTOM` 自定部门树校验 (`100001`) | `org-and-rbac.html` |
| 6 | `/system/dept` | 部门管理 | 组织权限 | 展示层级 `ancestors` 路径与联系电话手机号脱敏渲染 | `org-and-rbac.html` |
| 7 | `/system/post` | 岗位管理 | 组织权限 | 岗位编码、名称、状态标签与备注列表展示 | `org-and-rbac.html` |
| 8 | `/system/menu` | 菜单管理 | 组织权限（平台专属） | `M`/`C`/`F` 类型展示与 `platform_only=1` 平台专属标识 | `org-and-rbac.html` |
| 9 | `/system/tenant` | 租户管理 | 多租户治理（平台专属） | 租户编码/关联套餐/配额占用统计 (`accountCount=-1` 不限)/过期时间展示 | `tenant-and-package.html` |
| 10 | `/system/tenant-package` | 租户套餐 | 多租户治理（平台专属） | 套餐包含菜单数量与排除 `platform_only` 规则提示 | `tenant-and-package.html` |
| 11 | `/system/dict` | 数据字典 | 基础配置（平台专属） | 左类型 (`sys_dict_type`) / 右数据 (`sys_dict_data`) 同屏双面板联动、标签预览与默认项标识 | `enum-dict-config-audit.html` |
| 12 | `/system/config` | 系统参数 | 基础配置 | 按当前租户隔离展示 `sys.user.initPassword` 等键值与 `系统内置 (Y)`/`业务自建 (N)` 类型标记 | `enum-dict-config-audit.html` |
| 13 | `/system/oper-log` | 操作日志 | 审计安全 | 严格只读（无删改导），实时接收原型中个人中心/用户/角色/会话产生的日志，`720px` 抽屉查看 `[EXCLUDED]` 脱敏 JSON | `enum-dict-config-audit.html` |
| 14 | `/system/login-log` | 登录日志 | 审计安全 | 严格只读，实时追加 `/login` 成功/失败（101002/101004）及浏览器/OS 解析记录 | `enum-dict-config-audit.html` |
| 15 | `/system/online` | 在线会话 | 审计安全 | `tokenMask` + `sessionId` 防泄漏、`当前会话` 自保禁强退 (`101007`)、强退他人后写入 `DELETE` 审计日志 | `auth-and-workspace.html` |
| 16 | `/403` | 无权访问页 | 异常页 | 返回工作台；当无任何授权菜单（`no_menu_user`）时显式提供`退出登录`防死锁出口 | `shell-accepted.html` |
| 17 | `/404` | 未匹配路由页 | 异常页 | 展示 404 状态与返回工作台引导 | `shell-accepted.html` |

---

## 4. 全站原型演示样本数据集（摘自 `index.html` 内存库）

| 域 | 关键演示样本（唯一真源字段对齐 PRD） | 用途与验证要点 |
| :--- | :--- | :--- |
| **租户 (`DB.tenants`)** | `0`（编码 `000000`，平台默认租户，`protected: true`，`accountCount: -1`）<br>`10002`（编码 `100002`，星辰智能科技，`pkg_std`，`accountCount: 4`，`expireTime: 2027-12-31 23:59:59`）<br>`10003`（编码 `100003`，云港物流集团，`pkg_std`，`accountCount: -1`，`expireTime: null`） | 验证 `0` 号租户单/多态通用、`accountCount=-1` 不限、`>=1` 配额校验及 `NULL` 永久 |
| **租户套餐 (`DB.packages`)** | `pkg_std`（标准企业版套餐，9 个授权菜单）<br>`pkg_lite`（轻量团队版套餐，4 个授权菜单） | 验证套餐菜单范围及租户引用关系 |
| **部门 (`DB.depts`)** | 平台 `0`：`100 平台总部 (ancestors: 0)` → `101 研发中心 (0,100)` → `102 后端架构组 (0,100,101)`、`103 财务合规部 (0,100)`<br>星辰 `10002`：`200 星辰科技总部` → `201 智能制造事业部`<br>云港 `10003`：`300 云港物流总部` | 验证按租户隔离的部门树、`ancestors` 与 `@DataScope` 自定部门勾选 |
| **岗位 (`DB.posts`)** | 平台 `0`：`arch`（系统架构师）、`dev`（研发工程师）；`10002`：`xc_mgr`；`10003`：`yg_ops` | 验证按租户隔离的岗位选项 |
| **角色 (`DB.roles`)** | `r1 super_admin`（平台内置受保护，`ALL`，`*:*:*`）<br>`r2 ops_manager`（`CUSTOM`，已选部门 `101`/`102`）<br>`r10`/`r20 tenant_admin`（星辰/云港租户默认管理角色） | 验证 `super_admin` 不可编辑保护与 `CUSTOM` 至少选 1 部门规则 |
| **用户 (`DB.users`)** | 平台 `0`：`super_admin`（`protected: true`，密码更新时间已设置）、`chenmo`（`isSelf: true`，`pwdUpdateTime: null`）、`linyun`<br>星辰 `10002`：`xc_admin`、`zhangwei`<br>云港 `10003`：`yg_admin`<br>无菜单态：`guest_clerk`（虚拟待授权用户，触发 `/403` 退出兜底） | 验证内置禁删、自己禁删、初始密码 `Ateng@2026`、`pwdUpdateTime===null` 提醒条与个人中心真明文复制 |
| **字典 (`DB.dictTypes` / `dictData`)** | `sys_user_gender`（男 `0` / 女 `1` / 未知 `2` 默认）<br>`sys_yes_no`（是 `Y` / 否 `N` 默认） | 验证动态字典与 `/profile` 性别渲染联动 |
| **系统参数 (`DB.configs`)** | 键名 `sys.user.initPassword`：平台 `0` 为 `Ateng@2026`，租户 `10002` 为 `XingChen#2026`（`configType: 'Y'`） | 验证新增用户抽屉按当前有效租户动态预填初始口令 |
| **在线会话与日志** | `sid_self chenmo`（`at9f81****3d40`，`currentSession: true`）、`sid_linyun linyun`（`at3d12****811f`）、`sid_xc1 xc_admin`（`atxc11****022a`） | 验证自身会话禁强退 (`101007`) 及强退/改密/新增操作实时写入日志 |

---

## 5. 全站异常与边界状态覆盖矩阵

> 覆盖 Map `#1` 规定的 **全站原型演示样本与异常覆盖矩阵** 验收标准：

| 覆盖维度 | 状态场景 | 原型中触发/查看路径 | 预期表现与对齐契约 |
| :--- | :--- | :--- | :--- |
| **正常与初始导引** | `/dashboard` 初始口令温和提醒 | 登录或以 `chenmo` 查看 `/dashboard` | 顶部展示可关闭黄色 `alert-warning`，支持跳转 `/profile?tab=password` 或点击 `本次不再提醒` |
| **认证与防御边界** | 验证码错误 (`101001`) / 密码错误 (`101002`) / 5 次锁定 (`101004`) / 租户异常 (`101005`) | 切换 `/login`，分别输入错误验证码、开启多租户输错编码 `999999` 或连续 5 次错密码 | 输出对应业务码警告框、刷新 SVG 验证码、达到 5 次后禁用提交按钮 `已锁定 (15分钟)` 并写入登录日志 |
| **筛选空态与兜底重置** | 查询条件无匹配记录空态 | `/system/user` 搜索框输入无匹配关键词并查询 | 表格内合并列展示空状态提示，并提供一键`清空筛选条件`复位链接 |
| **网络/限流异常处理** | `500` 服务异常 + `traceId` / `429` 限流提示 | `/system/user` 工具栏点击 `模拟 500` 或 `模拟 429` | `500` 展示带 `trc-sim-500err` 的失败卡片与`重试`按钮；`429` 弹出限流提示 |
| **表单校验与配额拦截** | 账号正则/重名 `102002` / 密码 3 类字符 / 租户配额上限 `102006` | `/system/user` 打开 `+ 新增用户`；在配额满租户提交或输入非法字段 | 表单内联红色错误提示 + 顶部配额告警条（`102006`）阻止提交 |
| **Excel 批注回执流** | Fesod 整批 0 入库 + 行列级错误明细 | `/system/user` 点击 `演示 Excel 导入批注流` | 打开 `720px` `AtengExcelFeedback` 弹窗展示 3 条行错误并支持下载 `.xlsx` 批注反馈，同时写入审计日志 |
| **多租户双态与隔离** | `tenantEnabled=false` 单租户隐藏 / `tenantEnabled=true` 切租户隐去 `platform_only` | 底部切换 `多租户: 关/开`；开启后顶栏点击 `租户: 平台默认租户 (0) ▾` 切至 `10002` | 单租户隐藏租户输入与菜单；超管切租户后弹出警告条、关闭非固定页签并隐藏 `/system/menu`、`/dict`、`/tenant*` |
| **防误触与越权兜底** | `super_admin`、`tenant=0`、内置参数与自身会话保护；零菜单用户 `/403` | `/system/role`、`/system/online` 及总控台切至 `无菜单专员` | 受保护按钮呈 `disabled` 并附原因 `title`；无菜单用户进入 `/403` 展示`退出登录`出口防死锁 |
| **字段脱敏与真明文** | 列表/左侧栏脱敏显示 vs 编辑框/复制真明文 vs 审计日志 `[EXCLUDED]` | `/profile`、`/system/user`、`/system/dept`、`/system/oper-log` | 列表手机号 `139****5678`、邮箱 `c***@ateng.dev`、`tokenMask`；个人中心编辑与复制保留真明文；审计 JSON 密码脱敏 |
| **多页签与主题响应** | `AtengTabsNav` 6 指令右键菜单、工作区最大化与 Light/Dark 双主题 | 右键页签标签触发 `刷新`/`关闭当前`/`关闭左侧`/`关闭右侧`/`关闭其他`/`关闭全部`；点 `⤢`；点 `Light/Dark` | `/dashboard` 固定页签受保护；最大化隐藏侧栏/顶栏并支持 `Esc` 退出；全站色彩同步切换且零外部资源依赖 |

---

## 6. 自动化与本地脚本验证记录

在 `#9` 总装收口验证阶段，通过 Node.js VM 对 `docs/prototypes/phase1/` 目录下全部 **7 份 `.html` 原型**执行解析与 DOM 事件审计：
- **脚本语法校验**：7 份原型文件内联 `<script>` 全部通过 `vm.Script` 语法解析。
- **一体化交互与事件属性全量审计 (`index.html`)**：遍历验证全部 **17 条第一阶段路由**、Login（`101001` / `101005` / `101004` / 正常登录）、Profile（基础资料回写与操作日志写入、改密态）、Popovers 与 Tabs 6 指令右键菜单、筛选空态、`500` 模拟、`user_create` / `excel_feedback` / `datascope` / `oper_detail` 弹窗抽屉、超管跨租户隐藏 `platform_only`、无菜单用户 `/403` 退出兜底、Light/Dark 与 `tenantEnabled` 开关切换，累计审计通过 **1,046 个内联 DOM 事件处理器**（无引号断串或语法错误）。
- **外部依赖审计**：`rg` 核对无任何外部 CDN `<link>` 或 `<script src>` 引用，保证 100% 离线打开。

---

## 7. 人机联调走查核对表（HITL Sign-Off）

请评审确认以下各项后，即可签收关闭 `#9` 并推进 `#10` 终审归档：

1. **全链路交互贯通**：`index.html` 中 `/login` → `/dashboard` → `/profile` → 12 个 `/system/*` 模块 → `/403` / `/404` 跳转与覆盖矩阵入口是否顺畅？
2. **视觉与布局还原**：`Precision Slate & Cobalt` Light/Dark 色彩、方案 A 侧栏（`228px`/`60px`）/顶栏（`48px`）/页签栏（`36px`）高度与留白、弹窗与抽屉尺度（`index.html` 采用 `520px`/`720px` 面板演示，`00-overview-and-ux-standards.md` 规定正式编码档位为 `480/640px` Dialog 与 `360/500/720px` Drawer）是否符合预期？
3. **双态与安全语义**：`tenantEnabled` 单/多租户切换、平台超管切换租户隐藏 `platform_only` 菜单、脱敏渲染 vs 真明文编辑及高危保护语义是否准确无误？
4. **切片协同深度**：`auth-and-workspace.html`、`org-and-rbac.html`、`tenant-and-package.html`、`enum-dict-config-audit.html` 四份专项切片的细粒度交互（如套餐缩减裁剪预览、Fesod 批注明细、字典同屏修改、安全 `redirect` 校验等）是否满足编码参照需求？
