# `@atengk/element-plus` 本地构建（含 `#369`–`#372`）Layout 覆写边界、实例隔离与 TS Strict 接入调研报告

> **关联工单**：`atengk/ateng-solid#13`（Wayfinder 前置架构调研）
> **调研日期**：2026-11-24
> **前置基线**：承接 [UI 底座 `1.1.0` 能力调研报告](../prd/_research/ui-1.1.0-capabilities.md)，不重复罗列既有组件基线，聚焦架构选型、增量边界与严格 TS 落地约束。
> **一手信源**：
> - `ateng-ui` 仓库 `dev` 分支 commit `36da58c`（只读核验源码，包含 `#369`–`#372`）
> - `ateng-solid-admin-web/node_modules/@atengk/element-plus`（本地 `.yalc` 构建，包版本声明 `1.1.0`，`yalcSig: 74a243a820bff24247fea4e9aec9ecdc`，已包含 `36da58c` 产物）
> - `ateng-solid-admin-web/node_modules/@atengk/{core,vue}`（`1.1.0`）、`element-plus`（`2.14.7`）、`pinia`（`3.0.0`）
> - 规范与工程基线：`docs/specs/prd/design-system.md`、`docs/specs/prd/00-overview-and-ux-standards.md`、`docs/prototypes/phase1/shell-accepted.html`、`ateng-solid-admin-web/tsconfig.json`、`ateng-solid-admin-web/src/main.ts`、`ateng-solid-admin-web/src/styles/main.css`

---

## 1. `AtengProLayout` 视觉覆写成本 vs 自建轻量方案 A `AdminLayout`

### 1.1 逐行源码审计：样式变量、硬编码尺寸与 `!important` 冲突清单

以下逐文件核查 `ateng-ui` 布局与页签套件中的 CSS 变量、固定尺寸、未接线属性及 `!important` 规则：

| 源码文件（`ateng-ui`） | 关键行号 | 实测现状 | 与方案 A（`Precision Slate & Cobalt`）冲突点 |
| :--- | :--- | :--- | :--- |
| `packages/element-plus/src/components/pro-layout/AtengProLayout.vue` | `L52-54` | `tabsHeight: '38px'`、`fixedHeader: true`、`fixedAside: true` 仅在 `withDefaults` 中声明，**模板与样式全文零引用** | ① 传 `:tabs-height="36"` 无效，必须改传 `:tabs-props="{ height: '36px' }"`；② 根容器为 `min-height: 100vh`（`L709`）而非 `height: 100vh; overflow: hidden`，长表格会滚走顶栏与侧栏，必须 `:deep()` 强覆写视口锁与内容滚动 |
| 同上 | `L485-506` | `<ProLayoutTabs>` 后紧接 `<AtengContent class="at-pro-layout__content"><slot /></AtengContent>`，**两者之间无任何插槽**；`.at-pro-layout__content` 固定 `padding: 16px`（`L866`） | **跨租户观察横幅无原生全宽贴合插槽位**：放进 `#default` 会被 `16px` padding 缩进且随内容滚走；塞进 `#tabs` 需自行接管整个页签栏并在最大化时手动隐藏横幅 |
| 同上 | `L737-746` | `.at-pro-layout__logo { height: 56px; padding: 0 16px; border-bottom: 1px solid var(--el-border-color-extra-light); }` | **Logo 高度硬编码 `56px`**，不随 `:header-height="48"` 联动，导致侧栏底线与 `48px` 顶栏底线错位 `8px`，必须 `:deep()` 覆写 |
| 同上 | `L726, 729, 800, 884` | 侧栏/顶栏边框用 `--el-border-color-lighter`；过渡 `0.25s`；移动端遮罩含 `backdrop-filter: blur(2px)` | 方案 A 要求结构细线 `--solid-border`（`0.10`）、`0.2s ease`、零全屏 `backdrop-filter`（降低低配端 GPU 合成开销） |
| 同上 | `L432-449, 319-323, 911-921` | ① 折叠钮为 `<div role="button">` 缺键盘 Enter/Space 与 `aria-label`；② 面包屑仅按 `menuData` 精确匹配 `activeMenu`；③ `.is-maximized` 对 `header`/`aside`/`drawer-mask` 施加 **3 条 `display: none !important`**，且**无 `ESC` 退出最大化监听** | 隐藏路由（`/profile`、`/403`、`/404`）面包屑为空需覆盖 `#breadcrumb`；需外挂 `ESC` 键监听；折叠按钮无障碍缺失 |
| `packages/element-plus/src/components/pro-layout/ProMenu.vue` | `L120-166` | `.at-pro-menu.el-menu--collapse` 下含 **27 条 `:deep(...) !important`** 规则 | 方案 A 若按 `shell-accepted.html` 展示平铺域分组标题（`首页`/`组织权限`/`基础配置`/`多租户治理`/`审计安全`），`ProMenu` 仅渲染递归 `ElSubMenu`/`ElMenuItem` 不支持 `ElMenuItemGroup`，要实现分组须用 `#menu` 全量接管（等于绕过 `ProMenu`） |
| `packages/element-plus/src/components/pro-layout/ProMenuItemNode.vue` | `L131-139, 270-272` | 二级及以上菜单通过 **行内 `:style` 注入 `paddingLeft: '...px !important'`**（无图标 `60px` 起、有图标 `40px` 起），SubMenu 标题用 `v-bind` + `!important` | **行内 `!important` 无法被任何外部 CSS 覆盖**，侧栏宽度缩窄至 `228px` / `60px` 时难以微调紧凑缩进节奏 |
| `packages/element-plus/src/components/pro-layout/ProLayoutTabs.vue` | `L36-47` | 透传 `tabClick`/`tabClose`/`tabRefresh`/`update:tabs`/`tabOrderChange`/`update:isMaximized`/`maximizeChange`，**未转发 `update:modelValue`** | 使用 `AtengProLayout` 内置 `showTabs` 模式时，点击标签或批量关闭发出的 `update:modelValue` 会被吞掉，必须额外在 `@tabClick` / `@update:tabs` 中手动同步 `activeKey` |
| `packages/element-plus/src/components/tabs-nav/AtengTabsNav.vue` | `L266-269, 294-309, 401-414` | ① 右键与快捷下拉**硬编码 6 枚彩色 Emoji**（`🔄`/`❌`/`🚫`/`⬅️`/`➡️`/`🧹`），无插槽或文案 Prop 可替换；② `tab.icon` 仅支持 `typeof === 'object'` 或 CSS class 字符串，无 `iconResolver` 且跳过函数式图标组件 | 直接违背 `design-system.md` 的极简零装饰/零 Emoji 工程视觉基线 |
| 同上 | `L614-617, 657, 693, 728, 753, 799` | 含 **6 条 `!important`**；拖拽态、Card 激活态、Line 指示条**硬编码 Element Plus 天蓝 `rgba(64, 158, 255, ...)`** 投影；Pill 激活态依赖 `--el-color-primary-rgb`（Element Plus 原生未定义此变量） | 脱离 `theme-pro.css` 且换装深钴蓝 `#1D4ED8` 时，卡片/下划线/拖拽阴影会透出违和的 `#409eff` 天蓝光晕，须大面积 `:deep()` + `!important` 覆写 |

