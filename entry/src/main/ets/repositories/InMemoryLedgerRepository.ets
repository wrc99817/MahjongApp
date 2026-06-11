import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { GameSession, Group, GroupMember, LedgerOperation, OperationType, RoundRecord, User } from '../common/Models';
import { LedgerRepository } from './LedgerRepository';
import { validateRound } from '../services/Money';

const LEDGER_PREFERENCES_NAME = 'yiju_ledger_store';
const LEDGER_SNAPSHOT_KEY = 'ledger_snapshot_v1';
const LEDGER_SNAPSHOT_CHUNK_COUNT_KEY = 'ledger_snapshot_chunk_count_v1';
const LEDGER_SNAPSHOT_CHUNK_PREFIX = 'ledger_snapshot_chunk_v1_';
const LEDGER_SNAPSHOT_CHUNK_SIZE = 7000;
const LEDGER_SCHEMA_VERSION = 1;

function now(): number {
  return new Date().getTime();
}

function makeId(prefix: string): string {
  return `${prefix}_${new Date().getTime()}_${Math.floor(Math.random() * 10000)}`;
}

interface LedgerSnapshot {
  schemaVersion: number;
  currentUserId: string;
  users: User[];
  groups: Group[];
  members: GroupMember[];
  sessions: GameSession[];
  rounds: RoundRecord[];
  operations: LedgerOperation[];
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
  private storage?: preferences.Preferences;

  constructor() {
    const group = new Group('g_demo', '本地麻将账本', this.user.id, 'MJ2026', now(), 'synced');
    this.groups.push(group);
    for (let index = 0; index < this.users.length; index++) {
      this.members.push(new GroupMember(group.id, this.users[index].id, index === 0 ? 'owner' : 'member', group.createdAt));
    }
  }

  initialize(context: common.UIAbilityContext): void {
    try {
      this.storage = preferences.getPreferencesSync(context, { name: LEDGER_PREFERENCES_NAME });
      this.restoreFromStorage();
    } catch (error) {
      console.error(`LedgerRepository initialize failed: ${(error as Error).message}`);
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
      this.persist();
    }
  }

  private enqueue(groupId: string, entityId: string, type: OperationType, payload: string): void {
    this.operations.unshift(new LedgerOperation(makeId('op'), groupId, entityId, type, this.user.id, now(), payload));
    this.persist();
  }

  private restoreFromStorage(): void {
    if (!this.storage) {
      return;
    }
    const rawSnapshot = this.readSnapshotString();
    if (rawSnapshot.length === 0) {
      this.persist();
      return;
    }
    try {
      const snapshot = JSON.parse(rawSnapshot) as LedgerSnapshot;
      if (snapshot.schemaVersion !== LEDGER_SCHEMA_VERSION || snapshot.users.length === 0 || snapshot.groups.length === 0) {
        this.persist();
        return;
      }
      this.users = snapshot.users.map((item: User) => this.restoreUser(item));
      const restoredCurrentUser = this.users.find((item: User) => item.id === snapshot.currentUserId);
      this.user = restoredCurrentUser ? restoredCurrentUser : this.users[0];
      this.groups = snapshot.groups.map((item: Group) => this.restoreGroup(item));
      this.members = snapshot.members.map((item: GroupMember) => this.restoreMember(item));
      this.sessions = snapshot.sessions.map((item: GameSession) => this.restoreSession(item));
      this.rounds = snapshot.rounds.map((item: RoundRecord) => this.restoreRound(item));
      this.operations = snapshot.operations.map((item: LedgerOperation) => this.restoreOperation(item));
    } catch (error) {
      console.error(`LedgerRepository restore failed: ${(error as Error).message}`);
      this.persist();
    }
  }

