# 麻将记账 APP UI 重新设计方案

## 设计方向

整体采用鸿蒙原生应用风格，而不是简单套一组颜色。界面应具备以下特征：

- 页面结构清晰，内容区域留白克制，信息密度适中。
- 交互控件使用鸿蒙常见的大圆角、层级阴影、模糊材质和自然动效。
- 底部导航采用悬浮液体玻璃胶囊形态。
- “添加牌局”作为全局主操作，固定在底部胶囊导航正中间。
- 所有页面优先适配单手操作，关键按钮集中在屏幕下半区。
- 第一版主打离线隐私模式，因此首页要突出“本地账本、隐私、安全、快速记账”的感受。

## 全局布局

### 页面骨架

屏幕分为三层：

1. 顶部状态与标题层
2. 中部内容层
3. 底部悬浮导航层

页面不使用传统贴底 TabBar，而是使用悬浮在安全区上方的液体玻璃胶囊导航。

推荐结构：

```text
┌─────────────────────────────┐
│ 顶部：问候 / 页面标题 / 设置 │
│                             │
│ 内容：当前账本、统计、列表    │
│                             │
│                             │
│                             │
│        悬浮液体玻璃胶囊导航   │
└─────────────────────────────┘
```

## 底部悬浮液体玻璃胶囊导航

### 形态

底部导航是一个水平胶囊，悬浮在屏幕底部安全区上方。

视觉规则：

- 高度：72vp 左右。
- 左右边距：20vp。
- 底部距离：16vp 到 24vp，避开系统手势区域。
- 圆角：36vp，形成完整胶囊。
- 背景：半透明磨砂玻璃材质。
- 边框：1vp 高亮半透明描边。
- 阴影：柔和、低透明度，不要厚重。
- 胶囊内部元素有轻微液体融合感，中间按钮与胶囊产生视觉连接。

材质建议：

```text
背景：rgba(255, 255, 255, 0.72)
暗色模式：rgba(35, 38, 42, 0.72)
描边：rgba(255, 255, 255, 0.55)
阴影：rgba(20, 24, 30, 0.14)
模糊：backgroundBlurStyle.COMPONENT_ULTRA_THICK
```

### 导航结构

推荐 5 个视觉位置，但实际导航是 4 个页面 + 1 个主操作：

```text
账本    统计    +添加牌局    牌友    我的
```

中间的“添加牌局”不是普通 Tab，而是主操作按钮。

### 中间添加牌局按钮

按钮固定在胶囊正中间，视觉上从胶囊中“浮起”。

设计规则：

- 尺寸：64vp x 64vp。
- 圆形或接近圆形的大圆角按钮。
- 中心使用加号图标，不使用长文字。
- 按钮颜色使用麻将相关的温润红色或朱砂色，但降低饱和度，符合鸿蒙原生的克制感。
- 按下时有缩放与光泽变化。
- 点击后弹出“新建牌局”半屏 Sheet，而不是跳转到复杂页面。

推荐色：

```text
主按钮：#D94C45
按下态：#C83F38
图标：#FFFFFF
按钮投影：rgba(217, 76, 69, 0.32)
```

## 首页：账本

### 页面目标

首页要让用户打开 APP 后马上知道：

- 当前是隐私离线模式。
- 可以快速新建牌局。
- 最近牌局和总输赢一眼可见。

### 布局

顶部：

- 左侧显示问候或页面标题，例如“账本”。
- 副标题显示“离线隐私模式 · 数据仅保存在本机”。
- 右侧放设置或隐私盾牌图标。

核心信息区：

- 使用一块轻量信息面板展示今日或最近一局概览。
- 不做厚重卡片堆叠，避免像普通 H5 管理后台。

内容区：

- “最近牌局”列表。
- 每条记录展示时间、参与人数、总输赢、赢家/输家摘要。
- 账目金额使用红/绿区分，但颜色不要刺眼。

底部：

- 内容列表底部留出 110vp 以上空间，避免被悬浮胶囊遮挡。

## 统计页

### 页面目标

展示个人牌局表现，不做复杂报表堆砌。

模块：

- 总牌局数
- 总输赢
- 最近 7 天趋势
- 胜率
- 最常一起打的牌友

视觉方式：

- 采用鸿蒙风格的信息分组。
- 图表使用简洁线图或条形图。
- 不使用大面积渐变背景。

## 牌友页

### 页面目标

为后续在线模式和胜率分析做入口。

模块：

- 牌友列表。
- 与每位牌友的对局次数。
- 与每位牌友同桌时的胜率。
- “跟 TA 打时表现最好/最差”的轻提示。

第一版离线模式中，牌友数据来自本地账本；在线版本再加入账号、同步和共同账本。

## 我的页

### 页面目标

突出隐私、安全、数据管理。

模块：

- 隐私模式状态。
- 本地数据备份。
- 导出账本。
- 清空本地数据。
- 关于在线模式预告。

## 新建牌局 Sheet

点击底部中间“添加牌局”按钮后，不直接切整页，而是弹出半屏 Sheet。