### 1.2 移除 `theme-pro.css` 后的依赖变量与隐性样式断裂风险

`ateng-solid-admin-web/src/styles/main.css` 当前同时导入 `element-plus/dist/index.css`、`element-plus/theme-chalk/dark/css-vars.css`、`@atengk/element-plus/style.css`（`dist/index.css`）与 `@atengk/element-plus/theme-pro.css`。经扫描 `packages/element-plus/src/` 全量 `.vue`/`.ts`/`.scss` 与实测 `dist/index.css` 产物，**移除 `theme-pro.css` 仅保留 `style.css` 后的精确影响如下**：

1. **安全保底项（不会断裂）**：
   - `AtengProLayout` / `ProMenu` / `AtengTabsNav` / `AtengTable` / `AtengQueryForm` / `AtengDialog` / `AtengDrawer` / `AtengDict*` 等业务组件自身**零引用 `--at-*` 变量**，全部基于 Element Plus 标准 `--el-*` 令牌（仅 `AtengTabsNav.vue:728` 引用 `--el-color-primary-rgb` 带回退 `64, 158, 255`，及 `AtengDict*` 引用 `--el-space-base` 带像素回退）。
   - `packages/element-plus/src/styles/index.scss:8-77`（已打入 `dist/index.css`）为 `--at-radius-card`、`--at-radius-dialog`、`--at-shadow-floating`、`--at-shadow-focus-ring`、`--at-ambient-glow`、`--at-bg-overlay-translucent`、`--at-font-mono`、`--at-z-index-*` 及 `v-skeleton`（`.at-skeleton-active`）提供了独立保底定义（注意其中的 `--at-shadow-focus-ring` 与 `--at-ambient-glow` 默认值是 `#409eff`，须在 `Precision Slate & Cobalt` 令牌文件中覆盖）。
2. **高危断裂项（样式仅存于 `theme-pro.css`，`dist/index.css` 完全缺失！）**：
   - **`AtengLoadingBar` / `installLoadingBar(router)` 完全不可见**：`packages/element-plus/src/loading/loadingBar.ts:196-206` 动态向 `document.body` 插入 `.at-loading-bar > .at-loading-bar__track`，其全部样式仅存在于 `packages/element-plus/src/styles/theme-pro/_loading.scss:17-64`；移除 `theme-pro.css` 后进度条高度为 `0` 且无背景色，彻底失效。
   - **`AtengLoading` 组件完全失形**：`packages/element-plus/src/loading/AtengLoading.vue:109-129` 的 scoped CSS 仅定义了 4 条骨架条宽高，核心容器 `.at-loading-container`、顶沿流光 `.at-loading-shimmer-track`、波浪点 `.at-loader-wave-dots`、遮罩 `.at-loading-overlay` 均仅在 `theme-pro/_loading.scss:69-213` 定义。
   - **`initTheme()` 防过渡撕裂锁失效**：`packages/element-plus/src/theme/initTheme.ts:112` 在切换深浅色时添加 `html.is-theme-switching`（250ms），对应冻结规则仅在 `theme-pro/_basics.scss:249-253` 定义。
   - **全局 `tabular-nums` 与 `--el-color-*-rgb` 令牌缺失**：`theme-pro/_typography.scss:37-47` 的表格/分页/标签等宽数字规则与 `theme-pro/_tokens.scss` 的 `--el-color-primary-rgb` 等通道变量不会自动注入；移除 `theme-pro.css` 后须在 `ateng-solid` 自有 `tokens.css`（`Precision Slate & Cobalt`）中显式声明全套 `--el-*`、`--el-color-primary-rgb`、`--solid-*`、`tabular-nums` 及 `html.is-theme-switching` 规则。

### 1.3 客观工程对比表与架构选型建议

| 评估维度 | 方案一：复用 `AtengProLayout` + `:deep()` 覆写 | 方案二：自建轻量方案 A `AdminLayout`（推荐） |
| :--- | :--- | :--- |
| **结构槽位契合度**（228px/60px 左栏、48px 顶栏、36px 页签栏、100vh 锁视口） | **中低**：需覆写 `.at-pro-layout`（锁 `100vh`）、`.at-pro-layout__logo`（`56px -> 48px`）、`.at-pro-layout__content`（改滚动与内边距）、`#breadcrumb`（适配隐藏路由）；`fixedHeader`/`fixedAside`/`tabsHeight` 三个 Prop 实际无效 | **极高（100% 贴合）**：直接按 `design-system.md` §5 与 `shell-accepted.html` 编写 Flex 三区骨架，DOM 扁平、零多余嵌套 |
| **跨租户观察横幅插入位** | **受限**：页签栏与内容区之间无原生插槽，只能魔改 `#tabs`（兼职渲染横幅）或清零 `.at-pro-layout__content` padding 后在 `#default` 自包滚动壳 | **原生天然支持**：紧贴 `<AdminTabsBar>` 下方、`<main>` 滚动区上方直插 `<TenantObserveBanner v-if="..." />`，全宽 1px 底线贴合且最大化态自动隐藏 |
| **CSS 覆盖与 `!important` 冲突** | **高**：`ProMenu` 27 处 + `ProMenuItemNode` 行内 `paddingLeft !important`（无法覆盖）+ `AtengTabsNav` 6 处 `!important` + `#409eff` 硬编码投影 + 6 枚不可替换 Emoji | **极低（零 `!important` 对抗）**：完全消费 `--solid-*` 与 `--el-*` 令牌；侧栏复用 `ElMenu`（支持分组标题与 `@element-plus/icons-vue` 映射），页签条直连 `@atengk/vue` `useTabsNav` 无 Emoji 且零双触发 |
| **脱离 `theme-pro.css` 风险** | 仍需在应用层补全 `--solid-* -> --el-*`、`tabular-nums`、`is-theme-switching` 及顶栏加载条样式，且额外承担 `AtengTabsNav` 残留 `#409eff` 覆写 | 同样在应用层维护单一真源 `tokens.css`（+ 轻量顶栏路由进度条或待底座将 `.at-loading-bar` 迁入 `style.css`），但零第三方布局样式对抗 |
| **响应式抽屉（`<768px`）与最大化** | 内置 `matchMedia(768)` 抽屉与遮罩，但遮罩带 `blur(2px)`、缺 `ESC` 退出最大化、折叠钮缺键盘无障碍 | `useMediaQuery` / `matchMedia`（~25 行）+ `<ElDrawer direction="ltr">` 或原生滑出抽屉 + `ESC` 键退出最大化 + 完整 `aria-label` |
| **生态协同与长期维护成本** | 强耦合 `AtengProLayout` 内部 DOM 类名（上游调样式即破覆写）；仅在未来需要动态切换 `top`/`mix` 三形态时具备复用优势 | **代码量可控（约 220–300 行拆为 `AdminLayout` / `AdminSidebar` / `AdminTopbar` / `AdminTabsBar`）**；最关键的是：**导出 `ATENG_PRO_LAYOUT_KEY` 并在 `AdminLayout` 中 `provide(ATENG_PRO_LAYOUT_KEY, ctx)`（~12 行），即可 100% 保持 `AtengFooterBar` 等下游组件自动侧栏避让协同**！ |

