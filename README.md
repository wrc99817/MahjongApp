# 一局：纯血鸿蒙麻将记账 App

“一局”是一个 HarmonyOS NEXT / ArkTS / ArkUI 麻将记账 App。V1.0 以离线模式为主，目标是让线下麻将玩家可以在本机快速创建牌局、编辑参与人、录入输赢与开销、查看流水、统计和结算结果。

当前工程已搭建 HarmonyOS NEXT Stage 模型，并使用本地内存仓储承载演示数据与业务事件。V1.0 先完成可独立使用的离线账本，包括本地持久化、流水修正能力和完整历史查看；后续再逐步接入 AppGallery Connect 认证、云数据库和多端同步。

## 当前状态

- 技术路线：HarmonyOS NEXT Stage 模型、ArkTS、ArkUI、Hvigor。
- 当前数据：本地内存仓储，默认仅初始化当前用户和本地账本组；不再预置模拟牌局、历史流水或统计数据，App 首次启动从无牌局状态开始。
- 当前界面：牌局、统计、牌友、我的四个 Tab；四个主页面标题固定在滚动内容外，页面主要内容滚动时标题不移动；牌局结算页标题同样固定，只滚动结算内容；主页面标题仅保留大标题，不再展示顶部小字；无进行中牌局时，牌局页展示新建牌局卡片并进入独立新建牌局页；新建牌局的牌局信息卡片只展示牌局名称输入框，不再额外显示小标签；牌局页业务卡片标题统一使用一致的字号、高度和顶部间距；`prototype/prototype-web` 已同步为可交互 Web demo，用于把当前 App 状态可视化验收，不作为 App 技术栈替代。
- 当前交互：四个主页面使用 ArkUI `Swiper` 支持左右滑动切换，并与底部液态玻璃导航选中态同步；牌友页默认搜索入口和搜索页面输入框使用统一的 `搜索牌友或牌局` placeholder、14 号字体和灰色占位颜色，并共用 44vp 高度、22vp 圆角和 14vp 横向内边距的搜索框外壳，搜索图标、取消按钮都放入 44vp 高的居中容器，搜索态的空 placeholder 也由同一个 Text 组件渲染；点击取消时搜索层保持完整不透明，搜索框从顶部回落到牌友页默认搜索框位置，牌友页标题和下方内容在搜索框回落过程中同步渐显，动画完成后再卸载搜索层，避免露出底层淡标题和空内容的中间态；新建牌局页默认固定当前用户“我”，牌局名称、默认买入金额、牌友姓名等表单项统一使用名称在上、输入区在下的纵向布局，并采用固定顶部标题、固定底部“开始记账”按钮、中间内容独立滚动的页面结构，滚动区域与头尾操作区保持留白；默认买入金额初始为 200，可通过左右加减按钮按 50 调整，每次变化都会覆盖四位牌友入场金额；每位牌友入场金额改为姓名下方的左右加减步进器，可在默认金额基础上按 10 单独调整，步进按钮在页面内直接使用 ArkUI 原生 `Button` 绑定金额状态更新，使用系统 `sys.symbol.plus` / `sys.symbol.minus` 图标、无边框浅灰底和蓝色符号，含输入控件的新建表单卡片保持静态卡片面，避免父级按压缩放干扰小按钮点击；编辑牌局 Sheet 同步采用纵向表单和步进器模式，默认入场金额读取牌局创建时保存的默认值而不是任一牌友金额，按 50 调整时覆盖四位牌友买入金额，单个牌友入场金额可继续按 10 独立调整，并固定标题和底部保存按钮，中间表单区域独立滚动且与顶部/底部保持留白；牌友 2 到牌友 4 的姓名输入框默认分别填入“牌友1 / 牌友2 / 牌友3”，用户可直接修改，右侧下拉入口使用居中的系统 `sys.symbol.chevron_down` 符号选择已有牌友；牌友选择抽屉仅展示非本人的已有牌友，暂无牌友时展示空态提示。编辑牌局、历史详情、记账玩家选择使用 ArkUI `bindSheet` 半屏 Sheet；带返回入口的整页使用 ClashBox `Xb_TopTitleBar` / `Xb_CircleButton` 同源思路的圆形 `sys.symbol.chevron_left` 符号按钮，并支持从屏幕左侧边缘向右滑动返回；我的页清空所有数据采用二次确认，确认清空后仍停留在“我的”页，进入确认态后点击统计卡、关于卡或底部空白区域会恢复为“清空所有数据”；按钮、可点击小胶囊、可点击列表行、底部导航和可点击内容卡片均已接入按压缩小反馈。
- 当前状态联动：牌局页参与人、入场金额、默认入场金额、总入场和当前账面从仓储牌局与流水实时派生；参与人和入场金额卡片已改为 2x2 参与人信息网格，并在卡片内展示默认入场和总入场摘要；记账输入的当前方式、玩家选择、金额和备注草稿已收拢到 `EntryInputDraft`，金额输入使用 ArkUI `TextInput` 用户输入，单家收分改为在卡片内直接选择赢家并输入“每位输分”，卡片高度按内部元素内容收敛；页面仅保留 `ledgerViewRevision` 刷新信号，编辑牌局保存并关闭 Sheet 后会自动统一刷新，已验证不需要切换 Tab 即可更新；入场金额调整流水会按本次调整记录展示金额，非“我”参与人的入场金额变化不会再显示为 0。
- 当前闭环：支持从空牌局创建牌局、已有牌友选择/新牌友创建、入场金额必填校验、三种记账输入、编辑牌局、结算封账、结算完成页、历史详情、牌友表现和我的统计；三种记账输入默认不预填示例数据，单家收分在当前牌局参与人中选择赢家，AA 开销/手动调整通过当前牌局参与人抽屉选择对象；AA 开销支持填写备注并写入流水说明；结算页整场统计使用等宽 2x2 信息块，应收应付按牌友展示入场金额和带正负号的语义色账面金额，并单独提供最佳转账路径卡片；封账完成页使用结果卡片滑入和更丝滑的金额计数动画；统计页保留全部和历史牌局两个分段，全部页展示总览、最近封账、走势、胜率最高牌友，走势使用带日期标签的折线图；历史牌局直接以单局卡片列表展示日期、参与人、赢家、输家和输赢金额，历史详情按概览、最终账面、流水卡片分区；进行中牌局流水已使用 104vp 圆角白底行框并保持行间距，行内展示记账方式、时间和四位牌友本笔账面变化，长按前后复用同一行元素样式；流水长按显示接近 ClashBox 配置页的液态玻璃上下文菜单，背景渐进进入强模糊，被选中流水按真实坐标原位浮起，菜单从流水行边缘展开并按屏幕空间动态显示在流水下方或上方、与流水右侧边缘对齐，点击红色“删除”会撤回/作废流水（修改暂缓）；返回按钮统一为 ClashBox 风格半透明圆形符号按钮，整页返回场景支持左缘右滑返回，本轮已核对并修正固定尺寸图标/符号容器的横向与纵向居中；所有主要内容卡片已统一接入接近按钮手感的按压缩小和阴影收敛反馈；V1.0 剩余重点是本地持久化、完整流水与历史列表；登录、云同步、邀请加入和权限控制作为后续在线能力。

