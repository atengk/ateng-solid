# `@atengk/{core,vue,element-plus}@1.1.0` 组件能力与 `theme-pro` 视觉令牌基线一手调研报告

> **关联任务**：GitHub Issue #2（`ateng-solid` 前端技术基线核查）
> **调研日期**：2026-11-23
> **一手信源范围**：
> - `d:\source\ateng-solid\ateng-solid-admin-web\node_modules\@atengk\element-plus`（`1.1.0`，`.d.ts` 类型声明、`src/styles/theme-pro/*`、`dist/theme-pro.css`、`dist/index.css`）
> - `d:\source\ateng-solid\ateng-solid-admin-web\node_modules\@atengk\vue`（`1.1.0`，`dist/index.d.ts`）
> - `d:\source\ateng-solid\ateng-solid-admin-web\node_modules\@atengk\core`（`1.1.0`，`dist/index.d.ts`）
> - `d:\source\ateng-ui`（只读对照 Git Tag `v1.1.0`，commit `c0be02b`，仅用于核验 `.d.ts` 无法体现的默认插槽、DOM 渲染及内部联动细节）
> - 对比基线文档：`d:\source\ateng-solid\ateng-solid-admin-web\docs\specs\views-and-routes-spec.md` 与 `d:\source\ateng-solid\ateng-solid-admin-web\.agents\rules\styling-and-ateng-ui.md`

---

## 1. 一手信源导出全景与包装配基线

### 1.1 `@atengk/element-plus@1.1.0` 导出矩阵

依据 `node_modules\@atengk\element-plus\package.json`、`dist\index.d.ts`、`dist\installer.d.ts` 与 `d:\source\ateng-ui\packages\element-plus\src\installer.ts`：

- **样式入口（`package.json#exports`）**：
  - `./style.css` ➔ `./dist/index.css`（包含组件 scoped 样式与 `src/styles/index.scss` 保底令牌及 `v-skeleton` 样式）
  - `./theme-pro.css` ➔ `./dist/theme-pro.css`（由 `src/styles/theme-pro.scss` 独立编译，包含完整 `:root` / `[data-theme]` / `.dark` 令牌与 Element Plus 组件现代主题覆写）
  - `./styles/*` ➔ `./src/styles/*`
- **全局插件安装器 `install(app, options?: AtengElementPlusOptions)` / `installer`**：
  - 通过 `INSTALLED_KEY` Symbol 做幂等保护（`installer.ts:62,125-131`）；
  - `AtengElementPlusOptions` 仅支持 `{ dictProvider?: DictProvider }`（`dist/installer.d.ts:6-11`）；若需注册 `DictManager.setBatchProvider`，须在安装后显式调用；
  - 自动挂载 `app.config.globalProperties.$dictManager = DictManager` 与 `app.provide('DICT_MANAGER', DictManager)`（`installer.ts:151-152`）；
  - 批量注册 **39 个组件**，且每个组件同时注册 `Ateng*` 原名与 `At*` 别名（`installer.ts:77-140`、`dist/index.d.ts:8-9`）：
    - **布局导航类（9）**：`AtengProLayout`、`AtengTabsNav`、`AtengLayout`、`AtengHeader`、`AtengAside`、`AtengContent`、`AtengFooter`、`AtengPageContainer`、`AtengSplitLayout`
    - **容器卡片与锚点网格（7）**：`AtengDialog`、`AtengDrawer`、`AtengCard`、`AtengCardGroup`、`AtengFooterBar`、`AtengGrid`、`AtengAnchor`
    - **表格查询与详情展示（7）**：`AtengQueryForm`、`AtengTable`、`AtengDescriptions`、`AtengDescriptionsItem`、`AtengEmpty`、`AtengPageSkeleton`、`AtengStatistic`
    - **字典与表单控件（8）**：`AtengDictSelect`、`AtengDictRadio`、`AtengDictCheckbox`、`AtengDictTag`、`AtengDateRange`、`AtengIconSelect`、`AtengCaptcha`、`AtengUpload`
    - **Excel 与文件预览（3）**：`AtengExcelFeedback`、`AtengExcelExport`、`AtengFilePreview`
    - **文本代码日志与安全加载（5）**：`AtengStreamText`、`AtengLogViewer`、`AtengCodeView`、`AtengWatermark`、`AtengLoading`
  - 批量注册 **6 个指令**（`installer.ts:143-148`、`dist/directives/index.d.ts:7-12`）：`v-permission`（`vPermission`）、`v-role`（`vRole`）、`v-idempotent`（`vIdempotent`）、`v-copy`（`vCopy`）、`v-watermark`（`vWatermark`）、`v-skeleton`（`vSkeleton`）。
  - 独立工具门面：`DictManager`（`dist/components/dict/DictManager.d.ts`）、`AtengLoadingBar` / `installLoadingBar`（`dist/loading/loadingBar.d.ts`）、`initTheme` / `setThemeColor` / `mixColor`（`dist/theme/index.d.ts`）。

---

## 2. `@atengk/element-plus@1.1.0` 核心组件能力逐项核验

### 2.1 `AtengProLayout`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\pro-layout\index.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\pro-layout\types.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\pro-layout\context.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\pro-layout\AtengProLayout.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\pro-layout\ProMenu.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\pro-layout\ProMenuItemNode.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\pro-layout\ProLayoutTabs.vue`

1. **支持的布局模式**：`ProLayoutMode = 'side' | 'top' | 'mix'`（`types.d.ts:9`，默认 `'side'`）。
   - `'side'`：左侧垂直菜单（支持移动端 `< mobileBreakpoint`（默认 `768`）抽屉化）+ 右侧顶栏 + 标签栏 + 内容区 + 页脚。
   - `'top'`：顶栏承载 Logo + 水平 `ProMenu` + 右侧操作区，无侧边栏。
   - `'mix'`：顶栏承载 Logo + 一级水平 `mixTopMenuData` + 右侧操作区；下方左栏渲染当前选中一级大类的 `children`（若无子菜单则自动隐藏侧栏 `currentAsideWidth = '0px'`）；支持 `mixAutoSelectFirstLeaf`（默认 `true`）自动选中首个叶子菜单。
2. **完整插槽清单（`AtengProLayoutSlots`，共 14 个）** 与 **三模式可用性差异（重要）**：
   - `default`：主体内容区；
   - `logo?: (props: { collapsed: boolean; title: string; logo?: string }) => VNode[]`：默认渲染 `<img v-if="logo">` + `<span v-if="!internalCollapsed">{{ title }}</span>`；
   - `headerLeft`、`breadcrumb`、`headerCenter`：**仅 `'side'` 模式渲染**（`AtengProLayout.vue:452-469`），`'top'` 与 `'mix'` 模式不渲染；
   - `headerRight`：三种模式均渲染，但在 `'side'` 和 `'top'` 下内置默认兜底为 `$slots.headerActions` + `$slots.user`；**而在 `'mix'` 模式下（`AtengProLayout.vue:625-627`）仅写 `<slot name="headerRight" />`，无 `headerActions`/`user` 默认兜底**！
   - `headerActions`、`user`：仅当未覆盖 `#headerRight` 且处于 `'side'` 或 `'top'` 模式时自动渲染；
   - **注意**：`AtengProLayoutSlots` **不存在名为 `extra` 的插槽**（顶栏右侧扩展应使用 `headerRight` 或 `headerActions` + `user`；页面级 `AtengPageContainerSlots` 才有 `extra`）；
   - `menu?: (props: { menuData; mode: 'horizontal' | 'vertical'; collapsed: boolean })`：仅 `'side'` 与 `'top'` 模式支持全量接管（`'mix'` 模式未包 `#menu` 插槽）；
   - `menuItem?: (props: { item: ProMenuItem; depth: number })` 与 `menuIcon?: (props: { icon: string | Component; item: ProMenuItem; depth: number })`：三种模式均透传至 `ProMenu` / `ProMenuItemNode`；
   - `asideFooter?: (props: { collapsed: boolean })`：**仅 `'side'` 模式渲染**；
   - `tabs`：三种模式均由 `ProLayoutTabs.vue` 承载；若不覆盖 `#tabs` 且设 `showTabs: true`，则内部自动渲染 `<AtengTabsNav v-bind="tabsProps" :is-maximized="internalMaximized" />` 并转发 `tabClick`、`tabClose`、`tabRefresh`、`update:tabs`、`tabOrderChange`、`update:isMaximized`、`maximizeChange`；
   - `footer`：三种模式均在内容区底部渲染。