> **选型结论**：在第一阶段明确“唯一方案 A + `Precision Slate & Cobalt` + 脱离 `theme-pro.css`”前提下，**推荐采用自建轻量 `AdminLayout` + 复用 `@atengk/vue` `useTabsNav`（无头页签状态机与 `cachedViews`）+ `provide(ATENG_PRO_LAYOUT_KEY, layoutContext)`**。既彻底避开 `AtengProLayout`/`ProMenu`/`AtengTabsNav` 的行内 `!important`、Emoji 右键菜单、横幅缺位与批关闭双触发问题，又保留 `@atengk/vue` 状态机与 `AtengFooterBar` 生态协同。

---

## 2. `#369`–`#372`（提交 `36da58c`）精确签名与接入边界

已对照 `ateng-ui` commit `36da58c` 源码与 `ateng-solid-admin-web/node_modules/@atengk/element-plus/dist` 本地 `.yalc` 产物逐项核实：

### 2.1 `#369`：`AtengProLayout` `mix` 模式 `headerRight` 默认兜底
- **源码位置**：`packages/element-plus/src/components/pro-layout/AtengProLayout.vue:625-634`
- **精确行为**：`layout === 'mix'` 时，`.at-pro-layout__header-right` 内的 `<slot name="headerRight">` 已补齐与 `side`（`L473-480`）、`top`（`L553-560`）完全一致的默认兜底：
  ```html
  <slot name="headerRight">
    <div v-if="$slots.headerActions" class="at-pro-layout__header-actions">
      <slot name="headerActions" />
    </div>
    <div v-if="$slots.user" class="at-pro-layout__header-user">
      <slot name="user" />
    </div>
  </slot>
  ```
- **接入边界**：
  1. 一旦外部提供 `#headerRight`，`#headerActions` 与 `#user` 自动失效（覆盖关系）。
  2. `.at-pro-layout__header-actions` 与 `.at-pro-layout__header-user` 在组件 `<style scoped>` 中**无样式规则**（为普通 `<div>` 块级包裹），放入多个操作按钮时须自行加 `flex items-center gap-2`。
  3. `mix` 模式依然**不渲染** `#headerLeft`、`#breadcrumb`、`#headerCenter`、`#asideFooter` 与 `#menu`。

### 2.2 `#370`：`AtengDrawer` 新增 `AtengDrawerFooterScope` 并向 `#footer` 透传
- **源码与类型位置**：
  - `packages/element-plus/src/components/drawer/types.ts:153-166, 174`
  - `packages/element-plus/src/components/drawer/AtengDrawer.vue:247`
  - `ateng-solid-admin-web/node_modules/@atengk/element-plus/dist/components/drawer/types.d.ts:122-135, 142`（已通过 `drawer/index.d.ts` ➔ `components/index.d.ts` ➔ `dist/index.d.ts` 顶层导出）
- **精确签名**：
  ```ts
  export interface AtengDrawerFooterScope {
    confirm: () => Promise<void>;
    cancel: () => void;
    loading: boolean;
  }

  export interface AtengDrawerSlots {
    default?: () => VNode[];
    header?: () => VNode[];
    footer?: (scope: AtengDrawerFooterScope) => VNode[];
    title?: () => VNode[];
    placeholder?: () => VNode[];
  }
  ```
- **接入边界**：
  1. `confirm` 完整复用 `useAsyncConfirm`（先 `formRef.validate()` ➔ `emit('confirm')` ➔ 执行 `beforeConfirm` 并加 loading 锁 ➔ 非 `false` 且无异常则关闭并 `emit('success')`）。
  2. `cancel` 走 `handleCloseRequest`（受 `isLoading` 锁定、`beforeClose` 与 `confirmOnClose` 守护）。
  3. `loading` 为 `boolean`（模板解包自 `isLoading`，兼容受控 `confirmLoading` 与内部异步锁）。
  4. **TS 提醒**：因 `@atengk/element-plus` 产物缺 `.vue.d.ts`（见第 4.1 节），模板中 `#footer="{ confirm, cancel, loading }"` 的解构参数在 `vue-tsc` 下目前会被推断为 `any`，如需严格标注或封装回调，可从 `@atengk/element-plus` 导入 `type AtengDrawerFooterScope`。

### 2.3 `#371`：`AtengIconSelect` `#icon` / `#footer` 作用域插槽完整透传
- **源码与类型位置**：
  - `packages/element-plus/src/components/icon-select/types.ts:142-157`
  - `packages/element-plus/src/components/icon-select/AtengIconSelect.vue:187-192, 248-253`
  - `packages/element-plus/src/components/icon-select/IconPanel.vue:35, 128-146, 156-169`
- **精确签名**：
  ```ts
  export interface AtengIconSelectSlots {
    prefix?: () => unknown;
    icon?: (scope: { item: IconItem; selected: boolean }) => unknown;
    footer?: (scope: { selectedItem?: IconItem; copyCode: () => Promise<boolean> }) => unknown;
  }
  ```