## 状态架构方向

后续开发以 HarmonyOS NEXT / ArkTS / ArkUI 的状态管理方式落地，不照搬其他平台框架。

核心原则：

- `LedgerStore` / `LedgerRepository` 作为公共业务数据的唯一事实来源，管理 `users`、`groups`、`sessions`、`rounds`、`operations`。
- 页面只保存 UI 状态，例如当前 Tab、当前选中牌局 ID、Sheet 打开状态、筛选条件和输入框草稿。
- 参与人、入场金额、总入场、当前账面、进出账流水、结算结果和历史详情都应从仓储数据派生。
- 新建牌局、编辑牌局等 Sheet 使用表单草稿双向绑定；点击保存后通过仓储 action 一次性提交，取消时不污染真实数据。
- 所有业务动作统一走 repository action，完成后通过统一刷新入口重新读取仓储快照，再由 selector/派生函数计算页面展示。
- `bindSheet` 半模态保存后需要在关闭动画完成后再触发一次统一刷新，避免底层页面停留在旧快照，导致切换 Tab 后才显示最新数据。
- 页面如需驱动 ArkUI 重建，只保存 `ledgerViewRevision` 这类轻量 UI 版本号，不保存参与人、入场金额、账面等重复业务副本。
- 复杂对象需要响应内部字段变化时，优先使用 ArkUI `@Observed` / `@ObjectLink`；父子表单输入使用 `@Link` / `@Prop`；页面树共享状态可使用 `@Provide` / `@Consume`。
- `AppStorage` / `LocalStorage` 只用于合适作用域的数据共享，不作为普通事件总线或刷新通知滥用。
- 当前账面、统计、结算等金额结果优先从流水和牌局配置计算，不在多个页面长期保存重复副本。