3. **菜单数据结构、`fieldNames` 与 `iconResolver` 扩展点（`#365` 已在 `1.1.0` 落地）**：
   - `ProMenuItem` 字段：`path`、`title`、`icon?: string | Component`、`children?`、`badge?`、`badgeType?`、`disabled?`、`hidden?`、`affix?`、`target?: '_blank' | '_self'`、`meta?`；支持 `ProMenuFieldNames` 自定义字段映射；
   - `iconResolver?: ProMenuIconResolver`（`types.d.ts:99,127`）：签名 `(icon: string | Component, item: ProMenuItem, depth: number) => Component | string | undefined`。在 `ProMenuItemNode.vue:73-90` 中：
     - 若返回 Vue 组件（`object` 或 `function`），渲染 `<el-icon><component :is="resolvedIcon" /></el-icon>`；
     - 若返回非空字符串，渲染 `<el-icon><i :class="resolvedIcon" /></el-icon>`；
     - 若返回 `undefined`，回退使用原始 `itemIcon`；
     - 若未传有效 `icon`，渲染 `.at-pro-menu__fallback-icon`（默认 `display: none`，仅在侧栏 `el-menu--collapse` 折叠态下显示 `24×24` 标题首字母徽章）。
4. **布局上下文与 Expose**：
   - 向下 `provide(ATENG_PRO_LAYOUT_KEY, AtengProLayoutContext)`（含 `collapsed`、`asideWidth`、`headerHeight`、`layout`、`isMobile`、`isMaximized`、`toggleCollapse`、`toggleMaximize`），可被内部 `AtengTabsNav` 与 `AtengFooterBar` 注入协同；
   - `defineExpose<AtengProLayoutExpose>` 暴露 `toggleCollapse`、`toggleMaximize`、`collapsed`、`isMaximized`、`asideWidth`；
   - 内部样式注意：`is-maximized`、折叠态居中（`ProMenu.vue:120-166`）及无图标缩进（`ProMenuItemNode.vue:133,137,271`）含组件内置 `!important` 对齐防御规则。

---

### 2.2 `AtengTabsNav`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\tabs-nav\index.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\tabs-nav\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\tabs-nav\AtengTabsNav.vue`

1. **Props 与视觉风格（`AtengTabsNavProps`）**：
   - `modelValue?: string`（当前激活 `tab.key`）、`tabs?: TabItem[]`（复用 `@atengk/vue` 的 `TabItem`）；
   - `styleType?: 'card' | 'pill' | 'line'`（默认 `'card'`）、`height?: number | string`（默认 `'38px'`）；
   - `showIcon`（`true`）、`closable`（`true`）、`draggable`（`true`）、`contextMenu`（`true`）、`showQuickActions`（`true`）、`showMaximize`（`true`）、`isMaximized`（`false`）。
2. **右键上下文菜单与右侧快捷操作**：
   - 开启 `contextMenu` 时，每个标签由 `<ElDropdown trigger="contextmenu" :teleported="true">` 包裹，固定提供 **6 项 `TabCommand`**（`AtengTabsNav.vue:292-311`）：
     1. `refresh`（刷新当前）
     2. `close`（关闭当前，`:disabled="!isTabClosable(tab)"`）
     3. `closeOthers`（关闭其他，`:disabled="!canCloseOthers(tab)"`）
     4. `closeLeft`（关闭左侧，`:disabled="!canCloseLeft(index)"`）
     5. `closeRight`（关闭右侧，`:disabled="!canCloseRight(index)"`）
     6. `closeAll`（全部关闭，`:disabled="!canCloseAll()"`）
   - 右侧 `showQuickActions` 下拉针对当前激活 `activeKey` 提供除 `close` 外的 5 项命令（`AtengTabsNav.vue:399-415`）。
3. **`affix` 固定标签保护规则（`AtengTabsNav.vue:60-85,116-163,255`）**：
   - `tab.affix === true` 时：`isTabClosable(tab)` 强制返回 `false`（不显示关闭小叉号、右键“关闭当前”禁用）；
   - 批量关闭命令（`closeOthers`/`closeLeft`/`closeRight`/`closeAll`）全部显式过滤保留 `t.affix` 项；
   - 原生 HTML5 拖拽属性 `:draggable="draggable && !tab.affix ? 'true' : 'false'"` 禁止拖走固定页签，配合 `useTabsDrag` 阻止普通标签拖入固定区。
4. **事件契约（`AtengTabsNavEmits`）与关键状态流转差异**：
   - `update:modelValue(key)`、`update:tabs(tabs)`、`tabClick(tab)`、`tabClose(key, tab)`、`tabRefresh(key, tab)`、`tabOrderChange(newTabs)`、`maximizeChange(isMaximized)`、`update:isMaximized(isMaximized)`；
   - **重要行为差异**：点击单标签关闭按钮或右键 `close` / `refresh` **仅触发 `tabClose` / `tabRefresh`，不会自动触发 `update:tabs`**（需父级在 `@tab-close` 中调用 `useTabsNav.closeTab`）；而执行 `closeOthers`/`closeLeft`/`closeRight`/`closeAll` 时，组件内部会**既逐一 emit `tabClose`，又直接 emit `update:tabs` 与 `update:modelValue`**（`AtengTabsNav.vue:116-162`）；
   - 最大化按钮会同步注入调用 `proLayoutContext?.toggleMaximize(nextVal)`（`AtengTabsNav.vue:187-204`）。
5. **插槽（`AtengTabsNavSlots`）**：`tab({ tab, active, index })`、`prefix`、`suffix`、`extra`。

---

### 2.3 `AtengQueryForm`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\query-form\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\query-form\AtengQueryForm.vue`

1. **列数与容器感知响应式断点（`AtengQueryFormProps`）**：
   - `cols?: number | QueryFormResponsiveCols`；内部使用 `ResizeObserver` 监听 `<el-form>` 根节点真实 `clientWidth`（非单纯依赖窗口宽度，适合与 `AtengSplitLayout` 左树右表分栏配合！）；
   - 默认断点策略（`AtengQueryForm.vue:127-130`）：`< 768px` 为 `1` 列，`768~1200px` 为 `2` 列，`1200~1920px` 为 `3` 列，`>= 1920px` 为 `4` 列；固定数字限制在 `1~24`；
   - `gutter?: number` 默认 `16`，采用 CSS Grid `repeat(currentCols, minmax(0, 1fr))` 排版，操作区自动跨剩余列数右对齐。
2. **折叠机制**：
   - `collapsed?: boolean`（受控）与 `defaultCollapsed?: boolean`（默认 **`true`**）；
   - `collapsedRows?: number`（默认 `1`）；当 `cols <= 1` 时 `maxVisibleCount = rows`，否则 `maxVisibleCount = rows * cols - 1`（为操作栏预留最后 1 格）；
   - `showCollapse?: boolean`（默认 `true`），仅当 `totalItems > maxVisibleCount` 时显示展开/收起按钮；隐藏项使用 `v-show`（`AtengQueryForm.vue:332`），保留表单控件 DOM 状态与校验态。
3. **查询、重置与回车防抖**：
   - `enterSearch?: boolean`（默认 `true`），内置中文输入法 IME 防御 `if (event.isComposing || event.keyCode === 229) return`；
   - 查询与重置按钮均内置 `v-idempotent` 防连点；
   - `autoSearchOnReset?: boolean`（默认 `true`）。`handleReset()` 执行顺序（`AtengQueryForm.vue:270-282`）：① `formRef.value?.resetFields()` ➔ ② `emit('reset')` ➔ ③ 若传 `props.pagination` 调用 `props.pagination.reset()` ➔ ④ 若 `autoSearchOnReset !== false` 再触发 `emit('search', effectiveModel.value)` 与 `tableContext?.reset()`。**接入注意**：若 `AtengQueryForm` 已传 `:pagination="pagination"` 且嵌套在同样绑了 `:pagination="pagination"` 的 `<AtengTable #query>` 插槽内，点击重置会导致 `props.pagination.reset()` 与 `tableContext.reset()` 各调用一次（`AtengTable.vue:918`）；建议在嵌套进 `AtengTable` `#query` 时通过 `tableContext` 联动（或只在 `AtengTable` 传 `pagination`，`AtengQueryForm` 传 `:model="pagination.query" :search-loading="pagination.loading"`），避免双重重置请求。
4. **插槽与 Expose**：
   - 插槽（`AtengQueryFormSlots`）：`default`、`action({ collapsed, toggle, search, reset, model })`、`extra`；
   - Expose（`AtengQueryFormExpose`）：`formRef`、`validate`、`clearValidate`、`resetFields`、`search`、`reset`、`toggleCollapse`、`collapsed`。

---

### 2.4 `AtengTable`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\table\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\table\AtengTable.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\table\utils\vnode.ts`