- **接入边界**：
  1. `mode="popover"` 与 `mode="dialog"` 双模式均已通过 `v-if="$slots.icon"` / `v-if="$slots.footer"` 向 `IconPanel` 完整转发。
  2. `#icon` 接收 `{ item: IconItem; selected: boolean }`，仅替换图标图形区；`dialog` 模式下图标下方的 `<span class="item-name">{{ item.name }}</span>`（`IconPanel.vue:147`）仍会保留渲染。
  3. `#footer` 在 `IconPanel.vue:156` 绑定 `:selected-item="currentIconItem"` 与 `:copy-code="() => copyCode(modelValue)"`（Vue 模板自动转为驼峰 `selectedItem` 与 `copyCode`）。**重要**：`#footer` **仅替换底部左侧信息与复制按钮区（`.at-icon-select__info`）**，右侧 `<ElPagination>` 始终保留（`IconPanel.vue:170-178`）。
  4. 利用 `#footer` 可直接替换 `IconPanel.vue:166` 默认的 `📋 复制代码` Emoji 按钮；另注意 `dialog` 模式 `#prefix` 默认回退（`AtengIconSelect.vue:211-226`）未包含 `popover` 模式的单字回退（`L168-170`），全量接入 `@element-plus/icons-vue` 应统一通过 `:custom-icons` 注入完整映射表。

### 2.4 `#372`：`AtengExcelExport` 直传 `Blob` 解析 `Content-Disposition` 触发条件
- **源码位置**：
  - `packages/element-plus/src/components/excel-export/AtengExcelExport.vue:17-22, 111-121`
  - `packages/core/src/http/interceptors.ts:33, 41-43, 271-294`
  - `packages/core/src/http/client.ts:109`
  - `packages/core/src/file/disposition.ts:49-85`
- **精确优先级链路**：
  ```ts
  // AtengExcelExport.vue:115-120
  const explicitFilename = props.filename?.trim();
  const resolvedFilename =
    explicitFilename ||
    parseContentDispositionFilename(getBlobDisposition(result), `export_${Date.now()}.xlsx`);
  saveBlobAsFile(result, resolvedFilename, { revokeDelay: 0 });
  ```
  优先级严格为：**① 非空白 `props.filename` ➔ ② `getBlobDisposition(result)` 经 RFC 5987 (`filename*=UTF-8''...`) / `filename="..."` / `filename=...` 解码 ➔ ③ `export_<timestamp>.xlsx`**（纯空白 `filename: '   '` 会被 `trim()` 忽略并落入 ②；响应头格式非法时落入 ③ 而非 `'download'`）。
- **直传 `Blob` 命中 `Content-Disposition` 的 5 项充要前提（缺一即回退时间戳文件名）**：
  1. **强依赖 `@atengk/core` 拦截器 `WeakMap`**：`getBlobDisposition(blob)` 读取的是 `packages/core/src/http/interceptors.ts:33` 模块级 `blobDispositionWeakMap`。只有经过 `http` 或任意 `createHttpClient(...)` 实例（如 `adminHttpClient`）的响应拦截器（`interceptors.ts:286-291`），该 `Blob` 才会被登记 `Content-Disposition`。
  2. **禁止二次包装 `Blob`**：`action` 必须直接返回拦截器产出的原 `Blob` 引用；若执行 `new Blob([res])` 克隆或绕过 `@atengk/core` 改用原生 `fetch`/`axios.create()`，`WeakMap` 查无此键，必回退时间戳名。
  3. **请求必须声明 `responseType: 'blob'`**，以触发 `interceptors.ts:271-294` 的双态 JSON 异常检测与 `WeakMap` 登记。
  4. **浏览器可读取响应头**：同源（Vite 代理 / Nginx 同域）默认可读；跨域部署时后端必须返回 `Access-Control-Expose-Headers: Content-Disposition`。
  5. **单副本 `@atengk/core`**：`ateng-solid-admin-web/node_modules/.pnpm` 已核验 `app` 与 `@atengk/element-plus`（含 `.yalc`）共享唯一 `@atengk/core@1.1.0` 实例，`adminHttpClient` 写入的 `WeakMap` 可被 `AtengExcelExport` 正常读取。
- **与 `useExcel().exportExcel` / `http.download` 的防重约束**：若 `action` 内部自行调用 `adminHttpClient.download(...)`（返回 `Promise<boolean>`）或 `useExcel().exportExcel(...)`（返回 `Promise<string>`），因返回值非 `Blob`，`AtengExcelExport` 会跳过 `saveBlobAsFile` 仅弹成功提示并派发 `export-success`，不会双下载。

---

## 3. `createAtengVue` 实例隔离传递链路全量核查

### 3.1 底层注入与回退机制（`packages/vue/src/context/context.ts`）

1. **`createAtengVue(options)`（`L118-124`）**：执行 `app.provide(ATENG_VUE_CONFIG_KEY, options || {})`。
2. **`useAtengConfig()`（`L103-110`）**：
   - 先判定 `if (!hasInjectionContext()) return DEFAULT_OPTIONS;`——**一旦脱离 Vue 注入上下文，立即静默回落至 `@atengk/core` 全局单例 `{ httpClient: http, authManager, tenantManager, superAdminRoles: ['admin', 'super_admin'], defaultSize: 10 }`！**
   - 在注入上下文内时，`inject(ATENG_VUE_CONFIG_KEY, null)` 后通过 `normalizeAtengConfig`（`L54-74`）按字段空值合并回退至 `DEFAULT_OPTIONS`。
3. **`resolveAtengConfig(provides)`（`L85-94`）**：供自定义指令在非 `setup()` 生命周期内直接从 `provides` 原型链读取 `ATENG_VUE_CONFIG_KEY`。
4. **Pinia 3 与 Router Guard 上下文实测边界**：
   - 核查 `ateng-solid-admin-web/node_modules/pinia/dist/pinia.mjs:1468-1470`：Pinia 3 创建 setup store 时通过 `(pinia._a && pinia._a.runWithContext)` 执行 `setup()`。因此**前提是 `app.use(pinia)` 与 `app.use(createAtengVue(...))` 均已先于首次 `useXxxStore()` 调用**，store `setup()` 同步体内的 `useAtengConfig()` 才可命中自定义实例。
   - **以下 4 类调用点 `hasInjectionContext()` 恒为 `false`（必定回落全局单例！）**：
     1. `router.beforeEach` / `router.afterEach` 导航守卫内直接调 `useAuth()` / `useTenant()`；
     2. Pinia **异步 action 执行体内**动态调 `useAuth()` / `useTenant()` / `useExcel()`；
     3. 普通工具函数 / Axios 拦截器回调内直接调 `useAuth()` / `useTenant()` / `useExcel()`；
     4. Vitest 单测中仅用 `setActivePinia(createPinia())` 未挂载 `app.use(createAtengVue(...))` 时。