Sheet 内容：

- 牌局名称，默认“今天的牌局”。
- 参与玩家。
- 计分方式。
- 初始底分或金额。
- “开始记账”主按钮。

交互规则：

- Sheet 顶部有拖拽把手。
- 背景页面轻微缩放和模糊。
- Sheet 高度默认 60% 屏幕，可上拉展开。
- 输入玩家时优先展示最近牌友。

## 鸿蒙原生风格细节

### 颜色

不做单一红色主题。整体应是温润、干净、有东方麻将气质的现代原生界面。

建议色板：

```text
背景主色：#F7F5F0
内容底色：#FFFFFF
主行动色：#D94C45
强调绿色：#2E8B57
文字主色：#1F2329
文字次色：#69707A
分割线：#E7E1D8
玻璃白：rgba(255, 255, 255, 0.72)
```

### 字体与层级

- 页面标题：24fp 到 28fp，字重 Medium 或 Bold。
- 卡片标题：16fp 到 18fp。
- 正文：14fp 到 16fp。
- 金额数字：使用更高字重，避免过大。
- 不使用夸张大标题，保持工具型 APP 的效率感。

### 圆角

- 页面信息面板：20vp 到 24vp。
- 列表项：16vp 到 20vp。
- 底部胶囊：36vp。
- 中间添加按钮：32vp。

### 动效

动效要自然、短促，接近鸿蒙原生手感。

- Tab 切换：图标轻微上浮，文字淡入。
- 胶囊选中态：底部有柔和的液体滑块跟随。
- 添加按钮：点击时 0.94 缩放，松手回弹。
- Sheet 出现：从底部弹出，背景轻微虚化。

## ArkUI 页面结构建议

可以按以下组件拆分：

```text
MainPage
├─ PageHeader
├─ HomeSummary
├─ RecentGameList
├─ FloatingGlassTabBar
│  ├─ TabItem: 账本
│  ├─ TabItem: 统计
│  ├─ CenterAddButton
│  ├─ TabItem: 牌友
│  └─ TabItem: 我的
└─ CreateGameSheet
```

## ArkUI 伪代码

```ts
@Entry
@Component
struct MainPage {
  @State currentTab: number = 0
  @State showCreateSheet: boolean = false

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        PageHeader({ currentTab: this.currentTab })

        if (this.currentTab === 0) {
          HomeContent()
        } else if (this.currentTab === 1) {
          StatsContent()
        } else if (this.currentTab === 2) {
          FriendsContent()
        } else {
          MineContent()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F5F0')
      .padding({ left: 20, right: 20, top: 16, bottom: 112 })

      FloatingGlassTabBar({
        currentTab: this.currentTab,
        onTabChange: (index: number) => {
          this.currentTab = index
        },
        onCreateGame: () => {
          this.showCreateSheet = true
        }
      })
      .margin({ left: 20, right: 20, bottom: 18 })
    }
    .bindSheet($$this.showCreateSheet, this.CreateGameSheet(), {
      height: '60%',
      dragBar: true,
      backgroundColor: '#FFFFFF',
      blurStyle: BlurStyle.COMPONENT_ULTRA_THICK
    })
  }

  @Builder
  CreateGameSheet() {
    Column() {
      Text('新建牌局')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)

      // 玩家、金额、规则等输入区域
    }
    .padding(24)
    .width('100%')
  }
}
```

## 底部胶囊导航伪代码

```ts
@Component
struct FloatingGlassTabBar {
  @Prop currentTab: number
  onTabChange: (index: number) => void
  onCreateGame: () => void

  build() {
    Row() {
      TabItem({ icon: 'book', label: '账本', selected: this.currentTab === 0 })
        .onClick(() => this.onTabChange(0))

      TabItem({ icon: 'chart', label: '统计', selected: this.currentTab === 1 })
        .onClick(() => this.onTabChange(1))

      Button({ type: ButtonType.Circle }) {
        Text('+')
          .fontSize(32)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      .width(64)
      .height(64)
      .backgroundColor('#D94C45')
      .shadow({
        radius: 18,
        color: 'rgba(217, 76, 69, 0.32)',
        offsetY: 8
      })
      .onClick(() => this.onCreateGame())

      TabItem({ icon: 'people', label: '牌友', selected: this.currentTab === 2 })
        .onClick(() => this.onTabChange(2))

      TabItem({ icon: 'user', label: '我的', selected: this.currentTab === 3 })
        .onClick(() => this.onTabChange(3))
    }
    .height(72)
    .width('100%')
    .padding({ left: 14, right: 14 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .border({
      width: 1,
      color: 'rgba(255, 255, 255, 0.55)'
    })
    .borderRadius(36)
    .backdropBlur(28)
    .shadow({
      radius: 24,
      color: 'rgba(20, 24, 30, 0.14)',
      offsetY: 10
    })
  }
}
```

## 页面气质关键词

- 原生
- 轻盈
- 克制
- 隐私感
- 单手可用
- 液体玻璃
- 麻将文化但不复古
- 记账工具但不冰冷