1. **工具栏与密度控制**：
   - `tools?: boolean | TableToolItem[]`（默认 `true`），5 个原子项为 `'refresh' | 'density' | 'stripe' | 'column-setting' | 'fullscreen'`；另支持 `#toolbar-left` 与 `#toolbar-right`；
   - `density?: 'large' | 'default' | 'small'`（默认 `'default'`），分别对应 `.at-table--large/default/small` 的单元格上下内边距 `12px`/`8px`/`4px`（`AtengTable.vue:1384-1400`）；
   - `stripe` 默认 `false`、`border` 默认 `true`；全屏模式支持 `ESC` 键退出。
2. **列配置、列宽拖拽与持久化**：
   - 支持**混合列模式**：可传 `:columns="TableColumnConfig[]"`（支持 `prop`/`label`/`width`/`minWidth`/`fixed`/`sortable`/`align`/`type`/`visible`），亦可直接在 `#default` 书写原生 `<el-table-column>`（属性列渲染在前，插槽列经 `parseColumnVNodes` 与 `filterAndSortColumnVNodes` 处理后渲染在后）；
   - 列唯一键计算：`getColumnKey(col) = col.prop || col.label || col.type`（`AtengTable.vue:277`）；
   - 列设置 Popover 支持单列显隐、全选/半选、HTML5 拖拽重排、重置恢复初始顺序宽度；`enableColumnResize` 默认 `true`（最小安全宽度 `minResizeWidth` 默认 `40px`）；配置 `storageKey` 后，列顺序 `order`、显隐 `visible`、宽度 `widths` 持久化至 `localStorage`。
3. **双轨分页与 `usePagination` 联动**：
   - 绑定 `:pagination="pagination"` 时，自动消费 `records`、`loading`、`error`、`total`、`current`、`size`，并将分页条翻页、条数变更（默认 `pageSizes: [10, 20, 50, 100]`、`paginationLayout: 'total, sizes, prev, pager, next, jumper'`）、列头排序（`ascending`/`descending` 映射为 `[{ property, direction: 'ASC' | 'DESC' }]`）、刷新、检索与重置自动对接至状态机；
   - 离散模式可独立传 `data`、`loading`、`error`、`total`、`current`、`size`，并通过 `showPagination` 控制显隐（默认未传时有 `pagination` 或 `total` 自动显示）。
4. **树形表格支持（关键核实）**：
   - `AtengTableProps` **未显式声明** `treeProps`、`defaultExpandAll`、`lazy`、`load`、`indent` 等树表属性；
   - 但 `AtengTable` 声明了 `inheritAttrs: false` 并在底层 `<el-table v-bind="$attrs" :row-key="rowKey">`（`AtengTable.vue:72,1129-1131`）透传全部属性与事件，且默认 `rowKey: 'id'`（兼容雪花字符串主键）；
   - 因此 `/system/menu`、`/system/dept` 等树表可直接在使用 `<AtengTable>` 时透传 `:tree-props="{ children: 'children', hasChildren: 'hasChildren' }"`、`default-expand-all`、`:show-pagination="false"` 完整使用 Element Plus 树形表格能力。
5. **操作列写法**：
   - 组件无专有 `action` Prop；推荐在默认插槽 `<template #default>` 内直接编写 `<el-table-column label="操作" fixed="right" width="...">` 并使用 `#default="{ row }"` 作用域插槽；因 `parseColumnVNodes`（`vnode.ts:31`）识别 `label: '操作'`，操作列也会受控进入列设置与顺序管理（且在 `filterAndSortColumnVNodes` 中原样保留按钮组与 `v-permission` 指令）。
6. **跨页多选、批量操作栏与三态缺省页**：
   - 开启 `reserveSelection: true`（自动内部组合 `@atengk/vue` `useSelection`）或传入外部 `:selection` 实例，在选中行数 `> 0` 且 `showBatchBar: true` 时渲染底部粘滞批量操作悬浮条（支持 `#batch-actions="{ selectedRows, clearSelection }"`）；
   - 空态自动区分：`hasError` ➔ `AtengEmpty(status="network-error")`（带重试按钮）；`isSearchEmpty`（探测存在非保留键筛选参数且无结果）➔ `AtengEmpty(status="search")`（带“清空筛选条件”按钮）；常规无数据 ➔ `AtengEmpty(status="empty")`。

---

### 2.5 `AtengDialog` 与 `AtengDrawer`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\dialog\types.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\drawer\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\dialog\AtengDialog.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\drawer\AtengDrawer.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\shared\useAsyncConfirm.ts`

1. **尺寸与交互默认基线对比**：
   | 维度 | `AtengDialog` | `AtengDrawer` |
   | :--- | :--- | :--- |
   | **默认宽度 / 尺寸** | `width: '50%'`、`maxHeight: 'calc(100vh - 160px)'`（全屏 `120px`） | `size: 'default'`（`'small'`=`360px`、`'default'`=`500px`、`'large'`=`720px` 或自定义）、`direction: 'rtl'` |
   | **移动端适配** | `< 768px` 强制全屏（`isMobile`） | `< 768px` 且方向为 `rtl`/`ltr` 时强制 `'100%'` |
   | **拖拽与全屏** | `draggable: true`、`showFullscreen: true`（支持双击 Header） | 无拖拽/全屏，支持 `withHeader: true` |
   | **防误触关闭** | `closeOnClickModal: false`、`closeOnPressEscape: true`、`confirmOnClose: false` | `closeOnClickModal: false`、`closeOnPressEscape: true`、`confirmOnClose: false` |
   | **分帧延迟挂载** | `lazyRender: false`（展开期间渲染 `ElSkeleton` / `#placeholder`） | `lazyRender: false`（展开期间渲染 `ElSkeleton` / `#placeholder`） |
2. **插槽契约（含 `footer` 作用域差异）**：
   - `AtengDialogSlots`：`default`、`header`、`title`、`placeholder`、`footer(scope: AtengDialogFooterScope)`（实际传出 `:confirm="handleConfirm" :cancel="handleCancel" :loading="isLoading"`，`AtengDialog.vue:310`）；
   - `AtengDrawerSlots`：`default`、`header`、`title`、`placeholder`、`footer()`（**源码细节注意**：`AtengDrawer.vue:247` `<slot name="footer">` **未透传** `{ confirm, cancel, loading }` 作用域参数，若自定义 Drawer 页脚须通过 `ref` 调 `drawerRef.confirm()` / `cancel()`）。
3. **异步 Loading 锁与校验阻断协议（`useAsyncConfirm.ts:62-123`）**：
   - 点击确定按钮 ➔ ① 若传 `formRef`（支持 Ref 或 Getter），优先执行 `await form.validate()`；**校验失败直接就地返回，不开启 loading、不 emit `confirm`、不调 `beforeConfirm`、不关闭容器**；
   - ② 校验通过后 emit `confirm`；
   - ③ 若无 `beforeConfirm`，直接关闭（`update:modelValue(false)` + `close`）并 emit `success`；
   - ④ 若 `beforeConfirm` 返回 Promise，自动置 `internalLoading = true`（锁定确认按钮、禁用取消/关闭/遮罩/ESC 键）；返回值 `!== false` 且未 reject 时关闭并 emit `success`；若抛错或显式返回 `false` 则保持容器打开保护表单现场，并在 `finally` 释放 loading。

---

### 2.6 `AtengCaptcha`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\captcha\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\captcha\AtengCaptcha.vue`

1. **`type="image"` 图形验证码模式能力**：
   - **入参 Props**：
     - `type: 'image'`（默认 `'button'`）；
     - `imageSrc?: string`（支持 HTTP URL 或 Base64 Data URL；为空时展示“点击获取”占位提示）；
     - `imageWidth?: string | number`（默认 `'110px'`）、`imageHeight?: string | number`（默认 `'32px'`）；
     - `refresh?: () => Promise<void> | void`（**重要**：点击刷新是 **Prop 回调函数**，不是 Emit 事件！）；
     - `disabled?: boolean`、`customClass?: string`。
   - **刷新与防重机制（`AtengCaptcha.vue:188-200`）**：点击图片容器时，若未 `disabled` 且未 `isLoading` 且传入 `props.refresh`，自动置 `isLoading = true` 并发起 `await props.refresh()`；异常时 emit `error(err)`，`finally` 释放 `isLoading`；不会启动倒计时定时器。
   - **插槽与事件**：
     - `#loading` 插槽可自定义加载中遮罩（默认显示 `加载中...`）；
     - `AtengCaptchaEmits` 包含 `start`、`end`、`change(remaining)`、`error(error)`（`image` 模式下仅 `refresh` 抛错会触发 `error`）；
     - `AtengCaptchaExpose` 暴露 `{ start, reset, remainingSeconds, isCounting, isLoading }`。
2. **`type="button"` 倒计时模式**：支持 `seconds`（`60`）、`storageKey` + `storageType: 'local' | 'session'` 到期时间戳持久化防刷新清零、`beforeSend` 前置异步校验与 `send` 异步动作。

---

