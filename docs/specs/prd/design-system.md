# ateng-solid 设计系统规范 (`design-system.md` · MASTER)

- **文档定位**：`ateng-solid` 第一阶段（PC 管理后台）全局视觉识别、设计令牌（Design Tokens）、排版标尺与通用组件视觉契约唯一真源。
- **关联上游**：[`solid-admin-ux`](../../../.agents/skills/solid-admin-ux/SKILL.md) | [`contracts.md`](../../../.agents/rules/contracts.md) | [UI 底座调研报告](./_research/ui-1.1.0-capabilities.md)
- **技术边界声明**：本设计系统独立于 `@atengk/element-plus/theme-pro.css` 默认皮肤（上层可不加载 `theme-pro.css` 或完全覆写其令牌）；同时保持 `@atengk/core` + `@atengk/vue` 无头状态机、Element Plus 功能组件及 TailwindCSS **禁用 Preflight** 边界不变。

---

## 1. 视觉定位与核心原则（Pass 1 规划）

- **产品气质**：**精密工业冷岩钴蓝（Precision Slate & Cobalt）**——面向开源企业级基础设施管理台，以低饱和冷石白画布、1px 亚像素结构描边与沉稳深钴蓝操作焦点，传达“秩序清晰、信息高密、零炫技干扰”的工程信赖感。
- **核心设计原则**：
  1. **结构优于阴影**：用明确间距、1px 实体细边框与背景阶梯建立层级，卡片默认零厚重投影（投影仅保留给浮层、弹窗、下拉与悬浮条）。
  2. **一处明确主焦点**：主色仅聚焦主操作按钮、激活菜单项、当前焦点环与链接，严禁满屏高饱和装饰色块。
  3. **数据列等宽防抖动**：所有雪花 ID、统计数字、时间戳、IP 与分页计数强制使用等宽数字（`font-variant-numeric: tabular-nums`），避免翻页、排序与刷新时列宽跳动。
  4. **单/多租户视觉隔离可感知**：`tenantEnabled = true` 时，超管切换至非默认租户视角须有全站一致的非阻塞态提示，让跨租户操作一眼可辨。

---

## 2. 色彩与语义令牌体系（Light / Dark 双态）

> 所有业务样式与 Tailwind `@theme` 别名一律引用下表 CSS 变量（并双向映射至 Element Plus `--el-*` 变量），严禁在页面或组件内硬编码 Hex 色值。

| 语义角色 | CSS 变量名 | Light 基线值 | Dark 基线值 | 对比度与使用约束 |
| :--- | :--- | :--- | :--- | :--- |
| **页面画布底** | `--solid-bg-canvas` (`--el-bg-color-page`) | `#F6F7F9` | `#0B0F17` | 主工作区外层画布 |
| **卡片/容器面** | `--solid-bg-surface` (`--el-bg-color`) | `#FFFFFF` | `#111827` | 表格卡片、侧栏、顶栏、对话框底 |
| **浮层/下拉面** | `--solid-bg-elevated` (`--el-bg-color-overlay`) | `#FFFFFF` | `#182234` | Popover、ContextMenu、Select 下拉 |
| **次级填充面** | `--solid-bg-subtle` (`--el-fill-color-light`) | `#EEF1F5` | `#1E293B` | 输入框底、表头底、悬停态、标签底 |
| **主墨文本** | `--solid-text-primary` (`--el-text-color-primary`) | `#0F172A` | `#F8FAFC` | 标题、核心表格字段、主按钮反色（对比度 > 14:1） |
| **正文文本** | `--solid-text-regular` (`--el-text-color-regular`) | `#334155` | `#CBD5E1` | 表单标签、常规正文、导航文本（对比度 > 8:1） |
| **次要说明文本** | `--solid-text-secondary` (`--el-text-color-secondary`) | `#475569` | `#94A3B8` | 面包屑、辅助说明、占位提示（保证 `>= 4.5:1`） |
| **禁用/弱占位** | `--solid-text-muted` (`--el-text-color-placeholder`) | `#64748B` | `#64748B` | 仅用于装饰分割或禁用文本 |
| **主品牌钴蓝** | `--solid-primary` (`--el-color-primary`) | `#1D4ED8` | `#3B82F6` | 主 CTA、选中指示条、聚焦环（白字对比度 >= 4.5:1） |
| **主色悬停/按下** | `--solid-primary-hover` (`--el-color-primary-dark-2`) | `#1E40AF` | `#2563EB` | 主按钮 Hover / Active |
| **主色浅底** | `--solid-primary-soft` (`--el-color-primary-light-9`) | `#EFF6FF` | `rgba(59, 130, 246, 0.14)` | 菜单激活底、选中行轻提示、租户提示底 |
| **结构细边框** | `--solid-border` (`--el-border-color`) | `rgba(15, 23, 42, 0.10)` | `rgba(226, 232, 240, 0.12)` | 面板分割线、表格网格线、输入框描边 |
| **弱分割边框** | `--solid-border-light` (`--el-border-color-lighter`) | `rgba(15, 23, 42, 0.06)` | `rgba(226, 232, 240, 0.07)` | 列表行线、工具栏内分隔 |
| **成功语义** | `--solid-success` (`--el-color-success`) | `#047857` | `#10B981` | 正常状态、校验通过（Light 深翡翠绿保 5.4:1 文本对比） |
| **警告语义** | `--solid-warning` (`--el-color-warning`) | `#B45309` | `#F59E0B` | 切租户观察警告、配额预警（Light 深琥珀保 5.0:1） |
| **危险语义** | `--solid-danger` (`--el-color-danger`) | `#DC2626` | `#F87171` | 停用、删除、强退会话、表单错误、Excel 批注错行 |
| **信息中性语义** | `--solid-info` (`--el-color-info`) | `#475569` | `#94A3B8` | 默认只读状态胶囊、中性说明标签 |

