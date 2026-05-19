import promptAction from '@ohos.promptAction';
import { GameSession, Group, LedgerOperation, PlayerSummary, RoundRecord, User } from '../common/Models';
import { ledgerRepository } from '../repositories/InMemoryLedgerRepository';
import { buildPlayerSummaries, formatMoney, validateRound } from '../services/Money';
import { SyncService } from '../services/SyncService';

const PAGE_BG: string = '#F3F6FC';
const CARD_BG: string = '#FFFFFF';
const SOFT_BG: string = '#EDF2FA';
const NAV_BG: string = '#B8FFFFFF';
const TEXT_MAIN: string = '#1F2329';
const TEXT_SECOND: string = '#69707A';
const LINE: string = '#E4EAF3';
const BLUE: string = '#2F63F4';
const BLUE_SOFT: string = '#EAF1FF';
const RED: string = '#D94C45';
const GREEN: string = '#2E8B57';
const MUTED_GREEN: string = '#EAF4EE';
const ICON_GRAY: string = '#7B818B';

@Entry
@Component
struct Index {
  @State private currentTab: number = 0;
  @State private activeSheet: number = 0;
  @State private statsMode: number = 0;
  @State private entryMode: number = 0;
  @State private friendSearchActive: boolean = false;
  @State private friendSearchQuery: string = '';
  @State private collectorIndex: number = 0;
  @State private payerIndex: number = 1;
  @State private adjustIndex: number = 2;
  @State private showSettlement: boolean = false;
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
  @State private aaAmount: string = '48';
  @State private adjustAmount: string = '-20';
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

  private displayScore(index: number, fallback: number): number {
    if (this.users.length <= index) {
      return fallback;
    }
    const value = this.scoreOf(this.users[index].id);
    return value === 0 ? fallback : value;
  }

  private totalBalance(): number {
    let total = 0;
    for (let index = 0; index < this.users.length; index++) {
      total += this.scoreOf(this.users[index].id);
    }
    return total;
  }

  private totalRounds(): number {
    return Math.max(2, this.rounds.length);
  }