### 2.7 `AtengUpload`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\upload\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\upload\AtengUpload.vue`

1. **头像与直传场景（`chunk: false` 默认值）**：
   - **`httpRequest` 与透传修复（`#367` 已在 `1.1.0` 落地）**：`AtengUploadProps` 显式声明 `httpRequest?: (options: UploadRequestOptions) => XMLHttpRequest | Promise<unknown>`；`defineOptions({ inheritAttrs: false })` 隔离根部 `class`/`style` 与内部 `<el-upload>` 属性透传；`:http-request="chunk ? handleCustomHttpRequest : httpRequest"`（`AtengUpload.vue:32-35,461`），可直接传入对接 `@atengk/core` `http` 客户端的自定义上传函数，确保携带 `satoken-admin` / `X-Tenant-Id` 并识别业务错误信封。
   - **限制参数与前置拦截（`handleBeforeUpload`，`AtengUpload.vue:161-183`）**：
     - `maxSize?: number`（字节上限，如 `2 * 1024 * 1024`）：超限触发 `emit('size-exceed', rawFile, props.maxSize)` 并调用 `ElMessage.error(...)` 阻断；
     - `accept?: string`（支持逗号分隔后缀 `.jpg,.png`、MIME 通配符 `image/*` 与精确 MIME）：不匹配触发 `emit('type-reject', rawFile, props.accept)` 并调用 `ElMessage.error(...)` 阻断；
     - 支持透传自定义 `beforeUpload`、`beforeRemove`、`limit`（超数触发 `exceed`）、`multiple`（默认 `false`）、`listType: 'text' | 'picture' | 'picture-card'`（默认 `'text'`）、`showFileList`（默认 `true`）、`autoUpload`（默认 `true`）、`drag`（默认 `false`）、`name`（默认 `'file'`）、`action`（默认 `'#'`）。
   - **事件列表（`AtengUploadEmits`）**：
     - 通用/直传：`update:fileList`、`change`、`preview`、`preview-close`、`remove`、`success`、`error`、`progress`、`exceed`、`size-exceed(file, maxSize)`、`type-reject(file, accept)`；
     - 分片模式（`chunk: true`）：`chunk-progress`、`chunk-success`、`chunk-error`、`status-change`。
   - **灯箱预览与内存安全**：`showPreview` 默认 `true`，内部集成 `AtengFilePreview`（`mode="dialog"`、`previewDialogWidth: '80%'`、`previewHeight: '520px'`），自动管理 `URL.createObjectURL` 并在关闭、移除、`clearFiles` 及 `onUnmounted` 时全量 `URL.revokeObjectURL`。

---

### 2.8 `AtengIconSelect`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\icon-select\types.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\icon-select\icons-data.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\icon-select\AtengIconSelect.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\icon-select\IconPanel.vue`

1. **交互形态与参数**：
   - `mode?: 'popover' | 'dialog'`（默认 `'popover'`，`popoverWidth` 默认 `380`，`dialog` 宽度固定 `'560px'`）；
   - `pageSize?: number`（默认 `36`，`0` 为不分页）、`clearable: true`、`showCopy: true`、`customIcons?: IconItem[]`。
2. **默认图标库规模与集成关键限制（重要）**：
   - `DEFAULT_ICONS: IconItem[]`（`icons-data.ts:10-401`）共内建 **40 个** 常用图标元数据（包含 `name`、`label`、拼音/简拼 `pinyin`、零依赖 `svgPath`）；
   - 传入 `customIcons` 时会拼接于前部 `[...props.customIcons, ...DEFAULT_ICONS]`，支持 `component?: Component`（如 `@element-plus/icons-vue` 图标组件）或 `svgPath?: string` 渲染；
   - **若业务菜单需要从全量 `@element-plus/icons-vue` 选择图标，必须由业务侧映射构造 `customIcons` 传入**，否则组件仅可见上述 40 个默认图标；
   - **代码/插槽现状提示**：
     - 复制代码格式固定为 `<el-icon><${iconName} /></el-icon>`；
     - `AtengIconSelectSlots` 在 `.d.ts` 中声明了 `prefix`、`icon`、`footer` 三个插槽，但在 `1.1.0` `AtengIconSelect.vue` + `IconPanel.vue` 源码中**仅 `#prefix` 真正渲染生效**，`#icon` 与 `#footer` 尚未透传至 `IconPanel.vue`。

---

### 2.9 `AtengDictTag` / `AtengDictSelect` / `AtengDictRadio` / `AtengDictCheckbox` 与 `DictManager`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\dict\types.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\dict\DictManager.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\dict\utils.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\dict\AtengDictTag.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\dict\AtengDictSelect.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\dict\AtengDictRadio.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\dict\AtengDictCheckbox.vue`

1. **标准字典数据结构与字段映射**：
   - `DictItem`：`{ label: string; value: string | number | boolean; tagType?: 'success' | 'warning' | 'info' | 'primary' | 'danger' | '' | undefined; disabled?: boolean; cssClass?: string; raw?: unknown }`；
   - `DictFieldNames` 默认键名：`label: 'label'`、`value: 'value'`、`tagType: 'tagType'`、`disabled: 'disabled'`、`cssClass: 'cssClass'`；四组件均支持整套 `fieldNames` 及快捷 `labelField`/`valueField`/`tagTypeField`/`disabledField`，由 `normalizeDictItems` 自动归一化（先自定义字段后回退标准字段）；
   - **`valueType?: 'auto' | 'string' | 'number'`**（默认 `'auto'`）：比对时按 `String(itemValue) === String(targetValue)` 弱匹配，解决后端枚举/字典键为 `'0'`/`'1'` 字符串而表单绑数字 `0`/`1`（或反之）的回显失灵问题；选择变更时在 `'auto'` 模式下尽量维持外部原 `modelValue` 类型。
2. **`DictManager`（`DictManagerClass` 全局单例）**：
   - **纯内存 `Map` 缓存**（不写 WebStorage）+ **`inFlight` 飞行中并发请求去重合并**（同一页面多处同时挂载相同 `dictCode` 仅发一次请求）；
   - 核心方法：`setProvider(provider: (code: string) => Promise<DictItem[]>)`、`setBatchProvider(provider: (codes: string[]) => Promise<Record<string, DictItem[]>>)`、`loadDict(code, customLoader?, forceRefresh?)`、`preload(codes)`（增量过滤已缓存项，优先走 `batchProvider`，无则并发降级 `loadDict`）、`hasCache(code)`、`getCache(code)`、`clearCache(code?)`；异常时全部安全保底返回 `[]`。
3. **四组件特化能力对比**：
   | 组件 | 默认配置与独有特性 | 插槽与 Expose |
   | :--- | :--- | :--- |
   | `AtengDictTag` | `effect: 'light'`、`round: false`、`separator: ','`、`emptyText: '-'`；支持单值、数组、分隔符字符串；未匹配值降级渲染原值普通 Tag | `#empty`、`#default="{ item }"`；Expose：`refresh`, `dictItems`, `matchingItems`, `isLoading` |
   | `AtengDictSelect` | `placeholder: '请选择'`、`clearable: true`、`filterable: true`、`multiple: false`、`collapseTags: false`、`maxCollapseTags: 1`；透传 `$attrs` | `#option="{ item }"`、`#prefix`、`#empty`；Expose：`refresh`, `selectRef`, `dictItems`, `isLoading` |
   | `AtengDictRadio` | `button: false`（切换 `ElRadioButton`）、`border: false`；透传 `$attrs` | `#radio="{ item }"`；Expose：`refresh`, `radioGroupRef`, `dictItems`, `isLoading` |
   | `AtengDictCheckbox` | `button: false`、`border: false`、`separator?: string`（支持逗号字符串 v-model）、`showCheckAll: false`、`checkAllText: '全选'` | `#checkbox="{ item }"`；Expose：`refresh`, `dictItems`, `isLoading` |

---

### 2.10 `AtengDescriptions` & `AtengDescriptionsItem`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\descriptions\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\descriptions\AtengDescriptions.vue`

- **双模驱动**：支持 `<AtengDescriptionsItem>` 模板声明式 或 `:items="DescriptionsItemConfig[]"`（若 `items` 非空数组则优先于默认插槽解析）；默认 `border: true`、`column: 3`、`direction: 'horizontal'`、`emptyText: '--'`、`copyable: false`。
- **项级能力（`DescriptionsItemConfig`）**：
  - `mask?: 'phone' | 'idCard' | 'email' | 'name' | 'bankCard'` + `maskChar`（调用 `@atengk/core` `formatMask*` 展示脱敏，其中 `bankCard` 为 `formatMask(str, 4, 4)`）；
  - `type?: 'currency' | 'date'`（`currency` 调用 `formatCurrency` 默认 `￥` 与 2 位小数）；
  - `dictCode?: string`（自动联动渲染 `<AtengDictTag>`，并传递 `item.emptyText || emptyText` 即默认 `'--'`）；
  - `copyable?: boolean`（严格恪守**内存真明文**，复制脱敏前的原始字段值 `data[prop]`，空值自动隐藏复制按钮）；
  - `formatter?: (value, data) => string` 与容器级具名插槽 `#[item.prop]="{ value, data }"`。

