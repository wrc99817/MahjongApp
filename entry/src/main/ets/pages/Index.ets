import promptAction from '@ohos.promptAction';
import { GameSession, Group, LedgerOperation, PlayerSummary, RoundRecord, User } from '../common/Models';
import { ledgerRepository } from '../repositories/InMemoryLedgerRepository';
import { buildPlayerSummaries, formatMoney, validateRound } from '../services/Money';
import { SyncService } from '../services/SyncService';

const PAGE_BG: string = '#F8F8F6';
const CARD_BG: string = '#FAFFFFFF';
const SOFT_BG: string = '#FFF5F5F3';
const NAV_BG: string = '#DFFFFFFF';
const TEXT_MAIN: string = '#1D1D1F';
const TEXT_SECOND: string = '#777D86';
const LINE: string = '#1AE0E0E0';
const RED: string = '#F23830';
const GREEN: string = '#2F9657';
const ICON_GRAY: string = '#6E737A';

@Entry
@Component
struct Index {
  @State private currentTab: number = 0;
  @State private activeSheet: number = 0;
  @State private statsMode: number = 1;
  @State private collectorIndex: number = 0;
  @State private groups: Group[] = ledgerRepository.listGroups();
  @State private sessions: GameSession[] = [];
  @State private rounds: RoundRecord[] = [];
  @State private users: User[] = ledgerRepository.listUsers();
  @State private summaries: PlayerSummary[] = [];
  @State private operations: LedgerOperation[] = [];
  @State private selectedGroupId: string = '';
  @State private selectedSessionId: string = '';
  @State private newSessionTitle: string = '今天的牌局';
  @State private basePoint: string = '10';
  @State private entryAmount: string = '56';
  private syncService: SyncService = new SyncService();

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.groups = ledgerRepository.listGroups();
    if (this.selectedGroupId.length === 0 && this.groups.length > 0) {
      this.selectedGroupId = this.groups[0].id;
    }
    this.sessions = ledgerRepository.listSessions(this.selectedGroupId);
    if (this.selectedSessionId.length === 0 && this.sessions.length > 0) {
      this.selectedSessionId = this.sessions[0].id;
    }
    this.rounds = ledgerRepository.listRounds(this.selectedSessionId);
    this.operations = ledgerRepository.listOperations(this.selectedGroupId);
    this.summaries = buildPlayerSummaries(this.users, this.rounds);
  }

  private currentSessionTitle(): string {
    const session = this.sessions.find((item: GameSession) => item.id === this.selectedSessionId);
    return session ? session.title : '今晚南山局';
  }

  private scoreOf(userId: string): number {
    const summary = this.summaries.find((item: PlayerSummary) => item.userId === userId);
    return summary ? summary.total : 0;
  }

  private monthTotal(): number {
    return this.scoreOf(this.users[0].id) + 118;
  }

  private totalRounds(): number {
    return Math.max(12, this.rounds.length);
  }

  private switchTab(index: number): void {
    if (this.currentTab === index) {
      return;
    }
    this.getUIContext().animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
      this.currentTab = index;
    });
  }

  private openCreateSheet(): void {
    this.getUIContext().animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.activeSheet = 1;
    });
  }

  private closeSheet(): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutLinearIn }, () => {
      this.activeSheet = 0;
    });
  }

  private startNewSession(): void {
    const title = this.newSessionTitle.trim().length > 0 ? this.newSessionTitle.trim() : '今天的牌局';
    const playerIds = this.users.slice(0, 4).map((item: User) => item.id);
    const session = ledgerRepository.createSession(this.selectedGroupId, title, Number(this.basePoint), '离线隐私模式', playerIds);
    this.selectedSessionId = session.id;
    this.closeSheet();
    this.refresh();
    promptAction.showToast({ message: '牌局已创建' });
  }

  private addSingleCollectorRound(): void {
    const session = this.sessions.find((item: GameSession) => item.id === this.selectedSessionId);
    if (!session) {
      promptAction.showToast({ message: '请先创建牌局' });
      return;
    }
    const amount = Number(this.entryAmount);
    if (Number.isNaN(amount) || amount <= 0) {
      promptAction.showToast({ message: '请输入正确金额' });
      return;
    }
    const scores: Record<string, number> = {};
    const collectorId = this.users[this.collectorIndex].id;
    scores[collectorId] = amount;
    let paid = 0;
    let loserIndex = 0;
    const loserTotal = this.users.length - 1;
    for (let index = 0; index < this.users.length; index++) {
      if (this.users[index].id !== collectorId) {
        loserIndex += 1;
        const remain = loserIndex === loserTotal ? amount - paid : Math.floor(amount / loserTotal);
        scores[this.users[index].id] = -remain;
        paid += remain;
      }
    }
    const result = validateRound(session.playerIds, scores);
    if (!result.valid) {
      promptAction.showToast({ message: result.message });
      return;
    }
    ledgerRepository.addRound(this.selectedGroupId, session.id, scores, '单家收分');
    this.refresh();
    promptAction.showToast({ message: '已记一笔' });
  }

  private syncNow(): void {
    const result = this.syncService.sync(ledgerRepository);
    this.refresh();
    promptAction.showToast({ message: result.message });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.Screen()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(PAGE_BG)
      .scale(this.activeSheet > 0 ? { x: 0.985, y: 0.985 } : { x: 1, y: 1 })
      .opacity(this.activeSheet > 0 ? 0.62 : 1)
      .animation({ duration: 260, curve: Curve.FastOutSlowIn })

      this.GlassNav()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .bindSheet(this.activeSheet > 0, this.CreateGameSheet(), {
      height: SheetSize.FIT_CONTENT,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      blurStyle: BlurStyle.COMPONENT_THIN,
      backgroundColor: '#F8FFFFFF',
      maskColor: '#991D1D1F',
      dragBar: true,
      enableFloatingDragBar: true,
      showClose: false,
      preferType: SheetType.BOTTOM,
      mode: SheetMode.OVERLAY,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
      shouldDismiss: (sheetDismiss: SheetDismiss) => {
        sheetDismiss.dismiss();
        this.activeSheet = 0;
      }
    })
  }

  @Builder
  private Screen() {
    Scroll() {
      Column({ space: 20 }) {
        this.PageHeader()
        if (this.currentTab === 0) {
          this.HomePage()
        } else if (this.currentTab === 1) {
          this.StatsPage()
        } else if (this.currentTab === 2) {
          this.FriendsPage()
        } else {
          this.MinePage()
        }
      }
      .padding({ left: 20, right: 20, top: 26, bottom: 118 })
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  private PageHeader() {
    Row() {
      Column({ space: 12 }) {
        Text(this.pageTitle())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        if (this.currentTab === 0) {
          Text('离线隐私模式 · 数据仅保存在本机')
            .fontSize(14)
            .fontColor(TEXT_SECOND)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.currentTab === 0) {
        Text('🛡')
          .width(24)
          .height(24)
          .fontSize(18)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor('#1A2F9657')
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private pageTitle(): string {
    if (this.currentTab === 0) {
      return '账本';
    }
    if (this.currentTab === 1) {
      return '统计';
    }
    if (this.currentTab === 2) {
      return '牌友';
    }
    return '我的';
  }

  @Builder
  private HomePage() {
    Column({ space: 22 }) {
      this.HomeSummaryCard()
      Column({ space: 14 }) {
        this.SectionTitle('最近牌局', '全部 〉')
        this.GameListRow('今天 20:15', '四人 · 8局', '+96', '我赢', true, ['我', 'A', 'C', 'B'])
        this.GameListRow('今天 14:32', '四人 · 6局', '-48', '我输', false, ['我', 'A', 'B', 'C'])
        this.GameListRow('昨天 20:05', '三人 · 6局', '-32', '我输', false, ['我', 'A', 'B', 'C'])
        this.GameListRow('昨天 13:47', '四人 · 8局', '+88', '我赢', true, ['我', 'A', 'B', 'B'])
        this.GameListRow('05-26 20:18', '四人 · 6局', '+24', '我赢', true, ['我', 'A', 'C', 'D'])
      }
    }
  }

  @Builder
  private HomeSummaryCard() {
    Row() {
      this.SummaryCell('本月输赢', '+128', '元', RED)
      this.VerticalDivider()
      this.SummaryCell('牌局', '12', '局', TEXT_MAIN)
      this.VerticalDivider()
      this.SummaryCell('胜率', '58%', '%', GREEN)
    }
    .height(124)
    .padding({ left: 22, right: 22 })
    .borderRadius(14)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#12000000', offsetY: 8 })
  }

  @Builder
  private SummaryCell(label: string, value: string, unit: string, color: string) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
      Text(value)
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(unit)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private VerticalDivider() {
    Column()
      .width(1)
      .height(56)
      .backgroundColor('#E7E7E7')
  }

  @Builder
  private GameListRow(time: string, desc: string, amount: string, result: string, win: boolean, players: string[]) {
    Row({ space: 12 }) {
      Column({ space: 8 }) {
        Text(time)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(desc)
          .fontSize(13)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row({ space: -2 }) {
        ForEach(players, (name: string, index: number) => {
          Text(name)
            .width(18)
            .height(18)
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(index === 0 ? '#FFFFFF' : TEXT_MAIN)
            .textAlign(TextAlign.Center)
            .borderRadius(9)
            .backgroundColor(index === 0 ? GREEN : '#E7EAEE')
        }, (name: string, index: number) => `${name}-${index}`)
      }
      Column({ space: 4 }) {
        Text(amount)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(win ? RED : GREEN)
        Text(result)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(win ? RED : GREEN)
      }
      .alignItems(HorizontalAlign.End)
      Text('›')
        .fontSize(24)
        .fontColor('#B8BDC4')
    }
    .height(76)
    .padding({ left: 14, right: 12 })
    .borderRadius(12)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 12, color: '#0A000000', offsetY: 4 })
  }

  @Builder
  private StatsPage() {
    Column({ space: 20 }) {
      Row({ space: 4 }) {
        this.SegmentButton('本周', 0)
        this.SegmentButton('本月', 1)
        this.SegmentButton('全部', 2)
      }
      .height(40)
      .padding(4)
      .borderRadius(14)
      .backgroundColor('#ECEDEB')
      this.HomeSummaryCard()
      this.ChartCard()
      this.RankingCard()
    }
  }

  @Builder
  private SegmentButton(label: string, index: number) {
    Button(label)
      .height(32)
      .layoutWeight(1)
      .borderRadius(12)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.statsMode === index ? RED : TEXT_MAIN)
      .backgroundColor(this.statsMode === index ? '#FFFFFF' : '#00000000')
      .shadow(this.statsMode === index ? { radius: 8, color: '#14000000', offsetY: 2 } : { radius: 0, color: '#00000000' })
      .stateEffect(true)
      .onClick(() => this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutSlowIn }, () => this.statsMode = index))
  }

  @Builder
  private ChartCard() {
    Column({ space: 18 }) {
      Text('输赢走势（元）')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Stack({ alignContent: Alignment.Bottom }) {
        Column({ space: 31 }) {
          this.ChartGuide('300')
          this.ChartGuide('150')
          this.ChartGuide('0')
          this.ChartGuide('-150')
          this.ChartGuide('-300')
        }
        Row({ space: 16 }) {
          this.ChartBar(70)
          this.ChartBar(36)
          this.ChartBar(58)
          this.ChartBar(92)
          this.ChartBar(122)
          this.ChartBar(86)
          this.ChartBar(112)
        }
        .height(148)
        .alignItems(VerticalAlign.Bottom)
        .padding({ left: 44, right: 8, bottom: 18 })
      }
      .height(170)
    }
    .padding(18)
    .borderRadius(14)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 16, color: '#10000000', offsetY: 6 })
  }

  @Builder
  private ChartGuide(label: string) {
    Row({ space: 8 }) {
      Text(label)
        .width(36)
        .fontSize(11)
        .fontColor('#A0A5AA')
      Column()
        .height(1)
        .layoutWeight(1)
        .backgroundColor('#ECECEC')
    }
  }

  @Builder
  private ChartBar(heightValue: number) {
    Column()
      .width(16)
      .height(heightValue)
      .borderRadius(8)
      .linearGradient({ angle: 180, colors: [[0xF23830, 0.0], [0xF7C5C1, 1.0]] })
  }

  @Builder
  private RankingCard() {
    Column({ space: 16 }) {
      Text('跟谁打胜率最高')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      this.RankRow('1', '阿飞', '12局', '胜率 72%', '+96', '#C6A85A')
      this.RankRow('2', '大熊', '10局', '60%', '+48', '#7355A5')
      this.RankRow('3', '小明', '8局', '57%', '+32', '#4FA868')
      Text('查看更多 〉')
        .width('100%')
        .fontSize(13)
        .fontColor(TEXT_SECOND)
        .textAlign(TextAlign.Center)
    }
    .padding(18)
    .borderRadius(14)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 16, color: '#10000000', offsetY: 6 })
  }

  @Builder
  private RankRow(rank: string, name: string, games: string, rate: string, amount: string, color: string) {
    Row({ space: 12 }) {
      Text(rank)
        .width(18)
        .fontSize(14)
        .fontColor(TEXT_SECOND)
      Text(name.substring(0, 1))
        .width(24)
        .height(24)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .backgroundColor(color)
      Text(name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Text(games)
        .layoutWeight(1)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
      Text(rate)
        .fontSize(15)
        .fontColor(GREEN)
      Text(amount)
        .fontSize(14)
        .fontColor(RED)
    }
    .height(34)
  }

  @Builder
  private FriendsPage() {
    Column({ space: 18 }) {
      Row({ space: 8 }) {
        Text('⌕')
          .fontSize(20)
          .fontColor(ICON_GRAY)
        Text('搜索牌友')
          .fontSize(14)
          .fontColor(TEXT_SECOND)
      }
      .height(42)
      .padding({ left: 14, right: 14 })
      .borderRadius(21)
      .backgroundColor('#ECEDEA')

      Row() {
        Text('牌友')
          .layoutWeight(1)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
        Text('对局次数')
          .width(72)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
        Text('同桌胜率')
          .width(76)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
        Text('盈亏')
          .width(56)
          .textAlign(TextAlign.End)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .padding({ left: 4, right: 4 })

      this.FriendRow('A', '阿飞', '28局', '62%', '+156', RED, '#5BA36A')
      this.FriendRow('B', '大熊', '24局', '55%', '+48', RED, '#BE9D48')
      this.FriendRow('C', '小明', '20局', '57%', '+32', RED, '#B89A4D')
      this.FriendRow('D', '琪琪', '18局', '50%', '-12', GREEN, '#70559C')
      this.FriendRow('E', '老张', '16局', '47%', '-24', GREEN, '#44A5A0')
      this.FriendRow('F', '小李', '14局', '43%', '-36', GREEN, '#3F9468')
      this.FriendRow('G', '小周', '10局', '40%', '-48', GREEN, '#4BA6A6')
      this.FriendRow('H', '阿强', '8局', '38%', '-56', GREEN, '#E45045')
      Text('长按可删除牌友')
        .width('100%')
        .fontSize(13)
        .fontColor(TEXT_SECOND)
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })
    }
  }

  @Builder
  private FriendRow(letter: string, name: string, games: string, rate: string, amount: string, amountColor: string, color: string) {
    Row() {
      Row({ space: 12 }) {
        Text(letter)
          .width(28)
          .height(28)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .backgroundColor(color)
        Text(name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
      }
      .layoutWeight(1)
      Text(games)
        .width(72)
        .fontSize(14)
        .fontColor(TEXT_MAIN)
      Text(rate)
        .width(76)
        .fontSize(14)
        .fontColor(TEXT_MAIN)
      Text(amount)
        .width(56)
        .fontSize(14)
        .fontColor(amountColor)
        .textAlign(TextAlign.End)
    }
    .height(56)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private MinePage() {
    Column({ space: 22 }) {
      Row({ space: 14 }) {
        Text('🛡')
          .width(48)
          .height(48)
          .fontSize(26)
          .textAlign(TextAlign.Center)
          .borderRadius(16)
          .backgroundColor('#1A2F9657')
        Column({ space: 5 }) {
          Row({ space: 10 }) {
            Text('本地隐私模式')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(TEXT_MAIN)
            Text('已开启')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(GREEN)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(8)
              .backgroundColor('#182F9657')
          }
          Text('数据仅保存在本机，完全离线\n不上载、不同步、不收集')
            .fontSize(13)
            .fontColor(TEXT_SECOND)
        }
        .layoutWeight(1)
        Text('›')
          .fontSize(24)
          .fontColor('#B8BDC4')
      }
      .padding(18)
      .borderRadius(14)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 16, color: '#10000000', offsetY: 6 })

      Column({ space: 0 }) {
        this.SettingSectionTitle('数据与备份')
        this.SettingRow('☁', '本地备份', '上次备份：今天 08:00')
        this.SettingRow('⇩', '导出账本', '')
        this.SettingRow('◎', '数据管理', '')
      }
      Column({ space: 0 }) {
        this.SettingSectionTitle('更多')
        this.SettingRow('☻', '在线模式预告', '即将上线')
        this.SettingRow('ⓘ', '关于', '')
      }
    }
  }

  @Builder
  private SettingSectionTitle(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(TEXT_SECOND)
      .margin({ bottom: 8 })
      .width('100%')
  }

  @Builder
  private SettingRow(icon: string, title: string, value: string) {
    Row({ space: 12 }) {
      Text(icon)
        .width(28)
        .fontSize(18)
        .fontColor(TEXT_MAIN)
        .textAlign(TextAlign.Center)
      Text(title)
        .fontSize(16)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(12)
          .fontColor('#B1B5BA')
      }
      Text('›')
        .fontSize(22)
        .fontColor('#B8BDC4')
    }
    .height(56)
    .padding({ left: 16, right: 12 })
    .backgroundColor(CARD_BG)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private CreateGameSheet() {
    Column({ space: 22 }) {
      Text('新建牌局')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Column({ space: 10 }) {
        Text('牌局名称')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Row() {
          TextInput({ text: this.newSessionTitle, placeholder: '例如：周末娱乐局' })
            .height(42)
            .layoutWeight(1)
            .borderRadius(21)
            .backgroundColor('#F3F3F1')
            .onChange((value: string) => this.newSessionTitle = value)
          Text('×')
            .width(24)
            .fontSize(18)
            .fontColor(TEXT_SECOND)
        }
      }
      Column({ space: 14 }) {
        Text('参与玩家')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Row({ space: 10 }) {
          this.PlayerPill('我', true)
          this.PlayerPill('阿飞', false)
          this.PlayerPill('大熊', false)
          this.PlayerPill('小明', false)
          this.PlayerPill('+', false)
        }
      }
      this.SheetOptionRow('计分方式', '房费模式')
      this.SheetOptionRow('底分/金额', this.basePoint)
      Button('开始记账')
        .height(50)
        .width('100%')
        .borderRadius(12)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(RED)
        .shadow({ radius: 16, color: '#40F23830', offsetY: 8 })
        .stateEffect(true)
        .onClick(() => this.startNewSession())
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 24, bottom: 30 })
  }

  @Builder
  private PlayerPill(label: string, active: boolean) {
    Text(label)
      .height(34)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(active ? RED : TEXT_MAIN)
      .padding({ left: 14, right: 14 })
      .borderRadius(17)
      .backgroundColor(active ? '#00FFFFFF' : '#F4F4F2')
      .border({ width: active ? 1 : 0, color: RED })
  }

  @Builder
  private SheetOptionRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
      Text(value)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
      Text('›')
        .fontSize(22)
        .fontColor('#B8BDC4')
        .margin({ left: 8 })
    }
    .height(54)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private SectionTitle(title: string, action: string) {
    Row() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
      if (action.length > 0) {
        Text(action)
          .fontSize(13)
          .fontColor(TEXT_SECOND)
      }
    }
    .width('100%')
  }

  @Builder
  private GlassNav() {
    Row({ space: 2 }) {
      this.NavItem('▣', '账本', 0)
      this.NavItem('▥', '统计', 1)
      Button('+')
        .width(56)
        .height(56)
        .borderRadius(28)
        .fontSize(30)
        .fontWeight(FontWeight.Normal)
        .fontColor('#FFFFFF')
        .backgroundColor(RED)
        .shadow({ radius: 18, color: '#55F23830', offsetY: 8 })
        .scale(this.activeSheet > 0 ? { x: 0.92, y: 0.92 } : { x: 1, y: 1 })
        .animation({ duration: 240, curve: Curve.FastOutSlowIn })
        .stateEffect(true)
        .onClick(() => this.openCreateSheet())
      this.NavItem('♧', '牌友', 2)
      this.NavItem('♙', '我的', 3)
    }
    .height(66)
    .width('88%')
    .padding({ left: 6, right: 6, top: 5, bottom: 5 })
    .margin({ bottom: 28 })
    .borderRadius(33)
    .backgroundColor(NAV_BG)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 1, color: '#E8FFFFFF' })
    .shadow({ radius: 26, color: '#18000000', offsetY: 10 })
  }

  @Builder
  private NavItem(icon: string, label: string, index: number) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(18)
        .fontColor(this.currentTab === index ? RED : ICON_GRAY)
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTab === index ? RED : ICON_GRAY)
    }
    .height(54)
    .layoutWeight(1)
    .borderRadius(27)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.currentTab === index ? '#0DF23830' : '#00000000')
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    .onClick(() => this.switchTab(index))
  }
}