目标结构：

```text
ArkUI Page / Component
  @State: 当前 Tab、Sheet、筛选条件、输入草稿、ledgerViewRevision
  @Link/@Prop: 表单组件输入联动
  @Observed/@ObjectLink: 复杂 UI 状态对象

LedgerStore / LedgerRepository
  users / groups / sessions / rounds / operations
  createSession / updateSession / addRound / voidRound / sync

Selectors / Derived State
  currentSession
  currentPlayers
  currentBuyIns
  currentBalances
  visibleRounds
  settlementRows

Refresh Flow
  repository action
  refresh repository snapshot
  close bindSheet
  refresh again after sheet close animation
  derive UI display from currentSession + users + rounds

Persistence
  当前：InMemoryLedgerRepository
  V1.0：HarmonyOS relationalStore / Preferences 本地持久化
  后续：AppGallery Connect 认证、云数据库和多端同步
```

## V1.0 离线模式计划

| 模块 | V1.0 目标 | 当前实现状态 |
| --- | --- | --- |
| 创建牌局 | 新建离线牌局，设置牌局名称、参与人、入场金额 | 已实现 |
| 编辑牌局 | 编辑牌局名称、参与人姓名、默认入场金额、单个牌友入场金额 | 已实现，默认入场金额会保存为牌局配置，编辑时不再从某个牌友金额反推 |
| 单家收分 | 在当前牌局四位参与人中直接选择赢家，输入“每位输分”后保存，赢家自动记为三位输家的合计收入并校验合计为 0 | 已实现 |
| AA 开销 | 通过当前牌局参与人抽屉选择付款人，输入总金额后保存，自动按参与人平摊并写入流水 | 已实现 |
| 手动调整 | 通过当前牌局参与人抽屉选择调整对象，输入金额后保存平衡分录并记录原因 | 已实现 |
| 账面联动 | 记账后更新每位玩家当前账面、总入场和结算数据 | 已实现 |
| 记账历史 | 展示进出账流水，支持按全部 / 收分 / 开销 / 调整筛选 | 基础筛选已实现；完整列表 / 加载更多待补齐 |
| 流水修正 | 支持撤回/删除或作废流水，并保留操作记录；流水修改暂缓 | 已实现进行中牌局流水长按弹出渐进模糊上下文菜单，菜单从流水行边缘展开，点击带删除图标的“删除”选项后通过 `voidRound` 作废记录并刷新账面、统计、结算和历史详情；入场金额调整流水撤回时会同步回滚牌局入场金额 |
| 结算 | 展示大赢家、整场统计、按牌友展示的应收应付、最佳转账路径、封账和返回牌局 | 已实现，封账后进入带结果卡片和金额计数动画的完成页，并回到牌局空状态 |
| 统计 | 全部、历史牌局分段 | 已接入已封账牌局派生；全部页展示总览、最近封账、走势和胜率最高牌友；历史牌局直接展示单局卡片；历史牌局完整列表 / 加载更多待补齐 |
| 牌友页 | 搜索框、牌友列表、对局次数、同桌胜率、相关输赢 | 已接入已封账牌局派生，暂无牌友时展示轻量空态，搜索态保留本地轻量检索 |
| 我的页 | 我的牌局统计、关于、清空所有数据 | 已实现，统计卡片不再显示“所有统计”标题；关于行仅展示版本号，不显示入口箭头；清空数据使用二次确认，确认后停留在“我的”页 |
| 本地持久化 | 关闭 App 后保留离线账本 | 未实现，当前仍为内存仓储；V1.0 发布前必须完成 |