---

### 2.11 `AtengExcelFeedback` & `AtengExcelExport`

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\components\excel-feedback\types.d.ts`
  - `node_modules\@atengk\element-plus\dist\components\excel-export\types.d.ts`
  - `d:\source\ateng-ui\packages\element-plus\src\components\excel-feedback\AtengExcelFeedback.vue`
  - `d:\source\ateng-ui\packages\element-plus\src\components\excel-export\AtengExcelExport.vue`

1. **`AtengExcelFeedback`（导入错误明细与标红批注下载弹窗）**：
   - **精准错误明细数据结构（`ExcelFeedbackItem`）**：
     ```ts
     export interface ExcelFeedbackItem {
       rowNum: number | string;      // Excel 所在行号（如 2, 3）
       columnName?: string;          // 列名或字段名（如 "用户账号"）
       errorMessage: string;         // 具体校验失败原因
       rawValue?: unknown;           // 单元格原始值（可选）
     }
     ```
   - **渲染与下载触发细节**：
     - 基于 `AtengDialog`（默认 `title: '导入校验失败'`、`width: '720px'`、`pageSize: 10`）；
     - 内置分页 `ElTable` **仅展示 3 列**：`rowNum`（行号）、`columnName`（列名/字段，空值回退 `'-'`）、`errorMessage`（错误原因）；**`rawValue` 仅在本地 CSV 降级导出时作为第 4 列“提交原始值”输出**；
     - **标红批注下载参数**：支持静态 `fileUrl?: string` 或异步流动作 `downloadAction?: () => Promise<Blob | unknown>`（优先级 `downloadAction || fileUrl`），默认保存名 `fileName: '导入错误明细批注.xlsx'`；内部委托 `@atengk/vue` `useExcel().downloadFeedback(target, { filename })` 执行 `Blob-JSON` 双态检测与下载（触发 `download-success(filename)` / `download-error(err)`）；
     - 若 `fileUrl` 与 `downloadAction` 均未提供且 `allowCsvFallback: true`（默认），展示“导出错误清单 (CSV)”按钮，前端本地生成带 UTF-8 BOM `\uFEFF` 的 CSV（默认 `csvFileName: '导入错误清单.csv'`）；支持一键复制错误清单（`showCopy: true`）。
2. **`AtengExcelExport`（声明式流式导出按钮）**：
   - **Props**：`mode?: 'button' | 'dropdown'`（默认 `'button'`）、`action?: (params: Record<string, unknown>) => Promise<unknown>`、`filename?: string`、`params?: Record<string, unknown>`、`selectedIds?: (string | number)[]`、`text: '导出数据'`、`type: 'primary'`；
   - **与 `AtengTable` 上下文联动与触发入参**：
     - 注入 `ATENG_TABLE_CONTEXT_KEY` 获取 `getSelectedRows()` 与 `getQueryParams()`；
     - `button` 模式：若存在选中项（`selectedIds` 或表格勾选）默认触发 `'selected'`，否则触发 `'all'`；`dropdown` 模式提供“导出选中数据 (N 条)”和“导出全部数据”；
     - `'selected'` 时传入 `action` 的参数：`{ ...(params || {}), ids, selectedRows }`；
     - `'all'` 时传入 `action` 的参数：`{ ...tableQuery, ...(params || {}) }`；
     - **返回值下载与文件名细节（重要）**：若 `action` 返回 `Blob`，内部自动调用 `checkBlobForJsonError(result, result.type, 200)` 嗅探 JSON 错误报文并用 `saveBlobAsFile(result, props.filename || 'export_<ts>.xlsx')` 落地；**注意它不主动解析 `Content-Disposition` 响应头**，若需按服务端响应头自动提取文件名，可在自定义 `action` 中改用 `useExcel().exportExcel(...)` 接管下载（`action` 不返回 `Blob` 时不会重复下载）。

---

## 3. `@atengk/core@1.1.0` & `@atengk/vue@1.1.0` 核心底座能力

### 3.1 `AuthManager` 与 `TenantManager`

- **一手源码**：`node_modules\@atengk\core\dist\index.d.ts`、`d:\source\ateng-ui\packages\core\src\auth\auth-manager.ts`、`d:\source\ateng-ui\packages\core\src\tenant\tenant-manager.ts`

1. **`AuthManager`（`createAuthManager(options?: AuthManagerOptions)` / 全局单例 `authManager`）**：
   - 配置项：`tokenKey`（默认 `'token'`）、`headerName`（默认 `'token'`）、`bearerHeaderName`（默认 `'Authorization'`）、`tokenPrefix`（默认 `'Bearer '`）、`storage?: AuthStorage`（默认浏览器 `LocalStorageAuthStorage`，Node/SSR/无权限自动降级 `MemoryAuthStorage`）、`onUnauthorized?: () => void`；
   - **双轨 Header 组装**：`getHeaders()` 在存在有效 Token 时同时返回 `{ [headerName]: token, [bearerHeaderName]: '${tokenPrefix}${token}' }`（管理端配置 `tokenKey: 'satoken-admin', headerName: 'satoken-admin'` 时，请求会自动携带 `satoken-admin: <tk>` 与 `Authorization: Bearer <tk>`）；
   - **401 处理**：`handleUnauthorized()` 先调用 `clearToken()` 清空持久化存储，再带异常隔离地遍历触发全部 `onUnauthorized` 监听器（`onUnauthorized(listener)` 返回注销闭包）。
2. **`TenantManager`（`createTenantManager(options?: TenantManagerOptions)` / 全局单例 `tenantManager`）**：
   - 配置项：`tenantKey`（默认 `'tenant_id'`）、`headerName`（默认 `'X-Tenant-Id'`）、`storage?: TenantStorage`、`onTenantChange?: (tenantId: string | null) => void`；
   - **空值行为注意**：初始化未写过 Storage 时，`getTenantId()` 返回 `null`，`getHeaders()` 返回 `{}`；写入 `'0'` 时因非空字符串，注入 `{ 'X-Tenant-Id': '0' }`；传入空字符串或空格会触发 `clearTenantId()` 并广播 `onTenantChange(null)`。

---

### 3.2 `http`（`DefaultHttpClient` & 拦截器管道）

- **一手源码**：`node_modules\@atengk\core\dist\index.d.ts:1646-1979`、`d:\source\ateng-ui\packages\core\src\http\interceptors.ts`、`d:\source\ateng-ui\packages\core\src\transform\snowflake.ts`、`d:\source\ateng-ui\packages\core\src\file\blob-error.ts`

- **请求拦截器管道（`setupInterceptors`）**：
  1. **网关路由解析（`GatewayRouter`）**：按 `routes` 前缀或 `config.service` 分发 `baseURL` 与重写路径；
  2. **认证与多租户头注入**：自动将 `authManager.getHeaders()` 与 `tenantManager.getHeaders()` 写入请求头（忽略大小写判重，不覆盖调用方显式传的同名头）；可选对接 `RequestSigner` 防重放签名；
  3. **雪花 Long ID 16 位+ 大数防截断（`transformSnowflakeResponse`）**：自动插入 `transformResponse` 队列头部，利用正则表达式 `/("([^"\\]|\\.)*")|(?<=[:[,]\s*)(-?[0-9]{16,})(?=\s*[,\]}])/g` 在 `JSON.parse` 前把所有 16 位及以上的无引号整型值转为双引号字符串（跳过已有字符串字面量）；
  4. **防竞态取消与飞行中去重**：通过 `AbortCoordinator`（`cancelDuplicate`）与 `RequestDeduplicator`（`dedupeInFlight`）管理并发请求。
