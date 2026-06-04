import promptAction from '@ohos.promptAction';
import { GameSession, Group, LedgerOperation, PlayerSummary, RoundRecord, User } from '../common/Models';
import { ledgerRepository } from '../repositories/InMemoryLedgerRepository';
import { buildPlayerSummaries, formatMoney, validateRound } from '../services/Money';
import { SyncService } from '../services/SyncService';

const PAGE_BG: string = '#F3F6FC';
const CARD_BG: string = '#FFFFFF';
const SOFT_BG: string = '#EDF2FA';
const NAV_BG: string = '#70FFFFFF';
const TEXT_MAIN: string = '#1F2329';
const TEXT_SECOND: string = '#69707A';
const LINE: string = '#E4EAF3';
const BLUE: string = '#2F63F4';
const BLUE_SOFT: string = '#EAF1FF';
const RED: string = '#D94C45';
const GREEN: string = '#2E8B57';
const MUTED_GREEN: string = '#EAF4EE';
const ICON_GRAY: string = '#7B818B';
const BUY_IN_NOTE_MARKER: string = '||buyin:';

@Observed
class EntryInputDraft {
  mode: number = 0;
  collectorPlayerId: string = '';
  payerPlayerId: string = '';
  adjustPlayerId: string = '';
  singleAmount: string = '';
  aaAmount: string = '';
  aaNote: string = '';
  adjustAmount: string = '';
  adjustReason: string = '';
  revision: number = 0;

  touch(): void {
    this.revision += 1;
  }
}

@Component
struct EntryAmountTextField {
  label: string = '';
  placeholder: string = '';
  target: number = 0;
  @ObjectLink draft: EntryInputDraft;

  private currentValue(): string {
    if (this.target === 0) {
      return this.draft.singleAmount;
    }
    if (this.target === 1) {
      return this.draft.aaAmount;
    }
    return this.draft.adjustAmount;
  }

  private textWithPreviewText(value: string, previewText?: PreviewText): string {
    if (!previewText || previewText.value.length === 0) {
      return value;
    }
    const offset = Math.min(Math.max(previewText.offset, 0), value.length);
    return `${value.slice(0, offset)}${previewText.value}${value.slice(offset)}`;
  }

  private updateValue(value: string, previewText?: PreviewText): void {
    const nextValue = this.textWithPreviewText(value, previewText);
    if (this.target === 0) {
      this.draft.singleAmount = nextValue;
    } else if (this.target === 1) {
      this.draft.aaAmount = nextValue;
    } else {
      this.draft.adjustAmount = nextValue;
    }
    this.draft.touch();
  }

  build() {
    Column({ space: 6 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      TextInput({ text: this.currentValue(), placeholder: this.placeholder })
        .height(40)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
        .enablePreviewText(false)
        .inputFilter(this.target === 2 ? '[-0-9.]' : '[0-9.]')
        .onChange((value: string, previewText?: PreviewText) => {
          this.updateValue(value, previewText);
        })
        .onWillChange((change: EditableTextChangeValue) => {
          this.updateValue(change.content, change.previewText);
          return true;
        })
    }
    .width('100%')
  }
}

@Entry
@Component
struct Index {
  @State private currentTab: number = 0;
  @State private activeSheet: number = 0;
  @State private statsMode: number = 0;
  @State private friendSearchActive: boolean = false;
  @State private friendSearchQuery: string = '';
  @State private entryDraft: EntryInputDraft = new EntryInputDraft();
  @State private entryPlayerPickerTarget: number = -1;
  @State private showSettlement: boolean = false;
  @State private showCreatePage: boolean = false;
  @State private showSettlementComplete: boolean = false;
  @State private showHistoryDetail: boolean = false;
  @State private friendPickerTarget: number = -1;
  @State private pressedNavIndex: number = -1;
  @State private pressedCardKey: string = '';
  @State private pressedControlKey: string = '';
  @State private confirmClearData: boolean = false;
  @State private lastSettledTitle: string = '';
  @State private lastSettledWinnerName: string = '';
  @State private lastSettledWinnerScore: number = 0;
  @State private settlementCompletePlayed: boolean = false;
  @State private settlementCompleteCardOffset: number = 28;
  @State private settlementCompleteCardOpacity: number = 0;
  @State private settlementCompleteAmount: number = 0;
  @State private groups: Group[] = ledgerRepository.listGroups();
  @State private sessions: GameSession[] = [];
  @State private rounds: RoundRecord[] = [];
  @State private users: User[] = ledgerRepository.listUsers();
  @State private summaries: PlayerSummary[] = [];
  @State private operations: LedgerOperation[] = [];
  @State private ledgerViewRevision: number = 0;
  @State private selectedGroupId: string = '';
  @State private selectedSessionId: string = '';
  @State private newSessionTitle: string = '今天的牌局';
  @State private basePoint: string = '10';
  @State private newPlayer0Name: string = '我';
  @State private newPlayer1Name: string = '';
  @State private newPlayer2Name: string = '';
  @State private newPlayer3Name: string = '';
  @State private newPlayer0BuyIn: string = '';
  @State private newPlayer1BuyIn: string = '';
  @State private newPlayer2BuyIn: string = '';
  @State private newPlayer3BuyIn: string = '';
  @State private editSessionTitle: string = '';
  @State private editBasePoint: string = '10';
  @State private editNote: string = '';
  @State private editPlayer0Name: string = '我';
  @State private editPlayer1Name: string = '阿林';
  @State private editPlayer2Name: string = '老周';
  @State private editPlayer3Name: string = '小何';
  @State private editPlayer0BuyIn: string = '200';
  @State private editPlayer1BuyIn: string = '200';
  @State private editPlayer2BuyIn: string = '200';
  @State private editPlayer3BuyIn: string = '200';
  @State private cashflowFilter: number = 0;
  @State private historyDetailSessionId: string = '';
  private syncService: SyncService = new SyncService();

  aboutToAppear(): void {
    this.refresh();
  }


  private refresh(): void {
    this.users = ledgerRepository.listUsers();
    this.groups = ledgerRepository.listGroups();
    if (this.selectedGroupId.length === 0 && this.groups.length > 0) {
      this.selectedGroupId = this.groups[0].id;
    }
    this.sessions = ledgerRepository.listSessions(this.selectedGroupId);
    const activeSessions = this.activeSessionsFrom(this.sessions);
    if (activeSessions.length === 0) {
      this.selectedSessionId = '';
    } else if (this.selectedSessionId.length === 0
      || !activeSessions.some((item: GameSession) => item.id === this.selectedSessionId)) {
      this.selectedSessionId = activeSessions[0].id;
    }
    const nextRounds = ledgerRepository.listRounds(this.selectedSessionId);
    const nextSummaries = buildPlayerSummaries(this.users, nextRounds);
    this.rounds = nextRounds;
    this.operations = ledgerRepository.listOperations(this.selectedGroupId);
    this.summaries = nextSummaries;
    this.clearStaleEntrySelections();
    this.ledgerViewRevision += 1;
  }

  private currentSessionTitle(): string {
    const session = this.currentSession();
    return session ? session.title : '牌局';
  }

  private currentSession(): GameSession | undefined {
    return this.sessions.find((item: GameSession) => item.id === this.selectedSessionId && item.status === 'active');
  }

  private activeSessions(): GameSession[] {
    return this.activeSessionsFrom(this.sessions);
  }

  private activeSessionsFrom(sessions: GameSession[]): GameSession[] {
    return sessions.filter((item: GameSession) => item.status === 'active');
  }

  private settledSessions(): GameSession[] {
    return this.sessions.filter((item: GameSession) => item.status === 'settled');
  }

  private settledSessionsForScope(scope: number): GameSession[] {
    return this.settledSessions().filter((session: GameSession) => {
      if (scope === 1) {
        return this.isSessionInCurrentWeek(session);
      }
      if (scope === 2) {
        return this.isSessionInCurrentMonth(session);
      }
      return true;
    });
  }

  private userById(userId: string): User | undefined {
    return this.users.find((item: User) => item.id === userId);
  }

  private sessionPlayer(index: number): User {
    const session = this.currentSession();
    const playerId = session && session.playerIds.length > index ? session.playerIds[index] : '';
    const player = playerId.length > 0 ? this.userById(playerId) : undefined;
    return player ? player : this.users[Math.min(index, this.users.length - 1)];
  }

  private sessionPlayerId(index: number): string {
    return this.sessionPlayer(index).id;
  }

  private sessionPlayerName(index: number): string {
    return this.sessionPlayer(index).displayName;
  }

  private sessionPlayerCount(): number {
    const session = this.currentSession();
    return session ? session.playerIds.length : Math.min(4, this.users.length);
  }

  private currentPlayerIds(): string[] {
    const session = this.currentSession();
    return session ? session.playerIds.slice(0, 4) : this.users.slice(0, 4).map((item: User) => item.id);
  }

  private clearStaleEntrySelections(): void {
    const playerIds = this.currentPlayerIds();
    if (!playerIds.some((item: string) => item === this.entryDraft.collectorPlayerId)) {
      this.entryDraft.collectorPlayerId = '';
    }
    if (!playerIds.some((item: string) => item === this.entryDraft.payerPlayerId)) {
      this.entryDraft.payerPlayerId = '';
    }
    if (!playerIds.some((item: string) => item === this.entryDraft.adjustPlayerId)) {
      this.entryDraft.adjustPlayerId = '';
    }
    this.entryDraft.touch();
  }

  private buyInForUser(userId: string): number {
    const session = this.currentSession();
    if (!session) {
      return 200;
    }
    return Number(session.buyIns[userId] ?? 200);
  }

  private buyInAt(index: number): number {
    return this.buyInForUser(this.sessionPlayerId(index));
  }

  private playerNameById(userId: string): string {
    const user = this.userById(userId);
    return user ? user.displayName : '玩家';
  }

  private totalBuyIn(): number {
    let total = 0;
    const playerIds = this.currentPlayerIds();
    for (let index = 0; index < playerIds.length; index++) {
      total += this.buyInForUser(playerIds[index]);
    }
    return total;
  }

  private parsePositiveAmount(value: string, fallback: number = 0): number {
    const amount = Number(value);
    if (Number.isNaN(amount) || amount < 0) {
      return fallback;
    }
    return amount;
  }