## V1.0 剩余收口

1. 本地持久化：把 `InMemoryLedgerRepository` 替换或包装为 HarmonyOS 本地持久化仓储，至少保存用户、账本组、牌友、牌局、流水和操作日志，重启 App 后数据不丢失。
2. 完整历史与流水查看：进行中牌局流水、历史牌局列表和历史详情不再只截取前几条；需要支持完整滚动、加载更多或分页展示。

流水修改功能暂缓，当前以“长按流水菜单删除 = 撤回/作废流水”满足录错账修正场景。

V1.0 暂不处理在线同步状态产品化、本地备份、账单分享、通知设置、主题切换、登录、云同步、邀请加入和权限控制，这些能力进入 V1.5 / V2。

## 关键目录

- `entry/src/main/ets/common/Models.ets`：核心数据模型。
- `entry/src/main/ets/repositories/LedgerRepository.ets`：仓储接口。
- `entry/src/main/ets/repositories/InMemoryLedgerRepository.ets`：MVP 内存仓储和种子数据。
- `entry/src/main/ets/services/Money.ets`：金额校验、玩家汇总、金额格式化。
- `entry/src/main/ets/services/SyncService.ets`：同步服务占位。
- `entry/src/main/ets/pages/Index.ets`：ArkUI 主页面。
- `prototype/prototype-web`：可交互 Web demo，覆盖空牌局、新建牌局、三种记账、流水筛选/撤回、编辑 Sheet、结算封账、统计、历史详情、牌友搜索和我的页。
- `prototype/screenshots`：最新原型截图。
- `prototype/PROTOTYPE_DEV_SPEC.md`：原型到 ArkUI 的页面结构、状态逻辑和业务流程说明。
- `prototype/UI_DESIGN.md`：当前 UI 视觉基线和设计约束。

## 验收重点

- 新建牌局后，参与人、入场金额、当前账面和流水初始状态正确。
- 编辑牌局后，牌局标题、参与人姓名、入场金额、总入场和当前账面同步更新。
- 编辑入场金额后，应在进出账流水中体现，并同步影响相关派生展示。
- 单家收分、AA 开销、手动调整保存后，四人金额合计必须为 0。
- 保存记账后，当前账面、进出账历史、结算页和历史详情同步更新。
- 长按流水并通过模糊上下文菜单删除后，当前账面、统计、结算和历史详情必须从有效流水重新计算，并能看到对应操作记录；入场金额调整流水撤回后，总入场也要同步回滚。
- App 重启后，本地牌友、牌局、流水、封账历史和清空数据结果必须保持一致。
- 长牌局和多场历史数据可以完整查看，不因前端 `slice` 截断丢失入口。
- 统计页可在全部和历史牌局之间切换，历史牌局卡片可打开详情 Sheet。
- 牌友搜索态可进入、取消、清空，结果和空态显示正常。
- 我的页清空本地数据后，需要覆盖点击、二次确认、持久化清空和数据更新验证。

## 版本规划

- V1.0：离线模式记账闭环，包含创建/编辑牌局、三种记账输入、流水、结算、统计、牌友页、我的页基础能力、本地持久化、流水撤回/删除、完整历史与流水查看；流水修改暂缓。
- V1.5：常用玩家、历史筛选增强、账单分享、离线同步状态提示、本地备份、通知设置和主题切换。
- V2：登录、云备份、多群管理、AppGallery Connect 云同步、权限控制、高级统计、Excel/PDF 导出。
- V3：地方玩法辅助计算、战绩排行榜、AI 复盘摘要、服务卡片。