- **响应拦截器管道**：
  1. **Blob 双态异常嗅探（`checkBlobForJsonError`）**：当 `responseType === 'blob'` 或响应为 `Blob` 时，若 `data.type` 或 `Content-Type` 匹配 `application/(problem+)?json`，或 HTTP 非 2xx 且非空，异步读取 `data.text()` 并经 `parseSnowflakeJson` 解析出 `code`/`msg`/`traceId` 转译抛出 `BusinessException`（若其中 `code === 401` 同步触发 `authManager.handleUnauthorized()` 与 `onUnauthorized?.()`）；正常二进制流则通过 WeakMap 记录 `Content-Disposition`（可用 `getBlobDisposition(blob)` 读取）；
  2. **`Result<T>` 双态解包与逃生门**：
     - 默认 `unwrap: true`：当 `isResult(response.data)` 为真且 `result.code === 200` 时直接返回 `Promise<T>`（`result.data`）；
     - 逃生门 `unwrap: false`：返回完整 `Promise<Result<T>>`（`{ code, data, msg, traceId }`）；
     - 业务失败 `result.code !== 200`：**若 `result.code === 401` 自动触发 `authManager.handleUnauthorized()` 与 `onUnauthorized?.()`**，随后抛出 `BusinessException(result.code, result.msg, result.traceId, result)`；
  3. **HTTP 异常兜底与安全重试**：Axios HTTP `401` 同样触发 `authManager.handleUnauthorized()` + `onUnauthorized?.()`；提取服务端错误体中的 `code`/`msg`/`message`/`traceId` 构造 `BusinessException`；默认仅对幂等只读方法（`GET`/`HEAD`/`OPTIONS`）在网络/超时/5xx 时按配置 `retry` 执行指数退避重试，绝不自动重试 `POST`/`PUT`/`DELETE`。
  4. **安全下载门面 `http.download(url, filename?, config?)`**：自动设 `responseType: 'blob'`、执行双态错误拦截、按 RFC 5987/6266 解析文件名并调用 `saveBlobAsFile` 触发下载及 `URL.revokeObjectURL` 回收。

---

### 3.3 `usePagination`（`@atengk/vue`）

- **一手源码**：`node_modules\@atengk\vue\dist\index.d.ts:333-517`、`d:\source\ateng-ui\packages\vue\src\pagination\usePagination.ts`

- **函数签名**：`usePagination<TItem, TParams extends PageQuery = PageQuery>(service: (params: TParams) => Promise<PageResult<TItem>>, options?: UsePaginationOptions<TItem, TParams>): UsePaginationResult<TItem, TParams>`
- **入参配置 `UsePaginationOptions`**：
  - `defaultCurrent`（默认 `1`，支持 `MaybeRefOrGetter`）、`defaultSize`（默认继承全局 `defaultSize` 即 `10`）、`defaultSorts`（`SortItem[]`）、`defaultParams`（初始筛选条件）；
  - `refreshDeps`（变更时自动归 `current = 1` 并重新查询）、`manual`（默认 `false`，挂载即请求）、`ready`（支持响应式守卫）、`debounceInterval`/`throttleInterval`/`pollingInterval`/`cancelPrevious`（默认 `true`）、`onSuccess`/`onError`/`onFinally`。
- **出参与五维原子动作 `UsePaginationResult`**：
  - 响应式状态：`query: Partial<TParams>`（可直接双向绑定表单）、以及受 `readonly` 保护的 `current`、`size`、`sorts`、`total`、`records`、`loading`、`error`、`data`、`params`；
  - **严格空安全与参数净化契约**：
    - `records` 在异常或服务端缺省时 100% 保底返回 `[]`，`total` 保底 `0`；
    - `sorts` 为空数组时自动 `delete target.sorts`，不向后端透传空 `sorts: []`（`usePagination.ts:49-55`）；
  - 五维原子动作：`changePage(page)`、`changePageSize(nextSize)`（归 1）、`changeSort(sorts | (property, direction))`（归 1）、`search(extraParams?)`（合并 `query` 与入参并归 1）、`reset()`（清空动态新增键、恢复 `defaultParams` 与 `defaultSorts`、归 1 重查）；外加 `run`、`runAsync`、`refresh`、`refreshAsync`、`mutate`、`cancel`。

---

### 3.4 `useIdempotent` 与 `v-idempotent`

- **一手源码**：
  - `node_modules\@atengk\vue\dist\index.d.ts:820-898`、`d:\source\ateng-ui\packages\vue\src\idempotent\useIdempotent.ts`
  - `node_modules\@atengk\element-plus\dist\directives\idempotent\types.d.ts`、`vIdempotent.d.ts`、`d:\source\ateng-ui\packages\element-plus\src\directives\idempotent\vIdempotent.ts`

1. **`useIdempotent(actionFn, options?)`**：
   - 配置项：`timeout?: MaybeRefOrGetter<number | undefined>`（防死锁超时）、`onSuccess`/`onError`/`onFinally`/`onBlocked`；
   - 返回：`{ executing, error, run, runAsync, unlock }`；`run` 在锁定时静默触发 `onBlocked` 并返回 `undefined`，`runAsync` 在锁定时 reject；作用域销毁自动 `tryOnScopeDispose(unlock)`。
2. **`v-idempotent` 指令**：
   - 默认常数：`DEFAULT_IDEMPOTENT_DELAY = 1000`（ms）、`DEFAULT_IDEMPOTENT_TIMEOUT = 30000`（ms）；
   - **时间窗口模式**（无 `handler`）：`v-idempotent` / `v-idempotent:500` / `v-idempotent="800"`，放行首次点击并在窗口期内通过原生 DOM `click` 捕获阶段拦截器（`capture = true` + `stopImmediatePropagation()` + `preventDefault()`）阻断后续连击；
   - **异步互斥锁模式**（传入函数或 `{ handler, timeout, feedback }`）：接管点击并立即锁定，默认（除非加 `.noFeedback` 修饰符或 `feedback: false`）自动给宿主添加 `is-loading`、`is-disabled` 类与 `disabled` / `aria-disabled="true"` 属性；Promise `settled` 或同步异常或超时后确定性解锁还原。

---

### 3.5 `useAuth`、`v-permission` 与 `v-role`

- **一手源码**：
  - `node_modules\@atengk\vue\dist\index.d.ts:624-753`、`d:\source\ateng-ui\packages\vue\src\context\context.ts`、`packages\vue\src\auth\useAuth.ts`
  - `node_modules\@atengk\element-plus\dist\directives\shared\createAuthDirective.d.ts`、`d:\source\ateng-ui\packages\element-plus\src\directives\shared\createAuthDirective.ts`

1. **`createAtengVue` 全局上下文与超管角色基线**：
   - `DEFAULT_OPTIONS.superAdminRoles` 在 `@atengk/vue` 中仍默认 `['admin', 'super_admin']`（`context.ts:31`）；
   - `1.1.0` 已支持通过 `createAtengVue({ authManager, httpClient, tenantManager, superAdminRoles: ['super_admin'], defaultSize: 10 })` 全局覆写（`#364`），且 `v-permission` / `v-role` 通过 `resolveAtengConfig(provides)` 严格继承组件树或 `AppContext` 注入的 `authManager` 与 `superAdminRoles`（`#363`）。
2. **`useAuth` 状态机与权限匹配**：
   - 基于 `WeakMap<AuthManager, AuthInternalState>` 维持实例维度响应式单例，并自动订阅 `manager.onUnauthorized` 重置 `token`、`permissions`、`roles`、`user`；
   - `hasPermission(perm, mode='some')`：命中 `superAdminRoles` 直接全放行；否则按 Shiro 分段通配符算法 `matchSinglePermission` 匹配（支持 `*`、`*:*:*`、`sys:*`、`order:*:view`）；
   - `hasRole(role, mode='some')`：严格匹配真实 `roles` 数组，**超管角色不自动触发 `hasRole` 放行**。
3. **`v-permission` 与 `v-role` 指令行为**：
   - **默认模式**：无权限时物理移除 DOM 节点并替换为注释定位锚点（`<!-- v-permission -->` / `<!-- v-role -->`），并响应 `watch([auth.permissions, auth.roles])` 变化自动原位恢复或再次移除；
   - **`.disabled` 修饰符**：保留 DOM，添加 `is-disabled` 类、`disabled` 属性、`pointerEvents: none`、`opacity: 0.5` 及捕获阶段 click 拦截器；
   - **`.all` 修饰符**：传数组时切换为 `'every'` 全部满足模式（默认 `'some'`）。

---

### 3.6 内存真明文脱敏工具集（`@atengk/core`）

- **一手源码**：`node_modules\@atengk\core\dist\index.d.ts:391-431`、`d:\source\ateng-ui\packages\core\src\mask\mask.ts`

全部为渲染层纯函数，`null`/`undefined`/空串安全返回 `''`（不修改原模型）：
- `formatMask(value, startKeep = 0, endKeep = 0, maskChar = '*')`：通用区间掩码（`start + end >= len` 返回原文）；
- `formatMaskPhone(phone, maskChar = '*')`：支持 `+86`、空格、短横线分隔的标准 11 位手机号脱敏为 3-4-4（`'13812345678' -> '138****5678'`），异常长度回退 `formatMask(str, 3, 4)`；
- `formatMaskIdCard(idCard, startKeep = 6, endKeep = 4, maskChar = '*')`：18 位默认保留前 6 后 4，15 位默认保留前 6 后 3；
- `formatMaskEmail(email, maskChar = '*')`：保留域名后缀与用户名首尾字符（单字符用户名脱敏为 `'*@domain'`，双字符 `'a*@domain'`）；
- `formatMaskName(name, maskChar = '*')`：2 字脱敏末位（`'张*'`)，3 字及以上保留首尾（`'李*龙'`、`'诸**明'`）。