### 3.2 各 Composable / 指令 / 组件命中矩阵（`adminAuthManager` / `adminTenantManager` / `adminHttpClient` / `['super_admin']`）

| 能力项 | 源码锚点（`ateng-ui`） | 消费的上下文项 | 组件 `setup()` 内是否自动命中 `createAtengVue` | 非 `setup()` / 隐蔽回落风险与强制接入约束 |
| :--- | :--- | :--- | :--- | :--- |
| **`useAuth`** | `packages/vue/src/auth/useAuth.ts:138-143` | `authManager`、`superAdminRoles` | **自动命中** | 脱离 `setup()`（如 Router 守卫、单测）会回落全局 `authManager` + `['admin', 'super_admin']`，导致 `WeakMap` 响应式状态完全分裂！**Store 与守卫中必须显式传 `{ authManager: adminAuthManager, superAdminRoles: ['super_admin'] }`** |
| **`useTenant`** | `packages/vue/src/tenant/useTenant.ts:53-57` | `tenantManager` | **自动命中** | 同上，脱离 `setup()` 回落全局 `tenantManager`。**Store 与守卫中必须显式传 `{ tenantManager: adminTenantManager }`** |
| **`usePagination`** / **`useRequest`** | `packages/vue/src/pagination/usePagination.ts:70,80`、`request/useRequest.ts:34,100` | **不消费 `httpClient`！** 仅消费 `defaultSize` 与 `onError` | `defaultSize`/`onError` **自动命中** | **重要勘正**：两者均不发网络请求，实际 HTTP 客户端完全由入参 `service` 决定（`ateng-solid-admin-web/src/main.ts:28` 原 TODO 注释表述不准确，真正依赖 `createAtengVue.httpClient` 的是 `useExcel` 与 `AtengExcelFeedback`） |
| **`useExcel`** | `packages/vue/src/excel/useExcel.ts:38,128,176` | `httpClient`、`onError` | **自动命中**（当 `target` 为 URL 字符串或配置对象时） | 脱离 `setup()` 调用且传 URL/配置对象时**隐蔽回落至全局 `http`**（丢失 `satoken-admin` 与 `X-Tenant-Id`）！工具模块中必须显式传 `useExcel({ httpClient: adminHttpClient })` 或传已绑定 `adminHttpClient` 的异步函数 `target` |
| **`v-permission` / `v-role`** | `packages/element-plus/src/directives/shared/createAuthDirective.ts:35-50,198` | `authManager`、`superAdminRoles` | **自动命中**（经 `instance.$.provides` / `vnode.appContext.provides` ➔ `resolveAtengConfig` 显式传给 `useAuth`，兼容 `<Teleport>` 子树） | 仅脱离 `appContext` 的手动 `render(vnode, el)` 或单测未挂插件时回落全局单例 |
| **`AtengUpload`** | `packages/element-plus/src/components/upload/AtengUpload.vue:441-462`、`packages/vue/src/upload/useUpload.ts` | **零消费 `createAtengVue`** | **不会命中（完全绕过！）** | ① `chunk: false` 直传若只配 `:action` 不配 `:http-request`，底层 `ElUpload` 发裸 XHR（`headers: {}`，无鉴权头/租户头、无 401/信封解包），**必须显式传 `:http-request` 桥接 `adminHttpClient`**；② `chunk: true` 必须显式传 `:custom-upload-chunk` / `:custom-merge` 桥接 `adminHttpClient` |
| **`AtengExcelExport`** | `packages/element-plus/src/components/excel-export/AtengExcelExport.vue:107-121` | **零消费 `createAtengVue`** | **不适用**（网络请求完全由外部 `:action` 执行） | 必须由调用方在 `:action` 中显式调用 `adminHttpClient`；直传 `Blob` 时自动共享 `@atengk/core` `blobDispositionWeakMap` 解析文件名 |
| **`AtengExcelFeedback`** | `packages/element-plus/src/components/excel-feedback/AtengExcelFeedback.vue:60-62,176-179` | 经内部 `useExcel()` 间接消费 `httpClient`、`onError` | 传 `:file-url` 时**自动命中** `createAtengVue.httpClient` | ① 组件无 `httpClient` Prop，若使用 `:file-url` 且 `main.ts` 漏绑 `httpClient` 会**隐蔽回落至全局 `http` 报 401**；② 推荐统一传 `:download-action` 显式调用 `adminHttpClient`；③ 注意 `L178` 强制传入 `filename: props.fileName || '导入错误明细批注.xlsx'`，永远压过服务端 `Content-Disposition`（且 `L61` 向 `useExcel` 传入了无效键 `filename`） |
| **附：`useStream` / `useWebSocket`**（二期预留） | `packages/vue/src/stream/useStream.ts:106`、`websocket/useWebSocket.ts:59-73` | **零消费 `createAtengVue`** | **不会命中（隐蔽回落 / 缺失透传）** | ① `useStream` 默认回落绑定全局单例的 `defaultStreamClient`，须显式传 `streamClient`；② `useWebSocket` 未向 `createWebSocketClient` 传递 `authManager`/`tenantManager`，URL 自动拼装鉴权/租户参数失效，须靠 `params` 手动传入 |

> **装配铁律**：`ateng-solid-admin-web/src/main.ts` 必须在 `app.use(router)` 及任何 Store 实例化之前完成 `app.use(createAtengVue({ authManager: adminAuthManager, tenantManager: adminTenantManager, httpClient: adminHttpClient, superAdminRoles: ['super_admin'], defaultSize: 10 }))`，同时在 `useAuthStore`、`useTenantStore`、路由守卫与工具函数中**显式传入同一批管理端单例**做双保险。

---

## 4. TS Strict（`strict` + `noUncheckedIndexedAccess`）接入约束与避坑清单

`ateng-solid-admin-web/tsconfig.json:8-19` 开启了 `strict: true`、`noImplicitAny: true`、`strictNullChecks: true`、`noUncheckedIndexedAccess: true`、`noUnusedLocals: true`、`noUnusedParameters: true`、`noFallthroughCasesInSwitch: true` 与 `skipLibCheck: true`。

