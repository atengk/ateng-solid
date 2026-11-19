# 领域文档消费与维护规范 (Domain Docs)

本仓库（`ateng-solid` 根工作区）采用 **多上下文（Multi-Context）** 聚合工作区结构，规范工程技能在探索和演进系统时如何读取和维护上下文映射、词汇表与架构决策记录（ADR）。

---

## 1. 探索与设计前必读

1. **工作区上下文映射 [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md)**：定义根工作区与各独立子工程（`ateng-solid-server`、`ateng-solid-admin-web` 及规划中的多端仓库）的边界、通信协议与上游底座关系。根目录唯一维护 `CONTEXT-MAP.md`，**不创建根级单体 `CONTEXT.md`**。
2. **各子工程上下文文档**：进入具体子仓库执行探索或建模时，进一步读取目标子仓库的领域文档：
   - 后端（Multi-context）：`ateng-solid-server/CONTEXT-MAP.md` 与 `ateng-solid-server/ateng-solid-<module>/CONTEXT.md`；
   - 前端（Single-context）：`ateng-solid-admin-web/CONTEXT.md`。
3. **系统级架构决策记录 [`docs/adr/`](../adr/README.md)**：查阅跨端协议、多租户模型、Polyrepo 治理等全局 ADR。若某类文档在规划中子工程尚未建立，请静默继续，待首次术语或决策收敛时再按需创建。

---

## 2. 目录布局（Multi-Context）

```text
ateng-solid/
├── CONTEXT-MAP.md                      # 全工作区限界上下文与跨端拓扑唯一入口
├── docs/
│   ├── adr/                            # 系统级、跨端架构决策记录
│   ├── agents/                         # Agent 技能协作配置 (issue-tracker / triage-labels / domain)
│   └── specs/                          # 全局 MVP 蓝图与底层基础设施待增强清单
├── ateng-solid-server/                 # 独立后端仓库 (Multi-context: CONTEXT-MAP.md + 模块 CONTEXT.md)
└── ateng-solid-admin-web/              # 独立前端仓库 (Single-context: 根 CONTEXT.md + docs/adr/)
```

---

## 3. 术语一致性与 ADR 冲突显式声明

- **严格对齐词汇表**：编写蓝图、Issue 标题、跨端契约或方案时，统一使用词汇表确立的规范术语（如 `super_admin`、`tenant_id`、`tenant_code`、`DataScopeType`），严禁漂移到 `_Avoid_` 列表中的反模式词。
- **ADR 增量修订与冲突提示**：仅在决策同时满足“难以逆转（Hard to reverse）+ 缺上下文令人费解（Surprising）+ 存在真实权衡（Real trade-off）”时新建 ADR；若新方案与既有 ADR 冲突，必须在输出中显式声明（例如 `> _与 ADR-0002 存在冲突，建议重审原因：..._`），严禁静默覆写。