  private roundTime(value: number): string {
    const date = new Date(value);
    const hour = `${date.getHours()}`.padStart(2, '0');
    const minute = `${date.getMinutes()}`.padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private scoreText(userId: string, score: number): string {
    return `${this.playerNameById(userId)} ${formatMoney(score)}`;
  }

  private roundCategory(round: RoundRecord): number {
    if (round.note.includes('AA') || round.note.includes('茶水') || round.note.includes('包间') || round.note.includes('开销')) {
      return 2;
    }
    if (round.note.includes('调整') || round.note.includes('修正')) {
      return 3;
    }
    return 1;
  }

  private cashflowFilterText(): string {
    if (this.cashflowFilter === 1) {
      return '收分';
    }
    if (this.cashflowFilter === 2) {
      return '开销';
    }
    if (this.cashflowFilter === 3) {
      return '调整';
    }
    return '全部';
  }

  private cycleCashflowFilter(): void {
    this.cashflowFilter = (this.cashflowFilter + 1) % 4;
  }

  private visibleRounds(): RoundRecord[] {
    return this.rounds
      .filter((item: RoundRecord) => !item.isVoided)
      .filter((item: RoundRecord) => this.cashflowFilter === 0 || this.roundCategory(item) === this.cashflowFilter)
      .sort((left: RoundRecord, right: RoundRecord) => right.createdAt - left.createdAt);
  }

  private visibleRoundListHeight(): number {
    return this.visibleRounds().slice(0, 8).length * 58;
  }

  private activeRoundsFor(session: GameSession): RoundRecord[] {
    return ledgerRepository.listRounds(session.id)
      .filter((item: RoundRecord) => !item.isVoided)
      .sort((left: RoundRecord, right: RoundRecord) => right.createdAt - left.createdAt);
  }

  private historyRoundListHeight(session: GameSession): number {
    return this.activeRoundsFor(session).length * 58;
  }

  private visibleRoundAt(index: number): RoundRecord | undefined {
    const records = this.visibleRounds();
    return records.length > index ? records[index] : undefined;
  }

  private historyDetailSession(): GameSession | undefined {
    const session = this.sessions.find((item: GameSession) => item.id === this.historyDetailSessionId);
    return session ? session : this.currentSession();
  }

  private sessionPlayerNames(session: GameSession): string {
    const names: string[] = [];
    for (let index = 0; index < session.playerIds.length; index++) {
      names.push(this.playerNameById(session.playerIds[index]));
    }
    return names.join('、');
  }

  private sessionDateText(session: GameSession): string {
    const time = session.settledAt > 0 ? session.settledAt : session.createdAt;
    const date = new Date(time);
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`;
  }

  private sessionWinnerId(session: GameSession): string {
    let winnerId = session.playerIds.length > 0 ? session.playerIds[0] : '';
    let winnerScore = winnerId.length > 0 ? this.sessionScoreForUser(session, winnerId) : 0;
    for (let index = 0; index < session.playerIds.length; index++) {
      const score = this.sessionScoreForUser(session, session.playerIds[index]);
      if (score > winnerScore) {
        winnerId = session.playerIds[index];
        winnerScore = score;
      }
    }
    return winnerId;
  }

  private sessionLoserId(session: GameSession): string {
    let loserId = session.playerIds.length > 0 ? session.playerIds[0] : '';
    let loserScore = loserId.length > 0 ? this.sessionScoreForUser(session, loserId) : 0;
    for (let index = 0; index < session.playerIds.length; index++) {
      const score = this.sessionScoreForUser(session, session.playerIds[index]);
      if (score < loserScore) {
        loserId = session.playerIds[index];
        loserScore = score;
      }
    }
    return loserId;
  }

  private sessionWinnerSummary(session: GameSession): string {
    const winnerId = this.sessionWinnerId(session);
    return winnerId.length > 0 ? `${this.playerNameById(winnerId)} ${formatMoney(this.sessionScoreForUser(session, winnerId))}` : '暂无';
  }

  private sessionLoserSummary(session: GameSession): string {
    const loserId = this.sessionLoserId(session);
    return loserId.length > 0 ? `${this.playerNameById(loserId)} ${formatMoney(this.sessionScoreForUser(session, loserId))}` : '暂无';
  }

  private sessionPlayerNameFor(session: GameSession, index: number, fallback: string): string {
    if (session.playerIds.length <= index) {
      return fallback;
    }
    return this.playerNameById(session.playerIds[index]);
  }

  private sessionBuyInFor(session: GameSession, index: number): string {
    if (session.playerIds.length <= index) {
      return '200';
    }
    return `${Number(session.buyIns[session.playerIds[index]] ?? 200)}`;
  }

  private sessionBuyInTotal(session: GameSession): number {
    let total = 0;
    for (let index = 0; index < session.playerIds.length; index++) {
      total += Number(session.buyIns[session.playerIds[index]] ?? 200);
    }
    return total;
  }

  private sessionBuyInSummary(session: GameSession): string {
    const parts: string[] = [];
    for (let index = 0; index < session.playerIds.length; index++) {
      const playerId = session.playerIds[index];
      parts.push(`${this.playerNameById(playerId)} ${Number(session.buyIns[playerId] ?? 200)}`);
    }
    return parts.join('，');
  }

  private sessionScoreForCurrent(session: GameSession): number {
    const records = ledgerRepository.listRounds(session.id);
    return this.displayBalanceFromRounds(records, ledgerRepository.currentUser().id);
  }

  private sessionScoreForUser(session: GameSession, userId: string): number {
    return this.displayBalanceFromRounds(ledgerRepository.listRounds(session.id), userId);
  }

  private closedGameCount(scope: number = 0): number {
    return this.settledSessionsForScope(scope).length;
  }

  private closedCurrentTotal(scope: number = 0): number {
    let total = 0;
    const currentUserId = ledgerRepository.currentUser().id;
    const sessions = this.settledSessionsForScope(scope);
    for (let index = 0; index < sessions.length; index++) {
      total += this.sessionScoreForUser(sessions[index], currentUserId);
    }
    return total;
  }

  private closedWinRateText(scope: number = 0): string {
    const sessions = this.settledSessionsForScope(scope);
    if (sessions.length === 0) {
      return '0%';
    }
    let wins = 0;
    const currentUserId = ledgerRepository.currentUser().id;
    for (let index = 0; index < sessions.length; index++) {
      if (this.sessionScoreForUser(sessions[index], currentUserId) > 0) {
        wins += 1;
      }
    }
    return `${Math.round(wins * 100 / sessions.length)}%`;
  }

  private maxClosedWin(): number {
    let maxWin = 0;
    const currentUserId = ledgerRepository.currentUser().id;
    const sessions = this.settledSessions();
    for (let index = 0; index < sessions.length; index++) {
      maxWin = Math.max(maxWin, this.sessionScoreForUser(sessions[index], currentUserId));
    }
    return maxWin;
  }

  private distinctClosedPartners(): number {
    const currentUserId = ledgerRepository.currentUser().id;
    const partnerIds: string[] = [];
    const sessions = this.settledSessions();
    for (let index = 0; index < sessions.length; index++) {
      for (let playerIndex = 0; playerIndex < sessions[index].playerIds.length; playerIndex++) {
        const playerId = sessions[index].playerIds[playerIndex];
        if (playerId !== currentUserId && !partnerIds.includes(playerId)) {
          partnerIds.push(playerId);
        }
      }
    }
    return partnerIds.length;
  }

  private averageClosedDurationText(scope: number = 0): string {
    const sessions = this.settledSessionsForScope(scope);
    if (sessions.length === 0) {
      return '0h';
    }
    let totalDuration = 0;
    for (let index = 0; index < sessions.length; index++) {
      const settledAt = sessions[index].settledAt > 0 ? sessions[index].settledAt : sessions[index].createdAt;
      totalDuration += Math.max(0, settledAt - sessions[index].createdAt);
    }
    const averageHours = totalDuration / sessions.length / 3600000;
    if (averageHours < 0.1) {
      return '0h';
    }
    return `${Math.round(averageHours * 10) / 10}h`;
  }

  private latestSettledSession(scope: number = 0): GameSession | undefined {
    const sessions = this.settledSessionsForScope(scope).sort((left: GameSession, right: GameSession) => {
      return this.sessionTrendTime(right) - this.sessionTrendTime(left);
    });
    return sessions.length > 0 ? sessions[0] : undefined;
  }

  private trendSessions(): GameSession[] {
    return this.trendSessionsForScope(0);
  }

  private sessionTrendTime(session: GameSession): number {
    return session.settledAt > 0 ? session.settledAt : session.createdAt;
  }

  private trendSessionsForScope(scope: number): GameSession[] {
    return this.settledSessionsForScope(scope).sort((left: GameSession, right: GameSession) => {
      const leftTime = left.settledAt > 0 ? left.settledAt : left.createdAt;
      const rightTime = right.settledAt > 0 ? right.settledAt : right.createdAt;
      return leftTime - rightTime;
    });
  }

  private isSessionInCurrentWeek(session: GameSession): boolean {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const day = start.getDay() === 0 ? 7 : start.getDay();
    start.setDate(start.getDate() - day + 1);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start.getTime());
    end.setDate(start.getDate() + 7);
    const time = this.sessionTrendTime(session);
    return time >= start.getTime() && time < end.getTime();
  }

  private isSessionInCurrentMonth(session: GameSession): boolean {
    const now = new Date();
    const time = this.sessionTrendTime(session);
    const date = new Date(time);
    return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth();
  }

  private trendScoreAt(index: number, scope: number = 0): number {
    const sessions = this.trendSessionsForScope(scope);
    if (index < 0 || index >= sessions.length) {
      return 0;
    }
    return this.sessionScoreForCurrent(sessions[index]);
  }

  private trendDateTextAt(index: number, scope: number = 0): string {
    const sessions = this.trendSessionsForScope(scope);
    if (index < 0 || index >= sessions.length) {
      return '';
    }
    const time = this.sessionTrendTime(sessions[index]);
    const date = new Date(time);
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }

  private trendPointIndexes(scope: number = 0): string[] {
    const result: string[] = [];
    const sessions = this.trendSessionsForScope(scope);
    const count = Math.min(7, sessions.length);
    const offset = Math.max(0, sessions.length - count);
    for (let index = 0; index < count; index++) {
      result.push(`${offset + index}`);
    }
    return result;
  }

  private trendMinScore(scope: number = 0): number {
    const indexes = this.trendPointIndexes(scope);
    if (indexes.length === 0) {
      return 0;
    }
    let value = this.trendScoreAt(Number(indexes[0]), scope);
    for (let index = 0; index < indexes.length; index++) {
      value = Math.min(value, this.trendScoreAt(Number(indexes[index]), scope));
    }
    return value;
  }

  private trendMaxScore(scope: number = 0): number {
    const indexes = this.trendPointIndexes(scope);
    if (indexes.length === 0) {
      return 0;
    }
    let value = this.trendScoreAt(Number(indexes[0]), scope);
    for (let index = 0; index < indexes.length; index++) {
      value = Math.max(value, this.trendScoreAt(Number(indexes[index]), scope));
    }
    return value;
  }

  private trendPointX(index: number, scope: number = 0): number {
    const indexes = this.trendPointIndexes(scope);
    const localIndex = Math.max(0, indexes.indexOf(`${index}`));
    const divisor = Math.max(1, indexes.length - 1);
    return 18 + localIndex * (244 / divisor);
  }

  private trendPointY(index: number, scope: number = 0): number {
    const min = this.trendMinScore(scope);
    const max = this.trendMaxScore(scope);
    if (max === min) {
      return 66;
    }
    const ratio = (this.trendScoreAt(index, scope) - min) / (max - min);
    return 112 - ratio * 96;
  }

  private trendPathCommands(scope: number = 0): string {
    const indexes = this.trendPointIndexes(scope);
    if (indexes.length === 0) {
      return '';
    }
    let commands = '';
    for (let index = 0; index < indexes.length; index++) {
      const pointIndex = Number(indexes[index]);
      const prefix = index === 0 ? 'M' : 'L';
      commands += `${prefix}${this.trendPointX(pointIndex, scope)} ${this.trendPointY(pointIndex, scope)} `;
    }
    return commands.trim();
  }

  private partnerRankRows(): string[] {
    return this.partnerRankRowsForScope(0);
  }

  private partnerRankRowsForScope(scope: number): string[] {
    const rows: string[] = [];
    const currentUserId = ledgerRepository.currentUser().id;
    const sessions = this.settledSessionsForScope(scope);
    for (let index = 0; index < this.users.length; index++) {
      const user = this.users[index];
      if (user.id !== currentUserId) {
        let games = 0;
        let wins = 0;
        let total = 0;
        for (let sessionIndex = 0; sessionIndex < sessions.length; sessionIndex++) {
          const session = sessions[sessionIndex];
          if (session.playerIds.includes(user.id)) {
            games += 1;
            const score = this.sessionScoreForUser(session, user.id);
            total += score;
            if (score > 0) {
              wins += 1;
            }
          }
        }
        if (games > 0) {
          rows.push(`${user.id}|${games}|${Math.round(wins * 100 / games)}%|${total}`);
        }
      }
    }
    return rows.sort((left: string, right: string) => {
      const leftParts = left.split('|');
      const rightParts = right.split('|');
      const leftRate = Number(leftParts[2].replace('%', ''));
      const rightRate = Number(rightParts[2].replace('%', ''));
      if (rightRate !== leftRate) {
        return rightRate - leftRate;
      }
      return Number(rightParts[3]) - Number(leftParts[3]);
    });
  }

  private rankUserId(row: string): string {
    return row.split('|')[0];
  }

  private rankName(row: string): string {
    return this.playerNameById(this.rankUserId(row));
  }

  private rankGames(row: string): string {
    return row.split('|')[1];
  }

  private rankRate(row: string): string {
    return row.split('|')[2];
  }

  private rankAmount(row: string): number {
    return Number(row.split('|')[3] ?? 0);
  }

  private rankAvatarColor(row: string): string {
    const user = this.userById(this.rankUserId(row));
    return user ? user.avatarColor : BLUE;
  }

  private sessionWinner(session: GameSession): string {
    return this.sessionWinnerSummary(session);
  }

  private currentWinnerName(): string {
    let winnerId = this.currentPlayerIds()[0];
    let winnerScore = this.displayBalanceFromRounds(this.rounds, winnerId);
    const playerIds = this.currentPlayerIds();
    for (let index = 0; index < playerIds.length; index++) {
      const score = this.displayBalanceFromRounds(this.rounds, playerIds[index]);
      if (score > winnerScore) {
        winnerId = playerIds[index];
        winnerScore = score;
      }
    }
    return this.playerNameById(winnerId);
  }

  private currentWinnerScore(): number {
    let winnerScore = this.displayBalanceFromRounds(this.rounds, this.currentPlayerIds()[0]);
    const playerIds = this.currentPlayerIds();
    for (let index = 0; index < playerIds.length; index++) {
      winnerScore = Math.max(winnerScore, this.displayBalanceFromRounds(this.rounds, playerIds[index]));
    }
    return winnerScore;
  }

  private currentRoundCount(): number {
    return this.rounds.filter((item: RoundRecord) => !item.isVoided).length;
  }

  private currentRoundCountFor(session: GameSession): number {
    return ledgerRepository.listRounds(session.id).filter((item: RoundRecord) => !item.isVoided).length;
  }

  private historyWinnerScore(session: GameSession): number {
    let winnerScore = session.playerIds.length > 0 ? this.sessionScoreForUser(session, session.playerIds[0]) : 0;
    for (let index = 0; index < session.playerIds.length; index++) {
      winnerScore = Math.max(winnerScore, this.sessionScoreForUser(session, session.playerIds[index]));
    }
    return winnerScore;
  }

  private aaExpenseTotal(): number {
    let total = 0;
    for (let index = 0; index < this.rounds.length; index++) {
      if (!this.rounds[index].isVoided && this.roundCategory(this.rounds[index]) === 2) {
        const scores = this.rounds[index].playerScores;
        const playerIds = this.currentPlayerIds();
        for (let playerIndex = 0; playerIndex < playerIds.length; playerIndex++) {
          total += Math.max(0, Number(scores[playerIds[playerIndex]] ?? 0));
        }
      }
    }
    return total;
  }

  private adjustCount(): number {
    return this.rounds.filter((item: RoundRecord) => !item.isVoided && this.roundCategory(item) === 3).length;
  }

  private settlementRows(): string[] {
    const rows: string[] = [];
    let hasBalance = false;
    const playerIds = this.currentPlayerIds();
    for (let index = 0; index < playerIds.length; index++) {
      const userId = playerIds[index];
      const score = this.displayBalanceFromRounds(this.rounds, userId);
      if (score !== 0) {
        hasBalance = true;
      }
      rows.push(`${userId}|${score}|${this.buyInForUser(userId)}`);
    }
    return hasBalance ? rows : [];
  }

  private settlementRowUserId(row: string): string {
    return row.split('|')[0];
  }

  private settlementRowName(row: string): string {
    return this.playerNameById(this.settlementRowUserId(row));
  }

  private settlementRowDesc(row: string): string {
    return `入场 ${row.split('|')[2] ?? 0}`;
  }

  private settlementRowAmount(row: string): number {
    return Number(row.split('|')[1] ?? 0);
  }

  private settlementTransferRows(): string[] {
    const receivers: string[] = [];
    const payers: string[] = [];
    const playerIds = this.currentPlayerIds();
    for (let index = 0; index < playerIds.length; index++) {
      const score = this.displayBalanceFromRounds(this.rounds, playerIds[index]);
      if (score > 0) {
        receivers.push(`${playerIds[index]}|${score}`);
      } else if (score < 0) {
        payers.push(`${playerIds[index]}|${-score}`);
      }
    }
    const rows: string[] = [];
    let payerIndex = 0;
    let receiverIndex = 0;
    while (payerIndex < payers.length && receiverIndex < receivers.length) {
      const payerParts = payers[payerIndex].split('|');
      const receiverParts = receivers[receiverIndex].split('|');
      const amount = Math.min(Number(payerParts[1]), Number(receiverParts[1]));
      rows.push(`${payerParts[0]}|${receiverParts[0]}|${amount}`);
      payers[payerIndex] = `${payerParts[0]}|${Number(payerParts[1]) - amount}`;
      receivers[receiverIndex] = `${receiverParts[0]}|${Number(receiverParts[1]) - amount}`;
      if (Number(payers[payerIndex].split('|')[1]) === 0) {
        payerIndex += 1;
      }
      if (Number(receivers[receiverIndex].split('|')[1]) === 0) {
        receiverIndex += 1;
      }
    }
    return rows;
  }

  private settlementTransferTitle(row: string): string {
    const parts = row.split('|');
    return `${this.playerNameById(parts[0])} 转给 ${this.playerNameById(parts[1])}`;
  }

  private settlementTransferDesc(row: string): string {
    const parts = row.split('|');
    return `结清 ${this.playerNameById(parts[0])} 的应付`;
  }

  private settlementTransferAmount(row: string): string {
    return row.split('|')[2];
  }

  private roundTitle(round: RoundRecord): string {
    if (this.isBuyInAdjustmentRound(round)) {
      return '入场金额调整';
    }
    if (this.roundCategory(round) === 2) {
      return 'AA 开销';
    }
    if (this.roundCategory(round) === 3) {
      return '手动调整';
    }
    let bestId = '';
    let bestScore = -999999;
    const playerIds = this.playerIdsForRound(round);
    for (let index = 0; index < playerIds.length; index++) {
      const score = Number(round.playerScores[playerIds[index]] ?? 0);
      if (score > bestScore) {
        bestScore = score;
        bestId = playerIds[index];
      }
    }
    return `${this.playerNameById(bestId)} 收分`;
  }

  private roundDetail(round: RoundRecord): string {
    const parts: string[] = [];
    const playerIds = this.playerIdsForRound(round);
    for (let index = 0; index < playerIds.length; index++) {
      const score = Number(round.playerScores[playerIds[index]] ?? 0);
      if (score !== 0) {
        parts.push(this.scoreText(playerIds[index], score));
      }
    }
    const detail = parts.join('，');
    return `${this.roundTime(round.createdAt)} · ${detail.length > 0 ? detail : this.visibleRoundNote(round)}`;
  }

  private roundCurrentUserAmount(round: RoundRecord): number {
    const userId = ledgerRepository.currentUser().id;
    return Number(round.playerScores[userId] ?? 0) + this.buyInAdjustmentAmount(round, userId);
  }

  private roundDisplayAmount(round: RoundRecord): number {
    if (!this.isBuyInAdjustmentRound(round)) {
      return this.roundCurrentUserAmount(round);
    }
    const deltas = this.buyInAdjustmentDeltas(round);
    const playerIds = this.playerIdsForRound(round);
    let total = 0;
    for (let index = 0; index < playerIds.length; index++) {
      total += Number(deltas[playerIds[index]] ?? 0);
    }
    return total;
  }

  private playerIdsForRound(round: RoundRecord): string[] {
    const session = this.sessions.find((item: GameSession) => item.id === round.sessionId);
    return session ? session.playerIds.slice(0, 4) : this.currentPlayerIds();
  }

  private entryPlayerFieldText(playerId: string): string {
    return playerId.length > 0 ? this.playerNameById(playerId) : '请选择';
  }

  private isPositiveEntryAmount(value: string): boolean {
    const amount = Number(value);
    return !Number.isNaN(amount) && amount > 0;
  }

  private isValidAdjustAmount(value: string): boolean {
    const amount = Number(value);
    return !Number.isNaN(amount) && amount !== 0;
  }

  private buildSingleIncomeScores(playerIds: string[], collectorId: string, loserAmount: number): Record<string, number> {
    const scores: Record<string, number> = {};
    if (!playerIds.some((item: string) => item === collectorId) || loserAmount <= 0 || playerIds.length <= 1) {
      return scores;
    }
    const loserTotal = playerIds.length - 1;
    scores[collectorId] = loserAmount * loserTotal;
    for (let index = 0; index < playerIds.length; index++) {
      const playerId = playerIds[index];
      if (playerId !== collectorId) {
        scores[playerId] = -loserAmount;
      }
    }
    return scores;
  }

  private buildAAExpenseScores(playerIds: string[], payerId: string, amount: number): Record<string, number> {
    const scores: Record<string, number> = {};
    if (!playerIds.some((item: string) => item === payerId) || amount <= 0 || playerIds.length === 0) {
      return scores;
    }
    const share = Math.floor(amount / playerIds.length);
    let assigned = 0;
    for (let index = 0; index < playerIds.length; index++) {
      const playerId = playerIds[index];
      const cost = index === playerIds.length - 1 ? amount - assigned : share;
      scores[playerId] = playerId === payerId ? amount - cost : -cost;
      assigned += cost;
    }
    return scores;
  }

  private scoreOf(userId: string): number {
    return this.scoreFromRounds(this.rounds, userId);
  }

  private scoreOfFrom(summaries: PlayerSummary[], userId: string): number {
    const summary = summaries.find((item: PlayerSummary) => item.userId === userId);
    return summary ? summary.total : 0;
  }

  private scoreFromRounds(rounds: RoundRecord[], userId: string): number {
    let total = 0;
    for (let index = 0; index < rounds.length; index++) {
      const round = rounds[index];
      if (!round.isVoided) {
        total += Number(round.playerScores[userId] ?? 0);
      }
    }
    return total;
  }

  private displayBalanceFromRounds(rounds: RoundRecord[], userId: string): number {
    return this.scoreFromRounds(rounds, userId) + this.buyInAdjustmentFromRounds(rounds, userId);
  }

  private pressableCardScale(cardKey: string): ScaleOptions {
    return this.pressedCardKey === cardKey ? { x: 0.985, y: 0.985 } : { x: 1, y: 1 };
  }

  private handlePressableCardTouch(event: TouchEvent, cardKey: string): void {
    if (event.type === TouchType.Down) {
      this.pressedCardKey = cardKey;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedCardKey = '';
    }
  }

  private pressableControlScale(controlKey: string): ScaleOptions {
    return this.pressedControlKey === controlKey ? { x: 0.96, y: 0.96 } : { x: 1, y: 1 };
  }

  private handlePressableControlTouch(event: TouchEvent, controlKey: string): void {
    if (event.type === TouchType.Down) {
      this.pressedControlKey = controlKey;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedControlKey = '';
    }
  }

  private isBuyInAdjustmentRound(round: RoundRecord): boolean {
    return round.note.includes(BUY_IN_NOTE_MARKER);
  }

  private visibleRoundNote(round: RoundRecord): string {
    const markerIndex = round.note.indexOf(BUY_IN_NOTE_MARKER);
    return markerIndex >= 0 ? round.note.slice(0, markerIndex) : round.note;
  }

  private buyInAdjustmentAmount(round: RoundRecord, userId: string): number {
    const deltas = this.buyInAdjustmentDeltas(round);
    return Number(deltas[userId] ?? 0);
  }

  private buyInAdjustmentDeltas(round: RoundRecord): Record<string, number> {
    if (!this.isBuyInAdjustmentRound(round)) {
      return {};
    }
    const markerIndex = round.note.indexOf(BUY_IN_NOTE_MARKER);
    if (markerIndex < 0) {
      return {};
    }
    const payload = round.note.slice(markerIndex + BUY_IN_NOTE_MARKER.length);
    try {
      return JSON.parse(payload) as Record<string, number>;
    } catch (error) {
      return {};
    }
  }

  private buyInAdjustmentFromRounds(rounds: RoundRecord[], userId: string): number {
    let total = 0;
    for (let index = 0; index < rounds.length; index++) {
      const round = rounds[index];
      if (!round.isVoided) {
        total += this.buyInAdjustmentAmount(round, userId);
      }
    }
    return total;
  }

  private displayScore(index: number): number {
    return this.displayBalanceFromRounds(this.rounds, this.sessionPlayerId(index));
  }

  private totalBalance(): number {
    let total = 0;
    const playerIds = this.currentPlayerIds();
    for (let index = 0; index < playerIds.length; index++) {
      total += this.scoreOf(playerIds[index]);
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
    for (let index = 0; index < this.users.length; index++) {
      if (this.friendSearchUserVisible(this.users[index])) {
        count += 1;
      }
    }
    for (let index = 0; index < this.sessions.length; index++) {
      if (this.friendSearchSessionVisible(this.sessions[index])) {
        count += 1;
      }
    }
    return count;
  }

  private friendSearchUserVisible(user: User): boolean {
    return user.id !== ledgerRepository.currentUser().id && this.friendSearchMatches(`${user.displayName} ${this.friendOptionSummary(user.id)} ${this.friendTotalScore(user.id)}`);
  }

  private friendSearchSessionVisible(session: GameSession): boolean {
    return this.friendSearchMatches(`${session.title} ${session.status} ${this.sessionPlayerNames(session)} ${this.sessionScoreForCurrent(session)}`);
  }

  private sessionSearchDesc(session: GameSession): string {
    return `${session.status === 'active' ? '进行中' : '历史'} · ${this.sessionPlayerNames(session)}`;
  }

  private friendOptionSummary(userId: string): string {
    let games = 0;
    for (let index = 0; index < this.sessions.length; index++) {
      if (this.sessions[index].playerIds.includes(userId)) {
        games += 1;
      }
    }
    return games > 0 ? `对局 ${games} 次` : '本地牌友';
  }

  private friendGameCount(userId: string): number {
    let count = 0;
    const sessions = this.settledSessions();
    for (let index = 0; index < sessions.length; index++) {
      if (sessions[index].playerIds.includes(userId)) {
        count += 1;
      }
    }
    return count;
  }

  private friendTotalScore(userId: string): number {
    let total = 0;
    const sessions = this.settledSessions();
    for (let index = 0; index < sessions.length; index++) {
      if (sessions[index].playerIds.includes(userId)) {
        total += this.sessionScoreForUser(sessions[index], userId);
      }
    }
    return total;
  }

  private friendWinRateText(userId: string): string {
    const gameCount = this.friendGameCount(userId);
    if (gameCount === 0) {
      return '0%';
    }
    let wins = 0;
    const sessions = this.settledSessions();
    for (let index = 0; index < sessions.length; index++) {
      if (sessions[index].playerIds.includes(userId) && this.sessionScoreForUser(sessions[index], userId) > 0) {
        wins += 1;
      }
    }
    return `${Math.round(wins * 100 / gameCount)}%`;
  }

  private switchTab(index: number): void {
    this.getUIContext().animateTo({ duration: 240, curve: Curve.FastOutSlowIn }, () => {
      this.showSettlement = false;
      this.showCreatePage = false;
      this.showSettlementComplete = false;
      this.showHistoryDetail = false;
      this.friendSearchActive = false;
      this.pressedNavIndex = -1;
      this.currentTab = index;
    });
  }

  private openCreatePage(): void {
    this.prepareNewSessionForm();
    this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
      this.showCreatePage = true;
      this.showSettlement = false;
      this.showSettlementComplete = false;
      this.currentTab = 0;
    });
  }

  private closeCreatePage(): void {
    this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutLinearIn }, () => {
      this.showCreatePage = false;
      this.friendPickerTarget = -1;
      this.activeSheet = 0;
    });
  }

  private openSheet(sheet: number): void {
    if (sheet === 2) {
      this.prepareEditSessionForm();
    }
    this.getUIContext().animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
      this.activeSheet = sheet;
    });
  }

  private openHistorySheet(sessionId: string): void {
    this.historyDetailSessionId = sessionId;
    this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
      this.showHistoryDetail = true;
    });
  }

  private closeSheet(onClosed?: () => void): void {
    this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutLinearIn }, () => {
      this.activeSheet = 0;
    });
    if (onClosed) {
      setTimeout(() => {
        onClosed();
      }, 220);
    }
  }

  private openFriendPicker(target: number): void {
    if (target === 0) {
      return;
    }
    this.friendPickerTarget = target;
    this.openSheet(4);
  }

  private openEntryPlayerPicker(target: number): void {
    if (!this.currentSession()) {
      promptAction.showToast({ message: '请先创建牌局' });
      return;
    }
    this.entryPlayerPickerTarget = target;
    this.openSheet(5);
  }

  private entryPickerTitle(): string {
    if (this.entryPlayerPickerTarget === 0) {
      return '选择赢家';
    }
    if (this.entryPlayerPickerTarget === 1) {
      return '选择付款人';
    }
    return '选择调整对象';
  }

  private selectedEntryPickerPlayerId(): string {
    if (this.entryPlayerPickerTarget === 0) {
      return this.entryDraft.collectorPlayerId;
    }
    if (this.entryPlayerPickerTarget === 1) {
      return this.entryDraft.payerPlayerId;
    }
    if (this.entryPlayerPickerTarget === 2) {
      return this.entryDraft.adjustPlayerId;
    }
    return '';
  }

  private entryPickerUsers(): User[] {
    const users: User[] = [];
    const playerIds = this.currentPlayerIds();
    for (let index = 0; index < playerIds.length; index++) {
      const user = this.userById(playerIds[index]);
      if (user) {
        users.push(user);
      }
    }
    return users;
  }

  private selectEntryPlayer(userId: string): void {
    if (this.entryPlayerPickerTarget === 0) {
      this.entryDraft.collectorPlayerId = userId;
    } else if (this.entryPlayerPickerTarget === 1) {
      this.entryDraft.payerPlayerId = userId;
    } else if (this.entryPlayerPickerTarget === 2) {
      this.entryDraft.adjustPlayerId = userId;
    }
    this.entryDraft.touch();
    this.closeSheet(() => {
      this.entryPlayerPickerTarget = -1;
    });
  }

  private pickerQuery(): string {
    if (this.friendPickerTarget === 0) {
      return this.newPlayer0Name.trim().toLowerCase();
    }
    if (this.friendPickerTarget === 1) {
      return this.newPlayer1Name.trim().toLowerCase();
    }
    if (this.friendPickerTarget === 2) {
      return this.newPlayer2Name.trim().toLowerCase();
    }
    if (this.friendPickerTarget === 3) {
      return this.newPlayer3Name.trim().toLowerCase();
    }
    return '';
  }

  private pickerUserVisible(user: User): boolean {
    if (user.id === ledgerRepository.currentUser().id) {
      return false;
    }
    const query = this.pickerQuery();
    return query.length === 0 || user.displayName.toLowerCase().includes(query);
  }

  private selectablePickerUsers(): User[] {
    return this.users.filter((user: User) => this.pickerUserVisible(user));
  }

  private selectableFriendCount(): number {
    return this.users.filter((user: User) => user.id !== ledgerRepository.currentUser().id).length;
  }

  private selectFriendForNewSession(user: User): void {
    if (this.friendPickerTarget === 1) {
      this.newPlayer1Name = user.displayName;
    } else if (this.friendPickerTarget === 2) {
      this.newPlayer2Name = user.displayName;
    } else if (this.friendPickerTarget === 3) {
      this.newPlayer3Name = user.displayName;
    }
    this.closeSheet();
  }

  private prepareNewSessionForm(): void {
    const defaultTitle = this.sessions.length > 0 ? '今天的牌局' : '今晚南山局';
    this.newSessionTitle = this.newSessionTitle.trim().length > 0 ? this.newSessionTitle : defaultTitle;
    this.newPlayer0Name = ledgerRepository.currentUser().displayName;
    this.newPlayer1Name = '';
    this.newPlayer2Name = '';
    this.newPlayer3Name = '';
    this.newPlayer0BuyIn = '';
    this.newPlayer1BuyIn = '';
    this.newPlayer2BuyIn = '';
    this.newPlayer3BuyIn = '';
  }

  private prepareEditSessionForm(): void {
    const session = this.currentSession();
    if (!session) {
      return;
    }
    this.editSessionTitle = session.title;
    this.editBasePoint = `${session.basePoint}`;
    this.editNote = session.note;
    this.editPlayer0Name = this.sessionPlayerName(0);
    this.editPlayer1Name = this.sessionPlayerName(1);
    this.editPlayer2Name = this.sessionPlayerName(2);
    this.editPlayer3Name = this.sessionPlayerName(3);
    this.editPlayer0BuyIn = `${this.buyInAt(0)}`;
    this.editPlayer1BuyIn = `${this.buyInAt(1)}`;
    this.editPlayer2BuyIn = `${this.buyInAt(2)}`;
    this.editPlayer3BuyIn = `${this.buyInAt(3)}`;
  }

  private syncPlayerNames(names: string[], playerIds?: string[]): void {
    const targetIds = playerIds ? playerIds : this.users.slice(0, names.length).map((item: User) => item.id);
    for (let index = 0; index < names.length && index < targetIds.length; index++) {
      const name = names[index].trim();
      const user = this.userById(targetIds[index]);
      if (name.length > 0 && user && user.displayName !== name) {
        ledgerRepository.updateUser(targetIds[index], name);
      }
    }
    this.users = ledgerRepository.listUsers();
  }

  private normalizePlayerName(name: string): string {
    return name.trim().toLowerCase();
  }

  private resolvePlayerIds(names: string[]): string[] {
    const playerIds: string[] = [];
    const normalizedNames: string[] = [];
    for (let index = 0; index < names.length; index++) {
      const name = names[index].trim();
      if (name.length === 0) {
        promptAction.showToast({ message: '牌友姓名不能为空' });
        return [];
      }
      const normalized = this.normalizePlayerName(name);
      if (normalizedNames.includes(normalized)) {
        promptAction.showToast({ message: '同一场牌局不能重复选择牌友' });
        return [];
      }
      normalizedNames.push(normalized);
      playerIds.push(ledgerRepository.findOrCreateUser(name).id);
    }
    this.users = ledgerRepository.listUsers();
    return playerIds;
  }

  private buildBuyIns(amounts: string[], playerIds: string[]): Record<string, number> {
    const buyIns: Record<string, number> = {};
    for (let index = 0; index < playerIds.length; index++) {
      buyIns[playerIds[index]] = this.parsePositiveAmount(amounts[index], 200);
    }
    return buyIns;
  }

  private validateNewBuyIns(amounts: string[]): boolean {
    for (let index = 0; index < amounts.length; index++) {
      const value = amounts[index].trim();
      if (value.length === 0) {
        promptAction.showToast({ message: `请填写牌友${index + 1}入场金额` });
        return false;
      }
      const amount = Number(value);
      if (Number.isNaN(amount) || amount < 0) {
        promptAction.showToast({ message: '入场金额不能小于 0' });
        return false;
      }
    }
    return true;
  }

  private zeroScores(playerIds: string[]): Record<string, number> {
    const scores: Record<string, number> = {};
    for (let index = 0; index < playerIds.length; index++) {
      scores[playerIds[index]] = 0;
    }
    return scores;
  }

  private cloneBuyIns(source: Record<string, number>, playerIds: string[]): Record<string, number> {
    const buyIns: Record<string, number> = {};
    for (let index = 0; index < playerIds.length; index++) {
      const playerId = playerIds[index];
      buyIns[playerId] = Number(source[playerId] ?? 200);
    }
    return buyIns;
  }

  private buyInChangeNote(playerIds: string[], previousBuyIns: Record<string, number>, nextBuyIns: Record<string, number>): string {
    const changes: string[] = [];
    const deltas: Record<string, number> = {};
    for (let index = 0; index < playerIds.length; index++) {
      const playerId = playerIds[index];
      const previous = Number(previousBuyIns[playerId] ?? 200);
      const next = Number(nextBuyIns[playerId] ?? 200);
      deltas[playerId] = next - previous;
      if (previous !== next) {
        changes.push(`${this.playerNameById(playerId)} ${previous} -> ${next}`);
      }
    }
    return changes.length > 0 ? `入场金额调整：${changes.join('，')}${BUY_IN_NOTE_MARKER}${JSON.stringify(deltas)}` : '';
  }

  private startNewSession(): void {
    const title = this.newSessionTitle.trim().length > 0 ? this.newSessionTitle.trim() : '今天的牌局';
    const playerIds = this.resolvePlayerIds([this.newPlayer0Name, this.newPlayer1Name, this.newPlayer2Name, this.newPlayer3Name]);
    if (playerIds.length !== 4) {
      return;
    }
    const amountDrafts = [this.newPlayer0BuyIn, this.newPlayer1BuyIn, this.newPlayer2BuyIn, this.newPlayer3BuyIn];
    if (!this.validateNewBuyIns(amountDrafts)) {
      return;
    }
    const basePoint = this.parsePositiveAmount(this.basePoint, 10);
    const buyIns = this.buildBuyIns(amountDrafts, playerIds);
    const session = ledgerRepository.createSession(this.selectedGroupId, title, basePoint, '离线隐私模式', playerIds, buyIns);
    this.selectedSessionId = session.id;
    this.refresh();
    this.showCreatePage = false;
    promptAction.showToast({ message: '牌局已创建' });
  }

  private saveCurrentSession(): void {
    const session = this.currentSession();
    if (!session) {
      promptAction.showToast({ message: '请先创建牌局' });
      return;
    }
    const title = this.editSessionTitle.trim().length > 0 ? this.editSessionTitle.trim() : session.title;
    const playerIds = session.playerIds.slice(0, 4);
    this.syncPlayerNames([this.editPlayer0Name, this.editPlayer1Name, this.editPlayer2Name, this.editPlayer3Name], playerIds);
    const previousBuyIns = this.cloneBuyIns(session.buyIns, playerIds);
    const buyIns = this.buildBuyIns([this.editPlayer0BuyIn, this.editPlayer1BuyIn, this.editPlayer2BuyIn, this.editPlayer3BuyIn], playerIds);
    const changeNote = this.buyInChangeNote(playerIds, previousBuyIns, buyIns);
    const updatedSession = ledgerRepository.updateSession(this.selectedGroupId, session.id, title, this.parsePositiveAmount(this.editBasePoint, session.basePoint), this.editNote, playerIds, buyIns);
    if (changeNote.length > 0) {
      ledgerRepository.addRound(this.selectedGroupId, updatedSession.id, this.zeroScores(playerIds), changeNote);
    }
    this.selectedSessionId = updatedSession.id;
    this.refresh();
    this.closeSheet(() => this.refresh());
    promptAction.showToast({ message: '牌局已保存' });
  }

  private recordRound(session: GameSession, scores: Record<string, number>, note: string, successMessage: string): void {
    const result = validateRound(session.playerIds, scores);
    if (!result.valid) {
      promptAction.showToast({ message: result.message });
      return;
    }
    ledgerRepository.addRound(this.selectedGroupId, session.id, scores, note);
    const nextRounds = ledgerRepository.listRounds(session.id);
    const nextSummaries = buildPlayerSummaries(this.users, nextRounds);
    this.rounds = nextRounds;
    this.summaries = nextSummaries;
    this.operations = ledgerRepository.listOperations(this.selectedGroupId);
    this.ledgerViewRevision += 1;
    promptAction.showToast({ message: successMessage });
  }

  private voidRound(round: RoundRecord): void {
    const session = this.sessions.find((item: GameSession) => item.id === round.sessionId);
    if (!session || session.status !== 'active') {
      promptAction.showToast({ message: '已封账流水不能撤回' });
      return;
    }
    if (round.isVoided) {
      return;
    }
    if (this.isBuyInAdjustmentRound(round)) {
      const buyIns = this.cloneBuyIns(session.buyIns, session.playerIds);
      const deltas = this.buyInAdjustmentDeltas(round);
      for (let index = 0; index < session.playerIds.length; index++) {
        const playerId = session.playerIds[index];
        buyIns[playerId] = Number(buyIns[playerId] ?? 200) - Number(deltas[playerId] ?? 0);
      }
      ledgerRepository.updateSession(this.selectedGroupId, session.id, session.title, session.basePoint, session.note, session.playerIds.slice(), buyIns);
    }
    ledgerRepository.voidRound(this.selectedGroupId, round.id);
    this.refresh();
    promptAction.showToast({ message: '流水已撤回' });
  }

  private addSingleCollectorRound(): void {
    const session = this.sessions.find((item: GameSession) => item.id === this.selectedSessionId);
    if (!session) {
      promptAction.showToast({ message: '请先创建牌局' });
      return;
    }
    const loserAmount = Number(this.entryDraft.singleAmount);
    if (Number.isNaN(loserAmount) || loserAmount <= 0) {
      promptAction.showToast({ message: '请输入正确金额' });
      return;
    }
    const playerIds = session.playerIds.slice(0, 4);
    const collectorId = this.entryDraft.collectorPlayerId;
    if (!playerIds.some((item: string) => item === collectorId)) {
      promptAction.showToast({ message: '请选择赢家' });
      return;
    }
    const scores = this.buildSingleIncomeScores(playerIds, collectorId, loserAmount);
    const winnerAmount = loserAmount * (playerIds.length - 1);
    this.recordRound(session, scores, `单家收分：${this.playerNameById(collectorId)} 赢 ${winnerAmount}，每位输分 ${loserAmount}`, '已记一笔');
  }

  private addAAExpenseRound(): void {
    const session = this.currentSession();
    if (!session) {
      promptAction.showToast({ message: '请先创建牌局' });
      return;
    }
    const amount = Number(this.entryDraft.aaAmount);
    if (Number.isNaN(amount) || amount <= 0) {
      promptAction.showToast({ message: '请输入正确金额' });
      return;
    }
    const playerIds = session.playerIds.slice(0, 4);
    const payerId = this.entryDraft.payerPlayerId;
    if (!playerIds.some((item: string) => item === payerId)) {
      promptAction.showToast({ message: '请选择付款人' });
      return;
    }
    const scores = this.buildAAExpenseScores(playerIds, payerId, amount);
    const note = this.entryDraft.aaNote.trim();
    const noteSuffix = note.length > 0 ? ` · ${note}` : '';
    this.recordRound(session, scores, `AA 开销：${this.playerNameById(payerId)} 垫付 ${amount}${noteSuffix}`, 'AA 开销已记入');
  }

  private addAdjustRound(): void {
    const session = this.currentSession();
    if (!session) {
      promptAction.showToast({ message: '请先创建牌局' });
      return;
    }
    const amount = Number(this.entryDraft.adjustAmount);
    if (Number.isNaN(amount)) {
      promptAction.showToast({ message: '请输入正确金额' });
      return;
    }
    if (amount === 0) {
      promptAction.showToast({ message: '调整金额不能为 0' });
      return;
    }
    const playerIds = session.playerIds.slice(0, 4);
    const targetId = this.entryDraft.adjustPlayerId;
    if (!playerIds.some((item: string) => item === targetId)) {
      promptAction.showToast({ message: '请选择调整对象' });
      return;
    }
    const scores = this.buildBalancedAdjustScores(playerIds, targetId, amount);
    const reason = this.entryDraft.adjustReason.trim().length > 0 ? this.entryDraft.adjustReason.trim() : '手动调整';
    this.recordRound(session, scores, `手动调整：${this.playerNameById(targetId)} ${formatMoney(amount)} · ${reason}`, '调整已保存');
  }

  private buildBalancedAdjustScores(playerIds: string[], targetId: string, amount: number): Record<string, number> {
    const scores: Record<string, number> = {};
    scores[targetId] = amount;
    const otherIds = playerIds.filter((item: string) => item !== targetId);
    let assigned = 0;
    const oppositeTotal = -amount;
    for (let index = 0; index < otherIds.length; index++) {
      const average = oppositeTotal / otherIds.length;
      const score = index === otherIds.length - 1 ? oppositeTotal - assigned : (oppositeTotal >= 0 ? Math.floor(average) : Math.ceil(average));
      scores[otherIds[index]] = score;
      assigned += score;
    }
    return scores;
  }

  private syncNow(): void {
    const result = this.syncService.sync(ledgerRepository);
    this.refresh();
    promptAction.showToast({ message: result.message });
  }

  private closeCurrentSession(): void {
    const session = this.currentSession();
    if (!session) {
      promptAction.showToast({ message: '没有进行中的牌局' });
      return;
    }
    this.lastSettledTitle = session.title;
    this.lastSettledWinnerName = this.currentWinnerName();
    this.lastSettledWinnerScore = this.currentWinnerScore();
    this.resetSettlementCompleteMotion();
    ledgerRepository.settleSession(this.selectedGroupId, session.id);
    this.selectedSessionId = '';
    this.refresh();
    this.showSettlement = false;
    this.showSettlementComplete = true;
    this.currentTab = 0;
    promptAction.showToast({ message: '牌局已封账' });
  }

  private returnFromSettlementComplete(): void {
    this.showSettlementComplete = false;
    this.resetSettlementCompleteMotion();
    this.currentTab = 0;
    this.refresh();
  }

  private resetSettlementCompleteMotion(): void {
    this.settlementCompletePlayed = false;
    this.settlementCompleteCardOffset = 28;
    this.settlementCompleteCardOpacity = 0;
    this.settlementCompleteAmount = 0;
  }

  private playSettlementCompleteMotion(): void {
    if (this.settlementCompletePlayed) {
      return;
    }
    this.settlementCompletePlayed = true;
    this.getUIContext().animateTo({ duration: 360, curve: Curve.FastOutSlowIn }, () => {
      this.settlementCompleteCardOffset = 0;
      this.settlementCompleteCardOpacity = 1;
    });
    this.startSettlementAmountCount();
  }

  private startSettlementAmountCount(): void {
    const target = this.lastSettledWinnerScore;
    const steps = 64;
    let step = 0;
    const intervalId = setInterval(() => {
      step += 1;
      const progress = Math.min(step / steps, 1);
      const easedProgress = progress < 0.5 ? 4 * progress * progress * progress : 1 - Math.pow(-2 * progress + 2, 3) / 2;
      this.settlementCompleteAmount = Math.round(target * easedProgress);
      if (step >= steps) {
        this.settlementCompleteAmount = target;
        clearInterval(intervalId);
      }
    }, 16);
  }

  private clearAllData(): void {
    if (!this.confirmClearData) {
      this.confirmClearData = true;
      promptAction.showToast({ message: '再次点击确认清空本地数据' });
      return;
    }
    ledgerRepository.clearAllData();
    this.confirmClearData = false;
    this.selectedGroupId = '';
    this.selectedSessionId = '';
    this.historyDetailSessionId = '';
    this.showSettlement = false;
    this.showCreatePage = false;
    this.showSettlementComplete = false;
    this.showHistoryDetail = false;
    this.currentTab = 0;
    this.refresh();
    promptAction.showToast({ message: '本地数据已清空' });
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

      if (!this.showSettlement && !this.showCreatePage && !this.showSettlementComplete && !this.showHistoryDetail && !this.friendSearchActive) {
        this.GlassNav()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .bindSheet(this.activeSheet > 0, this.ActiveSheet(), {
      height: this.activeSheet === 3 ? SheetSize.MEDIUM : SheetSize.FIT_CONTENT,
      detents: this.activeSheet === 3 ? [SheetSize.MEDIUM, SheetSize.LARGE] : [SheetSize.FIT_CONTENT],
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
        if (this.activeSheet === 5) {
          this.entryPlayerPickerTarget = -1;
        }
        this.activeSheet = 0;
      }
    })
  }

  @Builder
  private Screen() {
    if (!this.showSettlement && !this.showSettlementComplete && !this.showCreatePage && !this.showHistoryDetail && !(this.currentTab === 2 && this.friendSearchActive)) {
      this.MainTabSwiper()
    } else {
      this.DetailScreen()
    }
  }

  @Builder
  private DetailScreen() {
    Scroll() {
      Column({ space: 18 }) {
        if (this.showSettlement) {
          this.SettlementPage()
        } else if (this.showSettlementComplete) {
          this.SettlementCompletePage()
        } else if (this.showCreatePage) {
          this.CreateGamePage()
        } else if (this.showHistoryDetail) {
          this.HistoryDetailPage()
        } else if (this.currentTab === 2 && this.friendSearchActive) {
          this.FriendSearchPage()
        }
      }
      .padding({ left: 20, right: 20, top: 26, bottom: (this.showSettlement || this.showCreatePage || this.showSettlementComplete || this.showHistoryDetail) ? 30 : 118 })
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
  private MainTabSwiper() {
    Swiper() {
      this.MainTabPage(0)
      this.MainTabPage(1)
      this.MainTabPage(2)
      this.MainTabPage(3)
    }
    .index(this.currentTab)
    .indicator(false)
    .loop(false)
    .duration(260)
    .curve(Curve.FastOutSlowIn)
    .onChange((index: number) => {
      this.currentTab = index;
    })
    .width('100%')
    .height('100%')
  }

  @Builder
  private MainTabPage(index: number) {
    Scroll() {
      Column({ space: 18 }) {
        this.PageHeaderFor(index)
        if (index === 0) {
          this.GamePage()
        } else if (index === 1) {
          this.StatsPage()
        } else if (index === 2) {
          this.FriendsPage()
        } else {
          this.MinePage()
        }
      }
      .padding({ left: 20, right: 20, top: 26, bottom: 118 })
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
    this.PageHeaderFor(this.currentTab)
  }

  @Builder
  private PageHeaderFor(index: number) {
    Row() {
      Column() {
        Text(this.pageTitleFor(index))
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

  private pageTitle(): string {
    return this.pageTitleFor(this.currentTab);
  }

  private pageTitleFor(index: number): string {
    if (index === 0) {
      return this.currentSessionTitle();
    }
    if (index === 1) {
      return '统计';
    }
    if (index === 2) {
      return '牌友';
    }
    return '我的';
  }

  @Builder
  private BackButton(onTap: () => void) {
    Button('<')
      .width(44)
      .height(44)
      .borderRadius(22)
      .fontSize(24)
      .fontWeight(FontWeight.Bold)
      .fontColor(TEXT_MAIN)
      .backgroundColor('#70FFFFFF')
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
      .border({ width: 1, color: '#D8FFFFFF' })
      .shadow({ radius: 12, color: '#10000000', offsetY: 5 })
      .stateEffect(true)
      .scale(this.pressableControlScale('back-button'))
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })
      .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'back-button'))
      .onClick(onTap)
  }

  @Builder
  private CreateGamePage() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        this.BackButton(() => this.closeCreatePage())
        Text('新建牌局')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
      }
      .width('100%')

      Column({ space: 6 }) {
        Text('先把这场局搭起来')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text('填写牌局名称、四位牌友和入场金额后，就可以开始记账。')
          .fontSize(13)
          .fontColor(TEXT_SECOND)
          .lineHeight(20)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(18)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Column({ space: 12 }) {
        this.SectionTitle('牌局信息', '')
        this.UnlabeledFullField(this.newSessionTitle, (value: string) => this.newSessionTitle = value)
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Column({ space: 10 }) {
        this.SectionTitle('牌友和入场金额', '4 人')
        this.CreateFixedPlayerRow('牌友1', this.newPlayer0Name, this.newPlayer0BuyIn, (value: string) => this.newPlayer0BuyIn = value)
        this.CreatePlayerInputRow('牌友2', this.newPlayer1Name, this.newPlayer1BuyIn, (value: string) => this.newPlayer1Name = value, (value: string) => this.newPlayer1BuyIn = value, () => this.openFriendPicker(1))
        this.CreatePlayerInputRow('牌友3', this.newPlayer2Name, this.newPlayer2BuyIn, (value: string) => this.newPlayer2Name = value, (value: string) => this.newPlayer2BuyIn = value, () => this.openFriendPicker(2))
        this.CreatePlayerInputRow('牌友4', this.newPlayer3Name, this.newPlayer3BuyIn, (value: string) => this.newPlayer3Name = value, (value: string) => this.newPlayer3BuyIn = value, () => this.openFriendPicker(3))
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Button('开始记账')
        .height(50)
        .width('100%')
        .borderRadius(16)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .shadow({ radius: 16, color: '#522F63F4', offsetY: 8 })
        .stateEffect(true)
        .scale(this.pressableControlScale('create-page-start'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'create-page-start'))
        .onClick(() => this.startNewSession())
    }
    .width('100%')
  }

  @Builder
  private SettlementCompletePage() {
    Column({ space: 28 }) {
      Column() {
        Column({ space: 12 }) {
          Text('封账完成')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(BLUE)
          Text(`恭喜${this.lastSettledWinnerName}成为${this.lastSettledTitle}大赢家`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .textAlign(TextAlign.Center)
          Text(formatMoney(this.settlementCompleteAmount))
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.lastSettledWinnerScore >= 0 ? GREEN : RED)
          Text('本场牌局已归档，统计和历史已更新')
            .fontSize(13)
            .fontColor(TEXT_SECOND)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 26, bottom: 26 })
        .borderRadius(24)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(CARD_BG)
        .shadow({ radius: 22, color: '#14000000', offsetY: 10 })
        .opacity(this.settlementCompleteCardOpacity)
        .translate({ y: this.settlementCompleteCardOffset })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Button('返回牌局')
        .height(50)
        .width('100%')
        .borderRadius(16)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .scale(this.pressableControlScale('settlement-complete-return'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'settlement-complete-return'))
        .onClick(() => this.returnFromSettlementComplete())
    }
    .width('100%')
    .height('92%')
    .padding({ top: 60, bottom: 20 })
    .onAppear(() => this.playSettlementCompleteMotion())
  }

  @Builder
  private HistoryDetailPage() {
    if (this.historyDetailSession()) {
      Column({ space: 16 }) {
        Row({ space: 10 }) {
          this.BackButton(() => this.showHistoryDetail = false)
          Text((this.historyDetailSession() as GameSession).title)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .layoutWeight(1)
        }
        .width('100%')
        this.HistoryDetailContent(this.historyDetailSession() as GameSession)
      }
    } else {
      Text('暂无牌局详情')
        .fontSize(18)
        .fontColor(TEXT_SECOND)
    }
  }

  @Builder
  private GamePage() {
    if (this.ledgerViewRevision % 2 === 0) {
      this.GamePageContent()
    } else {
      this.GamePageContent()
    }
  }

  @Builder
  private GamePageContent() {
    if (!this.currentSession()) {
      this.EmptyGameCard()
    } else {
      Column({ space: 16 }) {
        this.GameSetupCard()
        this.BalanceBoard()
        this.EntryPanel()
        this.CashflowHistory()
      }
    }
  }

  @Builder
  private EmptyGameCard() {
    Column({ space: 14 }) {
      Text('+')
        .width(54)
        .height(54)
        .fontSize(30)
        .fontColor(BLUE)
        .textAlign(TextAlign.Center)
        .borderRadius(27)
        .backgroundColor(BLUE_SOFT)
      Text('点击此处开启一场牌局吧')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Text('设置牌友和入场金额后，就可以开始记录输赢、开销和调整。')
        .fontSize(13)
        .fontColor(TEXT_SECOND)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(210)
    .padding(20)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(24)
    .backgroundColor(CARD_BG)
    .scale(this.pressableCardScale('empty-game'))
    .shadow({ radius: this.pressedCardKey === 'empty-game' ? 10 : 18, color: '#10000000', offsetY: this.pressedCardKey === 'empty-game' ? 4 : 8 })
    .animation({ duration: 160, curve: Curve.FastOutSlowIn })
    .onTouch((event: TouchEvent) => this.handlePressableCardTouch(event, 'empty-game'))
    .onClick(() => this.openCreatePage())
  }

  @Builder
  private GameSetupCard() {
    Column({ space: 12 }) {
      this.SectionTitle('参与人和入场金额', '')
      Row({ space: 8 }) {
        this.PlayerChip(this.sessionPlayerName(0), `${this.buyInAt(0)}`)
        this.PlayerChip(this.sessionPlayerName(1), `${this.buyInAt(1)}`)
        this.PlayerChip(this.sessionPlayerName(2), `${this.buyInAt(2)}`)
        this.PlayerChip(this.sessionPlayerName(3), `${this.buyInAt(3)}`)
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
          .scale(this.pressableControlScale('game-setup-edit'))
          .animation({ duration: 150, curve: Curve.FastOutSlowIn })
          .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'game-setup-edit'))
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
          .scale(this.pressableControlScale('game-setup-settle'))
          .animation({ duration: 150, curve: Curve.FastOutSlowIn })
          .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'game-setup-settle'))
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
      this.SectionTitle('当前账面', `总入场 ${this.totalBuyIn()}`)
      Grid() {
        GridItem() { this.BalanceCell(this.sessionPlayerName(0), this.displayScore(0)) }
        GridItem() { this.BalanceCell(this.sessionPlayerName(1), this.displayScore(1)) }
        GridItem() { this.BalanceCell(this.sessionPlayerName(2), this.displayScore(2)) }
        GridItem() { this.BalanceCell(this.sessionPlayerName(3), this.displayScore(3)) }
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

      if (this.entryDraft.mode === 0) {
        this.SingleIncomeCard()
      } else if (this.entryDraft.mode === 1) {
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
      .fontColor(this.entryDraft.mode === index ? BLUE : TEXT_SECOND)
      .backgroundColor(this.entryDraft.mode === index ? CARD_BG : '#00000000')
      .shadow(this.entryDraft.mode === index ? { radius: 8, color: '#12000000', offsetY: 2 } : { radius: 0, color: '#00000000' })
      .stateEffect(true)
      .scale(this.pressableControlScale(`entry-mode-${index}`))
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })
      .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `entry-mode-${index}`))
      .onClick(() => this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutSlowIn }, () => {
        this.entryDraft.mode = index;
        this.entryDraft.touch();
      }))
  }

  @Builder
  private SingleIncomeCard() {
    Column({ space: 12 }) {
      this.ModeCardHeader('单家收分', '选择赢家，再填写每位输家需要扣除的分数')
      Column({ space: 6 }) {
        Text('赢家')
          .fontSize(12)
          .fontColor(TEXT_SECOND)
        Row({ space: 8 }) {
          ForEach(this.currentPlayerIds(), (playerId: string) => {
            this.WinnerOption(playerId)
          }, (playerId: string) => playerId)
        }
      }
      EntryAmountTextField({ label: '每位输分', placeholder: '输入每位输分', target: 0, draft: this.entryDraft })
      Button('记一笔')
        .height(44)
        .width('100%')
        .borderRadius(14)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .stateEffect(true)
        .scale(this.pressableControlScale('single-income-save'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'single-income-save'))
        .onClick(() => this.addSingleCollectorRound())
    }
  }

  @Builder
  private AAExpenseCard() {
    Column({ space: 12 }) {
      this.ModeCardHeader('AA 开销', '茶水、包间、外卖等共同支出，选择付款人后自动分摊')
      Row({ space: 10 }) {
        this.SelectLikeField('付款人', () => this.entryPlayerFieldText(this.entryDraft.payerPlayerId), () => this.entryDraft.payerPlayerId.length === 0, () => {
          this.openEntryPlayerPicker(1);
        })
        Column() {
          EntryAmountTextField({ label: '总金额', placeholder: '输入金额', target: 1, draft: this.entryDraft })
        }
        .layoutWeight(1)
      }
      this.FullField('备注', this.entryDraft.aaNote, (value: string) => {
        this.entryDraft.aaNote = value;
        this.entryDraft.touch();
      })
      Button('平摊记账')
        .height(44)
        .width('100%')
        .borderRadius(14)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .stateEffect(true)
        .scale(this.pressableControlScale('aa-expense-save'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'aa-expense-save'))
        .onClick(() => this.addAAExpenseRound())
    }
  }

  @Builder
  private ManualAdjustCard() {
    Column({ space: 12 }) {
      this.ModeCardHeader('手动调整', '用于修正录错、补录或特殊约定，流水中会保留调整原因')
      Row({ space: 10 }) {
        this.SelectLikeField('调整对象', () => this.entryPlayerFieldText(this.entryDraft.adjustPlayerId), () => this.entryDraft.adjustPlayerId.length === 0, () => {
          this.openEntryPlayerPicker(2);
        })
        Column() {
          EntryAmountTextField({ label: '调整金额', placeholder: '输入金额', target: 2, draft: this.entryDraft })
        }
        .layoutWeight(1)
      }
      this.FullField('原因', this.entryDraft.adjustReason, (value: string) => {
        this.entryDraft.adjustReason = value;
        this.entryDraft.touch();
      })
      Button('保存调整')
        .height(44)
        .width('100%')
        .borderRadius(14)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .stateEffect(true)
        .scale(this.pressableControlScale('manual-adjust-save'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'manual-adjust-save'))
        .onClick(() => this.addAdjustRound())
    }
  }

  @Builder
  private WinnerOption(playerId: string) {
    Button(this.playerNameById(playerId))
      .height(36)
      .layoutWeight(1)
      .borderRadius(14)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.entryDraft.collectorPlayerId === playerId ? '#FFFFFF' : TEXT_MAIN)
      .backgroundColor(this.entryDraft.collectorPlayerId === playerId ? BLUE : SOFT_BG)
      .stateEffect(true)
      .scale(this.pressableControlScale(`winner-${playerId}`))
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })
      .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `winner-${playerId}`))
      .onClick(() => {
        this.entryDraft.collectorPlayerId = playerId;
        this.entryDraft.touch();
      })
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
  private SelectLikeField(label: string, value: () => string, isPlaceholder: () => boolean, onTap: () => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      Row() {
        Text(value())
          .fontSize(15)
          .fontColor(isPlaceholder() ? TEXT_SECOND : TEXT_MAIN)
          .layoutWeight(1)
      }
        .height(40)
        .padding({ left: 12, right: 12 })
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
        .scale(this.pressableControlScale(`select-field-${label}`))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `select-field-${label}`))
        .onClick(onTap)
    }
    .layoutWeight(1)
  }

  @Builder
  private FullField(label: string, value: string, onChange: (value: string) => void) {
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
  }

  @Builder
  private CashflowHistory() {
    Column({ space: 12 }) {
      Row() {
        Text('进出账历史')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .layoutWeight(1)
        Button(this.cashflowFilterText())
          .height(30)
          .padding({ left: 12, right: 12 })
          .borderRadius(15)
          .fontSize(13)
          .fontColor(BLUE)
          .backgroundColor(BLUE_SOFT)
          .stateEffect(true)
          .scale(this.pressableControlScale('cashflow-filter'))
          .animation({ duration: 150, curve: Curve.FastOutSlowIn })
          .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'cashflow-filter'))
          .onClick(() => this.cycleCashflowFilter())
      }
      .width('100%')
      if (this.visibleRounds().length === 0) {
        Text('暂无符合筛选条件的流水')
          .height(56)
          .fontSize(13)
          .fontColor(TEXT_SECOND)
      } else {
        List() {
          ForEach(this.visibleRounds().slice(0, 8), (round: RoundRecord) => {
            this.CashflowRecordListItem(round, true)
          }, (round: RoundRecord) => round.id)
        }
        .height(this.visibleRoundListHeight())
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private CashflowRecordRow(round: RoundRecord) {
    this.CashflowRow(this.roundTitle(round), this.roundDetail(round), formatMoney(this.roundDisplayAmount(round)), this.roundDisplayAmount(round) >= 0)
  }

  @Builder
  private CashflowRecordListItem(round: RoundRecord, canDelete: boolean) {
    if (canDelete) {
      ListItem() {
        this.CashflowRecordRow(round)
      }
      .transition({ type: TransitionType.Delete, opacity: 0 })
      .swipeAction({
        end: {
          builder: () => {
            this.DeleteRoundSwipeAction(round)
          },
          actionAreaDistance: 72
        },
        edgeEffect: SwipeEdgeEffect.Spring
      })
    } else {
      ListItem() {
        this.CashflowRecordRow(round)
      }
    }
  }

  @Builder
  private UnlabeledFullField(value: string, onChange: (value: string) => void) {
    TextInput({ text: value })
      .height(40)
      .fontSize(15)
      .fontColor(TEXT_MAIN)
      .borderRadius(13)
      .backgroundColor('#F8F6F2')
      .onChange(onChange)
  }

  @Builder
  private DeleteRoundSwipeAction(round: RoundRecord) {
    Row() {
      Button() {
        Column({ space: 2 }) {
          Row()
            .width(16)
            .height(3)
            .borderRadius(2)
            .backgroundColor('#FFFFFF')
          Row()
            .width(20)
            .height(18)
            .border({ width: 2, color: '#FFFFFF' })
            .borderRadius(4)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(RED)
      .stateEffect(true)
      .scale(this.pressableControlScale(`delete-round-${round.id}`))
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })
      .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `delete-round-${round.id}`))
      .onClick(() => this.voidRound(round))
    }
    .width(72)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF0EE')
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
        this.BackButton(() => this.showSettlement = false)
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
        Text(this.currentWinnerName())
          .fontSize(25)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(formatMoney(this.currentWinnerScore()))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.currentWinnerScore() >= 0 ? GREEN : RED)
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
        if (this.settlementRows().length === 0) {
          Text('当前账面已结清')
            .height(54)
            .fontSize(14)
            .fontColor(TEXT_SECOND)
            .width('100%')
            .textAlign(TextAlign.Center)
        } else {
          ForEach(this.settlementRows(), (row: string) => {
            this.PayableRow(this.settlementRowName(row), this.settlementRowDesc(row), this.settlementRowAmount(row))
          }, (row: string) => row)
        }
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)

      this.SettlementTransferCard()

      Row({ space: 12 }) {
        Button('封账')
          .height(48)
          .layoutWeight(1)
          .borderRadius(16)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .backgroundColor(SOFT_BG)
          .stateEffect(true)
          .scale(this.pressableControlScale('settlement-close'))
          .animation({ duration: 150, curve: Curve.FastOutSlowIn })
          .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'settlement-close'))
          .onClick(() => this.closeCurrentSession())
        Button('返回牌局')
          .height(48)
          .layoutWeight(1)
          .borderRadius(16)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(BLUE)
          .stateEffect(true)
          .scale(this.pressableControlScale('settlement-return'))
          .animation({ duration: 150, curve: Curve.FastOutSlowIn })
          .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'settlement-return'))
          .onClick(() => this.showSettlement = false)
      }
    }
  }

  @Builder
  private SettlementSummary() {
    Column({ space: 12 }) {
      this.SectionTitle('整场统计', `${this.sessionPlayerCount()} 人 · ${this.currentRoundCount()} 笔`)
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.SummaryMini('总入场', `${this.totalBuyIn()}`)
          this.SummaryMini('流水', `${this.currentRoundCount()} 笔`)
        }
        .width('100%')
        Row({ space: 10 }) {
          this.SummaryMini('AA 开销', `${this.aaExpenseTotal()}`)
          this.SummaryMini('调整', `${this.adjustCount()} 笔`)
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
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
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
    .backgroundColor('#FBFAF7')
  }

  @Builder
  private PayableRow(title: string, desc: string, amount: number) {
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
      Text(formatMoney(amount))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(amount > 0 ? GREEN : (amount < 0 ? RED : TEXT_SECOND))
    }
    .height(58)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private SettlementTransferCard() {
    Column({ space: 12 }) {
      this.SectionTitle('最佳转账路径', `${this.settlementTransferRows().length} 步`)
      if (this.settlementTransferRows().length === 0) {
        Text('无需转账，当前账面已结清')
          .height(54)
          .fontSize(14)
          .fontColor(TEXT_SECOND)
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.settlementTransferRows(), (row: string) => {
          this.TransferPathRow(this.settlementTransferTitle(row), this.settlementTransferDesc(row), this.settlementTransferAmount(row))
        }, (row: string) => row)
      }
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
  }

  @Builder
  private TransferPathRow(title: string, desc: string, amount: string) {
    Row({ space: 12 }) {
      Text('转')
        .width(34)
        .height(34)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(BLUE)
        .textAlign(TextAlign.Center)
        .borderRadius(17)
        .backgroundColor(BLUE_SOFT)
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
        .fontColor(BLUE)
    }
    .height(58)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private StatsPage() {
    Column({ space: 16 }) {
      Row({ space: 4 }) {
        this.StatsSegment('全部', 0)
        this.StatsSegment('历史牌局', 3)
      }
      .height(42)
      .width('100%')
      .padding(4)
      .borderRadius(18)
      .backgroundColor(SOFT_BG)

      if (this.visibleStatsMode() === 3) {
        this.HistorySessions()
      } else {
        this.StatsSummary(0)
        this.LatestClosedGameCard(0)
        this.TrendCard('整体走势', this.statsScopeText(0), 0)
        this.PartnerRankCard('胜率最高牌友', 0)
      }
    }
  }

  private visibleStatsMode(): number {
    return this.statsMode === 3 ? 3 : 0;
  }

  private statsScopeText(scope: number): string {
    return '全部';
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
      .fontColor(this.visibleStatsMode() === index ? BLUE : TEXT_MAIN)
      .backgroundColor(this.visibleStatsMode() === index ? CARD_BG : '#00000000')
      .shadow(this.visibleStatsMode() === index ? { radius: 8, color: '#12000000', offsetY: 2 } : { radius: 0, color: '#00000000' })
      .stateEffect(true)
      .scale(this.pressableControlScale(`stats-segment-${index}`))
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })
      .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `stats-segment-${index}`))
      .onClick(() => this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutSlowIn }, () => this.statsMode = index))
  }

  @Builder
  private StatsSummary(scope: number = 0) {
    Row() {
      this.SummaryCell('总输赢', formatMoney(this.closedCurrentTotal(scope)), '元', this.closedCurrentTotal(scope) >= 0 ? GREEN : RED)
      this.VerticalDivider()
      this.SummaryCell('胜率', this.closedWinRateText(scope), '', GREEN)
      this.VerticalDivider()
      this.SummaryCell('牌局数', `${this.closedGameCount(scope)}`, '局', TEXT_MAIN)
    }
    .height(112)
    .padding({ left: 18, right: 18 })
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#12000000', offsetY: 8 })
  }

  @Builder
  private SummaryCell(label: string, value: string, unit: string, color: string) {
    Column({ space: 4 }) {
      Text(label)
        .height(18)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      Text(value)
        .height(30)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .textAlign(TextAlign.Center)
      Text(unit)
        .height(16)
        .fontSize(11)
        .fontColor(TEXT_SECOND)
        .textAlign(TextAlign.Center)
    }
    .height(72)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
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
  private TrendCard(title: string, range: string, scope: number = 0) {
    Column({ space: 18 }) {
      this.SectionTitle(title, range)
      if (this.trendPointIndexes(scope).length === 0) {
        this.StatsEmptyState('暂无走势数据', '封账后会按每局输赢生成折线')
      } else {
        Stack() {
          Path({ commands: this.trendPathCommands(scope) })
            .width(280)
            .height(132)
            .fill('#00000000')
            .stroke(BLUE)
            .strokeWidth(4)
          ForEach(this.trendPointIndexes(scope), (item: string) => {
            this.TrendPoint(Number(item), scope)
          }, (item: string) => item)
          ForEach(this.trendPointIndexes(scope), (item: string) => {
            this.TrendDateLabel(Number(item), scope)
          }, (item: string) => `date-${item}`)
        }
        .width('100%')
        .height(158)
        .backgroundColor('#FBFAF7')
        .borderRadius(18)
      }
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private TrendPoint(index: number, scope: number = 0) {
    Column()
      .width(9)
      .height(9)
      .borderRadius(5)
      .backgroundColor(BLUE)
      .border({ width: 2, color: CARD_BG })
      .position({ x: this.trendPointX(index, scope) - 4, y: this.trendPointY(index, scope) - 4 })
  }

  @Builder
  private TrendDateLabel(index: number, scope: number = 0) {
    Text(this.trendDateTextAt(index, scope))
      .width(42)
      .fontSize(10)
      .fontColor(TEXT_SECOND)
      .textAlign(TextAlign.Center)
      .position({ x: this.trendPointX(index, scope) - 21, y: 126 })
  }

  @Builder
  private PartnerRankCard(title: string, scope: number = 0) {
    Column({ space: 14 }) {
      this.SectionTitle(title, '')
      if (this.partnerRankRowsForScope(scope).length === 0) {
        this.StatsEmptyState('暂无牌友排行', '封账后会按同桌胜率生成排行')
      } else {
        ForEach(this.partnerRankRowsForScope(scope).slice(0, 3), (row: string) => {
          this.RankRow(`${this.partnerRankRowsForScope(scope).indexOf(row) + 1}`, row)
        }, (row: string) => row)
      }
    }
    .padding(16)
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private StatsEmptyState(title: string, desc: string) {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Text(desc)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
    }
    .width('100%')
    .height(118)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(18)
    .backgroundColor('#FBFAF7')
  }

  @Builder
  private RankRow(rank: string, row: string) {
    Row({ space: 10 }) {
      Text(rank)
        .width(18)
        .fontSize(14)
        .fontColor(TEXT_SECOND)
      Text(this.rankName(row).substring(0, 1))
        .width(28)
        .height(28)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .borderRadius(14)
        .backgroundColor(this.rankAvatarColor(row))
      Column({ space: 3 }) {
        Text(this.rankName(row))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(`同桌 ${this.rankGames(row)} 次`)
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(this.rankRate(row))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(GREEN)
      Text(formatMoney(this.rankAmount(row)))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.rankAmount(row) >= 0 ? GREEN : RED)
    }
    .height(44)
  }

  @Builder
  private HistorySessions() {
    Column({ space: 12 }) {
      if (this.settledSessions().length === 0) {
        Text('暂无已封账牌局')
          .height(56)
          .fontSize(13)
          .fontColor(TEXT_SECOND)
          .width('100%')
          .textAlign(TextAlign.Center)
          .borderRadius(22)
          .backgroundColor(CARD_BG)
      } else {
        ForEach(this.settledSessions().slice(0, 5), (session: GameSession) => {
          this.HistoryCard(session)
        }, (session: GameSession) => session.id)
      }
    }
    .width('100%')
  }

  @Builder
  private HistoryCard(session: GameSession) {
    Column({ space: 10 }) {
      Row() {
        Text(session.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .layoutWeight(1)
        Text(this.sessionDateText(session))
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      Row({ space: 10 }) {
        this.HistoryCardResult('赢家', this.sessionWinnerSummary(session), GREEN)
        this.HistoryCardResult('输家', this.sessionLoserSummary(session), RED)
      }
      .width('100%')
      Text(`${session.playerIds.length} 人 · ${this.sessionPlayerNames(session)}`)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
        .textAlign(TextAlign.Center)
        .width('100%')
      Text(`入场 ${this.sessionBuyInTotal(session)} · ${this.sessionBuyInSummary(session)}`)
        .fontSize(13)
        .fontColor(TEXT_SECOND)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(22)
    .backgroundColor('#F4F7FD')
    .scale(this.pressableCardScale(`history-${session.id}`))
    .animation({ duration: 160, curve: Curve.FastOutSlowIn })
    .onTouch((event: TouchEvent) => this.handlePressableCardTouch(event, `history-${session.id}`))
    .onClick(() => this.openHistorySheet(session.id))
  }

  @Builder
  private HistoryCardResult(label: string, value: string, color: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor(TEXT_SECOND)
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
    }
    .height(52)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(14)
    .backgroundColor('#FBFAF7')
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
      .scale(this.pressableControlScale('friends-search-open'))
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })
      .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'friends-search-open'))
      .onClick(() => this.openFriendSearch())

      if (this.selectableFriendCount() === 0) {
        this.FriendListEmptyState()
      } else {
        Column({ space: 0 }) {
          ForEach(this.users, (user: User) => {
            if (user.id !== ledgerRepository.currentUser().id) {
              this.FriendRow(user.displayName.substring(0, 1), user.displayName, `对局 ${this.friendGameCount(user.id)} 次 · 同桌胜率 ${this.friendWinRateText(user.id)}`, formatMoney(this.friendTotalScore(user.id)), this.friendTotalScore(user.id) >= 0 ? GREEN : RED, BLUE_SOFT, BLUE)
            }
          }, (user: User) => user.id)
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
        .borderRadius(22)
        .backgroundColor(CARD_BG)
        .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
      }
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
              .scale(this.pressableControlScale('friend-search-clear'))
              .animation({ duration: 150, curve: Curve.FastOutSlowIn })
              .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'friend-search-clear'))
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
          .scale(this.pressableControlScale('friend-search-cancel'))
          .animation({ duration: 150, curve: Curve.FastOutSlowIn })
          .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'friend-search-cancel'))
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
      this.SearchEmptyState()
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
          ForEach(this.users, (user: User) => {
            if (this.friendSearchUserVisible(user)) {
              this.FriendSearchResultRow(user.displayName.substring(0, 1), user.displayName, `对局 ${this.friendGameCount(user.id)} 次 · 同桌胜率 ${this.friendWinRateText(user.id)}`, formatMoney(this.friendTotalScore(user.id)), this.friendTotalScore(user.id) >= 0 ? GREEN : RED, BLUE_SOFT, BLUE)
            }
          }, (user: User) => user.id)
          ForEach(this.sessions, (session: GameSession) => {
            if (this.friendSearchSessionVisible(session)) {
              this.GameSearchResultRow(session.title, this.sessionSearchDesc(session), formatMoney(this.sessionScoreForCurrent(session)), this.sessionScoreForCurrent(session) >= 0 ? GREEN : RED)
            }
          }, (session: GameSession) => session.id)
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
      .scale(this.pressableControlScale(`search-suggestion-${label}`))
      .animation({ duration: 150, curve: Curve.FastOutSlowIn })
      .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `search-suggestion-${label}`))
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
  private FriendListEmptyState() {
    Column({ space: 8 }) {
      Text('暂无牌友')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      Text('新建牌局时填写或选择牌友后，会在这里显示。')
        .fontSize(13)
        .fontColor(TEXT_SECOND)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(132)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 18, right: 18 })
    .borderRadius(22)
    .backgroundColor(CARD_BG)
    .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
  }

  @Builder
  private MinePage() {
    Column({ space: 18 }) {
      Column({ space: 12 }) {
        Text(`已封账 ${this.closedGameCount()} 局`)
          .width('100%')
          .fontSize(13)
          .fontColor(TEXT_SECOND)
          .textAlign(TextAlign.End)
        Grid() {
          GridItem() { this.MineStatCell('总输赢', formatMoney(this.closedCurrentTotal()), this.closedCurrentTotal() >= 0 ? GREEN : RED) }
          GridItem() { this.MineStatCell('胜率', this.closedWinRateText(), TEXT_MAIN) }
          GridItem() { this.MineStatCell('总牌局', `${this.closedGameCount()}`, TEXT_MAIN) }
          GridItem() { this.MineStatCell('最大单局', formatMoney(this.maxClosedWin()), this.maxClosedWin() >= 0 ? GREEN : RED) }
          GridItem() { this.MineStatCell('平均时长', this.averageClosedDurationText(), TEXT_MAIN) }
          GridItem() { this.MineStatCell('同桌牌友', `${this.distinctClosedPartners()}`, TEXT_MAIN) }
        }
        .columnsTemplate('1fr 1fr')
        .rowsGap(10)
        .columnsGap(10)
      }
      .padding(16)
      .width('100%')
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Column({ space: 0 }) {
        this.SettingRow('关于', 'v0.1')
      }
      .padding({ left: 16, right: 12 })
      .width('100%')
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Button(this.confirmClearData ? '再次点击确认清空所有数据' : '清空所有数据')
        .height(52)
        .width('100%')
        .borderRadius(18)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(RED)
        .backgroundColor('#FFF0EE')
        .stateEffect(true)
        .scale(this.pressableControlScale('mine-clear-data'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'mine-clear-data'))
        .onClick(() => this.clearAllData())
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private MineStatCell(label: string, value: string, color: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
    }
    .width('100%')
    .height(76)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
    .backgroundColor('#F8FAFF')
  }

  @Builder
  private SettingRow(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(TEXT_MAIN)
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(12)
          .fontColor('#A6ABB2')
      }
    }
    .height(56)
    .border({ width: { bottom: 1 }, color: LINE })
  }

  @Builder
  private ActiveSheet() {
    if (this.activeSheet === 1) {
      this.CreateGameSheet()
    } else if (this.activeSheet === 2) {
      this.EditGameSheet()
    } else if (this.activeSheet === 3) {
      this.HistoryDetailSheet()
    } else if (this.activeSheet === 4) {
      this.FriendSelectSheet()
    } else if (this.activeSheet === 5) {
      this.EntryPlayerSelectSheet()
    } else {
      Column()
        .height(1)
        .width('100%')
    }
  }

  @Builder
  private CreateGameSheet() {
    Column({ space: 18 }) {
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
        this.CreateFixedPlayerRow('牌友1', this.newPlayer0Name, this.newPlayer0BuyIn, (value: string) => this.newPlayer0BuyIn = value)
        this.CreatePlayerInputRow('牌友2', this.newPlayer1Name, this.newPlayer1BuyIn, (value: string) => this.newPlayer1Name = value, (value: string) => this.newPlayer1BuyIn = value, () => this.openFriendPicker(1))
        this.CreatePlayerInputRow('牌友3', this.newPlayer2Name, this.newPlayer2BuyIn, (value: string) => this.newPlayer2Name = value, (value: string) => this.newPlayer2BuyIn = value, () => this.openFriendPicker(2))
        this.CreatePlayerInputRow('牌友4', this.newPlayer3Name, this.newPlayer3BuyIn, (value: string) => this.newPlayer3Name = value, (value: string) => this.newPlayer3BuyIn = value, () => this.openFriendPicker(3))
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
        .scale(this.pressableControlScale('sheet-create-start'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'sheet-create-start'))
        .onClick(() => this.startNewSession())
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 34 })
  }

  @Builder
  private EditGameSheet() {
    Column({ space: 16 }) {
      Text('编辑牌局')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
      this.FullField('牌局名称', this.editSessionTitle, (value: string) => this.editSessionTitle = value)
      Column({ space: 10 }) {
        Text('参与人和入场金额')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        this.EditablePlayerRow(this.editPlayer0Name, this.editPlayer0BuyIn, (value: string) => this.editPlayer0Name = value, (value: string) => this.editPlayer0BuyIn = value)
        this.EditablePlayerRow(this.editPlayer1Name, this.editPlayer1BuyIn, (value: string) => this.editPlayer1Name = value, (value: string) => this.editPlayer1BuyIn = value)
        this.EditablePlayerRow(this.editPlayer2Name, this.editPlayer2BuyIn, (value: string) => this.editPlayer2Name = value, (value: string) => this.editPlayer2BuyIn = value)
        this.EditablePlayerRow(this.editPlayer3Name, this.editPlayer3BuyIn, (value: string) => this.editPlayer3Name = value, (value: string) => this.editPlayer3BuyIn = value)
      }
      Button('保存')
        .height(50)
        .width('100%')
        .borderRadius(14)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(BLUE)
        .stateEffect(true)
        .scale(this.pressableControlScale('sheet-edit-save'))
        .animation({ duration: 150, curve: Curve.FastOutSlowIn })
        .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, 'sheet-edit-save'))
        .onClick(() => this.saveCurrentSession())
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 34 })
  }

  @Builder
  private HistoryDetailSheet() {
    if (this.historyDetailSession()) {
      this.HistoryDetailContent(this.historyDetailSession() as GameSession)
    } else {
      Text('暂无牌局详情')
        .fontSize(18)
        .fontColor(TEXT_SECOND)
        .width('100%')
        .padding(22)
    }
  }

  @Builder
  private HistoryDetailContent(session: GameSession) {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        this.SectionTitle('牌局概览', this.sessionDateText(session))
        Row() {
          Text(`${session.status === 'settled' ? '已封账' : '进行中'} · ${session.playerIds.length} 人 · ${this.currentRoundCountFor(session)} 笔`)
            .fontSize(13)
            .fontColor(TEXT_SECOND)
            .layoutWeight(1)
          Text(`总入场 ${this.sessionBuyInTotal(session)}`)
            .fontSize(13)
            .fontColor(TEXT_SECOND)
        }
        .width('100%')
        Row({ space: 10 }) {
          this.HistoryResultMini('大赢家', this.sessionWinnerSummary(session), GREEN)
          this.HistoryResultMini('大输家', this.sessionLoserSummary(session), RED)
        }
        .width('100%')
        Text(`参与人：${this.sessionPlayerNames(session)}`)
          .fontSize(13)
          .fontColor(TEXT_SECOND)
          .lineHeight(20)
          .width('100%')
        Text(`入场：${this.sessionBuyInSummary(session)}`)
          .fontSize(13)
          .fontColor(TEXT_SECOND)
          .lineHeight(20)
          .width('100%')
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Column({ space: 8 }) {
        this.SectionTitle('最终账面', `总入场 ${this.sessionBuyInTotal(session)}`)
        this.HistoryBalanceRow(session, 0)
        this.HistoryBalanceRow(session, 1)
        this.HistoryBalanceRow(session, 2)
        this.HistoryBalanceRow(session, 3)
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })

      Column({ space: 10 }) {
        this.SectionTitle('进出账流水', `${this.currentRoundCountFor(session)} 笔`)
        if (this.activeRoundsFor(session).length > 0) {
          List() {
            ForEach(this.activeRoundsFor(session), (round: RoundRecord) => {
              this.CashflowRecordListItem(round, false)
            }, (round: RoundRecord) => round.id)
          }
          .height(this.historyRoundListHeight(session))
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
        } else {
          Text('暂无流水')
            .fontSize(13)
            .fontColor(TEXT_SECOND)
            .height(54)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
    }
    .width('100%')
    .padding({ left: 0, right: 0, top: 0, bottom: 30 })
  }

  @Builder
  private HistoryResultMini(label: string, value: string, color: string) {
    Column({ space: 5 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SECOND)
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
    }
    .height(62)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
    .backgroundColor('#F8FAFF')
  }

  @Builder
  private HistoryBalanceRow(session: GameSession, index: number) {
    if (session.playerIds.length > index) {
      Row() {
        Column({ space: 4 }) {
          Text(this.sessionPlayerNameFor(session, index, '玩家'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Text(`入场 ${this.sessionBuyInFor(session, index)}${this.sessionScoreForUser(session, session.playerIds[index]) === this.historyWinnerScore(session) ? ' · 大赢家' : ''}`)
            .fontSize(12)
            .fontColor(TEXT_SECOND)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(formatMoney(this.sessionScoreForUser(session, session.playerIds[index])))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.sessionScoreForUser(session, session.playerIds[index]) >= 0 ? GREEN : RED)
      }
      .height(58)
      .padding({ left: 12, right: 12 })
      .borderRadius(16)
      .backgroundColor('#F8FAFF')
    }
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
  private EditablePlayerRow(name: string, amount: string, onNameChange: (value: string) => void, onAmountChange: (value: string) => void) {
    Row({ space: 10 }) {
      TextInput({ text: name })
        .height(40)
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .padding({ left: 12 })
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
        .onChange(onNameChange)
      TextInput({ text: amount })
        .height(40)
        .width(88)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .textAlign(TextAlign.Center)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
        .onChange(onAmountChange)
    }
  }

  @Builder
  private LatestClosedGameCard(scope: number = 0) {
    if (this.latestSettledSession(scope)) {
      Column({ space: 12 }) {
        this.SectionTitle('最近封账', '已归档')
        this.CashflowRow((this.latestSettledSession(scope) as GameSession).title, `赢家：${this.sessionWinner(this.latestSettledSession(scope) as GameSession)} · ${this.statsScopeText(scope)}最近一局`, formatMoney(this.sessionScoreForCurrent(this.latestSettledSession(scope) as GameSession)), this.sessionScoreForCurrent(this.latestSettledSession(scope) as GameSession) >= 0)
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
    } else {
      Column({ space: 12 }) {
        this.SectionTitle('最近封账', '已归档')
        this.StatsEmptyState('暂无封账牌局', `${this.statsScopeText(scope)}范围内还没有已封账牌局`)
      }
      .padding(16)
      .borderRadius(22)
      .backgroundColor(CARD_BG)
      .shadow({ radius: 18, color: '#10000000', offsetY: 8 })
    }
  }

  @Builder
  private EntryPlayerSelectSheet() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.entryPickerTitle())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Text('仅从当前牌局参与人中选择，包括我。')
            .fontSize(12)
            .fontColor(TEXT_SECOND)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 0 }) {
        ForEach(this.entryPickerUsers(), (user: User) => {
          this.EntryPlayerPickerOption(user)
        }, (user: User) => user.id)
      }
      .width('100%')
      .constraintSize({ maxHeight: 320 })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 28 })
  }

  @Builder
  private EntryPlayerPickerOption(user: User) {
    Row({ space: 12 }) {
      Text(user.displayName.substring(0, 1))
        .width(36)
        .height(36)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor(user.avatarColor)
      Column({ space: 4 }) {
        Text(user.displayName)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(this.selectedEntryPickerPlayerId() === user.id ? '当前已选' : `入场 ${this.buyInForUser(user.id)}`)
          .fontSize(12)
          .fontColor(this.selectedEntryPickerPlayerId() === user.id ? BLUE : TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.selectedEntryPickerPlayerId() === user.id) {
        Text('✓')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(BLUE)
      }
    }
    .height(58)
    .border({ width: { bottom: 1 }, color: LINE })
    .scale(this.pressableControlScale(`entry-picker-${user.id}`))
    .animation({ duration: 150, curve: Curve.FastOutSlowIn })
    .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `entry-picker-${user.id}`))
    .onClick(() => this.selectEntryPlayer(user.id))
  }

  @Builder
  private FriendSelectSheet() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('选择牌友')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
          Text('仅显示已存在牌友，也可以直接在输入框里输入新名字')
            .fontSize(12)
            .fontColor(TEXT_SECOND)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 0 }) {
        if (this.selectablePickerUsers().length === 0) {
          this.EmptyFriendPickerState(this.selectableFriendCount() === 0 ? '目前暂时还没有牌友' : '没有匹配的牌友')
        } else {
          ForEach(this.selectablePickerUsers(), (user: User) => {
            this.FriendPickerOption(user)
          }, (user: User) => user.id)
        }
      }
      .width('100%')
      .constraintSize({ maxHeight: 360 })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 28 })
  }

  @Builder
  private EmptyFriendPickerState(message: string) {
    Column({ space: 8 }) {
      Text(message)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)
      Text('可以先直接输入新牌友名字，创建牌局后会自动保存到本地牌友。')
        .fontSize(12)
        .fontColor(TEXT_SECOND)
        .textAlign(TextAlign.Center)
        .lineHeight(18)
    }
    .width('100%')
    .padding({ top: 28, bottom: 28, left: 16, right: 16 })
    .borderRadius(16)
    .backgroundColor('#F8FAFF')
  }

  @Builder
  private FriendPickerOption(user: User) {
    Row({ space: 12 }) {
      Text(user.displayName.substring(0, 1))
        .width(36)
        .height(36)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor(user.avatarColor)
      Column({ space: 4 }) {
        Text(user.displayName)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
        Text(this.friendOptionSummary(user.id))
          .fontSize(12)
          .fontColor(TEXT_SECOND)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .height(58)
    .border({ width: { bottom: 1 }, color: LINE })
    .scale(this.pressableControlScale(`friend-picker-${user.id}`))
    .animation({ duration: 150, curve: Curve.FastOutSlowIn })
    .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `friend-picker-${user.id}`))
    .onClick(() => this.selectFriendForNewSession(user))
  }

  @Builder
  private CreateFixedPlayerRow(label: string, name: string, amount: string, onAmountChange: (value: string) => void) {
    Row({ space: 10 }) {
      Text(label)
        .width(46)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_SECOND)
      Text(name)
        .height(42)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)
        .padding({ left: 12, right: 12 })
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
      TextInput({ text: amount, placeholder: '金额' })
        .height(42)
        .width(82)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .textAlign(TextAlign.Center)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
        .onChange(onAmountChange)
    }
    .width('100%')
  }

  @Builder
  private CreatePlayerInputRow(label: string, name: string, amount: string, onNameChange: (value: string) => void, onAmountChange: (value: string) => void, onPicker: () => void) {
    Row({ space: 10 }) {
      Text(label)
        .width(46)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_SECOND)
      Row({ space: 6 }) {
        TextInput({ text: name, placeholder: '输入或选择牌友' })
          .height(40)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor(TEXT_MAIN)
          .padding({ left: 0, right: 0 })
          .backgroundColor('#00000000')
          .onChange(onNameChange)
        Text('⌄')
          .width(28)
          .height(32)
          .fontSize(18)
          .fontColor(TEXT_SECOND)
          .textAlign(TextAlign.Center)
          .scale(this.pressableControlScale(`player-picker-${label}`))
          .animation({ duration: 150, curve: Curve.FastOutSlowIn })
          .onTouch((event: TouchEvent) => this.handlePressableControlTouch(event, `player-picker-${label}`))
          .onClick(onPicker)
      }
      .height(42)
      .layoutWeight(1)
      .padding({ left: 12, right: 4 })
      .borderRadius(13)
      .backgroundColor('#F8F6F2')
      TextInput({ text: amount, placeholder: '金额' })
        .height(42)
        .width(82)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .textAlign(TextAlign.Center)
        .borderRadius(13)
        .backgroundColor('#F8F6F2')
        .onChange(onAmountChange)
    }
    .width('100%')
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
    .height(28)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private GlassNav() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('96%')
        .height(58)
        .borderRadius(29)
        .backgroundColor('#42FFFFFF')
        .border({ width: 1, color: '#BFFFFFFF' })

      Column()
        .width('78%')
        .height(1)
        .backgroundColor('#CCFFFFFF')
        .opacity(0.72)
        .margin({ bottom: 50 })

      Row({ space: 2 }) {
        this.NavItem('牌局', 0)
        this.NavItem('统计', 1)
        this.NavItem('牌友', 2)
        this.NavItem('我的', 3)
      }
      .height(60)
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    }
    .height(76)
    .width('90%')
    .padding({ left: 6, right: 6, top: 6, bottom: 6 })
    .margin({ bottom: 24 })
    .borderRadius(38)
    .backgroundColor(NAV_BG)
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .border({ width: 1, color: '#D8FFFFFF' })
    .shadow({ radius: 30, color: '#22000000', offsetY: 12 })
  }

  @Builder
  private NavItem(label: string, index: number) {
    Column({ space: 4 }) {
      this.NavGlyph(index)
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.navItemColor(index))
    }
    .height(56)
    .layoutWeight(1)
    .borderRadius(28)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.currentTab === index ? '#242F63F4' : '#00000000')
    .scale(this.navItemScale(index))
    .opacity(this.pressedNavIndex === index ? 0.72 : 1)
    .animation({ duration: 180, curve: Curve.FastOutSlowIn })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedNavIndex = index;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedNavIndex = -1;
      }
    })
    .onClick(() => this.switchTab(index))
  }

  private navItemColor(index: number): string {
    return this.currentTab === index ? BLUE : ICON_GRAY;
  }

  private navItemScale(index: number): ScaleOptions {
    if (this.pressedNavIndex === index) {
      return { x: 0.94, y: 0.94 };
    }
    if (this.currentTab === index) {
      return { x: 1.04, y: 1.04 };
    }
    return { x: 1, y: 1 };
  }

  @Builder
  private NavGlyph(index: number) {
    if (index === 0) {
      if (this.currentTab === index) {
        Column({ space: 3 }) {
          Column().width(11).height(2).borderRadius(1).backgroundColor(BLUE)
          Column().width(11).height(2).borderRadius(1).backgroundColor(BLUE)
          Column().width(8).height(2).borderRadius(1).backgroundColor(BLUE)
        }
        .width(22)
        .height(22)
        .padding({ left: 5, right: 4, top: 5 })
        .border({ width: 1.5, color: BLUE })
        .borderRadius(5)
      } else {
        Column({ space: 4 }) {
          Column().width(15).height(2).borderRadius(1).backgroundColor(ICON_GRAY)
          Column().width(15).height(2).borderRadius(1).backgroundColor(ICON_GRAY)
          Column().width(10).height(2).borderRadius(1).backgroundColor(ICON_GRAY)
        }
        .width(22)
        .height(22)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    } else if (index === 1) {
      Row({ space: 3 }) {
        Column().width(4).height(10).borderRadius(2).backgroundColor(this.navItemColor(index))
        Column().width(4).height(16).borderRadius(2).backgroundColor(this.navItemColor(index))
        Column().width(4).height(13).borderRadius(2).backgroundColor(this.navItemColor(index))
      }
      .width(24)
      .height(22)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Bottom)
    } else if (index === 2) {
      Row({ space: 2 }) {
        Column({ space: 2 }) {
          Column().width(7).height(7).borderRadius(4).border({ width: 1.4, color: this.navItemColor(index) })
          Column().width(13).height(7).borderRadius(6).border({ width: 1.4, color: this.navItemColor(index) })
        }
        Column({ space: 2 }) {
          Column().width(6).height(6).borderRadius(3).border({ width: 1.2, color: this.navItemColor(index) })
          Column().width(11).height(6).borderRadius(5).border({ width: 1.2, color: this.navItemColor(index) })
        }
        .margin({ top: 4 })
      }
      .height(22)
      .alignItems(VerticalAlign.Center)
    } else {
      Column({ space: 2 }) {
        Column().width(8).height(8).borderRadius(4).border({ width: 1.5, color: this.navItemColor(index) })
        Column().width(17).height(9).borderRadius(8).border({ width: 1.5, color: this.navItemColor(index) })
      }
      .width(24)
      .height(22)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
  }
}