### 4.1 前置发现：`@atengk/element-plus` 构建产物缺失 `.vue.d.ts`（组件类型退化为 `any`）

经直接检视 `ateng-solid-admin-web/node_modules/@atengk/element-plus/dist` 与使用项目本地 `typescript@5.6.3` Compiler API 实测验证：
- **根因**：`packages/element-plus/vite.config.ts:18-22` 使用 `vite-plugin-dts`（底层调用 `tsc` 而非 `vue-tsc`）并依赖 `packages/element-plus/src/env.d.ts` 的 `declare module '*.vue'`，导致打包产物 `dist/` 下 **`.vue.d.ts` 文件数量为 `0`**，且各组件 `dist/components/*/index.d.ts` 保留悬空语句 `import { default as AtengXxx } from './AtengXxx.vue'`，同时缺少 `declare module 'vue' { export interface GlobalComponents { ... } }`。
- **实测后果**：
  - `typeof AtengTable`、`typeof AtengQueryForm`、`typeof AtengDrawer`、`typeof AtengIconSelect`、`typeof AtengTabsNav`、`typeof AtengProLayout` 以及 `AtengDrawerInstance` / `AtengTabsNavInstance` 等 `InstanceType<typeof ...>` 别名在 `ateng-solid-admin-web` 中**全部退化为 `any`**！
  - `vue-tsc --noEmit` 不会对任何 `<Ateng*>` 模板上的 Props 拼写、Emit 签名、Slot 作用域字段做编译期校验（例如把 `AtengCaptcha` 的 `:refresh` 误写为 `@refresh` 也不会报错！）。
- **上层硬性避坑规范**：
  1. **组件 `ref` 严禁写 `InstanceType<typeof AtengXxx>` 或使用 `AtengDrawerInstance` / `AtengTabsNavInstance`**：必须显式导入强类型 `*Expose` 接口（如 `shallowRef<AtengTableExpose<SysUserVO> | null>(null)`、`shallowRef<AtengQueryFormExpose<SysUserQuery> | null>(null)`、`shallowRef<AtengDrawerExpose | null>(null)`、`shallowRef<AtengIconSelectExpose | null>(null)`）。
  2. **手动对齐 Props/Slots 契约**：在底座补齐 `.vue.d.ts` 与 `GlobalComponents` 前，封装公共组件或编写页面时显式引用导出的 `*Props` / `*Scope` 接口校验载荷类型。

### 4.2 `DictManager.setProvider` / `setBatchProvider` 与 `DictItem.tagType`

- **精确类型声明**（`node_modules/@atengk/element-plus/dist/components/dict/types.d.ts:35-68`、`DictManager.d.ts:27, 37, 65`）：
  ```ts
  export interface DictItem {
    label: string;
    value: string | number | boolean;
    tagType?: 'success' | 'warning' | 'info' | 'primary' | 'danger' | '' | undefined;
    disabled?: boolean;
    cssClass?: string;
    raw?: unknown;
  }
  export type DictProvider = (code: string) => Promise<DictItem[]>;
  export type DictBatchProvider = (codes: string[]) => Promise<Record<string, DictItem[]>>;
  ```
- **严格 TS 与运行时避坑清单**：
  1. **`DictItem.tagType` 与 `element-plus@2.14.7` `ElTag` 双重约束**：
     - 后端 `sys_dict_data.listClass` 常见值 `'default'` **不可赋值给 `DictItem['tagType']`**（TS 编译报 `TS2322`）。
     - 虽然 `DictItem['tagType']` 允许空串 `''`，但核查 `node_modules/element-plus/es/components/tag/src/tag.d.ts`：`ElTag` 的 `type` 仅允许 `'primary' | 'success' | 'warning' | 'info' | 'danger'`。`AtengDictTag.vue:184` 直接透传 `:type="item.tagType"`，传 `''` 会触发 Element Plus 开发态 Vue Prop 校验警告！
     - **唯一安全写法**：在 `DictProvider` / `DictBatchProvider` 适配器内统一编写白名单收窄函数，将 `'default'` / `''` / `null` / 未知值归一化为 `undefined`（或按设计系统映射为 `'info'`）：
       ```ts
       const VALID_TAG_TYPES = new Set(['success', 'warning', 'info', 'primary', 'danger'] as const);
       type SafeTagType = 'success' | 'warning' | 'info' | 'primary' | 'danger';
       function normalizeTagType(raw?: string | null): SafeTagType | undefined {
         if (!raw || raw === 'default') return undefined;
         return VALID_TAG_TYPES.has(raw as SafeTagType) ? (raw as SafeTagType) : undefined;
       }
       ```
  2. **`noUncheckedIndexedAccess` 下的 `preload` / `batchProvider` 索引**：`await DictManager.preload(['sys_user_sex'])` 返回 `Record<string, DictItem[]>`，索引 `res['sys_user_sex']` 类型为 **`DictItem[] | undefined`**，消费必须加 `?? []`；`install(app, { dictProvider })` 仅注册单查 `setProvider`，`DictManager.setBatchProvider(...)` 必须在插件安装后单独注册。
  3. **静态枚举与动态字典统一路由**：`DictProvider` / `DictBatchProvider` 内按约定的前缀或枚举表名分流至 `/admin/system/enums` 与 `/admin/system/dict/data/type/*`，两者统一转换为上述标准 `DictItem[]`。

### 4.3 `AtengTabsNav`（`TabItem` 与批关闭双触发事件）

- **精确类型声明**（`node_modules/@atengk/vue/dist/index.d.ts:1746-1778`、`node_modules/@atengk/element-plus/dist/components/tabs-nav/types.d.ts:14-110`）：
  ```ts
  interface TabItem {
    key: string;
    title: string;
    icon?: unknown;
    affix?: boolean;
    closable?: boolean;
    componentName?: string;
    meta?: Record<string, unknown>;
  }
  ```
