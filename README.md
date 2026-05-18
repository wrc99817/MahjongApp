# 雀账：纯血鸿蒙麻将记账 App

这是一个从零搭建的 HarmonyOS NEXT / ArkTS / ArkUI MVP 工程，用于线下麻将玩家进行好友群组同步记账。当前版本实现了可演示的端侧流程，并把本地仓储与云同步抽象出来，方便后续替换为真实的 HarmonyOS RDB 和 AppGallery Connect 云数据库。

## 已实现

- Stage 模型工程结构：`AppScope`、`entry`、`EntryAbility`、`pages/Index`。
- ArkUI 首页 MVP：账本、记一局、统计三个工作区。
- 群组账本：创建群组、生成邀请码、展示成员。
- 牌局记录：创建牌局，手动录入四人输赢金额。
- 自动校验：四人输赢合计必须为 0，否则禁止保存。
- 明细与撤回：展示每局输赢，支持撤回最近一局并保留操作记录。
- 结算看板：按玩家汇总总输赢、场均金额。
- 同步抽象：本地写入生成 `LedgerOperation`，`SyncService` 当前为模拟同步，后续替换云数据库。

## 关键目录

- `entry/src/main/ets/common/Models.ets`：核心数据模型。
- `entry/src/main/ets/repositories/LedgerRepository.ets`：仓储接口。
- `entry/src/main/ets/repositories/InMemoryLedgerRepository.ets`：MVP 内存仓储和种子数据。
- `entry/src/main/ets/services/Money.ets`：金额校验与统计。
- `entry/src/main/ets/services/SyncService.ets`：同步服务占位。
- `entry/src/main/ets/pages/Index.ets`：ArkUI 主页面。

## 后续接入真实能力

1. 用 HarmonyOS `relationalStore` 实现 `LedgerRepository`，替换 `InMemoryLedgerRepository`。
2. 接入 AppGallery Connect 认证服务，把 `currentUser()` 替换为真实用户。
3. 接入 AppGallery Connect 云数据库，把 `LedgerOperation` 上传并监听群组变更。
4. 为冲突处理增加版本号比较和操作历史详情页。
5. 增加截图分享、Excel/PDF 导出和商业版会员字段。

## 验收重点

- 输赢合计不为 0 时不能保存。
- 保存后明细、统计、同步队列同时更新。
- 撤回最近一局后统计不再计入该局。
- 模拟同步后待同步操作清零。
