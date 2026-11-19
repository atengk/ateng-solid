# 贡献指南 (Contributing Guide)

感谢你关注并参与 `ateng-solid` 多端工作区的建设！`ateng-solid` 采用独立多仓库（Polyrepo）协作架构，请根据改动范围在对应仓库内提交变更。

---

## 1. 分支与工作区协同模型

本项目及各子工程统一遵循 **`main`（稳定发布只读）+ `dev`（活跃开发）双分支** 模型：

1. **初始化工作区（首次接入推荐）**：
   ```bash
   # 拉取启用的子仓库、激活全部仓库 Git Hooks、切齐 dev 分支并检查本地环境
   bash scripts/workspace.sh sync
   bash scripts/workspace.sh init
   ```
2. **基于 `dev` 分支拉取特性/修复分支**（在对应子仓或根仓独立执行）：
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b feat/your-feature-name
   ```
3. **跨仓契约单一真源**：
   - 跨端协议统一维护在根仓 [`.agents/rules/contracts.md`](./.agents/rules/contracts.md)；
   - 修改跨端契约后，必须运行 `bash scripts/workspace.sh sync-contracts` 同步至各子仓并分别提交。
4. **发起 Pull Request**：向目标仓库的 `dev` 分支发起 PR（版本发布时由 `dev` 合并至 `main` 并打标签）。

---

## 2. Commit 提交信息规范

统一遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 规范：`<type>(<scope>): <清晰中文描述>`。

| 类型 | 说明 | 示例 |
| :--- | :--- | :--- |
| `feat` | 新增功能或特性 | `feat(contracts): 补充导出流式契约` |
| `fix` | 缺陷与 Bug 修复 | `fix(workspace): 修复子仓钩子检测` |
| `docs` | 文档变动 | `docs(adr): 新增多租户 BIGINT 决策记录` |
| `style` | 格式调整（不影响逻辑） | `style: 统一脚本缩进格式` |
| `refactor` | 代码重构 | `refactor(workspace): 拆分校验函数` |
| `perf` | 性能优化 | `perf: 优化并行巡检耗时` |
| `test` | 测试补充或修改 | `test: 补充契约同步检测用例` |
| `build` | 构建或依赖变动 | `build: 更新工作流依赖动作` |
| `ci` | CI/CD 流水线变动 | `ci: 启用跨仓契约同步门禁` |
| `chore` | 常规维护 | `chore: 更新 .gitignore 规则` |
| `revert` | 回滚先前提交 | `revert: 回退变更` |

### 本地提交钩子与助手脚本
- **本地钩子守门**：[`.githooks/commit-msg`](./.githooks/commit-msg) 自动校验提交信息首行格式（通过 `bash scripts/workspace.sh init` 或 `git config core.hooksPath .githooks` 激活）。
- **规范化提交助手**：支持交互向导与非交互式参数调用：
  ```bash
  # 交互式向导
  bash scripts/commit.sh

  # 非交互式（推荐先精准 git add）
  git add <file-path>
  bash scripts/commit.sh -t docs -s contracts -m "完善跨端分页与枚举契约" -y
  ```

> 💡 **Windows 提示**：在 Windows PowerShell / CMD 中，直接通过 Git 自带的 Bash 执行 `bash scripts/workspace.sh` 或 `bash scripts/commit.sh` 即可。

---

## 3. Pull Request 与文档闭环准则

- **PR 标题规范**：PR 标题必须同样符合 Conventional Commits 格式，CI 会自动校验。
- **特性即文档（Doc-as-Feature）**：新增或修改跨端契约、工作流、脚本能力时，须在同一 PR 中同步更新对应文档及最小示例。
- **推荐合并方式**：采用 **Squash and merge**，以规范的 PR 标题作为主干提交历史。

---

## 4. 发版流程

仅允许在干净同步的 `main` 分支通过 GitHub Actions 网页端 `workflow_dispatch`、原生 `git tag vX.Y.Z` 或 `bash scripts/release.sh` 发起发版，严禁在 `dev` 分支直接打发版标签。