- **严格 TS 与状态流避坑清单**：
  1. **`noUncheckedIndexedAccess` 边界**：`useTabsNav().tabs.value[0]` 类型为 **`TabItem | undefined`**，`tab.meta?.keepAlive` 为 `unknown`，`tab.icon` 为 `unknown`，严禁直接非空访问或无收窄透传。
  2. **批关闭双触发与单关不对称行为**（`AtengTabsNav.vue:88-204`、`useTabsDrag.ts:87-88`）：
     - 点击单标签关闭 / 右键 `close`：仅派发 `tabClose(key, tab)`（**不发** `update:tabs` / `update:modelValue`）；
     - 批量关闭（`closeOthers`/`closeLeft`/`closeRight`/`closeAll`）：**先循环对每个被关页签派发 `tabClose(ct.key, ct)`，紧接着再派发 `update:tabs(newTabs)` 与 `update:modelValue(nextKey)`**；
     - 拖拽排序：同时派发 `update:tabs(newTabs)` 与 `tabOrderChange(newTabs)`；
     - 最大化按钮：同时派发 `update:isMaximized(next)`、`maximizeChange(next)`，并在存在 `ATENG_PRO_LAYOUT_KEY` 时再调 `proLayoutContext.toggleMaximize(next)`。
  3. **避坑规则**：若仍使用 `AtengTabsNav`，切勿同时将 `@tab-close` 接到 `tabsNav.closeTab` 且绑定 `v-model:tabs`（批关闭会触发 N 次冗余 `closeTab` 写存储与路由跳转再被 `update:tabs` 覆盖），也切勿将 `@maximize-change` 接到无参翻转函数；若采纳第 1.3 节建议自建 `AdminTabsBar` 直连 `useTabsNav`（调用 `closeTab`/`closeOthers`/`closeLeft`/`closeRight`/`closeAll`/`moveTab`/`refreshTab`），可一次性消除双触发、Emoji 菜单与 `tab.icon` 无解析器三项缺陷。

### 4.4 `AtengQueryForm`（嵌套 `AtengTable #query`）

- **精确类型声明**（`node_modules/@atengk/element-plus/dist/components/query-form/types.d.ts:22-31, 131-148`、`AtengQueryForm.vue:1`）：
  ```ts
  // AtengQueryForm.vue:1
  // <script setup lang="ts" generic="T extends Record<string, unknown> = Record<string, unknown>">
  export interface AtengQueryFormProps<T = Record<string, unknown>> {
    model?: T;
    pagination?: UsePaginationResult<T>; // 注意：上游泛型缺陷，误将 T 传给 TItem 而非 TParams！
    searchLoading?: boolean;
    autoSearchOnReset?: boolean;
    // ...
  }
  ```
- **实测 4 大严格 TS 与运行时避坑点**：
  1. **上游泛型错位缺陷（已由 `tsc` 实测复现 `TS2322`）**：`UsePaginationResult<TItem, TParams>` 第一泛型为表格行实体，第二泛型为查询参数。`AtengQueryFormProps<UserQuery>['pagination']` 误写为 `UsePaginationResult<UserQuery, PageQuery>`，将 `usePagination<UserRow, UserQuery>(...)` 赋给它直接触发 `TS2322`（`Property 'id' is missing in type 'UserQuery' but required in type 'UserRow'`）。
  2. **嵌套 `<AtengTable #query>` 严禁给 `AtengQueryForm` 传 `:pagination`**：`AtengQueryForm.vue:258-263, 273-280` 在 `handleSearch` 和 `handleReset` 中会**先后各调用一次 `props.pagination.*` 与 `tableContext.*`**，导致每次查询或重置都发**两次重复请求**！正确接法：仅在 `<AtengTable :pagination="pagination">` 绑定分页状态机，内部 `<AtengQueryForm :model="pagination.query" :search-loading="pagination.loading.value">` 通过 `tableContext` 联动。
  3. **`pagination.loading` 必须显式 `.value`（致命运行时陷阱！）**：`AtengQueryForm` **未消费 `tableContext.loading`**（尽管 `AtengTable.vue:923` 提供了它）；而 `usePagination()` 返回的是**普通对象**（非 `reactive`），其 `loading` 是 `DeepReadonly<Ref<boolean>>`。在 Vue 模板中写 `:search-loading="pagination.loading"` 不会自动解包 `Ref`，会传入 `RefImpl` 对象导致 `AtengQueryForm.vue:218` 的 `if (props.searchLoading) return true` **恒为真、查询按钮永久转圈**！必须写 `:search-loading="pagination.loading.value"`（或顶层解构 `const { loading } = pagination`）。
  4. **嵌套重置 `@reset` 双触发 + `type` 声明建议**：点击重置时 `AtengQueryForm.vue:272` 先 `emit('reset')`，随后 `tableContext.reset()` 调用 `registeredResetHandlers`（`AtengQueryForm.vue:232-235`）再次 `emit('reset')`——因此**严禁在 `@reset` 回调中手动调接口**；且为兼容 `T extends Record<string, unknown>`（在未来 `.vue.d.ts` 修复后不报 `TS2344`），查询参数类型推荐用 `type SysUserQuery = PageQuery & { username?: string; deptId?: string }` 而非无索引签名的 `interface`。

### 4.5 `AtengTable` 树表透传与泛型约束

- **精确类型声明**（`node_modules/@atengk/element-plus/dist/components/table/types.d.ts:62-81`、`AtengTable.vue:1, 72, 1126-1139`）：
  ```ts
  // AtengTable.vue:1
  // <script setup lang="ts" generic="T extends Record<string, unknown> = Record<string, unknown>">
  export interface AtengTableProps<T = Record<string, unknown>> {
    data?: T[];
    pagination?: UsePaginationResult<T>; // 注意：未声明第二泛型 TParams，默认 PageQuery
    rowKey?: string | ((row: T) => string);
    // 未显式声明 treeProps / defaultExpandAll / lazy / load / indent / expandRowKeys
  }
  ```
