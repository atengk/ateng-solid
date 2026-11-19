# 架构决策记录 (Architecture Decision Records - ADR)

本目录记录 `ateng-solid` 全端工作区级与跨端协同相关的架构决策（ADR）。各独立子工程内部的专有技术选型决策收敛于各自仓库的 `docs/adr/`。

## 决策矩阵总览 (Decision Matrix)

| 编号 | 决策标题 | 状态 | 核心收益与权衡 | 影响范围 | 详细文档 |
| :---: | :--- | :---: | :--- | :--- | :---: |
| **0001** | **Polyrepo 隔离、单向契约同步与子仓独立开发架构** | 🟢 Accepted | 兼顾多仓库独立发版隔离与单开子仓 AI 规约自洽，根仓持有 `contracts.md` 真源并通过 `workspace.sh` 同步与防漂移校验 | 全工作区 | [查看](./0001-polyrepo-workspace-and-contract-sync.md) |
| **0002** | **行级多租户 `tenant_id BIGINT` 与租户套餐边界模型** | 🟢 Accepted | 统一全库 `tenant_id` 为 `BIGINT`（默认 `0`、`tenant_code='000000'`），100% 契合 `ateng-boot` `DefaultTenantLineHandler` 防索引失效；纳入 `sys_tenant_package` 与超管受控切租户边界 | 跨端契约、后端、前端 | [查看](./0002-multi-tenant-bigint-and-package-model.md) |

---

## 编写与防膨胀准则 (ADR Governance)

1. 仅当发生跨端协议重大调整、新增端仓库或变更工作区协同拓扑时新建全局 ADR（四位编号递增）。
2. 仅涉及后端内部或前端内部的实现型决策，一律写入对应子仓库 `docs/adr/`，不在根仓堆砌细节。
3. 优化既有决策时优先在原 ADR 中增量修订，并同步更新本索引表与 [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md)。
