import promptAction from '@ohos.promptAction';
import { GameSession, Group, LedgerOperation, PlayerSummary, RoundRecord, User } from '../common/Models';
import { ledgerRepository } from '../repositories/InMemoryLedgerRepository';
import { buildPlayerSummaries, formatMoney, validateRound } from '../services/Money';
import { SyncService } from '../services/SyncService';

@Entry
@Component
struct Index {
  @State private currentTab: number = 0;
  @State private showCreateSheet: boolean = false;
  @State private entryMode: number = 0;
  @State private collectorIndex: number = 0;
  @State private activeSessionIndex: number = 0;
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
  @State private roundNote: string = '单家收分';
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

  private currentSession(): GameSession | undefined {
    return this.sessions.find((item: GameSession) => item.id === this.selectedSessionId);
  }

  private currentSessionTitle(): string {
    const session = this.currentSession();
    return session ? session.title : '今晚南山局';
  }

  private currentSessionDuration(): string {
    return `${this.users.length} 人 · 2.4h`;
  }

  private netTotal(): number {
    let total = 0;
    for (let index = 0; index < this.summaries.length; index++) {
      total += this.summaries[index].total;
    }
    return total;
  }

  private totalBuyIn(): number {
    return Number(this.basePoint) * 200 || 800;
  }

  private scoreOf(userId: string): number {
    const summary = this.summaries.find((item: PlayerSummary) => item.userId === userId);
    return summary ? summary.total : 0;
  }

  private bestSummaryName(): string {
    if (this.summaries.length === 0) {
      return '我';
    }
    let best = this.summaries[0];
    for (let index = 1; index < this.summaries.length; index++) {
      if (this.summaries[index].total > best.total) {
        best = this.summaries[index];
      }
    }
    return best.name;
  }

  private bestSummaryTotal(): number {
    if (this.summaries.length === 0) {
      return 0;
    }
    let best = this.summaries[0].total;
    for (let index = 1; index < this.summaries.length; index++) {
      best = Math.max(best, this.summaries[index].total);
    }
    return best;
  }

  private addSingleCollectorRound(): void {
    if (this.entryMode !== 0) {
      promptAction.showToast({ message: 'AA 开销和手动调整将在下一版接入' });
      return;
    }
    const session = this.currentSession();
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
    ledgerRepository.addRound(this.selectedGroupId, session.id, scores, this.roundNote);
    this.refresh();
    promptAction.showToast({ message: '已记一笔' });
  }

  private startNewSession(): void {
    const title = this.newSessionTitle.trim().length > 0 ? this.newSessionTitle.trim() : '今天的牌局';
    const playerIds = this.users.slice(0, 4).map((item: User) => item.id);
    const session = ledgerRepository.createSession(this.selectedGroupId, title, Number(this.basePoint), '离线隐私模式', playerIds);
    this.selectedSessionId = session.id;
    this.showCreateSheet = false;
    this.refresh();
    promptAction.showToast({ message: '牌局已创建' });
  }

