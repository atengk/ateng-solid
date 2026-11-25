# 第一阶段静态枚举、动态字典、系统参数与审计日志 PRD (`04-enum-dict-config-audit.md`)

- **所属阶段**：第一阶段（MVP 最小稳定内核）
- **关联工单**：[确定静态枚举、动态字典、系统参数与审计日志域 PRD 与原型](https://github.com/atengk/ateng-solid/issues/8)（路线图：[第一阶段（MVP 内核）需求文档（PRD）与高保真交互原型路线图](https://github.com/atengk/ateng-solid/issues/1)）
- **前置真源**：
  - [设计系统规范](./design-system.md) | [第一阶段总览与全站交互规范](./00-overview-and-ux-standards.md)
  - [跨端通信协议与数据契约](../../agents/contracts.md) | [Boot 1.2.0 调研](./_research/boot-1.2.0-constraints.md) | [UI 1.1.0 调研](./_research/ui-1.1.0-capabilities.md)
  - [EnumDictionaryController.java](../../../../ateng-boot/ateng-boot-web/src/main/java/io/github/atengk/boot/web/dict/EnumDictionaryController.java)（底座参考）
- **交互参考原型**：[枚举、字典、参数与审计原型 (`enum-dict-config-audit.html`)](../../prototypes/phase1/enum-dict-config-audit.html) | [定稿方案 A 基础壳 (`shell-accepted.html`)](../../prototypes/phase1/shell-accepted.html)

---

## 1. 域范围、Specs 增量对齐与底座边界

### 1.1 纳入模块与只读/平台边界
| 菜单路径 / 端点 | 路由名称 | 组件路径 (`src/views/`) | 核心权限码 | 运行边界 |
| :--- | :--- | :--- | :--- | :--- |
| `/admin/system/enums/**` | 无独立页面 | - | `@SaCheckLogin` | **静态枚举只读端点**：`ateng-solid-system` `SysEnumController` 接管暴露 |
| `/system/dict` | `SysDict` | `system/dict/index.vue` | `system:dict:{list,create,update,delete}` | **平台专属（`platform_only = 1`）**：同屏双面板管理；只读消费端点全租户开放 |
| `/system/config` | `SysConfig` | `system/config/index.vue` | `system:config:{list,create,update,delete}` | 租户行级隔离；内置参数禁止修改键名与删除 |
| `/system/oper-log` | `SysOperLog` | `system/oper-log/index.vue` | `system:oper-log:list` | 租户行级隔离；**严格只读**（无增删改/清空/导出）+ `720px` 详情抽屉 |
| `/system/login-log` | `SysLoginLog` | `system/login-log/index.vue` | `system:login-log:list` | 租户行级隔离；**严格只读**（无增删改/清空/导出） |

### 1.2 对既有 Specs 的增量修正备忘（将于工单 `#10` 统一同步子仓文档）
1. **`sys_oper_log` 增补 `browser VARCHAR(64) NULL` 与 `os VARCHAR(64) NULL`**：直接持久化底座 `OperateLogModel` 已同步解析的浏览器与操作系统字段；`operate_type` 明确为 `INT NOT NULL` 对齐 `OperateTypeEnum.code`。
2. **`sys_dict_type`、`sys_dict_data`、`sys_config` 增补 `remark VARCHAR(500) NULL`**。
3. **补充接口端点**：`/admin/system/dict` 补充 `GET /type/{id}`、`GET /type/options`、`PUT /type/{id}/status`、`GET /data/{id}`、`PUT /data/{id}/status`；`/admin/system/config` 补充 `GET /{id}`；规范 `SysConfig.configType` 为枚举 `Y(系统内置)` / `N(业务自建)`。

### 1.3 `ateng-boot:1.2.0` 与 `ateng-ui:1.1.0` 实测边界对齐
| 底座组件 / 工具 | 实测约束与本域落地规范 | 调研锚点 |
| :--- | :--- | :--- |
| **`EnumDictionaryRegistry`** | 配置 `ateng.boot.web.enum.endpoint-enabled=false` 关闭底座默认 `/api/system/enums`，由 `SysEnumController` 注入 `EnumDictionaryRegistry` 挂载 `/admin/system/enums` 并实施 `@SaCheckLogin` 管控（默认 `LOWER_CAMEL_CASE` 剥离 `Enum` 后缀） | `boot-1.2.0-constraints.md` §4.2 / `B5` |
| **`@OperateLog` & `OperateLogModel`** | 注解属性名为 **`type`**（非 `operateType`）；切面在请求线程同步填充 `userId`/`tenantId`/`browser`/`os`/`description` 后投递异步线程执行 `OperateLogStorageProvider#store`（异步线程不可调 `LoginHelper.getLoginUser()`，须用 `model.tenantId` + `model.userId` 主键查库补全真实 `userName`）；`AuditParamSanitizer` 自动将敏感键替换为 `"[EXCLUDED]"` | `boot-1.2.0-constraints.md` `F7` / §4.1 |
| **`UserAgentUtil`** | 纯 JDK 零依赖有界扫描；登录日志由认证事件消费者直接调用 `UserAgentUtil.parse(rawUa)` 提取 `browser` 与 `os` 写入 `sys_login_log` | `boot-1.2.0-constraints.md` §4.1 / `B11` |
| **`DictManager` & `AtengDictTag`** | `DictManager` 采用内存 `Map` + `inFlight` 请求去重；`AtengDictTag` `tagType` 仅接受 `'primary'|'success'|'warning'|'danger'|'info'|''|undefined`（转换层将任何 `'default'` 归一化为 `''`）；未匹配值降级渲染原值中性标签 | `ui-1.1.0-capabilities.md` §2.9 / `D11` |

---

## 2. 静态枚举与动态数据字典分工及 `/system/dict` 规范

### 2.1 全站枚举与动态字典明确分工清单

#### 一、静态枚举（代码强类型 `IBaseEnum` ➔ `/admin/system/enums` 只读消费）
前端枚举适配层统一将后端 `OptionItem<T>`（`{ code, label, disabled, extra }`）映射为 `@atengk/element-plus` `DictItem`（`{ label, value, ... }`），禁止录入数据库动态字典表：

| 枚举别名 (`/enums/{name}`) | 对应后台枚举 | 常量值清单 | 消费场景 |
| :--- | :--- | :--- | :--- |
| `commonStatus` | `CommonStatusEnum` | `0=正常`、`1=停用` | 租户/套餐/用户/角色/菜单/部门/岗位/字典启停状态 |
| `menuType` | `MenuTypeEnum` | `M=目录`、`C=页面菜单`、`F=按钮权限` | 菜单管理类型选择与标签 |
| `dataScopeType` | `DataScopeType` | `1=全部`、`2=自定部门`、`3=本部门`、`4=本部门及以下`、`5=仅本人` | 角色数据权限弹窗与列表标签 |
| `operateType` | `OperateTypeEnum` (底座) | `0=其他`, `1=新增`, `2=修改`, `3=删除`, `4=查询`, `5=导出`, `6=导入`, `7=登录`, `8=登出`, `9=授权`, `10=清空` | 操作日志筛选与标签 |
| `logStatus` | `LogStatusEnum` | `0=成功`、`1=失败` | 操作日志与登录日志状态筛选及标签 |
| `configType` | `ConfigTypeEnum` | `Y=系统内置`、`N=业务自建` | 系统参数类型筛选与防删判断 |
| `visibleStatus` | `VisibleStatusEnum` | `0=显示`、`1=隐藏` | 菜单侧栏显隐状态 |

#### 二、动态业务字典（`sys_dict_type` / `sys_dict_data` ➔ `DictManager` 缓存消费）
第一阶段仅随种子初始化以下真正被业务页面消费的核心字典：
1. **`sys_user_gender`**（用户性别）：`0=男`、`1=女`、`2=未知`（默认）—— 供 `/profile`、`/system/user` 与 Excel 导入导出消费；
2. **`sys_yes_no`**（是否标识）：`Y=是`（`primary`）、`N=否`（`info`，默认）—— 供系统通用布尔扩展配置消费。

### 2.2 动态字典管理（`/system/dict` · 平台专属同屏双面板）
- **布局与联动**：采用 `<AtengSplitLayout storage-key="solid:split:sys-dict">`（桌面端左面板 `42%` 展示字典类型、右面板 `58%` 展示当前选中类型的字典数据；`<1120px` 上下堆叠）。默认自动选中左侧第一条字典类型加载右侧明细。
- **左面板：字典类型（`sys_dict_type`）**：
  - 检索：`dictName`、`dictType`、`status`；
  - 表格列：`字典名称`、`字典类型`（`mono`）、`状态`（Switch 确认切换）、`操作`（`编辑`、`删除`）；
  - **新增 / 编辑弹窗（`480px`）**：`dictName`（必填 `2~50`）、`dictType`（必填 `^[a-z][a-z0-9_]{1,63}$` 且全局未删唯一；**编辑态锁定 `dictType` 只读不可改**）、`status`、`remark`；
  - **删除护栏**：若该 `dictType` 下仍存在任何未软删的 `sys_dict_data` 明细项，**拦截删除**抛 `SystemResultCode(102005, "字典类型【{dictName}】下尚有 {count} 条字典数据，请先清空后再删除")`。
- **右面板：字典数据（`sys_dict_data`）**：
  - 顶部展示当前所属字典类型胶囊（`{dictName} ({dictType})`）及 `[+ 新增字典数据]`、`[刷新字典缓存]`（触发 `DictManager.clearCache(dictType)`）；
  - 表格列：`字典标签`（直接用 `<AtengDictTag>` 样式渲染预览效果！）、`字典键值`（`mono`）、`排序`（`tabular-nums`）、`默认`（`[默认]` 标记）、`状态`、`操作`（`编辑`、`删除`）；
  - **新增 / 编辑弹窗（`520px`）**：
    - `dictType`（只读显示当前类型）；
    - `dictLabel`（标签文本，必填 `1~64`）、`dictValue`（键值，必填 `1~64`，同 `dictType` 内唯一）；
    - `tagType`（回显样式，单选 6 档：`''` 默认 / `primary` 钴蓝 / `success` 翡翠绿 / `warning` 琥珀橙 / `danger` 警示红 / `info` 灰中性）+ `cssClass`（选填自定义类名）+ **上方/下方实时预览区（渲染真实标签样式与文字）**；
    - `sort`（整数排序）、`isDefault`（是否默认开关：**同一 `dictType` 下互斥唯一**——勾选保存时后端在同一事务内先将该 `dictType` 其他记录的 `is_default` 设为 `0`，再将当前记录设为 `1`）、`status`、`remark`。
- **停用影响与客户端缓存规则**：
  - 当字典类型本身 `status = 1`（停用）时，`GET /admin/system/dict/data/type/{dictType}` 返回空数组 `[]`；当单个字典项 `status = 1` 时，仅过滤掉该已停用项；
  - 新增/编辑表单的 `<AtengDictSelect>` / `<AtengDictRadio>` 不再出现已停用项；历史列表表格里的 `<AtengDictTag>` 未命中正常项时自动降级展示原始存储值，不报错不空白；
  - 任一字典类型或字典项增删改/启停成功后，前端主动清理 `DictManager.clearCache(dictType)`。

---

## 3. 系统参数管理（`/system/config`）

### 3.1 租户隔离与内置保护规则
- **租户隔离**：`sys_config` 按当前生效 `tenant_id` 行级隔离（不同租户可独立覆盖自己的业务参数值）。
- **检索与表格**：
  - 检索区：`configName`（参数名称）、`configKey`（参数键名）、`configType`（参数类型：`系统内置 Y` / `业务自建 N`）；
  - 表格列：多选框、`参数名称`、`参数键名`（`mono` + 内置参数标示 `[系统内置]`）、`参数键值`（`mono`，过长截断+Tooltip）、`参数类型`、`备注`、`创建时间`、操作列（`编辑`、`删除`）；
  - **内置防误删保护（`configType === 'Y'`）**：表格复选框与`删除`按钮置灰禁用并悬停说明 `"系统内置核心参数受保护，禁止删除"`；后端 `DELETE /admin/system/config/{ids}` 对 `configType = 'Y'` 硬拒绝抛 `SystemResultCode(102007)`。
- **新增 / 编辑弹窗（`560px`）**：
  - `configName`（必填 `2~100`）；
  - `configKey`（必填 `^[a-zA-Z0-9._-]{2,100}$`，同租户唯一 `102002`；**编辑系统内置参数时锁定 `configKey` 只读不可改**）；
  - `configValue`（必填 `1~500`，文本域支持多行）；
  - `configType`（新建普通自建默认为 `N`，内置参数不可降级为 `N`）；
  - `remark`（选填 `<= 500`）。

### 3.2 第一阶段内置核心参数清单与 YAML 配置边界
1. **分工铁律**：
   - **YAML 配置**（`application.yml`）：承载应用启动装配期、底层基础设施及匿名未认证阶段配置（如 `ateng.solid.tenant.enabled`、`ateng.solid.auth.captcha-enabled`、防爆破阈值、存储 Guard、Jackson/Flyway 参数）；
   - **`sys_config` 参数表**：承载需在运行时由租户/运营人员在界面动态调整且可按租户差异化的业务默认参数。
2. **第一阶段种子内置核心参数与多租户兜底规则**：
   - **`sys.user.initPassword`**（名称：`用户管理-初始默认密码`、默认值：`'Ateng@2026'`、`configType = 'Y'`）：由新建用户、重置密码、用户 Excel 导入与新建租户初始化管理员统一通过 `GET /admin/system/config/key/sys.user.initPassword`（或服务端直读）消费；
   - **多租户平台兜底回退**：开启多租户时，按 `configKey` 读取参数优先查当前生效租户（带 `30m` 缓存）；若普通租户尚未覆盖该键，自动回退读取平台默认租户 `0` 的全局值（租户新建同名键后即刻覆盖生效）；
   - **强校验防呆**：当管理员在 `/system/config` 修改 `configKey === 'sys.user.initPassword'` 的 `configValue` 时，前后端**强制同步校验新值符合全站口令复杂度规则**（`8~20` 位无空白且至少包含大小写字母、数字、特殊字符中的 3 类），防止保存弱口令引发下游新建/重置用户失败。

---

## 4. 只读操作日志（`/system/oper-log`）与登录日志（`/system/login-log`）

### 4.1 严格只读审计原则
- 两模块菜单仅配 `list` 查询权限（`system:oper-log:list`、`system:login-log:list`），**无任何新增、编辑、删除、批量清空与导出操作**，底层表继承 `BaseIdEntity + TenantAware<Long>`（无软删除列与乐观锁）。
- 仅按当前生效 `tenant_id` 隔离检索；`operate_location` 与 `login_location` 在首期极简栈下保持可空，前端空值统一展示 `'--'`。

### 4.2 操作日志（`/system/oper-log`）与 `720px` 详情抽屉
- **检索区（`AtengQueryForm`，默认折叠 1 行）**：
  - 首行：`module`（操作模块模糊）、`userName`（操作人员模糊）、`operateType`（操作类型下拉，消费 `/admin/system/enums/operateType`）、`status`（操作状态：`0-成功`/`1-失败`）；
  - 展开行：`traceId`（全链路追踪 ID 精确匹配）、`operateTimeRange`（操作时间区间，内置快捷选项：`今天`、`最近 7 天`、`最近 30 天`，可清空查全量）。
- **表格列**：`日志ID`（`mono`）、`traceId`（`mono` + 一键复制按钮）、`操作模块`、`操作类型`（标签展示 `OperateTypeEnum`）、`请求方法 & 路径`（如 `POST /admin/system/user`，过长省略+Tooltip）、`操作人员`（`userName`）、`客户端 IP`（`tabular-nums`）、`浏览器 / 系统`（如 `Chrome 130 / Windows 10`）、`状态`（`成功`/`失败`胶囊）、`耗时 (ms)`（`tabular-nums`）、`操作时间`（`tabular-nums`）、固定右侧操作列（`[详情]`）。
- **操作日志详情抽屉（`AtengDrawer` `720px`，消费 `GET /admin/system/log/oper/{id}`）**：
  1. **基础摘要区（`AtengDescriptions`，2 列网格）**：日志ID、`traceId`（支持一键复制）、操作模块、操作类型、请求方式、请求路径、操作人员（`userName` + `userId`）、客户端 IP、浏览器、操作系统、执行耗时、执行状态与操作时间；
  2. **请求参数（`requestParams`）与响应结果（`responseResult`）区**：
     - 若内容为合法 JSON 字符串，自动执行美化缩进排版（2 空格）；
     - 置于有界等宽代码滚动区（默认最大高度 `240px`，防止超长 JSON 撑爆抽屉），顶部提供 `[复制]` 与 `[展开完整 / 收起]` 按钮；
     - 敏感参数已由底层 `AuditParamSanitizer` 脱敏替换为 `"[EXCLUDED]"`（如 `password`、`oldPassword`、`newPassword`、`token`）；
  3. **失败异常摘要区（仅 `status === 1` 时渲染）**：使用危险语义警告条（`--solid-danger-soft`）展示安全处理后的 `errorMsg`（严禁展示原始 Java 堆栈或 SQL 语句）。

### 4.3 登录日志（`/system/login-log`）
- **检索区（`AtengQueryForm`，默认折叠 1 行）**：
  - 首行：`username`（登录账号）、`clientIp`（客户端 IP）、`status`（登录状态：`0-成功`/`1-失败`）；
  - 展开行：`traceId`（精确匹配）、`loginTimeRange`（快捷选项：`今天`/`最近 7 天`/`最近 30 天`）。
- **表格列（全字段表格直显，无需额外详情抽屉）**：`日志ID`、`traceId`（`mono` + 复制）、`登录账号`、`登录体系`（`admin`）、`客户端 IP`、`浏览器`、`操作系统`、`登录状态`（成功/失败标签）、`提示消息`（如 `"登录成功"`、`"图形验证码无效或已过期 (101001)"`、`"连续登录失败已锁定 (101004)"`，单行过长省略并悬停展示全文）、`登录时间`（`tabular-nums`）。

---

## 5. API 契约与错误码汇总

| 资源域 | 关键端点 | 权限码 | 说明 |
| :--- | :--- | :--- | :--- |
| **静态枚举** | `GET /admin/system/enums`、`GET /enums/{name}`、`GET / POST /enums/batch` | `@SaCheckLogin` | 注入 `EnumDictionaryRegistry`，统一包装 `Result<T>` |
| **动态字典类型** | `GET /dict/type/page`、`GET /dict/type/options`、`GET /dict/type/{id}`、`POST /dict/type`、`PUT /dict/type`、`PUT /dict/type/{id}/status`、`DELETE /dict/type/{ids}` | `system:dict:*` | 平台租户 `0` 维护；`dictType` 编辑只读；有明细禁删 `102005` |
| **动态字典数据** | `GET /dict/data/page`、`GET /dict/data/{id}`、`POST /dict/data`、`PUT /dict/data`、`PUT /dict/data/{id}/status`、`DELETE /dict/data/{ids}` | `system:dict:*` | `isDefault` 同类型互斥；`tagType` 收敛 6 档 |
| **动态字典消费** | `GET /admin/system/dict/data/type/{dictType}` | `@SaCheckLogin` | 全租户登录可调；仅返回正常启用的字典项（类型停用返回 `[]`） |
| **系统参数** | `GET /config/page`、`GET /config/{id}`、`GET /config/key/{configKey}`、`POST /config`、`PUT /config`、`DELETE /config/{ids}` | `system:config:*`（`key/` 为 `@SaCheckLogin`） | 内置 `Y` 禁止删改键名 `102007`；`sys.user.initPassword` 强口令校验 |
| **审计日志** | `GET /log/oper/page`、`GET /log/oper/{id}`、`GET /log/login/page` | `system:oper-log:list` / `system:login-log:list` | 严格只读分页查询（按时间倒序）与操作日志详情 |

---

## 6. UX 与反模板自检清单（对齐 `ux-and-copy-checklist.md`）

- [x] **无重复录入与样式漂移**：静态枚举与动态字典职责彻底切分；动态字典弹窗提供 `<AtengDictTag>` 实时样式预览，避免盲选 `tagType`。
- [x] **内置参数安全防线**：`sys.user.initPassword` 等 `configType=Y` 内置项不可误删或篡改键名，且参数值保存时前置拦截弱口令。
- [x] **长报文不撑爆与审计可追溯**：操作日志详情抽屉对 JSON 自动美化并限制代码区默认高度（支持滚动、一键复制与展开），所有 `traceId` 一键可复制。
