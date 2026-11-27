# ADR-0007: API 列表动态脱敏与编辑详情真明文边界契约

- **状态**：`Accepted`
- **日期**：`2026-11-27`
- **作者**：`Ateng`
- **关联模块**：`ateng-solid-system`、`ateng-solid-auth`、`ateng-solid-admin-web`（[`docs/agents/contracts.md`](../agents/contracts.md) · [`ateng-solid-server` ADR-0004](../../ateng-solid-server/docs/adr/0004-deterministic-field-encryption-and-search-boundary.md)）

---

## 1. 背景与决策驱动

早期的跨端约定将非只读字段统一定义为“后端全量返回内存真明文，由前端表格层 `formatMask*` 自行掩码展示”。在实际安全审查与渗透视角下，该策略在高频分页与树形接口上存在明显隐患：

1. **分页/树列表批量拉取暴露原始联系信息**：用户分页（`GET /admin/system/user/page`）与部门树（`GET /admin/system/dept/tree`）单次响应可返回数十至数百条记录；若服务端序列化为全明文响应体，任何仅具备列表查看权限的账号或已失窃会话都能在网络层直接爬取全量明文手机号与邮箱，前端表格掩码仅防君子不防抓包。
2. **编辑表单与个人中心仍需真明文闭环**：管理员点击单条“编辑”弹窗（`GET /admin/system/user/{id}`、`GET /admin/system/dept/{id}`）或当前用户打开个人中心（`GET /admin/auth/profile`）时，若下发带 `*` 号的掩码字符串，表单保存时极易把 `138****5678` 当成新值写回数据库覆盖真实数据，或触发手机号格式校验失败（`100001`）。

同时，前期规约中将底座 Jackson 脱敏注解误写为 `@Sensitive`，而 `ateng-boot-core` 提供的真实注解为 `@FieldSensitive`（基于 Jackson `ContextualSerializer` 仅在出界 JSON 序列化阶段动态掩码，绝不污染 Java 内存对象）。

---

## 2. 核心决策（四层边界）

确立 **“存储加密 ➔ 列表/导出服务端动态脱敏 ➔ 单条编辑/个人中心真明文 ➔ 前端表单真明文不污染”** 的分层敏感信息治理契约：

1. **列表/分页/树响应（服务端动态出界脱敏）**：
   - 面向多条记录浏览的列表与树形 VO 必须在敏感联系字段上显式标注底座 `@FieldSensitive`：
     - `UserVO.phone` -> `@FieldSensitive(SensitiveType.MOBILE_PHONE)`（如 `138****5678`）
     - `UserVO.email` -> `@FieldSensitive(SensitiveType.EMAIL)`（如 `z******n@example.com`）
     - `DeptTreeVO.phone` -> `@FieldSensitive(SensitiveType.MOBILE_PHONE)`
     - `DeptTreeVO.email` -> `@FieldSensitive(SensitiveType.EMAIL)`
   - 轻量下拉选项 VO（如 `UserOptionVO`、`DeptOptionVO`）不承载 `phone`/`email` 敏感字段。
2. **异步/流式 Excel 导出（服务端列级脱敏）**：
   - 用户等包含个人联系信息的导出模型通过底座 `@ExcelSensitive`（`SensitiveType.MOBILE_PHONE` / `EMAIL`）在写出工作簿前完成掩码，错误批注下载或模板导入按各自合规通道受控流转。
3. **编辑详情与个人中心（受控真明文直出）**：
   - 面向单实体精准读取且直接服务于表单回填保存的详情视图保留原始明文（由权限码与 `@DataScope` / 归属校验双重守卫）：
     - `UserDetailVO`（`GET /admin/system/user/{id}`）
     - `DeptVO`（`GET /admin/system/dept/{id}`）
     - `PersonalProfileVO`（`GET /admin/auth/profile`）
   - 若未来业务演进需要在编辑详情中也默认脱敏，需显式拆分为独立“查看授权解锁端点”或引入后端占位符保留不改语义，不得静默修改上述契约。
4. **持久层与注解真名统一**：
   - 存储加密统一收敛于 `ateng-boot-mybatis-plus` 的 `@FieldEncrypt(deterministic = true)` + `DeterministicEncryptTypeHandler`；
   - 全仓库文档、规约与 ADR 统一使用真实注解名 `@FieldSensitive`，彻底清理历史误写 `@Sensitive`。

---

## 3. 备选方案与权衡

| 备选方案 | 放弃原因 |
| :--- | :--- |
| **所有查询（含分页/树列表）继续返回全明文，仅靠前端打码** | HTTP 响应体可被直接抓包读取全量明文手机号/邮箱，分页列表存在高危批量数据爬取风险 |
| **详情接口（`UserDetailVO`/`DeptVO`）也一律强制脱敏** | 表单回填会把 `138****5678` 回写污染存储或阻断部分字段编辑保存；改用全字段留空防覆盖方案显著增加前后端状态复杂度，不适合通用后台首期主线 |
| **全局按字段权限动态切换明密文** | 当前 RBAC 模型以菜单与操作动作三段式权限码为粒度，为单字段动态引入复杂属性级权限评估收益远低于维护成本；先用清晰固定的列表/详情 VO 分层边界可零复杂度落地并保持后续可扩展性 |

---

## 4. 对上下游模块的影响

- **服务端（`ateng-solid-system` / `ateng-solid-auth`）**：列表响应 VO 仅在出界 Jackson 序列化期间掩码，Service 层内存实体、查重、加密存储与审计比对逻辑零改动；单测与集成测试显式覆盖“列表掩码 + 详情真明文”双断言。
- **前端（`ateng-solid-admin-web`）**：列表页直接展示服务端返回的安全掩码值（不再依赖前端裸收全明文再掩码，避免网络载荷泄漏）；编辑弹窗通过详情接口回填原始真明文，恪守表单状态不存带 `*` 脏值原则。