  private syncNow(): void {
    const result = this.syncService.sync(ledgerRepository);
    this.refresh();
    promptAction.showToast({ message: result.message });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.currentTab === 0) {
          this.GamePage()
        } else if (this.currentTab === 1) {
          this.StatsPage()
        } else if (this.currentTab === 2) {
          this.FriendsPage()
        } else {
          this.MinePage()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FB')

      this.GlassNav()

      if (this.showCreateSheet) {
        this.SheetLayer()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FB')
  }

  @Builder
  private ScreenScroll() {
    Scroll() {
      Column({ space: 14 }) {
        this.PageHeader()
        if (this.currentTab === 0) {
          this.GameContent()
        } else if (this.currentTab === 1) {
          this.StatsContent()
        } else if (this.currentTab === 2) {
          this.FriendsContent()
        } else {
          this.MineContent()
        }
      }
      .padding({ left: 20, right: 20, top: 18, bottom: 118 })
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  private GamePage() {
    this.ScreenScroll()
  }

  @Builder
  private StatsPage() {
    this.ScreenScroll()
  }

  @Builder
  private FriendsPage() {
    this.ScreenScroll()
  }

  @Builder
  private MinePage() {
    this.ScreenScroll()
  }

  @Builder
  private PageHeader() {
    Row() {
      Column({ space: 4 }) {
        Text(this.headerEyebrow())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0A59F7')
        Text(this.headerTitle())
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button(this.headerAction())
        .width(48)
        .height(48)
        .borderRadius(24)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0A59F7')
        .backgroundColor('#EAF1FF')
        .onClick(() => this.headerActionTap())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private headerEyebrow(): string {
    if (this.currentTab === 0) {
      return '当前进行中';
    }
    if (this.currentTab === 1) {
      return '复盘';
    }
    if (this.currentTab === 2) {
      return '牌友关系';
    }
    return '账户与数据';
  }

  private headerTitle(): string {
    if (this.currentTab === 0) {
      return this.currentSessionTitle();
    }
    if (this.currentTab === 1) {
      return '统计';
    }
    if (this.currentTab === 2) {
      return '牌友';
    }
    return '我的';
  }

  private headerAction(): string {
    if (this.currentTab === 0) {
      return '编';
    }
    if (this.currentTab === 1) {
      return '筛';
    }
    if (this.currentTab === 2) {
      return '+';
    }
    return '设';
  }

  private headerActionTap(): void {
    if (this.currentTab === 0) {
      this.showCreateSheet = true;
    } else if (this.currentTab === 3) {
      this.syncNow();
    } else {
      promptAction.showToast({ message: '功能预留中' });
    }
  }

  @Builder
  private GameContent() {
    Column({ space: 12 }) {
      Column({ space: 12 }) {
        Row() {
          Text('参与人和入场金额')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
            .layoutWeight(1)
          Text('离线隐私')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0A59F7')
        }
        Row({ space: 8 }) {
          ForEach(this.users, (user: User) => {
            this.PlayerChip(user)
          }, (user: User) => user.id)
        }
        Row({ space: 10 }) {
          Button('编辑')
            .height(44)
            .layoutWeight(1)
            .borderRadius(22)
            .fontColor('#0A59F7')
            .backgroundColor('#EAF1FF')
          Button('结算')
            .height(44)
            .layoutWeight(1)
            .borderRadius(22)
            .fontColor('#FFFFFF')
            .backgroundColor('#0A59F7')
            .onClick(() => this.currentTab = 1)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        Row() {
          Text('当前账面')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
            .layoutWeight(1)
          Text(`总入场 ${this.totalBuyIn()}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0A59F7')
        }
        Grid() {
          ForEach(this.users, (user: User) => {
            GridItem() {
              Column({ space: 6 }) {
                Text(user.displayName)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#6B7785')
                Text(formatMoney(this.scoreOf(user.id)))
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.scoreOf(user.id) >= 0 ? '#16A06A' : '#D94838')
              }
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .borderRadius(20)
              .backgroundColor('#F8FAFF')
            }
          }, (user: User) => user.id)
        }
        .columnsTemplate('1fr 1fr')
        .rowsGap(10)
        .columnsGap(10)
        .height(146)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        Text('记账输入')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        Row({ space: 4 }) {
          this.EntryModeButton('单家收分', 0)
          this.EntryModeButton('AA 开销', 1)
          this.EntryModeButton('手动调整', 2)
        }
        .padding(4)
        .borderRadius(24)
        .backgroundColor('#DEE7F4')
        Row({ space: 10 }) {
          TextInput({ text: this.users[this.collectorIndex].displayName, placeholder: '收分玩家' })
            .height(44)
            .layoutWeight(1)
            .borderRadius(22)
            .backgroundColor('#F8FAFF')
            .onClick(() => this.collectorIndex = (this.collectorIndex + 1) % this.users.length)
          TextInput({ text: this.entryAmount, placeholder: '金额' })
            .height(44)
            .layoutWeight(1)
            .type(InputType.Number)
            .borderRadius(22)
            .backgroundColor('#F8FAFF')
            .onChange((value: string) => this.entryAmount = value)
        }
        Button('记一笔')
          .height(46)
          .width('100%')
          .borderRadius(23)
          .fontColor('#FFFFFF')
          .backgroundColor('#0A59F7')
          .onClick(() => this.addSingleCollectorRound())
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        Row() {
          Text('进出账历史')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
            .layoutWeight(1)
          Text('筛选')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0A59F7')
        }
        ForEach(this.rounds, (round: RoundRecord) => {
          this.FlowRow(round)
        }, (round: RoundRecord) => round.id)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')
    }
  }

  @Builder
  private StatsContent() {
    Column({ space: 14 }) {
      Row({ space: 4 }) {
        this.SegmentButton('本周', true)
        this.SegmentButton('本月', false)
        this.SegmentButton('全部', false)
        this.SegmentButton('历史牌局', false)
      }
      .padding(4)
      .borderRadius(26)
      .backgroundColor('#DEE7F4')

      Row({ space: 8 }) {
        this.StatCell('总输赢', formatMoney(this.scoreOf(this.users[0].id)), this.scoreOf(this.users[0].id) >= 0 ? '#16A06A' : '#D94838')
        this.StatCell('胜率', '62%', '#182431')
        this.StatCell('牌局数', `${this.sessions.length}`, '#182431')
      }
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        Row() {
          Text('近期走势')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
            .layoutWeight(1)
          Text('7 天')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0A59F7')
        }
        Row({ space: 12 }) {
          this.Bar(32)
          this.Bar(54)
          this.Bar(44)
          this.Bar(96)
          this.Bar(72)
          this.Bar(112)
          this.Bar(88)
        }
        .height(150)
        .alignItems(VerticalAlign.Bottom)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        Text('整场结算')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        Column({ space: 8 }) {
          this.SettleRow('大赢家', this.bestSummaryName(), formatMoney(this.bestSummaryTotal()))
          this.SettleRow('总入场', '4 人', `${this.totalBuyIn()}`)
          this.SettleRow('流水', `${this.rounds.length} 笔`, '已平衡')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        Text('历史牌局')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        ForEach(this.sessions, (session: GameSession) => {
          Row() {
            Column({ space: 4 }) {
              Text(session.title)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#182431')
              Text(`赢家：${this.bestSummaryName()} ${formatMoney(this.bestSummaryTotal())}`)
                .fontSize(13)
                .fontColor('#6B7785')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text(`${session.playerIds.length} 人`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0A59F7')
          }
          .padding(12)
          .borderRadius(22)
          .backgroundColor('#F8FAFF')
        }, (session: GameSession) => session.id)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')
    }
  }

  @Builder
  private FriendsContent() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text('搜')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0A59F7')
        Text('搜索牌友或牌局')
          .fontSize(14)
          .fontColor('#6B7785')
          .layoutWeight(1)
      }
      .height(48)
      .padding({ left: 14, right: 14 })
      .borderRadius(24)
      .backgroundColor('#E8EEF8')

      Column({ space: 12 }) {
        ForEach(this.users, (user: User) => {
          Row({ space: 12 }) {
            Text(user.displayName.substring(0, 1))
              .width(48)
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0A59F7')
              .textAlign(TextAlign.Center)
              .borderRadius(24)
              .backgroundColor('#EAF1FF')
            Column({ space: 4 }) {
              Text(user.displayName)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#182431')
              Text('对局 28 次 · 同桌胜率 72%')
                .fontSize(13)
                .fontColor('#6B7785')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text(formatMoney(this.scoreOf(user.id)))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.scoreOf(user.id) >= 0 ? '#16A06A' : '#D94838')
          }
          .padding({ top: 10, bottom: 10 })
        }, (user: User) => user.id)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')
    }
  }

  @Builder
  private MineContent() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        Text('我')
          .width(56)
          .height(56)
          .borderRadius(28)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0A59F7')
          .textAlign(TextAlign.Center)
          .backgroundColor('#EAF1FF')
        Column({ space: 4 }) {
          Text('麻将账本')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
          Text('管理数据、导出账本和查看在线模式设置')
            .fontSize(13)
            .fontColor('#6B7785')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .padding(18)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        this.SettingRow('本地备份', '今晚 20:08')
        this.SettingRow('导出账本', 'CSV / Excel')
        this.SettingRow('数据管理', '清理与恢复')
        this.SettingRow('在线模式设置', `待同步 ${ledgerRepository.pendingOperations().length} 条`)
        this.SettingRow('关于', 'v0.1')
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(26)
      .backgroundColor('#FFFFFF')
    }
  }

  @Builder
  private PlayerChip(user: User) {
    Column({ space: 2 }) {
      Text(user.displayName)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')
      Text('200')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6B7785')
    }
    .padding({ left: 12, right: 12, top: 7, bottom: 7 })
    .borderRadius(22)
    .backgroundColor('#F8FAFF')
  }

  @Builder
  private EntryModeButton(label: string, index: number) {
    Button(label)
      .height(38)
      .layoutWeight(1)
      .borderRadius(19)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.entryMode === index ? '#0A59F7' : '#6B7785')
      .backgroundColor(this.entryMode === index ? '#FFFFFF' : '#00000000')
      .onClick(() => this.entryMode = index)
  }

  @Builder
  private SegmentButton(label: string, selected: boolean) {
    Button(label)
      .height(40)
      .layoutWeight(1)
      .borderRadius(20)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(selected ? '#0A59F7' : '#6B7785')
      .backgroundColor(selected ? '#FFFFFF' : '#00000000')
  }

  @Builder
  private StatCell(label: string, value: string, color: string) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontColor('#6B7785')
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  private Bar(heightValue: number) {
    Column()
      .height(heightValue)
      .layoutWeight(1)
      .borderRadius(16)
      .linearGradient({
        angle: 180,
        colors: [[0x0A59F7, 0.0], [0x7AA8FF, 1.0]]
      })
  }

  @Builder
  private SettleRow(label: string, name: string, value: string) {
    Row() {
      Column({ space: 4 }) {
        Text(label)
          .fontSize(13)
          .fontColor('#6B7785')
        Text(name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(value.startsWith('-') ? '#D94838' : '#16A06A')
    }
    .padding(12)
    .borderRadius(22)
    .backgroundColor('#F8FAFF')
  }

  @Builder
  private FlowRow(round: RoundRecord) {
    Row() {
      Column({ space: 4 }) {
        Text(`${this.users[this.collectorIndex].displayName} 单家收分`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        Text(`第 ${round.index} 笔 · ${round.note.length > 0 ? round.note : '手动记账'}`)
          .fontSize(13)
          .fontColor('#6B7785')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(formatMoney(Number(round.playerScores[this.users[0].id] ?? 0)))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Number(round.playerScores[this.users[0].id] ?? 0) >= 0 ? '#16A06A' : '#D94838')
    }
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  private SettingRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')
        .layoutWeight(1)
      Text(value)
        .fontSize(12)
        .fontColor('#6B7785')
    }
    .height(58)
  }

  @Builder
  private GlassNav() {
    Row({ space: 4 }) {
      this.NavItem('▣', '牌局', 0)
      this.NavItem('▥', '统计', 1)
      Button('+')
        .width(58)
        .height(58)
        .borderRadius(29)
        .fontSize(30)
        .fontColor('#FFFFFF')
        .backgroundColor('#0A59F7')
        .onClick(() => this.showCreateSheet = true)
      this.NavItem('◉', '牌友', 2)
      this.NavItem('●', '我的', 3)
    }
    .height(72)
    .width('90%')
    .padding(7)
    .margin({ bottom: 22 })
    .borderRadius(36)
    .backgroundColor('#CCFFFFFF')
  }

  @Builder
  private NavItem(icon: string, label: string, index: number) {
    Column({ space: 3 }) {
      Text(icon)
        .fontSize(20)
        .fontColor(this.currentTab === index ? '#0A59F7' : '#6B7785')
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTab === index ? '#0A59F7' : '#6B7785')
    }
    .height(58)
    .layoutWeight(1)
    .borderRadius(29)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.currentTab === index ? '#1A0A59F7' : '#00000000')
    .onClick(() => this.currentTab = index)
  }

  @Builder
  private SheetLayer() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#33182431')
        .onClick(() => this.showCreateSheet = false)
      Column({ space: 12 }) {
        Column()
          .width(42)
          .height(5)
          .borderRadius(3)
          .backgroundColor('#C8D1DF')
        Text('新建牌局')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        TextInput({ text: this.newSessionTitle, placeholder: '牌局名称' })
          .height(48)
          .borderRadius(24)
          .backgroundColor('#F8FAFF')
          .onChange((value: string) => this.newSessionTitle = value)
        Text('离线模式参与人')
          .fontSize(13)
          .fontColor('#6B7785')
        ForEach(this.users, (user: User) => {
          Row({ space: 8 }) {
            TextInput({ text: user.displayName, placeholder: '玩家' })
              .height(40)
              .layoutWeight(1)
              .borderRadius(20)
              .backgroundColor('#F8FAFF')
            TextInput({ text: '200', placeholder: '入场' })
              .height(40)
              .width(92)
              .borderRadius(20)
              .backgroundColor('#F8FAFF')
          }
        }, (user: User) => user.id)
        Row({ space: 10 }) {
          TextInput({ text: '按金额', placeholder: '计分方式' })
            .height(48)
            .layoutWeight(1)
            .borderRadius(24)
            .backgroundColor('#F8FAFF')
          TextInput({ text: this.basePoint, placeholder: '底分' })
            .height(48)
            .layoutWeight(1)
            .type(InputType.Number)
            .borderRadius(24)
            .backgroundColor('#F8FAFF')
            .onChange((value: string) => this.basePoint = value)
        }
        Button('开始记账')
          .height(52)
          .width('100%')
          .borderRadius(26)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#0A59F7')
          .onClick(() => this.startNewSession())
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 10, bottom: 24 })
      .borderRadius({ topLeft: 26, topRight: 26 })
      .backgroundColor('#F7FFFFFF')
    }
    .width('100%')
    .height('100%')
  }
}
