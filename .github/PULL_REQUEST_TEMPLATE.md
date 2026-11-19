## 变更说明
<!-- 请简要说明本次跨端契约、工作区治理或架构文档变更背景 -->

## 关联 Issue
- 修复/关联: close #

## 变更类型
- [ ] `feat`: 新增契约能力或工作区特性
- [ ] `fix`: 修正契约冲突、脚本缺陷或文档误述
- [ ] `docs`: 架构文档、ADR 或规约更新
- [ ] `style`: 格式调整（不影响逻辑）
- [ ] `refactor`: 结构整理或脚本重构
- [ ] `test`: 补充或调整校验测试
- [ ] `build`: 构建或工具链基线变动
- [ ] `ci`: CI/CD 流水线变动
- [ ] `chore`: 其他日常维护

## 自检清单
- [ ] 提交信息与 PR 标题符合 Conventional Commits 规范
- [ ] 若修改了 `.agents/rules/contracts.md`，已运行 `bash scripts/workspace.sh sync-contracts` 同步至子仓
- [ ] 已本地验证脚本语法与一致性检查（`bash scripts/workspace.sh check-contracts --allow-missing`）
- [ ] Markdown 文档互链均采用相对路径，无绝对路径或敏感信息明文