---

### 3.7 其他已就绪底座设施速览

- **多页签无头状态机 `useTabsNav`（`@atengk/vue`）**：提供 `tabs`、`activeKey`、`cachedViews`（基于 `TabItem.componentName` 并自动在 `refreshTab` 时瞬态剔除 `refreshingKey`）、`isMaximized`、`openTab`（支持 `maxTabs` FIFO 淘汰与 `affix` 置顶）、`closeTab`/`closeOthers`/`closeLeft`/`closeRight`/`closeAll`、`moveTab`、`pinTab`、`refreshTab`、`setTabs`、`setActiveKey`、`toggleMaximize`，支持 `session`/`local` 持久化。
- **流式导出与回写 `useExcel`（`@atengk/vue`）**：支持 `exportExcel` 与 `downloadFeedback`（默认保底文件名 `defaultFilename: 'export.xlsx'`、`defaultFeedbackFilename: 'error_feedback.xlsx'`），内置 `AbortController`、`checkBlobForJsonError` 双态检测、`parseContentDispositionFilename` RFC 5987 文件名提取及延迟 `URL.revokeObjectURL`。
- **分栏布局 `AtengSplitLayout`（`@atengk/element-plus`）**：支持水平/垂直双向拖拽调宽、折叠把手（`first`/`second`/`both`）、边缘磁吸附（`snapThreshold: 30`）与 `storageKey` 持久化，适用于 `/system/user`（左部门树右用户表）与 `/system/dict`（左字典类型右字典数据）。
- **页面容器与顶栏加载条**：`AtengPageContainer`（面包屑、页头操作流折叠、吸底协同、脱壳全屏）、`AtengLoadingBar` / `installLoadingBar(router)`（2px 顶栏 GPU 流光线，零遮罩挂载 Vue Router）。

---

## 4. `theme-pro.css` 视觉令牌基线与主题引擎

- **一手源码**：
  - `node_modules\@atengk\element-plus\dist\theme-pro.css`
  - `node_modules\@atengk\element-plus\src\styles\theme-pro.scss`
  - `node_modules\@atengk\element-plus\src\styles\theme-pro\_tokens.scss`、`\_typography.scss`、`\_basics.scss`、`\_loading.scss`、`\_overlays.scss`、`\_tables.scss`
  - `node_modules\@atengk\element-plus\dist\theme\initTheme.d.ts`、`setThemeColor.d.ts`

### 4.1 关键 CSS 变量分层清单

1. **中性基底令牌（Light `:root` vs Dark `:root.dark, .dark`）**：
   | 令牌分组 | Light 模式基线值 | Dark 模式基线值（Slate 深空冷灰） | 用途 |
   | :--- | :--- | :--- | :--- |
   | **背景表面** | `--el-bg-color`: `#ffffff`<br>`--el-bg-color-page`: `#f8fafc`<br>`--el-bg-color-overlay`: `#ffffff` | `#0c1017`<br>`#07090e`<br>`#121824` | 卡片主底、页面画布、浮层底色 |
   | **文本阶梯** | `--el-text-color-primary`: `#090d16`<br>`--el-text-color-regular`: `#334155`<br>`--el-text-color-secondary`: `#64748b`<br>`--el-text-color-placeholder`: `#94a3b8`<br>`--el-text-color-disabled`: `#cbd5e1` | `#f1f5f9`<br>`#cbd5e1`<br>`#94a3b8`<br>`#475569`<br>`#334155` | 主标题、正文、次要说明、占位、禁用 |
   | **亚像素边框** | `--el-border-color`: `rgba(15, 23, 42, 0.08)`<br>`-light`: `0.05` / `-lighter`: `0.03` / `-extra-light`: `0.02`<br>`-dark`: `0.16` / `-darker`: `0.24` | `rgba(255, 255, 255, 0.08)`<br>`-light`: `0.05` / `-lighter`: `0.03` / `-extra-light`: `0.02`<br>`-dark`: `0.14` / `-darker`: `0.22` | 无锐利硬线的微透物理描边 |
   | **填充表面** | `--el-fill-color`: `#f1f5f9`<br>`-light`/`-lighter`: `#f8fafc`<br>`-extra-light`: `#fafafa`<br>`-dark`: `#e2e8f0` / `-darker`: `#cbd5e1` / `-blank`: `#ffffff` | `#162032`<br>`-light`: `#0f1522` / `-lighter`: `#0d121c`<br>`-extra-light`: `#090e17`<br>`-dark`: `#1e293b` / `-darker`: `#243147` / `-blank`: `#0c1017` | 悬停底、斑马纹、禁用底、输入填充 |

2. **5 套极客科技预设主题（`:root` 默认 `indigo`，支持 `[data-theme='...']` 局部/全局切换）**：
   | 预设名 | Light 主色 (`--el-color-primary`) | Dark 主色 | 配套动态令牌 |
   | :--- | :--- | :--- | :--- |
   | `indigo`（默认） | `#4f46e5` (`rgb: 79, 70, 229`) | `#6366f1` (`rgb: 99, 102, 241`) | 含 `light-1~9`、`dark-2`、`--at-shadow-focus-ring`、`--at-ambient-glow` |
   | `emerald` | `#10b981` | `#34d399` | 同上 |
   | `violet` | `#7c3aed` | `#8b5cf6` | 同上 |
   | `ocean` | `#0284c7` | `#38bdf8` | 同上 |
   | `rose` | `#e11d48` | `#f43f5e` | 同上 |
   - **固定语义辅助色**：`success`（`#10b981`）、`warning`（`#f59e0b`）、`danger`（`#f43f5e`）、`info`（`#64748b`），全量提供 `-rgb`、`light-1~9` 及 `dark-2`。

3. **`--at-*` 扩展令牌与排版/阴影/Z-Index 标尺**：
   - **弹性圆角**：`--el-border-radius-base: 6px`、`--el-border-radius-small: 4px`、`--el-border-radius-round: 9999px`、`--el-border-radius-circle: 100%`、`--at-radius-card: 10px`、`--at-radius-dialog: 16px`；
   - **阴影与微光**：`--el-box-shadow*`（双层接触微影）、`--at-shadow-floating`、`--at-shadow-focus-ring`（双层激光环）、`--at-ambient-glow`、`--at-bg-overlay-translucent`（Light `rgba(255,255,255,0.95)` / Dark `rgba(18,24,36,0.95)`）；
   - **Z-Index 标尺**：`--at-z-index-base: 1`、`--at-z-index-sticky: 100`、`--at-z-index-overlay: 1000`、`--at-z-index-fullscreen: 2000`、`--at-z-index-top-bar: 9999`；
   - **排版与等宽数字**：`--el-font-family`（`Plus Jakarta Sans, Inter, ...`）、`--at-font-mono`（`JetBrains Mono, ...`），并对 `.el-table` / `.at-table` / `.el-pagination` / `.el-tag` / `.el-statistic` / `.el-descriptions` 开启 `font-variant-numeric: tabular-nums`；
   - **局部组件覆盖变量**：`--el-table-*`（`_tables.scss`）、`--el-scrollbar-*`（6px 极窄冷钛滚动条，`_basics.scss`）、`--el-datepicker-*` / `--el-cascader-*`（`_pickers.scss`）、`--at-loading-bar-height`（`2px`，`_loading.scss`）、`--el-dialog-padding-primary: 0`（`_overlays.scss`）；
   - **无障碍与性能防御**：`html.is-theme-switching` 过渡防撕裂、剥离全屏 `backdrop-filter`、`prefers-reduced-motion`、`forced-colors` 与 `@media print` 报表打印样式基线。

### 4.2 运行时主题引擎 API

- **`initTheme(options?: InitThemeOptions): ThemeManager`**（`initTheme.ts:52-191`）：
  - 支持 `light` / `dark` / `auto`（默认 `'auto'`），本地存储默认键 `'ateng-theme-mode'`，监听系统 `prefers-color-scheme: dark`；
  - 切换时自动为 `target`（默认 `document.documentElement`）添加 `is-theme-switching` 类 250ms 消除样式过渡风暴，并维护 `dark` 类；
  - 提供 `getMode()`、`getActiveTheme()`、`setMode(mode)`、`setColor(hex)` 与 **`cleanup()`**（务必在卸载时调用释放媒体查询监听）。
- **`setThemeColor(hex, options?)`**（`setThemeColor.d.ts:38`）：支持 3/6 位 Hex，按 Element Plus Sass `color.mix` 线性插值实时演算并写入 `--el-color-primary*`、`--at-shadow-focus-ring`、`--at-ambient-glow`。