  private persist(): void {
    if (!this.storage) {
      return;
    }
    const snapshot: LedgerSnapshot = {
      schemaVersion: LEDGER_SCHEMA_VERSION,
      currentUserId: this.user.id,
      users: this.users,
      groups: this.groups,
      members: this.members,
      sessions: this.sessions,
      rounds: this.rounds,
      operations: this.operations
    };
    try {
      const serialized = JSON.stringify(snapshot);
      const chunkCount = Math.max(1, Math.ceil(serialized.length / LEDGER_SNAPSHOT_CHUNK_SIZE));
      const previousChunkCountValue = this.storage.getSync(LEDGER_SNAPSHOT_CHUNK_COUNT_KEY, 0);
      const previousChunkCount = typeof previousChunkCountValue === 'number' ? previousChunkCountValue : 0;
      for (let index = 0; index < chunkCount; index++) {
        const start = index * LEDGER_SNAPSHOT_CHUNK_SIZE;
        this.storage.putSync(`${LEDGER_SNAPSHOT_CHUNK_PREFIX}${index}`, serialized.slice(start, start + LEDGER_SNAPSHOT_CHUNK_SIZE));
      }
      for (let index = chunkCount; index < previousChunkCount; index++) {
        this.storage.deleteSync(`${LEDGER_SNAPSHOT_CHUNK_PREFIX}${index}`);
      }
      this.storage.deleteSync(LEDGER_SNAPSHOT_KEY);
      this.storage.putSync(LEDGER_SNAPSHOT_CHUNK_COUNT_KEY, chunkCount);
      this.storage.flushSync();
    } catch (error) {
      console.error(`LedgerRepository persist failed: ${(error as Error).message}`);
    }
  }

  private readSnapshotString(): string {
    if (!this.storage) {
      return '';
    }
    const chunkCountValue = this.storage.getSync(LEDGER_SNAPSHOT_CHUNK_COUNT_KEY, 0);
    if (typeof chunkCountValue === 'number' && chunkCountValue > 0) {
      let snapshot = '';
      for (let index = 0; index < chunkCountValue; index++) {
        const chunk = this.storage.getSync(`${LEDGER_SNAPSHOT_CHUNK_PREFIX}${index}`, '');
        if (typeof chunk !== 'string') {
          return '';
        }
        snapshot += chunk;
      }
      return snapshot;
    }
    const legacySnapshot = this.storage.getSync(LEDGER_SNAPSHOT_KEY, '');
    return typeof legacySnapshot === 'string' ? legacySnapshot : '';
  }

  private restoreUser(item: User): User {
    return new User(item.id, item.displayName, item.avatarColor);
  }

  private restoreGroup(item: Group): Group {
    return new Group(item.id, item.name, item.ownerId, item.inviteCode, item.createdAt, item.syncState);
  }

  private restoreMember(item: GroupMember): GroupMember {
    return new GroupMember(item.groupId, item.userId, item.role, item.joinedAt);
  }

  private restoreSession(item: GameSession): GameSession {
    return new GameSession(item.id, item.groupId, item.title, item.basePoint, item.note, item.playerIds.slice(), item.createdAt, item.syncState, this.copyScores(item.buyIns), item.status, item.settledAt, item.defaultBuyIn);
  }

  private restoreRound(item: RoundRecord): RoundRecord {
    const round = new RoundRecord(item.id, item.sessionId, item.index, this.copyScores(item.playerScores), item.note, item.createdBy, item.createdAt, item.syncState);
    round.version = item.version;
    round.isVoided = item.isVoided;
    return round;
  }

  private restoreOperation(item: LedgerOperation): LedgerOperation {
    const operation = new LedgerOperation(item.id, item.groupId, item.entityId, item.type, item.actorId, item.createdAt, item.payload);
    operation.version = item.version;
    operation.syncState = item.syncState;
    return operation;
  }

  private copyScores(source: Record<string, number>): Record<string, number> {
    const result: Record<string, number> = {};
    Object.keys(source).forEach((key: string) => {
      result[key] = Number(source[key] ?? 0);
    });
    return result;
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