---

## 3. 字体排版、圆角与层级标尺

### 3.1 字体栈与字号阶梯
- **UI 正文字体**：`'PingFang SC', 'HarmonyOS Sans SC', 'Microsoft YaHei', 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, sans-serif`
- **等宽与数据字体**：`'JetBrains Mono', 'Cascadia Mono', ui-monospace, SFMono-Regular, monospace`
- **数字排版铁律**：表格单元格、分页数字、统计值、雪花 ID 与时间列统一附加 `font-variant-numeric: tabular-nums;`。
- **字号阶梯**：
  - `12px`（`0.75rem`）：徽标、表格状态 Tag、辅助时间戳（全站可读文本最小底线）
  - `13px`（`0.8125rem`）：侧边栏菜单项、页签文字、高密表格正文、面包屑
  - `14px`（`0.875rem`）：标准正文、表单输入、按钮文案、常规表格正文
  - `16px`（`1rem`）：抽屉/弹窗标题、卡片区块标题
  - `20px`（`1.25rem`）：登录页与工作台主标题

### 3.2 圆角、阴影与 Z-Index 标尺
- **圆角克制收拢**：
  - `--solid-radius-sm: 4px`（小标签、页签内胶囊、紧凑按钮）
  - `--solid-radius-md: 6px`（输入框、标准按钮、菜单项、常规卡片）
  - `--solid-radius-lg: 8px`（外层工作区卡片、对话框主体）
  - `--solid-radius-pill: 9999px`（状态圆点、租户视角徽标）
- **阴影与焦点环**：
  - 内容卡片：`box-shadow: none; border: 1px solid var(--solid-border);`
  - 浮层弹窗/右键菜单：`0 12px 28px -6px rgba(15, 23, 42, 0.14), 0 4px 10px -2px rgba(15, 23, 42, 0.06)`（Dark 模式加深描边至 `rgba(226, 232, 240, 0.16)`）
  - 键盘焦点环（全站可访问性底线）：`outline: none; box-shadow: 0 0 0 2px var(--solid-bg-surface), 0 0 0 4px var(--solid-primary);`

---

## 4. 去模板化自检与修订记录（Pass 2 Critique）

按 `solid-admin-ux` 执行第二遍反模板审校，显式否决以下 AI 默认套路并修订如下：

| 常见 AI 默认套路 | 本设计系统采取的修订措施 | 修订原因 |
| :--- | :--- | :--- |
| 默认紫蓝渐变主色与发光渐变卡片 | 改用纯正深钴蓝 `#1D4ED8` + 零渐变哑光冷石白画布 `#F6F7F9` | 彻底脱离 `theme-pro` 默认靛紫味及 AI 常见炫光模板，强化企业基础设施沉稳感 |
| 浅灰白底配过浅文字 `#94A3B8` 导致对比不足 | 将 Light 次要文本上调至 `#475569`、Success/Warning 收深至 `#047857`/`#B45309` | 严格保证常规文本与彩色文字标签均满足 WCAG `>= 4.5:1` 对比度 |
| 工作台与表单页面堆砌无意义英文全大写 Eyebrow 标签、装饰性序号（`01/02`）与模糊阴影 | 取消所有纯装饰英文眉标、非序列卡片序号及卡片大投影，改用 `1px` 细线与精准中文语义标题 | 减少视觉噪声，把屏幕空间留给真实表格数据与导航层级 |
| 通用笼统按钮文案（如“提交”“确定”） | 全站规范为具体动作动词（“保存配置”“确认删除”“强退会话”“重置密码”） | 配合弹窗二次确认与操作结果反馈保持前后端动词一致 |

---

## 5. `AdminLayout` 布局结构定稿（方案 A · 2026-11-24 评审通过）

经多结构变体原型（[`shell-variants.html`](../../prototypes/phase1/shell-variants.html) 对比 A 经典左侧栏、B 双轨域栏、C 顶左混合流）实测比选，正式选定 **方案 A（经典精密左侧栏 + 单行顶栏 + 独立页签栏）** 作为 `ateng-solid` 第一阶段唯一 `AdminLayout` 架构，并沉淀为纯净基础壳 [`shell-accepted.html`](../../prototypes/phase1/shell-accepted.html)：

- **桌面端骨架尺寸**：
  - 左侧导航栏：展开态 `228px` / 折叠态 `60px`（`transition: width 0.2s ease`），通高置顶承载品牌区与分组菜单；`< 768px` 自动收折为抽屉浮层；
  - 顶部栏：固定高 `48px`，左区承载侧栏折叠开关与面包屑，右区承载租户切换胶囊（仅开启多租户时显示）、Light/Dark 切换按钮与当前用户下拉菜单；
  - 独立多页签条：固定高 `36px`，贴附于顶栏下方，右侧提供当前页刷新与工作区最大化开关；
  - 跨租户观察横幅：仅在 `tenantEnabled = true` 且平台超管切换至非 `0` 号租户时出现于页签栏下方，展示当前工作租户与一键切回平台按钮。
- **被淘汰方案归档**：变体 B（双轨域栏）与变体 C（顶左混合流）记录保留在 [`shell-variants.html`](../../prototypes/phase1/shell-variants.html) 作为布局探索一手记录，不进入第一阶段正式规范。
