# ADR-0003: 多租户默认关闭可开关策略、权限隔离边界与安全初始化协议

- **状态**：`Accepted`
- **日期**：2026-11-19
- **作者**：Ateng
- **影响范围**：全库 DDL 规范、`ateng-solid-server`、`ateng-solid-admin-web`、`contracts.md`

---

## 1. 背景与权衡痛点

首期 MVP 需要兼顾两类真实落地诉求：一方面绝大多数企业内部项目开箱只需极简单租户后台，首期不想被复杂的 SaaS 租户交互与多租户缓存牵制；另一方面架构必须为未来一键切换 SaaS 多租户保留零重构升级通道。同时，在 `grill-with-docs` 深度核查中识别出以下四项影响长期演进、一旦落盘难以逆转的跨端设计边界：

1. 多租户默认开启 vs 默认关闭可开关，以及多对多关联表是否携带 `tenant_id` 列；
2. 平台治理域（租户、套餐、菜单、字典管理）与普通租户业务域的权限分层及套餐缩减联动；
3. Flyway 迁移脚本中是否硬编码超管默认密码哈希；
4. 用户 Excel 批量导入校验失败时的事务原子性与前后端回写协议。

---

## 2. 核心决策

1. **多租户支持开启与关闭，默认关闭（零重构 Schema 预留）**：
   - 新增业务总开关 `ateng.solid.tenant.enabled`（**默认 `false`**），同步联动 `ateng.boot.mybatis-plus.tenant.enabled: false`；
   - 数据库全部租户业务表及 4 张租户内关联表（`sys_user_role`、`sys_user_post`、`sys_role_menu`、`sys_role_dept`）**仍保留 `tenant_id BIGINT NOT NULL DEFAULT 0`**，`sys_tenant_package_menu` 与其他平台共享表列入 `ignore-tables`；
   - 关闭状态下系统固定以平台默认租户 `0`（`000000`）运行，登录前置端点向前端返回 `tenantEnabled: false`，前端自动隐藏登录页租户编码输入框、顶栏超管租户切换器及侧边栏租户/套餐管理菜单；开启后无需改表即可完整激活 SaaS 多租户能力。
2. **平台治理与租户业务严格分层 + 套餐变更联动裁剪**：
   - `sys_tenant`、`sys_tenant_package`、`sys_menu`、`sys_dict` 4 类管理菜单与写接口严格归属平台租户（`tenantId == 0L`），禁止勾选进租户套餐；动态字典只读消费接口 `GET /admin/system/dict/data/type/{dictType}` 对全量登录用户开放；
   - 缩减套餐菜单时在事务内联动裁剪关联租户角色的越界 `sys_role_menu` 并刷新权限缓存；`account_count` 配额仅在新增/启用用户时增量拦截，不强停既有存量账号；
   - 在线会话管理按当前生效租户视角隔离并防越权强退；静态枚举端点依托 `ateng-boot#1094` 配置 `ateng.boot.web.enum.endpoint-enabled=false` 禁用内置控制器，由 `ateng-solid-system` 自建 `SysEnumController` 注入 `EnumDictionaryRegistry` 接管 `/admin/system/enums` 并实施 `@SaCheckLogin` 及后续权限/租户精细管控。
3. **超管账号与初始口令采用“SQL 脱敏 + 启动引导器动态初始化”**：
   - `V1.0.1__system_init_seed.sql` 仅初始化默认租户、角色、菜单、字典等非敏感元数据，严禁在迁移 SQL 中硬编码生产/默认密码哈希；
   - 由 `ateng-solid-bootstrap` 的 `ApplicationRunner` 在检测到租户 `0` 无超管用户时，读取 `ateng.solid.init.super-admin-password`（生产未配则自动生成 16 位强随机口令并仅在首次启动日志输出一次；`application-test.yml` 配置固定测试桩口令）通过 `PasswordUtil.hash` 动态入库。
4. **Excel 批量导入采用“整批原子校验 + JSON 明细 + 临时标红批注下载”协议**：
   - 导入文件存在任一行校验错误时整批回滚不入库，后端调用 `ExcelFeedbackUtil` 生成标红批注 `.xlsx` 暂存（带短 TTL 且校验操作人与租户归属）；
   - `POST /admin/system/user/import` 统一返回 `Result<ImportResultVO>`（含 `totalCount`/`successCount`/`failCount`/`errors[]`/`feedbackToken`），由前端 `AtengExcelFeedback` 直接渲染错误明细表格并按需通过独立下载端点流式下载标红 `.xlsx`。

---

## 3. 后果与权衡

- **优点**：首期交付极简单租户后台零心智负担，未来切 SaaS 多租户零表结构迁移；消除弱口令硬编码风险；前后端 Excel 校验交互类型单一且与 `AtengExcelFeedback` 原生契合。
- **代价**：前端登录与布局壳需按后端下发的 `tenantEnabled` 开关做条件渲染；导入标红文件需维护短时效缓存清理与归属鉴权；多租户开启前依赖 `ateng-boot#1093` 完成角色权限缓存租户维度隔离。
