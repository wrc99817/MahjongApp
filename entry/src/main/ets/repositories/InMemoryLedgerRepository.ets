import { GameSession, Group, GroupMember, LedgerOperation, OperationType, RoundRecord, User } from '../common/Models';
import { LedgerRepository } from './LedgerRepository';
import { validateRound } from '../services/Money';

function now(): number {
  return new Date().getTime();
}

function makeId(prefix: string): string {
  return `${prefix}_${new Date().getTime()}_${Math.floor(Math.random() * 10000)}`;
}

export class InMemoryLedgerRepository implements LedgerRepository {
  private user: User = new User('u_host', '我', '#126A50');
  private users: User[] = [
    new User('u_host', '我', '#126A50')
  ];
  private groups: Group[] = [];
  private members: GroupMember[] = [];
  private sessions: GameSession[] = [];
  private rounds: RoundRecord[] = [];
  private operations: LedgerOperation[] = [];

  constructor() {
    const group = new Group('g_demo', '本地麻将账本', this.user.id, 'MJ2026', now(), 'synced');
    this.groups.push(group);
    for (let index = 0; index < this.users.length; index++) {
      this.members.push(new GroupMember(group.id, this.users[index].id, index === 0 ? 'owner' : 'member', group.createdAt));
    }
  }

  currentUser(): User {
    return this.user;
  }

  listUsers(): User[] {
    return this.users.slice();
  }

  listGroups(): Group[] {
    return this.groups.slice();
  }

  listMembers(groupId: string): GroupMember[] {
    return this.members.filter((item: GroupMember) => item.groupId === groupId);
  }

  listSessions(groupId: string): GameSession[] {
    return this.sessions.filter((item: GameSession) => item.groupId === groupId).sort((left: GameSession, right: GameSession) => right.createdAt - left.createdAt);
  }

  listRounds(sessionId: string): RoundRecord[] {
    return this.rounds.filter((item: RoundRecord) => item.sessionId === sessionId).sort((left: RoundRecord, right: RoundRecord) => left.index - right.index);
  }

  listOperations(groupId: string): LedgerOperation[] {
    return this.operations.filter((item: LedgerOperation) => item.groupId === groupId).sort((left: LedgerOperation, right: LedgerOperation) => right.createdAt - left.createdAt);
  }

  createGroup(name: string): Group {
    const group = new Group(makeId('g'), name, this.user.id, `MJ${Math.floor(1000 + Math.random() * 9000)}`, now(), 'pending');
    this.groups.unshift(group);
    this.members.push(new GroupMember(group.id, this.user.id, 'owner', group.createdAt));
    this.users.slice(1, 4).forEach((item: User) => this.members.push(new GroupMember(group.id, item.id, 'member', group.createdAt)));
    this.enqueue(group.id, group.id, 'create_group', JSON.stringify(group));
    return group;
  }

  findOrCreateUser(displayName: string): User {
    const normalized = this.normalizeName(displayName);
    const existing = this.users.find((item: User) => this.normalizeName(item.displayName) === normalized);
    if (existing) {
      return existing;
    }
    const user = new User(makeId('u'), displayName.trim(), this.nextAvatarColor());
    this.users.push(user);
    if (this.groups.length > 0) {
      this.members.push(new GroupMember(this.groups[0].id, user.id, 'member', now()));
      this.enqueue(this.groups[0].id, user.id, 'create_user', JSON.stringify(user));
    }
    return user;
  }

  updateUser(userId: string, displayName: string): User {
    const userIndex = this.users.findIndex((item: User) => item.id === userId);
    if (userIndex < 0) {
      throw new Error('玩家不存在');
    }
    const current = this.users[userIndex];
    const updated = new User(current.id, displayName, current.avatarColor);
    this.users[userIndex] = updated;
    if (this.user.id === updated.id) {
      this.user = updated;
    }
    this.enqueue(this.groups.length > 0 ? this.groups[0].id : '', updated.id, 'update_user', JSON.stringify(updated));
    return updated;
  }

  createSession(groupId: string, title: string, basePoint: number, note: string, playerIds: string[], buyIns: Record<string, number> = {}, defaultBuyIn: number = 200): GameSession {
    const session = new GameSession(makeId('s'), groupId, title, basePoint, note, playerIds.slice(), now(), 'pending', this.cloneBuyIns(buyIns, playerIds), 'active', 0, defaultBuyIn);
    this.sessions.unshift(session);
    this.enqueue(groupId, session.id, 'create_session', JSON.stringify(session));
    return session;
  }