- **严格 TS 与树表透传避坑清单**：
  1. **树表属性透传机制与顺序**：`AtengTable` 设置 `inheritAttrs: false` 并在 `<el-table v-bind="$attrs" :data="tableData" :row-key="rowKey" ...>`（`L1129-1135`）前置透传 `$attrs`。因此 `/system/menu`、`/system/dept` 可直接透传 `:tree-props="{ children: 'children', hasChildren: 'hasChildren' }"`、`:default-expand-all="true"`、`:indent="16"`、`:lazy`、`:load`、`:expand-row-keys`，并显式传 `row-key="id"`（雪花 `string` 主键）与 `:show-pagination="false"`。
  2. **树表严禁开启 `reserveSelection: true`**：`AtengTable.vue:700-746` 的跨页勾选差量计算仅遍历顶层 `tableData.value`，不会递归 `children`，开启会导致树形子节点取消勾选状态不同步。
  3. **动态“展开/折叠全部”**：Element Plus `el-table` 挂载后修改 `default-expand-all` 不影响已渲染行，需通过强类型 ref `tableRef.value?.tableRef?.toggleRowExpansion(node, expanded)` 递归切换，或通过 `:key` 受控重挂（树节点少时）。
  4. **泛型与 `interface` 索引签名陷阱（已实测 `TS2322` / `TS2344`）**：
     - `UsePaginationResult<UserRow, UserQuery>` 可赋值给 `AtengTableProps<UserRow>['pagination']`，但**不可赋值给未指定 `T` 的 `AtengTableProps['pagination']`**（因默认 `T = Record<string, unknown>`，报 `TS2322: Index signature for type 'string' is missing in type 'UserRow'`）。
     - 若业务 VO 使用 `type SysUserVO = { id: string; ... }`（或加索引签名），可同时兼容 `T extends Record<string, unknown>`，避免未来 `@atengk/element-plus` 补齐 `.vue.d.ts` 后爆发 `TS2344`；但根治方案仍应由上游将 `generic="T extends Record<string, unknown>"` 放宽为 `generic="T extends object = Record<string, unknown>"` 并补充 `TParams extends PageQuery = PageQuery`。
  5. **`<el-table-column>` `#default="{ row }"` 类型收窄**：Element Plus 列插槽 `row` 为 `any`，在 `strict` 项目中调用业务方法或访问可选字段时应显式收窄（如通过局部类型守卫/渲染辅助函数或 `(row as SysMenuVO)`），防止绕过 `noUncheckedIndexedAccess` 检查。

---

## 5. 新发现的 `ateng-ui` 底座缺口汇总（供评估是否提报上游 Issue）

依据 `foundation-first-gate.md` 边界，本次调研新识别出以下 `ateng-ui` 底座级缺口（按对 `ateng-solid` 第一阶段影响程度分级）：

| 级别 | 缺口归属与源码位置 | 客观现象 | 对 `ateng-solid` 第一阶段是否构成硬阻断及处置建议 |
| :---: | :--- | :--- | :--- |
| **P1（强烈建议提单）** | `@atengk/element-plus` 类型打包与泛型（`packages/element-plus/vite.config.ts:18-22`、`query-form/types.ts:31`、`table/types.ts:71`、`AtengTable.vue:1`、`AtengQueryForm.vue:1`） | ① `dist/` 缺 `.vue.d.ts` 与 `GlobalComponents`，全部 39 个组件及 `*Instance` 退化为 `any`；② `AtengQueryFormProps<T>['pagination']` 错传 `T` 给 `TItem`；③ `T extends Record<string, unknown>` 排斥无索引签名的 `interface` | **不阻断运行时，但削弱严格 TS 守门价值**。建议向 `atengk/ateng-ui` 提 Issue：切换 `vue-tsc` 生成 `.vue.d.ts` + 导出 `GlobalComponents` + 修正 `AtengQueryForm`/`AtengTable` 泛型约束 |
| **P1（脱离 `theme-pro.css` 必看）** | `@atengk/element-plus` 基础样式脱耦（`packages/element-plus/src/styles/theme-pro/_loading.scss:17-213`、`_basics.scss:249-253` vs `styles/index.scss`） | `AtengLoadingBar`、`AtengLoading`、`html.is-theme-switching` 样式仅打入 `theme-pro.css`，未进入 `style.css`（`dist/index.css`），脱离 `theme-pro.css` 后直接失效 | **若第一阶段用 `installLoadingBar(router)` / `AtengLoading` / `initTheme` 且不加载 `theme-pro.css`，会直接不可见/失效**。建议向 `atengk/ateng-ui` 提 Issue 将组件基础骨架样式下沉至 `dist/index.css`（或确认是否停工等待 / 改用 CSS 覆盖） |
| **P2（组件细节缺陷）** | `AtengQueryForm`（`AtengQueryForm.vue:217-223, 232-235, 258-281`） | 未消费 `tableContext.loading`；嵌套 `AtengTable #query` 时点击重置双次 `emit('reset')`；同时传 `pagination` 时搜索与重置均发双请求 | **可规避不阻断**（按第 4.4 节仅在 `AtengTable` 绑 `pagination`，`AtengQueryForm` 传 `:model` 与 `:search-loading="pagination.loading.value"`），建议提单根治 |
| **P2（组件细节缺陷）** | `AtengExcelFeedback`（`AtengExcelFeedback.vue:60-62, 177-179`） | `L61` 传给 `useExcel` 的 `filename` 不存在于 `UseExcelOptions`；`L178` 强制传非空默认值，压过后端 `Content-Disposition` | **不阻断**（传静态明确 `fileName` 即可工作），建议提单对齐 `#372` 的 `Content-Disposition` 优先级 |
| **P2（组件细节缺陷）** | `AtengDictTag`（`dict/types.ts:47`、`AtengDictTag.vue:184`） | `DictItem.tagType` 允许 `''`，但透传至 `element-plus@2.14.7` `<el-tag :type="">` 触发开发态 Vue Prop 校验警告 | **不阻断**（上层 `DictProvider` 统一归一化为 `undefined`），建议底座同步将 `''` 在渲染层转为 `undefined` |
| **P2（若弃用 `AtengProLayout` 则无影响）** | `AtengProLayout` & `AtengTabsNav`（`AtengProLayout.vue:52-54, 738`、`ProLayoutTabs.vue:36-47`、`AtengTabsNav.vue:116-162, 267, 294-309`） | `fixedHeader`/`fixedAside`/`tabsHeight` 未接线；Logo 固定 `56px`；缺横幅槽位与 `ESC` 退出最大化；`ProLayoutTabs` 漏转发 `update:modelValue`；`AtengTabsNav` 硬编码 Emoji、批关闭双触发、缺 `iconResolver` | **采纳自建轻量方案 A `AdminLayout` 即完全绕开**；可作为通用优化建议反馈 `atengk/ateng-ui` |
| **P3（二期实时能力）** | `useStream` & `useWebSocket`（`packages/vue/src/stream/useStream.ts:106`、`websocket/useWebSocket.ts:59-73`） | 未接入 `useAtengConfig()` 继承 `authManager`/`tenantManager`，且 `useWebSocket` 未暴露 `authManager`/`tenantManager` 配置透传 | 首期未启用 SSE/WS，二期前需向 `atengk/ateng-ui` 提单补齐 |
