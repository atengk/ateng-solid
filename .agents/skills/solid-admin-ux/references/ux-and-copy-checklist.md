# Solid Admin UX, Accessibility & Microcopy Checklist

Reference checklist for PRD copywriting, HTML prototypes, and Vue implementation reviews.

## 1. UX Priority Matrix (Audit Top-to-Bottom)

| Priority | Domain | Required Standard | Failure / Anti-Pattern |
| :---: | :--- | :--- | :--- |
| **1** | **Accessibility** | Text/control contrast `>= 4.5:1` (large/bold `>= 3:1`); visible `:focus-visible` ring on every interactive control; icon-only buttons carry `aria-label` + tooltip; full keyboard Tab/Esc operation in dialogs/drawers. | Removing focus outlines; gray-on-gray text; icon-only table actions without accessible name. |
| **2** | **Interaction & Anti-Repeat** | Primary submit buttons lock via loading state (`v-idempotent` / `useAsyncConfirm`); destructive actions (delete, status disable, force logout) require explicit confirmation; forbidden actions (`tenantId="0"`, `super_admin`, self) render disabled with clear reason tooltip. | Silent state changes; double-click duplicate submissions; clickable delete buttons that only fail on backend. |
| **3** | **Layout & Stability** | Reserve loading/skeleton space to avoid CLS jump; no unintended horizontal page scroll; dense tables keep sticky right action column and `tabular-nums` alignment; drawer/dialog widths scale cleanly below `768px`. | Fixed rigid pixel containers overflowing small laptops; unaligned numbers in ID/count/time columns. |
| **4** | **Forms & Validation** | Persistent visible field labels (never placeholder-only); errors appear inline next to the offending field; `AtengDialog`/`AtengDrawer` validation blocks locally without losing unsaved input; edit forms load true plaintext (`内存真明文`). | Placeholder-only inputs; top-only generic toast hiding which field failed; masked `138****5678` prefilled into edit inputs. |
| **5** | **Navigation & Context** | Active route clearly highlighted; `AtengTabsNav` keeps `affix` Dashboard unclosable; when `super_admin` switches `X-Tenant-Id`, show an unmistakable active-tenant indicator and clear/refresh cross-tenant view state. | Stale data from previous tenant lingering in open tabs after switching `X-Tenant-Id`. |
| **6** | **Visual Restraint** | Spend boldness in one intentional focal area; hairline borders and spacing convey hierarchy without heavy box shadows everywhere; respect `prefers-reduced-motion`; keep animations purposeful and tied to user state transitions. | Decorative badges/eyebrow labels over every section; arbitrary gradients; bouncing idle animations. |

## 2. Enterprise Admin Microcopy Rules

1. **Action-Specific Verbs**: Name buttons for what happens (`保存配置`, `新增用户`, `强退会话`, `重置密码`, `下载批注文件`), avoiding generic `提交` or `确定` when a specific action is clearer.
2. **Action-Outcome Consistency**: Keep vocabulary identical end-to-end (button `停用租户` -> confirmation `确认停用租户【...】？` -> toast `已停用租户`).
3. **Diagnostic Errors**: Explain *what* failed and *how to recover* in plain domain language—never blame or apologize vaguely (`"验证码已过期，请点击图片刷新后重新输入"` rather than `"出错了，请重试"`).
4. **Actionable Empty States**: Distinguish initial empty (`"暂无岗位数据"` + `新增岗位` CTA), filtered empty (`"未找到符合筛选条件的用户"` + `清空筛选条件`), and error empty (`"加载失败"` + `重试`).
5. **No Decorative Formatting Tells**: Avoid ALL-CAPS English eyebrow tags above Chinese headings, avoid fake `01 / 02 / 03` numbering on non-sequential cards, and avoid appending `→` to every button label.

## 3. Upstream Foundation Alignment

When designing components or flows in prototypes/PRD, cross-check real constraints in [ui-1.1.0-capabilities.md](../../../../docs/specs/prd/_research/ui-1.1.0-capabilities.md) (especially `AtengProLayout` slots, `AtengTabsNav` `close` vs `closeOthers` events, `AtengCaptcha` `:refresh` prop, `AtengIconSelect` 40-icon default set, `AtengExcelFeedback` 3-column table + CSV fallback, and `U5`–`U8` pending upstream fixes).