  updateSession(groupId: string, sessionId: string, title: string, basePoint: number, note: string, playerIds: string[], buyIns: Record<string, number>, defaultBuyIn?: number): GameSession {
    const sessionIndex = this.sessions.findIndex((item: GameSession) => item.id === sessionId);
    if (sessionIndex < 0) {
      throw new Error('牌局不存在');
    }
    const current = this.sessions[sessionIndex];
    const updated = new GameSession(current.id, current.groupId, title, basePoint, note, playerIds.slice(), current.createdAt, 'pending', this.cloneBuyIns(buyIns, playerIds), current.status, current.settledAt, defaultBuyIn ?? current.defaultBuyIn);
    this.sessions[sessionIndex] = updated;
    this.enqueue(groupId, updated.id, 'update_session', JSON.stringify(updated));
    return updated;
  }

  settleSession(groupId: string, sessionId: string): GameSession {
    const sessionIndex = this.sessions.findIndex((item: GameSession) => item.id === sessionId);
    if (sessionIndex < 0) {
      throw new Error('牌局不存在');
    }
    const current = this.sessions[sessionIndex];
    const updated = new GameSession(current.id, current.groupId, current.title, current.basePoint, current.note, current.playerIds.slice(), current.createdAt, 'pending', this.cloneBuyIns(current.buyIns, current.playerIds), 'settled', now(), current.defaultBuyIn);
    this.sessions[sessionIndex] = updated;
    this.enqueue(groupId, updated.id, 'settle_session', JSON.stringify(updated));
    return updated;
  }

  addRound(groupId: string, sessionId: string, scores: Record<string, number>, note: string): RoundRecord {
    const session = this.sessions.find((item: GameSession) => item.id === sessionId);
    if (!session) {
      throw new Error('牌局不存在');
    }
    if (session.status === 'settled') {
      throw new Error('已封账牌局不能继续记账');
    }

    const result = validateRound(session.playerIds, scores);
    if (!result.valid) {
      throw new Error(result.message);
    }

    const nextIndex = this.listRounds(sessionId).length + 1;
    const round = new RoundRecord(makeId('r'), sessionId, nextIndex, scores, note, this.user.id, now(), 'pending');
    this.rounds.push(round);
    this.enqueue(groupId, round.id, 'create_round', JSON.stringify(round));
    return round;
  }

  voidRound(groupId: string, roundId: string): void {
    const round = this.rounds.find((item: RoundRecord) => item.id === roundId);
    if (!round) {
      return;
    }
    round.isVoided = true;
    round.version += 1;
    round.syncState = 'pending';
    this.enqueue(groupId, round.id, 'void_round', JSON.stringify(round));
  }

  clearAllData(): void {
    const groupId = this.groups.length > 0 ? this.groups[0].id : 'g_demo';
    this.users = [new User('u_host', '我', '#126A50')];
    this.user = this.users[0];
    this.groups = [new Group(groupId, '本地麻将账本', this.user.id, 'MJ2026', now(), 'pending')];
    this.members = [new GroupMember(groupId, this.user.id, 'owner', now())];
    this.sessions = [];
    this.rounds = [];
    this.operations = [];
    this.enqueue(groupId, groupId, 'clear_data', '{}');
  }

  pendingOperations(): LedgerOperation[] {
    return this.operations.filter((item: LedgerOperation) => item.syncState === 'pending');
  }

  markOperationSynced(operationId: string): void {
    const operation = this.operations.find((item: LedgerOperation) => item.id === operationId);
    if (operation) {
      operation.syncState = 'synced';
    }
  }

  private enqueue(groupId: string, entityId: string, type: OperationType, payload: string): void {
    this.operations.unshift(new LedgerOperation(makeId('op'), groupId, entityId, type, this.user.id, now(), payload));
  }

  private cloneBuyIns(source: Record<string, number>, playerIds: string[]): Record<string, number> {
    const buyIns: Record<string, number> = {};
    for (let index = 0; index < playerIds.length; index++) {
      const playerId = playerIds[index];
      buyIns[playerId] = Number(source[playerId] ?? 200);
    }
    return buyIns;
  }

  private normalizeName(name: string): string {
    return name.trim().toLowerCase();
  }

  private nextAvatarColor(): string {
    const colors: string[] = ['#126A50', '#C43E32', '#2A6FB3', '#D2902F', '#4FA868', '#7355A5', '#C6A85A'];
    return colors[this.users.length % colors.length];
  }
}

export const ledgerRepository: LedgerRepository = new InMemoryLedgerRepository();