  private openFriendSearch(): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
      this.friendSearchActive = true;
    });
  }

  private closeFriendSearch(): void {
    this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutLinearIn }, () => {
      this.friendSearchActive = false;
      this.friendSearchQuery = '';
    });
  }

  private friendSearchText(): string {
    return this.friendSearchQuery.trim().toLowerCase();
  }

  private friendSearchMatches(value: string): boolean {
    const query = this.friendSearchText();
    return query.length === 0 || value.toLowerCase().includes(query);
  }

  private friendSearchResultCount(): number {
    const query = this.friendSearchText();
    if (query.length === 0) {
      return 0;
    }
    let count = 0;
    if (this.friendSearchMatches('阿林 对局 28 次 同桌胜率 72 216')) {
      count += 1;
    }
    if (this.friendSearchMatches('老周 周 对局 19 次 同桌胜率 48 -68')) {
      count += 1;
    }
    if (this.friendSearchMatches('陈姐 陈 对局 14 次 同桌胜率 64 84')) {
      count += 1;
    }
    if (this.friendSearchMatches('今晚南山局 我 阿林 老周 小何 进行中')) {
      count += 1;
    }
    if (this.friendSearchMatches('周六家庭局 表哥 爸 妈 历史')) {
      count += 1;
    }
    return count;
  }

  private switchTab(index: number): void {
    this.getUIContext().animateTo({ duration: 240, curve: Curve.FastOutSlowIn }, () => {
      this.showSettlement = false;
      this.friendSearchActive = false;
      this.currentTab = index;
    });
  }

  private openSheet(sheet: number): void {
    this.getUIContext().animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
      this.activeSheet = sheet;
    });
  }

  private closeSheet(): void {
    this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutLinearIn }, () => {
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
        const score = loserIndex === loserTotal ? amount - paid : Math.floor(amount / loserTotal);
        scores[this.users[index].id] = -score;
        paid += score;
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

  private addAAExpenseRound(): void {
    const amount = Number(this.aaAmount);
    if (Number.isNaN(amount) || amount <= 0) {
      promptAction.showToast({ message: '请输入正确金额' });
      return;
    }
    promptAction.showToast({ message: 'AA 开销记录已预览，后续接入正式流水' });
  }

  private addAdjustRound(): void {
    const amount = Number(this.adjustAmount);
    if (Number.isNaN(amount)) {
      promptAction.showToast({ message: '请输入正确金额' });
      return;
    }
    promptAction.showToast({ message: '手动调整已预览，后续接入审计流水' });
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
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(PAGE_BG)
      .scale(this.activeSheet > 0 ? { x: 0.985, y: 0.985 } : { x: 1, y: 1 })
      .opacity(this.activeSheet > 0 ? 0.66 : 1)
      .position({ x: 0, y: 0 })
      .animation({ duration: 260, curve: Curve.FastOutSlowIn })

      if (!this.showSettlement && !this.friendSearchActive) {
        this.GlassNav()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .bindSheet(this.activeSheet > 0, this.ActiveSheet(), {
      height: SheetSize.MEDIUM,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      blurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
      backgroundColor: '#F8FFFFFF',
      maskColor: '#991F2329',
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
      Column({ space: 18 }) {
        if (this.showSettlement) {
          this.SettlementPage()
        } else if (this.currentTab === 2 && this.friendSearchActive) {
          this.FriendSearchPage()
        } else {
          this.PageHeader()
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
      }
      .padding({ left: 20, right: 20, top: 26, bottom: this.showSettlement ? 30 : 118 })
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }

  @Builder
  private PageHeader() {
    Row() {
      Column({ space: 8 }) {
        Text(this.headerEyebrow())
          .fontSize(13)
          .fontColor(TEXT_SECOND)
        Text(this.pageTitle())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private headerEyebrow(): string {
    if (this.currentTab === 0) {
      return '当前进行中';
    }
    if (this.currentTab === 1) {
      if (this.statsMode === 1) {
        return '本周复盘';
      }
      if (this.statsMode === 2) {
        return '本月复盘';
      }
      if (this.statsMode === 3) {
        return '历史牌局';
      }
      return '总览';
    }
    if (this.currentTab === 2) {
      return '本地牌友';
    }
    return '账户与数据';
  }

  private pageTitle(): string {
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

  @Builder
  private GamePage() {
    Column({ space: 16 }) {
      this.GameSetupCard()
      this.BalanceBoard()
      this.EntryPanel()
      this.CashflowHistory()
    }
  }

  @Builder
  private GameSetupCard() {
    Column({ space: 12 }) {
      this.SectionTitle('参与人和入场金额', '')
      Row({ space: 8 }) {
        this.PlayerChip('我', '200')
        this.PlayerChip('阿林', '200')
        this.PlayerChip('老周', '200')
        this.PlayerChip('小何', '200')
      }
      Row({ space: 10 }) {
        Button('编辑')
          .height(34)
          .layoutWeight(1)
          .borderRadius(17)
          .fontSize(14)
          .fontColor(TEXT_MAIN)
          .backgroundColor(SOFT_BG)
          .stateEffect(true)
          .onClick(() => this.openSheet(2))
        Button('结算')
          .height(34)
          .layoutWeight(1)
          .borderRadius(17)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(BLUE)
          .stateEffect(true)
          .onClick(() => this.showSettlement = true)
      }
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#12000000', offsetY: 8 })
  }

  @Builder
  private PlayerChip(name: string, buyIn: string) {
    Column({ space: 2 }) {
      Text(name)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .maxLines(1)
      Text(buyIn)
        .fontSize(11)
        .fontColor(TEXT_SECOND)
        .maxLines(1)
    }
      .height(46)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(23)
      .backgroundColor('#F8F6F2')
      .border({ width: 1, color: LINE })
  }

  @Builder
  private BalanceBoard() {
    Column({ space: 12 }) {
      this.SectionTitle('当前账面', '总入场 800')
      Grid() {
        GridItem() { this.BalanceCell('我', this.displayScore(0, 56)) }
        GridItem() { this.BalanceCell('阿林', this.displayScore(1, 24)) }
        GridItem() { this.BalanceCell('老周', this.displayScore(2, -48)) }
        GridItem() { this.BalanceCell('小何', this.displayScore(3, -32)) }
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(10)
      .columnsGap(10)
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private BalanceCell(name: string, score: number) {
    Column({ space: 6 }) {
      Text(name)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_SECOND)
      Text(formatMoney(score))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(score >= 0 ? GREEN : RED)
    }
    .height(72)
    .width('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .borderRadius(20)
    .backgroundColor('#F8FAFF')
  }

  @Builder
  private EntryPanel() {
    Column({ space: 14 }) {
      this.SectionTitle('记账输入', '')
      Row({ space: 4 }) {
        this.EntryModeButton('单家收分', 0)
        this.EntryModeButton('AA 开销', 1)
        this.EntryModeButton('手动调整', 2)
      }
      .height(42)
      .padding(4)
      .borderRadius(18)
      .backgroundColor(SOFT_BG)

      if (this.entryMode === 0) {
        this.SingleIncomeCard()
      } else if (this.entryMode === 1) {
        this.AAExpenseCard()
      } else {
        this.ManualAdjustCard()
      }
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private EntryModeButton(label: string, index: number) {
    Button(label)
      .height(34)
      .layoutWeight(1)
      .borderRadius(15)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.entryMode === index ? BLUE : TEXT_SECOND)
      .backgroundColor(this.entryMode === index ? CARD_BG : '#00000000')
      .shadow(this.entryMode === index ? { radius: 8, color: '#12000000', offsetY: 2 } : { radius: 0, color: '#00000000' })
      .stateEffect(true)
      .onClick(() => this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutSlowIn }, () => this.entryMode = index))
  }

  @Builder
  private SingleIncomeCard() {
    Column({ space: 12 }) {
      this.ModeCardHeader('单家收分', '一位玩家收分，自动分摊到输家')
      Row({ space: 10 }) {
        this.SelectLikeField('收分玩家', this.users[this.collectorIndex].displayName)
        this.NumberField('金额', this.entryAmount, (value: string) => this.entryAmount = value)
      }
      Row({ space: 8 }) {
        this.EntryTag('老周 -28')
        this.EntryTag('小何 -28')
      }
      Button('记一笔')
        .height(44)
        .width('100%')
        .borderRadius(14)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .stateEffect(true)
        .onClick(() => this.addSingleCollectorRound())
    }
  }

  @Builder
  private AAExpenseCard() {
    Column({ space: 12 }) {
      this.ModeCardHeader('AA 开销', '茶水、包间、外卖等共同支出，选择付款人后自动分摊')
      Row({ space: 10 }) {
        this.SelectLikeField('付款人', this.users[this.payerIndex].displayName)
        this.NumberField('总金额', this.aaAmount, (value: string) => this.aaAmount = value)
      }
      Row({ space: 8 }) {
        this.EntryTag('我 -12')
        this.EntryTag('阿林 +36')
        this.EntryTag('老周 -12')
        this.EntryTag('小何 -12')
      }
      Button('平摊记账')
        .height(44)
        .width('100%')
        .borderRadius(14)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .stateEffect(true)
        .onClick(() => this.addAAExpenseRound())
    }
  }

  @Builder
  private ManualAdjustCard() {
    Column({ space: 12 }) {
      this.ModeCardHeader('手动调整', '用于修正录错、补录或特殊约定，流水中会保留调整原因')
      Row({ space: 10 }) {
        this.SelectLikeField('调整对象', this.users[this.adjustIndex].displayName)
        this.NumberField('调整金额', this.adjustAmount, (value: string) => this.adjustAmount = value)
      }
      this.FullField('原因', '修正上一笔录入')
      Button('保存调整')
        .height(44)
        .width('100%')
        .borderRadius(14)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .stateEffect(true)
        .onClick(() => this.addAdjustRound())
    }
  }

  @Builder
  private ModeCardHeader(title: string, desc: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Text(desc)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private SelectLikeField(label: string, value: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      TextInput({ text: value })
        .height(40)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
    }
    .layoutWeight(1)
  }

  @Builder
  private NumberField(label: string, value: string, onChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      TextInput({ text: value })
        .height(40)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
        .onChange(onChange)
    }
    .layoutWeight(1)
  }

  @Builder
  private FullField(label: string, value: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      TextInput({ text: value })
        .height(40)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
    }
  }

  @Builder
  private EntryTag(label: string) {
    Text(label)
      .height(30)
      .fontSize(13)
      .fontColor(TEXT_MAIN)
      .padding({ left: 12, right: 12 })
      .borderRadius(15)
      .backgroundColor(SOFT_BG)
  }

  @Builder
  private CashflowHistory() {
    Column({ space: 12 }) {
      this.SectionTitle('进出账历史', '筛选')
      this.CashflowRow('我 自摸收分', '20:18 · 阿林 -16，老周 -16，小何 -16', '+48', true)
      this.CashflowRow('包间费 AA', '20:05 · 阿林垫付，4 人平摊', '-15', false)
      this.CashflowRow('老周 点炮', '19:52 · 我 +24，老周 -24', '+24', true)
      this.CashflowRow('小何 杠上开花', '19:37 · 三家各 -12', '-12', false)
      this.CashflowRow('茶水 AA', '19:20 · 我垫付 40，4 人平摊', '+30', true)
      this.CashflowRow('手动调整', '19:10 · 修正阿林入场金额', '+10', true)
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private CashflowRow(title: string, desc: string, amount: string, positive: boolean) {
    Row() {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(desc)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(amount)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(positive ? GREEN : RED)
    }
    .height(58)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private SettlementPage() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Button('<')
          .width(40)
          .height(40)
          .borderRadius(20)
          .fontSize(20)
          .fontColor(TEXT_MAIN)
          .backgroundColor(CARD_BG)
          .stateEffect(true)
          .onClick(() => this.showSettlement = false)
        Text(this.currentSessionTitle())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('大赢家')
          .fontSize(13)
          .fontColor(TEXT_SECOND)
        Text('我')
          .fontSize(25)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text('+56')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(GREEN)
        Text('本场净赢最高，当前账面已平衡')
          .fontSize(13)
          .fontColor(TEXT_SECOND)
      }
      .width('100%')
      .padding(22)
      .borderRadius(24)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 20, color: '#14000000', offsetY: 8 })

      this.SettlementSummary()
      Column({ space: 12 }) {
        this.SectionTitle('应收应付', '')
        this.PayableRow('老周 付给 我', '结清后老周账面归零', '48')
        this.PayableRow('小何 付给 我', '结清后小何账面归零', '8')
        this.PayableRow('小何 付给 阿林', '补齐阿林应收', '24')
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)

      Row({ space: 12 }) {
        Button('封账')
          .height(48)
          .layoutWeight(1)
          .borderRadius(16)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .backgroundColor(SOFT_BG)
          .onClick(() => promptAction.showToast({ message: '封账能力后续接入' }))
        Button('返回牌局')
          .height(48)
          .layoutWeight(1)
          .borderRadius(16)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(BLUE)
          .onClick(() => this.showSettlement = false)
      }
    }
  }

  @Builder
  private SettlementSummary() {
    Column({ space: 12 }) {
      this.SectionTitle('整场统计', '4 人 · 2.4h')
      Grid() {
        GridItem() { this.SummaryMini('总入场', '800') }
        GridItem() { this.SummaryMini('流水', '16 笔') }
        GridItem() { this.SummaryMini('AA 开销', '48') }
        GridItem() { this.SummaryMini('调整', '2 笔') }
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(10)
      .columnsGap(10)
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
  }

  @Builder
  private SummaryMini(label: string, value: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
    }
    .height(66)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
    .backgroundColor('#FBFAF7')
  }

  @Builder
  private PayableRow(title: string, desc: string, amount: string) {
    Row() {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(desc)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(amount)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
    }
    .height(58)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private StatsPage() {
    Column({ space: 16 }) {
      Row({ space: 4 }) {
        this.StatsSegment('全部', 0)
        this.StatsSegment('本周', 1)
        this.StatsSegment('本月', 2)
        this.StatsSegment('历史牌局', 3, 1.35)
      }
      .height(42)
      .width('100%')
      .padding(4)
      .borderRadius(18)
      .backgroundColor(SOFT_BG)

      if (this.statsMode === 3) {
        this.HistorySessions()
      } else {
        this.StatsSummary()
        if (this.statsMode === 1) {
          this.WeekReview()
        } else if (this.statsMode === 2) {
          this.MonthReview()
        } else {
          this.TrendCard('整体走势', '全部')
          this.PartnerRankCard('胜率最高牌友')
        }
      }
    }
  }

  @Builder
  private StatsSegment(label: string, index: number, weight: number = 1) {
    Button(label)
      .height(34)
      .layoutWeight(weight)
      .padding({ left: 0, right: 0 })
      .borderRadius(15)
      .fontSize(label.length > 3 ? 12 : 13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.statsMode === index ? BLUE : TEXT_MAIN)
      .backgroundColor(this.statsMode === index ? CARD_BG : '#00000000')
      .shadow(this.statsMode === index ? { radius: 8, color: '#12000000', offsetY: 2 } : { radius: 0, color: '#00000000' })
      .stateEffect(true)
      .onClick(() => this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutSlowIn }, () => this.statsMode = index))
  }

  @Builder
  private StatsSummary() {
    Row() {
      if (this.statsMode === 1) {
        this.SummaryCell('本周输赢', '+96', '元', GREEN)
        this.VerticalDivider()
        this.SummaryCell('胜率', '67%', '%', GREEN)
        this.VerticalDivider()
        this.SummaryCell('牌局', '3', '局', TEXT_MAIN)
      } else if (this.statsMode === 2) {
        this.SummaryCell('本月输赢', '+128', '元', GREEN)
        this.VerticalDivider()
        this.SummaryCell('平均时长', '2.4h', '', TEXT_MAIN)
        this.VerticalDivider()
        this.SummaryCell('牌局', '12', '局', TEXT_MAIN)
      } else {
        this.SummaryCell('总输赢', '+368', '元', GREEN)
        this.VerticalDivider()
        this.SummaryCell('胜率', '62%', '%', GREEN)
        this.VerticalDivider()
        this.SummaryCell('牌局数', '18', '局', TEXT_MAIN)
      }
    }
    .height(112)
    .padding({ left: 18, right: 18 })
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#12000000', offsetY: 8 })
  }

  @Builder
  private SummaryCell(label: string, value: string, unit: string, color: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(unit)
        .fontSize(11)
        .fontColor(TEXT_SECOND)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private VerticalDivider() {
    Column()
      .width(1)
      .height(52)
      .backgroundColor(LINE)
  }

  @Builder
  private TrendCard(title: string, range: string) {
    Column({ space: 18 }) {
      this.SectionTitle(title, range)
      Row({ space: 13 }) {
        this.ChartBar(44)
        this.ChartBar(70)
        this.ChartBar(55)
        this.ChartBar(102)
        this.ChartBar(78)
        this.ChartBar(116)
        this.ChartBar(96)
      }
      .height(142)
      .padding({ left: 10, right: 10, bottom: 10 })
      .alignItems(VerticalAlign.Bottom)
      .backgroundColor('#FBFAF7')
      .borderRadius(18)
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private ChartBar(heightValue: number) {
    Column()
      .width(20)
      .height(heightValue)
      .borderRadius(10)
      .linearGradient({ angle: 180, colors: [[0x2F63F4, 0.0], [0x9BB8FF, 1.0]] })
  }

  @Builder
  private WeekReview() {
    Column({ space: 14 }) {
      Column({ space: 12 }) {
        this.SectionTitle('本周节奏', '3 局')
        Row({ space: 8 }) {
          this.WeekCell('周二', '+56')
          this.WeekCell('周四', '-12')
          this.WeekCell('周六', '+52')
        }
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      Column({ space: 8 }) {
        this.SectionTitle('本周建议', '')
        Text('近期波动偏小，适合继续保持当前记账节奏，优先复盘 AA 和手动调整记录。')
          .fontSize(14)
          .fontColor(TEXT_SECOND)
          .lineHeight(22)
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
    }
  }

  @Builder
  private WeekCell(day: string, amount: string) {
    Column({ space: 8 }) {
      Text(day)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Text(amount)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(amount.startsWith('+') ? GREEN : RED)
    }
    .height(78)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(18)
    .backgroundColor('#FBFAF7')
  }

  @Builder
  private MonthReview() {
    Column({ space: 14 }) {
      this.TrendCard('本月走势', '05 月')
      Column({ space: 12 }) {
        this.SectionTitle('本月组合', '')
        this.CashflowRow('我、阿林、老周、小何', '出现 5 次', '+88', true)
        this.CashflowRow('家庭局', '出现 3 次', '-24', false)
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
    }
  }

  @Builder
  private PartnerRankCard(title: string) {
    Column({ space: 14 }) {
      this.SectionTitle(title, '')
      this.RankRow('1', '阿林', '同桌 16 次', '72%', '+96', '#C6A85A')
      this.RankRow('2', '陈姐', '同桌 9 次', '64%', '+48', '#7355A5')
      this.RankRow('3', '小何', '同桌 8 次', '57%', '+32', '#4FA868')
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private RankRow(rank: string, name: string, games: string, rate: string, amount: string, color: string) {
    Row({ space: 10 }) {
      Text(rank)
        .width(18)
        .fontSize(14)
        .fontColor(TEXT_SECOND)
      Text(name.substring(0, 1))
        .width(28)
        .height(28)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .borderRadius(14)
        .backgroundColor(color)
      Column({ space: 3 }) {
        Text(name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(games)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(rate)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(GREEN)
      Text(amount)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(GREEN)
    }
    .height(44)
  }

  @Builder
  private HistorySessions() {
    Column({ space: 12 }) {
      this.SectionTitle('历史牌局', '')
      this.HistoryCard('今晚南山局', '赢家：我', '4 人 · 我、阿林、老周、小何', '入场 800', '+56')
      this.HistoryCard('周六家庭局', '赢家：表哥', '4 人 · 我、爸、妈、表哥', '入场 400', '+88')
      this.HistoryCard('午后茶楼局', '赢家：陈姐', '4 人 · 我、陈姐、王哥、阿敏', '入场 800', '+64')
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private HistoryCard(title: string, winner: string, players: string, buyIn: string, amount: string) {
    Column({ space: 8 }) {
      Row() {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .layoutWeight(1)
        Text(amount)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(amount.startsWith('+') ? GREEN : RED)
      }
      Text(winner)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
      Text(players)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
      Text(buyIn)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
    }
    .width('100%')
    .padding(16)
    .borderRadius(22)
    .backgroundColor('#F4F7FD')
    .onClick(() => this.openSheet(3))
  }

  @Builder
  private FriendsPage() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Text('⌕')
          .fontSize(18)
          .fontColor(BLUE)
        Text('搜索牌友或牌局')
          .fontSize(14)
          .fontColor(TEXT_SECOND)
      }
      .height(44)
      .width('100%')
      .padding({ left: 14, right: 14 })
      .borderRadius(22)
      .backgroundColor(SOFT_BG)
      .onClick(() => this.openFriendSearch())

      Column({ space: 0 }) {
        this.FriendRow('林', '阿林', '对局 28 次 · 同桌胜率 72%', '+216', GREEN, '#EAF1FF', BLUE)
        this.FriendRow('周', '老周', '对局 19 次 · 同桌胜率 48%', '-68', RED, '#FFF0EE', RED)
        this.FriendRow('陈', '陈姐', '对局 14 次 · 同桌胜率 64%', '+84', GREEN, '#EAF4EE', GREEN)
      }
      .padding({ left: 16, right: 16 })
      .width('100%')
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private FriendSearchPage() {
    Column({ space: 18 }) {
      Row({ space: 10 }) {
        Row({ space: 8 }) {
          Text('⌕')
            .fontSize(18)
            .fontColor(BLUE)
          TextInput({ text: this.friendSearchQuery, placeholder: '搜索牌友、牌局、输赢金额' })
            .height(42)
            .layoutWeight(1)
            .fontSize(15)
            .fontColor(TEXT_MAIN)
            .placeholderColor(TEXT_SECOND)
            .backgroundColor('#00000000')
            .padding({ left: 0, right: 0 })
            .onChange((value: string) => {
              this.friendSearchQuery = value;
            })
          if (this.friendSearchQuery.length > 0) {
            Text('×')
              .width(24)
              .height(24)
              .fontSize(18)
              .fontColor(TEXT_SECOND)
              .textAlign(TextAlign.Center)
              .borderRadius(12)
              .backgroundColor('#E1E7F0')
              .onClick(() => {
                this.friendSearchQuery = '';
              })
          }
        }
        .height(46)
        .layoutWeight(1)
        .padding({ left: 14, right: 10 })
        .borderRadius(23)
        .backgroundColor(SOFT_BG)

        Text('取消')
          .fontSize(15)
          .fontColor(BLUE)
          .fontWeight(FontWeight.Bold)
          .onClick(() => this.closeFriendSearch())
      }
      .width('100%')

      if (this.friendSearchQuery.trim().length === 0) {
        this.FriendSearchDiscovery()
      } else {
        this.FriendSearchResults()
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.FastOutSlowIn }))
  }

  @Builder
  private FriendSearchDiscovery() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        this.SectionTitle('最近搜索', '')
        Row({ space: 8 }) {
          this.SearchSuggestion('阿林')
          this.SearchSuggestion('今晚南山局')
          this.SearchSuggestion('老周')
        }
      }
      .width('100%')

      Column({ space: 0 }) {
        this.SearchSectionTitle('常搜牌友')
        this.FriendSearchResultRow('林', '阿林', '对局 28 次 · 最近同桌 2 次', '+216', GREEN, '#EAF1FF', BLUE)
        this.FriendSearchResultRow('陈', '陈姐', '对局 14 次 · 最近常在一桌', '+84', GREEN, '#EAF4EE', GREEN)
      }
      .padding({ left: 16, right: 16 })
      .width('100%')
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Column({ space: 0 }) {
        this.SearchSectionTitle('相关牌局')
        this.GameSearchResultRow('今晚南山局', '进行中 · 我、阿林、老周、小何', '+56', GREEN)
        this.GameSearchResultRow('周六家庭局', '历史 · 表哥、爸、妈、我', '+88', GREEN)
      }
      .padding({ left: 16, right: 16 })
      .width('100%')
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private FriendSearchResults() {
    Column({ space: 16 }) {
      Row() {
        Text('搜索结果')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .layoutWeight(1)
        Text(`${this.friendSearchResultCount()} 条`)
          .fontSize(13)
          .fontColor(TEXT_SECOND)
      }
      .width('100%')

      if (this.friendSearchResultCount() === 0) {
        this.SearchEmptyState()
      } else {
        Column({ space: 0 }) {
          if (this.friendSearchMatches('阿林 对局 28 次 同桌胜率 72 216')) {
            this.FriendSearchResultRow('林', '阿林', '对局 28 次 · 同桌胜率 72%', '+216', GREEN, '#EAF1FF', BLUE)
          }
          if (this.friendSearchMatches('老周 周 对局 19 次 同桌胜率 48 -68')) {
            this.FriendSearchResultRow('周', '老周', '对局 19 次 · 同桌胜率 48%', '-68', RED, '#FFF0EE', RED)
          }
          if (this.friendSearchMatches('陈姐 陈 对局 14 次 同桌胜率 64 84')) {
            this.FriendSearchResultRow('陈', '陈姐', '对局 14 次 · 同桌胜率 64%', '+84', GREEN, '#EAF4EE', GREEN)
          }
          if (this.friendSearchMatches('今晚南山局 我 阿林 老周 小何 进行中')) {
            this.GameSearchResultRow('今晚南山局', '进行中 · 我、阿林、老周、小何', '+56', GREEN)
          }
          if (this.friendSearchMatches('周六家庭局 表哥 爸 妈 历史')) {
            this.GameSearchResultRow('周六家庭局', '历史 · 表哥、爸、妈、我', '+88', GREEN)
          }
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
        .borderRadius(22)
        .backgroundColor(CARD_BG)
        .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SearchSuggestion(label: string) {
    Text(label)
      .height(34)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(TEXT_MAIN)
      .padding({ left: 13, right: 13 })
      .borderRadius(17)
      .backgroundColor(CARD_BG)
      .border({ width: 1, color: LINE })
      .onClick(() => {
        this.friendSearchQuery = label;
      })
  }

  @Builder
  private SearchSectionTitle(title: string) {
    Text(title)
      .height(44)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(TEXT_SECOND)
      .width('100%')
      .padding({ top: 12 })
  }

  @Builder
  private FriendSearchResultRow(letter: string, name: string, summary: string, amount: string, amountColor: string, avatarBg: string, avatarColor: string) {
    Row({ space: 12 }) {
      Text(letter)
        .width(36)
        .height(36)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(avatarColor)
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor(avatarBg)
      Column({ space: 4 }) {
        Text(name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(summary)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(amount)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(amountColor)
    }
    .width('100%')
    .height(66)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private GameSearchResultRow(title: string, desc: string, amount: string, amountColor: string) {
    Row({ space: 12 }) {
      Text('局')
        .width(36)
        .height(36)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(BLUE)
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .backgroundColor(BLUE_SOFT)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(desc)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(amount)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(amountColor)
    }
    .width('100%')
    .height(66)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private SearchEmptyState() {
    Column({ space: 10 }) {
      Text('⌕')
        .width(54)
        .height(54)
        .fontSize(26)
        .fontColor(BLUE)
        .textAlign(TextAlign.Center)
        .borderRadius(27)
        .backgroundColor(BLUE_SOFT)
      Text('没有找到相关牌友或牌局')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Text('换个昵称、姓氏或牌局名再试试')
        .fontSize(13)
        .fontColor(TEXT_SECOND)
    }
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center)
    .borderRadius(24)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private FriendRow(letter: string, name: string, summary: string, amount: string, amountColor: string, avatarBg: string, avatarColor: string) {
    Row({ space: 12 }) {
      Text(letter)
        .width(34)
        .height(34)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(avatarColor)
        .textAlign(TextAlign.Center)
        .borderRadius(17)
        .backgroundColor(avatarBg)
      Column({ space: 4 }) {
        Text(name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(summary)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(amount)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(amountColor)
    }
    .width('100%')
    .height(64)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private MinePage() {
    Column({ space: 18 }) {
      Row({ space: 14 }) {
        Text('账')
          .width(42)
          .height(42)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(BLUE)
          .textAlign(TextAlign.Center)
          .borderRadius(14)
          .backgroundColor(BLUE_SOFT)
        Column({ space: 5 }) {
          Text('麻将账本')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Text('管理数据、导出账本和查看在线模式设置')
            .fontSize(13)
            .fontColor(TEXT_SECOND)
        }
        .layoutWeight(1)
      }
      .padding(18)
      .width('100%')
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Column({ space: 0 }) {
        this.SettingRow('备', '本地备份', '今晚 20:08')
        this.SettingRow('出', '导出账本', 'CSV / Excel')
        this.SettingRow('管', '数据管理', '清理与恢复')
        this.SettingRow('线', '在线模式设置', '同步与共享')
        this.SettingRow('关', '关于', 'v0.1')
      }
      .padding({ left: 16, right: 12 })
      .width('100%')
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
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
        .width(30)
        .height(30)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(BLUE)
        .textAlign(TextAlign.Center)
        .borderRadius(10)
        .backgroundColor(BLUE_SOFT)
      Text(title)
        .fontSize(16)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(12)
          .fontColor('#A6ABB2')
      }
      Text('›')
        .fontSize(22)
        .fontColor('#B8BDC4')
    }
    .height(56)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private ActiveSheet() {
    if (this.activeSheet === 2) {
      this.EditGameSheet()
    } else if (this.activeSheet === 3) {
      this.HistoryDetailSheet()
    } else {
      this.CreateGameSheet()
    }
  }

  @Builder
  private CreateGameSheet() {
    Column({ space: 20 }) {
      Text('新建牌局')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Column({ space: 8 }) {
        Text('牌局名称')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Row() {
          TextInput({ text: this.newSessionTitle, placeholder: '例如：周末娱乐局' })
            .height(42)
            .layoutWeight(1)
            .borderRadius(21)
            .backgroundColor('#F4F1EC')
            .onChange((value: string) => this.newSessionTitle = value)
          Text('×').width(24).fontSize(18).fontColor(TEXT_SECOND)
        }
      }
      Column({ space: 10 }) {
        Text('离线模式参与人')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        this.PlayerEditRow('我', '200')
        this.PlayerEditRow('阿林', '200')
        this.PlayerEditRow('老周', '200')
        this.PlayerEditRow('小何', '200')
      }
      Row({ space: 10 }) {
        this.SheetInputField('计分方式', '按金额')
        this.SheetInputField('底分', this.basePoint)
      }
      Button('开始记账')
        .height(50)
        .width('100%')
        .borderRadius(14)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .shadow({ radius: 16, color: '#522F63F4', offsetY: 8 })
        .stateEffect(true)
        .onClick(() => this.startNewSession())
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 30 })
  }

  @Builder
  private EditGameSheet() {
    Column({ space: 16 }) {
      Text('编辑牌局')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      this.FullField('牌局名称', this.currentSessionTitle())
      Column({ space: 10 }) {
        Text('参与人和入场金额')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        this.PlayerEditRow('我', '200')
        this.PlayerEditRow('阿林', '200')
        this.PlayerEditRow('老周', '200')
        this.PlayerEditRow('小何', '200')
      }
      Row({ space: 10 }) {
        this.SheetInputField('开始时间', '19:10')
        this.SheetInputField('备注', '南山茶楼')
      }
      Button('保存')
        .height(50)
        .width('100%')
        .borderRadius(14)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .onClick(() => this.closeSheet())
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 30 })
  }

  @Builder
  private HistoryDetailSheet() {
    Column({ space: 16 }) {
      Text('今晚南山局')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Row() {
        Text('赢家')
          .fontSize(14)
          .fontColor(TEXT_SECOND)
          .layoutWeight(1)
        Text('我 +56')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(GREEN)
      }
      .height(44)
      .padding({ left: 14, right: 14 })
      .borderRadius(16)
      .backgroundColor('#F4F7FD')
      Column({ space: 8 }) {
        Text('参与人和入场金额')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        this.PlayerEditRow('我', '200')
        this.PlayerEditRow('阿林', '200')
        this.PlayerEditRow('老周', '200')
        this.PlayerEditRow('小何', '200')
      }
      Column({ space: 10 }) {
        this.SectionTitle('记账流水', '')
        this.CashflowRow('我 单家收分', '20:02 · 老周 -28，小何 -28', '+56', true)
        this.CashflowRow('茶水 AA', '19:48 · 4 人平摊', '-12', false)
        this.CashflowRow('手动调整', '19:36 · 修正阿林入账', '+20', true)
      }
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 30 })
  }

  @Builder
  private PlayerEditRow(name: string, amount: string) {
    Row({ space: 10 }) {
      TextInput({ text: name })
        .height(40)
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .padding({ left: 12 })
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
      TextInput({ text: amount })
        .height(40)
        .width(88)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .textAlign(TextAlign.Center)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
    }
  }

  @Builder
  private SheetInputField(label: string, value: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      TextInput({ text: value })
        .height(42)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .borderRadius(21)
        .backgroundColor('#F4F7FD')
    }
    .layoutWeight(1)
  }

  @Builder
  private PlayerPill(label: string, active: boolean) {
    Text(label)
      .height(34)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(active ? BLUE : TEXT_MAIN)
      .padding({ left: 14, right: 14 })
      .borderRadius(17)
      .backgroundColor(active ? '#00FFFFFF' : '#F4F1EC')
      .border({ width: active ? 1 : 0, color: BLUE })
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
        .fontSize(17)
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
      this.NavItem('牌局', 0)
      this.NavItem('统计', 1)
      Button('+')
        .width(64)
        .height(64)
        .borderRadius(32)
        .fontSize(30)
        .fontWeight(FontWeight.Normal)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .shadow({ radius: 18, color: '#522F63F4', offsetY: 8 })
        .scale(this.activeSheet > 0 ? { x: 0.92, y: 0.92 } : { x: 1, y: 1 })
        .animation({ duration: 240, curve: Curve.FastOutSlowIn })
        .stateEffect(true)
        .onClick(() => this.openSheet(1))
      this.NavItem('牌友', 2)
      this.NavItem('我的', 3)
    }
    .height(72)
    .width('88%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .margin({ bottom: 24 })
    .borderRadius(36)
    .backgroundColor(NAV_BG)
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .border({ width: 1, color: '#E8FFFFFF' })
    .shadow({ radius: 26, color: '#24000000', offsetY: 10 })
  }

  @Builder
  private NavItem(label: string, index: number) {
    Column({ space: 4 }) {
      this.NavGlyph(index, this.currentTab === index ? BLUE : ICON_GRAY)
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTab === index ? BLUE : ICON_GRAY)
    }
    .height(56)
    .layoutWeight(1)
    .borderRadius(28)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.currentTab === index ? '#142F63F4' : '#00000000')
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    .onClick(() => this.switchTab(index))
  }

  @Builder
  private NavGlyph(index: number, color: string) {
    if (index === 0) {
      Column({ space: 3 }) {
        Column().width(11).height(2).borderRadius(1).backgroundColor(color)
        Column().width(11).height(2).borderRadius(1).backgroundColor(color)
        Column().width(8).height(2).borderRadius(1).backgroundColor(color)
      }
      .width(22)
      .height(22)
      .padding({ left: 5, right: 4, top: 5 })
      .border({ width: 1.5, color: color })
      .borderRadius(5)
    } else if (index === 1) {
      Row({ space: 3 }) {
        Column().width(4).height(10).borderRadius(2).backgroundColor(color)
        Column().width(4).height(16).borderRadius(2).backgroundColor(color)
        Column().width(4).height(13).borderRadius(2).backgroundColor(color)
      }
      .width(24)
      .height(22)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Bottom)
    } else if (index === 2) {
      Row({ space: 2 }) {
        Column({ space: 2 }) {
          Column().width(7).height(7).borderRadius(4).border({ width: 1.4, color: color })
          Column().width(13).height(7).borderRadius(6).border({ width: 1.4, color: color })
        }
        Column({ space: 2 }) {
          Column().width(6).height(6).borderRadius(3).border({ width: 1.2, color: color })
          Column().width(11).height(6).borderRadius(5).border({ width: 1.2, color: color })
        }
        .margin({ top: 4 })
      }
      .height(22)
      .alignItems(VerticalAlign.Center)
    } else {
      Column({ space: 2 }) {
        Column().width(8).height(8).borderRadius(4).border({ width: 1.5, color: color })
        Column().width(17).height(9).borderRadius(8).border({ width: 1.5, color: color })
      }
      .width(24)
      .height(22)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
  }
}