---

## 5. 与现有规范文档（`views-and-routes-spec.md` & `styling-and-ateng-ui.md`）的逐项比对与出入清单

| 编号 | 涉及文档与章节 | 现行文档描述 | `1.1.0` 一手源码实际状态 | 出入性质与建议处理 |
| :---: | :--- | :--- | :--- | :--- |
| **D1** | 任务路径 vs 仓库实际路径 | 任务指向 `docs/specs/styling-and-ateng-ui.md` | 实际文件位于 `ateng-solid-admin-web/.agents/rules/styling-and-ateng-ui.md`（`docs/specs/` 下仅 `views-and-routes-spec.md` 与 `frontend-architecture-and-conventions.md`） | **路径提示**：后续 PRD/Spec 引用请使用正确路径 `.agents/rules/styling-and-ateng-ui.md` |
| **D2** | `styling-and-ateng-ui.md` §2.1 & `views-and-routes-spec.md` 第 4 行 | 描述 `ateng-ui#365` 为“等待底座 `ateng-ui#365` 通用扩展点…仅渲染 `<i :class="itemIcon" />`”及“依赖上游 `ateng-ui` 增强项（如 `#365`）…待前置闭环” | `@atengk/element-plus@1.1.0` **已正式发布落地** `iconResolver?: ProMenuIconResolver` Prop 与 `#menuIcon` 插槽（`ProMenuItemNode.vue:73-90`），且 `admin-web/AGENTS.md:33` 与根仓 `foundation-enhancements-checklist.md` 已标为解封 | **文档滞后**：更新两份文档移除“等待发版”表述，直接写按 `:icon-resolver` 回调对接 `@element-plus/icons-vue` |
| **D3** | `styling-and-ateng-ui.md` §2.2 vs `views-and-routes-spec.md` §2 `useAppStore` | `styling-and-ateng-ui.md` 写 `<KeepAlive :include="cachedRouteNames">`，`views-and-routes-spec.md` 将缓存集合职责归入 `useAppStore` | `@atengk/vue` `useTabsNav()` 直接返回计算属性 **`cachedViews: ComputedRef<string[]>`**（基于 `TabItem.componentName` 并处理 `refreshTab` 瞬态剔除）；`ADR-0002` 与 `foundation-enhancements-checklist.md` 均用 `cachedViews` | **符号/职责对齐**：布局壳推荐直接使用 `useTabsNav` 的 `cachedViews`（或由 `useTabsStore`/`useAppStore` 包装暴露 `cachedViews`），并在多标签 `@tab-close` 中留意 `close` 与 `closeOthers/All` 事件差异 |
| **D4** | `views-and-routes-spec.md` §2 `useAuthStore` & `src/main.ts` | 写“监听 `AuthManager.onUnauthorized` 广播，401 时清空状态、重置动态路由并跳转 `/login`” | `useAuth()` 内部已在 `getOrCreateAuthState` 自动监听 `manager.onUnauthorized` 清空响应式凭据；`src/main.ts:28` 当前仅传 `authManager: adminAuthManager`，尚未传入 `httpClient` 与 `tenantManager` | **装配提醒**：Spec 2 创建 `httpClient` 与 `tenantManager` 时，必须传入同一实例至 `createAtengVue({ httpClient, authManager, tenantManager, superAdminRoles: ['super_admin'] })` |
| **D5** | `views-and-routes-spec.md` §2 `useTenantStore` | 写“串联 `TenantManager`（`X-Tenant-Id`，默认 `"0"`）…登出重置回 `"0"`” | `TenantManager` 默认构造未写 Storage 时 `getTenantId()` 返回 `null`、`getHeaders()` 返回 `{}` | **显式初始化提醒**：应用启动与登出后须显式执行 `tenantManager.setTenantId('0')`，确保请求头稳定携带 `X-Tenant-Id: 0` |
| **D6** | `views-and-routes-spec.md` §1.2 `/system/menu` (`AtengIconSelect`) | 指定菜单管理使用 `AtengIconSelect` | `DEFAULT_ICONS` 仅含 **40 个** 常用图标，且 `IconPanel.vue` 未透传 `.d.ts` 声明的 `#icon`/`#footer` 插槽 | **选型提醒**：须将 `@element-plus/icons-vue` 图标清单转为 `IconItem[]` 通过 `:custom-icons` 注入，并与 `AtengProLayout` `iconResolver` 共享同一套图标名映射表 |
| **D7** | `views-and-routes-spec.md` §1.2 `/system/user` (`AtengExcelExport` / `AtengExcelFeedback`) | 列出直接使用 `AtengExcelFeedback` 与 `AtengExcelExport` | ① `AtengExcelExport` 直接返回 `Blob` 且未传 `filename` 时使用 `export_<ts>.xlsx`（不读 `Content-Disposition`）；② `AtengExcelFeedback` 表格只渲染 3 列（`rawValue` 仅进 CSV）；③ `AtengExcelFeedback` 的 `downloadAction` 通过 `useExcel().downloadFeedback` 执行 | **用法提醒**：若导出依赖后端 `Content-Disposition` 文件名，建议 `action` 内部调 `useExcel().exportExcel(...)`；若由前端指定 `filename`（如 `"用户数据.xlsx"`），可直接让 `action` 返回 `Blob` |
| **D8** | `views-and-routes-spec.md` §1.2 `/system/menu` & `/system/dept`（树形 `AtengTable`） | 称“树形 `AtengTable`” | `AtengTableProps` 未显式声明 `treeProps`/`defaultExpandAll`，而是通过 `inheritAttrs: false` + `v-bind="$attrs"` 透传给 `<el-table>` | **用法确认**：可用！直接传 `:tree-props="{ children: 'children', hasChildren: 'hasChildren' }"`、`default-expand-all` 与 `:show-pagination="false"` 即可 |
| **D9** | `views-and-routes-spec.md` §1.2 `/system/tenant-package`（`AtengDrawer`） | 使用 `AtengDrawer` 做菜单树选择抽屉 | `AtengDrawer` 默认 `size: 'default'`（`500px`），且其 `#footer` 插槽**不透传** `{ confirm, cancel, loading }`（不同于 `AtengDialog`） | **写法提醒**：若自定义抽屉页脚按钮，需用 `ref` 调用 `drawerRef.confirm()` / `cancel()`，或直接复用内置页脚 + `:before-confirm` |
| **D10** | `views-and-routes-spec.md` §1.1 `/login`（`<AtengCaptcha type="image" />`） | 写使用 `<AtengCaptcha type="image" />` | `type="image"` 的点击刷新绑定属性名为 **Prop `:refresh="fn"`**（而非 `@refresh` 事件），`imageSrc` 传 URL 或 Base64 | **接口防坑**：模板绑定务必写 `:refresh="loadCaptcha"`，而非 `@refresh` |
| **D11** | `styling-and-ateng-ui.md` §2.4（`DictManager` & `AtengDict*`） | 描述注册 `provider`/`batchProvider` 对接动态字典与静态枚举 | `install(app, { dictProvider })` 仅注册 `setProvider`；`setBatchProvider` 须单独调用 `DictManager.setBatchProvider(...)`；`AtengDictTag` `tagType` 仅接受 `'success' | 'warning' | 'info' | 'primary' | 'danger' | '' | undefined` | **映射防坑**：后端 `listClass` 若返回 `'default'` 时，需在 `provider` 转换层归一化为 `''` 或 `undefined` |
| **D12** | `styling-and-ateng-ui.md` §1.3 & `src/styles/main.css` | 提及 Tailwind `@theme` 映射 `--color-page` / `--color-card` / `--color-main` / `--color-subtle` | `src/styles/main.css` 已映射 7 个语义色彩别名，但尚未映射 `theme-pro` 的 `--at-radius-card`/`--at-radius-dialog`、`--at-font-mono`、`--color-success`/`warning`/`danger` 及 `initTheme` 初始化接入 | **按需扩充**：后续业务样式若需直接使用 Tailwind 圆角/等宽字体/状态色工具类，可在 `src/styles/main.css` `@theme` 补充映射；暗黑/预设切换按需集成 `initTheme` 与 `[data-theme]` |
| **D13** | 补充：`AtengProLayout` `mix` 模式插槽差异 | 若未来切换 `'top'` 或 `'mix'` 布局 | `mix` 模式顶部 `headerRight` **无 `headerActions`/`user` 默认兜底**，且无 `headerLeft`/`breadcrumb`/`headerCenter`/`asideFooter` | **布局壳防御**：`AdminLayout.vue` 若要兼容动态切换 `side`/`top`/`mix` 三模式，顶栏右侧动作与用户头像应统一放入 `#headerRight` 插槽内，勿依赖 `headerActions`/`user` 兜底 |
