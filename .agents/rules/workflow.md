---
trigger: always_on
description: "重型跨模块任务的 Blueprint-Spec-Ticket 分级推进流与 Tested-Docs 文档保真准则"
---

# 研发推进工作流与文档保真规范 (workflow.md)

> **作用域**：`ateng-solid` 根工作区及子仓库跨模块重型任务规划、规格设计及文档交付。
> 融合自 `oss-template` 的 `workflow-blueprint-spec-ticket` 与 `quality-tested-docs` 扩展规约，并针对全端业务系统进行轻量化适配。

---

## 1. 分级任务推进流（Blueprint ➔ Spec ➔ Ticket）

为兼顾系统级架构可控性与日常敏捷迭代效率，仅在以下**重型任务场景**强制启动三级确认流：
- **强制触发条件**：
  1. 初始化新端工程（如未来启用 `ateng-solid-mp`、`ateng-solid-app`、`ateng-solid-desktop`、`ateng-solid-portal-web`）；
  2. 新增后端独立微服务域或改造跨模块 `-api` 契约拓扑；
  3. 跨前后端核心通信协议重构、全库核心基表重构或向 `ateng-cloud` 拆分迁移。
- **豁免场景（直接开发）**：常规单模块 CRUD 接口、常规后台页面、局部 Bug 修复与常规重构，无需走三级重型流程。

### 三阶段与双重人类确认门禁
1. **阶段 1：蓝图（Blueprint）** → 落盘至 `docs/specs/` 或 `docs/blueprints/`，明确业务目标、架构拓扑、模块边界与 Spec 拆解；**产出后暂停等待用户确认**。
2. **阶段 2：规格（Spec）** → 按模块定义对外 API 契约、状态机、异常防卫与原子 Ticket 清单；**产出后暂停等待用户确认**。
3. **阶段 3：切片执行（Ticket）** → 逐片按“先测试 ➔ 再实现 ➔ 更新文档 ➔ 本地验证通过”闭环推进。

---

## 2. 零未文档化功能与 1:1 测试保真准则 (Code & Test-First Docs)

完整文档结构标准与《10 项准出自检清单》详见 **[`docs/agents/documentation-specification.md`](../../docs/agents/documentation-specification.md)**，核心约束如下：

- **Code & Test-First 1:1 逆向沉淀**：任何功能在实现源码并通过本地测试（`mvn clean test` / `pnpm 四合一`）后，**必须同窗口 1:1 逆向沉淀至对应模块 `README.md`（应用五维骨架 + 第 0 节全景矩阵）、`docs/specs/`、`CONTEXT.md` 及 `llms.txt`**，杜绝“代码写了但文档隐身”。
- **可运行示例同源提炼**：文档中展示的请求载荷、YAML/Env 配置与代码用法，必须来源于真实通过测试或编译验证的代码与运行结果，剔除测试桩噪声，严禁凭空捏造未经验证的字段或输出。
- **变更闭环三要素**：每个具体功能小节在同一屏幕内必须同时闭环交代：① 专属配置片段；② 真实调用示例/请求载荷；③ 核心机制边界与失败防御行为。
