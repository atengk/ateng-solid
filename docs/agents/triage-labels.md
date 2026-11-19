# 分诊标签词表 (Triage Labels)

工程技能通过 5 个标准分诊角色管理工单状态。本文件定义这些角色与当前仓库（`atengk/ateng-solid`）GitHub Issues 实际标签的 1:1 映射：

| 技能标准角色 | 本仓库实际标签 | 含义与流转说明 |
| :--- | :--- | :--- |
| `needs-triage` | `needs-triage` | 待维护者评估优先级、归属边界与是否需下沉底座 |
| `needs-info` | `needs-info` | 等待提报者补充上下文、复现步骤或契约细节 |
| `ready-for-agent` | `ready-for-agent` | 规格清晰完备且无底座阻塞，可直接交由 AI Agent 执行 |
| `ready-for-human` | `ready-for-human` | 涉及敏感决策、密钥/生产审批或强主观体验，须人工处理 |
| `wontfix` | `wontfix` | 经评估超出范围、不采纳或由其他方案替代 |

当技能指令要求应用对应分诊角色（例如标注 `ready-for-agent`）时，统一使用上表“本仓库实际标签”列中的精确标签字符串。