## 文档维护口径

`README.md` 作为项目主计划和功能状态表使用。`AGENTS.md` 记录协作和工程原则。`prototype/PROTOTYPE_DEV_SPEC.md` 记录页面结构、状态逻辑和业务流程。`docs/HARMONYOS_NATIVE_LIGHT_MOTION_RULES.md` 记录可复用的 HarmonyOS 原生轻动效规则。涉及数据模型、状态架构、同步策略、核心流程或通用动效规则变更时，应同步更新这些文档。
# 2026-06-05 animation update

- Bottom navigation now uses a lighter glass background, a sliding selected indicator, and `SwiperController`-driven horizontal tab switching.
- Main tab pages, detail pages, and cashflow lists now use `EdgeEffect.Spring` so real-device scrolling keeps native elastic space at the top and bottom.
- Follow-up tuning keeps the four main pages cached in one `Swiper`, removes state-first tab jumps, centers nav items over the selected indicator, and lowers the nav fill opacity for a more liquid-glass feel.
- Main navigation has been corrected to follow ClashBox's `FloatBar` pattern: a single blurred floating container, fixed `60x60` tab items, no moving background layer, and selected icon lift only.
- Page, start window, and system container backgrounds now share the ClashBox-style `#F1F3F5` background to reduce visual seams around the status and gesture bars.
- Detail page back buttons now follow the ClashBox circular symbol-button pattern with `sys.symbol.chevron_left`, and detail pages can return via a right swipe from the left screen edge.
- Detail pages are now mounted as a full-page layer over the cached main `Swiper`, enter from the right with `TransitionEdge.END`, return to the right on back, and consume `onBackPress()` so the real-device left-edge system gesture returns to the previous in-app page instead of exiting the app.
- New-session friend picker selection now forces the name input field to rebuild with the selected friend's display name; the settlement transfer path no longer shows the redundant leading transfer badge.
- The friends page search now expands in place at the top of the page instead of opening a right-side detail page, hides the bottom nav while searching, removes the cancel button, and keeps the search icon vertically centered; friend rows no longer show redundant name-avatar badges.
- The friends page search now uses a Header Transition: the friends title fades and slides up when search starts, the search bar stays at the top and becomes the input field, and an upward swipe on the friends page can also enter search mode.
- The friends search icon now uses a centered system `SymbolGlyph` instead of a text glyph, the empty search guide is shown as a lightweight hint card, and the Header Transition timing has been smoothed with coordinated title, search-bar, and content motion.
- Friend search now opens as a lightweight full-page temporary search layer over the friends tab, focuses the input and requests the keyboard on entry, shows a cancel action, disables main-tab swiping while active, and supports right-swipe/back to return to the friends page.
- Friend search entry now uses a pseudo shared-element motion: the temporary search bar starts near the original friends-page search field, moves upward into the search-page top position, then fades in the cancel action and guide/results content.
- Friend search return now keeps the underlying friends-page search field hidden until the temporary search layer has finished closing, avoiding a transient double-search-bar overlap.
- Friend search return motion now collapses the cancel action, right padding, shadow, radius, and top offset on the same curve so the temporary search bar visually restores as a pseudo shared search field.
- Friend search return now keeps the temporary search layer mounted until the closing motion finishes and aligns the collapsed search bar with the friends-page search field, removing the small return-position hitch.
- Entry player picker rows for payer and adjustment target no longer show redundant leading name-avatar badges.
- Successful entries in all three game-entry modes now reset the entry draft immediately after the round is written, clearing amount, note, reason, and selected-player fields while staying on the current entry mode.
- Fixed-size symbol and icon containers were reviewed for centering; empty-state icons, search icons, avatar letters, transfer markers, dropdown/clear glyphs, and the selected game nav glyph now use explicit center alignment.
- Major content cards now share a button-like press response: card scale drops to `0.96` and the shadow tightens while pressed.
- Cold start stays on the system start-window path, without an extra centered start-window icon; page, start window, window background, and system container background share the ClashBox-style `#F1F3F5` page color.
