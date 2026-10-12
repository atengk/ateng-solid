# ateng-solid 项目规约与目录指引 (AGENTS.md)

本仓库根目录为 **ateng-solid** 多端数字化系统的聚合工作区（Polyrepo Workspace）。每个子目录均为**完全独立的 Git 仓库**，由 Antigravity Agent 遵循本规约进行协同。

---

## 1. 子目录结构与职责说明

```text
ateng-solid/
├── ateng-solid-server/          # 后端服务工程 (Spring Boot 模块化单体，内聚 SQL 与部署)
├── ateng-solid-admin-web/       # 管理后台 Web 前端工程 (Vue PC 管理端)
├── ateng-solid-mp/              # 移动端小程序工程
├── ateng-solid-app/             # 移动端 App 工程 (iOS / Android)
├── ateng-solid-desktop/         # PC 桌面客户端工程
└── ateng-solid-portal-web/      # 门户与官网 Web 前端工程
```

- [`./ateng-solid-server`](./ateng-solid-server)：后端核心服务工程，采用模块化单体架构，内聚数据库 SQL 脚本、部署配置与接口契约。
- [`./ateng-solid-admin-web`](./ateng-solid-admin-web)：管理后台 PC Web 前端工程。
- [`./ateng-solid-mp`](./ateng-solid-mp)：移动端小程序工程。
- [`./ateng-solid-app`](./ateng-solid-app)：移动端 App 工程。
- [`./ateng-solid-desktop`](./ateng-solid-desktop)：PC 桌面客户端工程。
- [`./ateng-solid-portal-web`](./ateng-solid-portal-web)：门户与官网 Web 前端工程。

---

## 2. Antigravity Agent 行为准则

### 2.1 Git 独立管理
- 根目录作为聚合工作区总仓库，仅管理全景文档、规范与全局编排配置，严禁在根目录提交任何子工程业务源码。
- 各子工程独立管理 Git 版本，代码暂存与提交必须在对应子工程目录内独立执行。

### 2.2 跨端契约协同
- 后端接口通过标准规范（OpenAPI）输出，前端按后端接口定义对接。
- 跨端联动开发时，保持数据传输对象与前端接口类型定义的一致性。

### 2.3 根目录防污染
- 严禁在根目录下创建临时脚本、测试数据或构建产物。
- 专属配置与数据脚本必须严格收敛至对应的子工程目录内。
