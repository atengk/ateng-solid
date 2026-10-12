# ateng-solid

**ateng-solid** 是一套面向企业级场景的全端多端数字化系统聚合工作区（Polyrepo Workspace），涵盖后端统一服务、管理后台 Web 端、移动端 App、小程序、桌面端及官方门户。

---

## 1. 仓库矩阵与工程目录

本工程采用松耦合的多仓库架构（Polyrepo），各子工程均为完全独立的 Git 仓库，可独立克隆与演进：

| 子工程目录 | 仓库链接 | 职责描述 | 技术栈 | 状态 |
| :--- | :--- | :--- | :--- | :--- |
| [`ateng-solid-server`](./ateng-solid-server) | [atengk/ateng-solid-server](https://github.com/atengk/ateng-solid-server) | 后端统一服务工程（模块化单体） | Java 21 / Spring Boot 3 / Maven | 进行中 |
| [`ateng-solid-admin-web`](./ateng-solid-admin-web) | [atengk/ateng-solid-admin-web](https://github.com/atengk/ateng-solid-admin-web) | 管理后台 Web 前端工程 | Vue 3 / Vite / TypeScript / pnpm | 进行中 |
| [`ateng-solid-mp`](./ateng-solid-mp) | - | 移动端小程序工程 | 规划中 | 待初始化 |
| [`ateng-solid-app`](./ateng-solid-app) | - | 移动端跨平台 App (iOS / Android) | 规划中 | 待初始化 |
| [`ateng-solid-desktop`](./ateng-solid-desktop) | - | PC 桌面客户端工程 | 规划中 | 待初始化 |
| [`ateng-solid-portal-web`](./ateng-solid-portal-web) | - | 门户与官网 Web 前端工程 | 规划中 | 待初始化 |

---

## 2. 架构规范与协同原则

1. **版本解耦**：根仓库仅负责工作区协同、全景文档与公共支撑；各子工程在各自子目录下独立提交与推送。
2. **接口契约标准**：后端通过标准 OpenAPI 规范输出接口，各前端遵循接口契约进行类型生成与联调对接。
3. **环境基线**：
   - OpenJDK 21 LTS + Apache Maven 3.9+
   - Node.js v22+ + pnpm 11+
