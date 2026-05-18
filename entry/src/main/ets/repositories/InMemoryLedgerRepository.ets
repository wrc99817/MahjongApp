import { GameSession, Group, GroupMember, LedgerOperation, RoundRecord, User } from '../common/Models';
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
    new User('u_host', '我', '#126A50'),
    new User('u_lin', '阿林', '#C43E32'),
    new User('u_qi', '小齐', '#2A6FB3'),
    new User('u_yan', '燕子', '#D2902F')
  ];
  private groups: Group[] = [];
  private members: GroupMember[] = [];
  private sessions: GameSession[] = [];
  private rounds: RoundRecord[] = [];
  private operations: LedgerOperation[] = [];

  constructor() {
    const group = new Group('g_demo', '周末麻将账本', this.user.id, 'MJ2026', now() - 86400000, 'synced');
    this.groups.push(group);
    for (let index = 0; index < this.users.length; index++) {
      this.members.push(new GroupMember(group.id, this.users[index].id, index === 0 ? 'owner' : 'member', group.createdAt));
    }
    const session = new GameSession('s_demo', group.id, '5月18日东风局', 1, '手动记账 MVP 示例', this.users.map((item: User) => item.id), now() - 3600000, 'synced');
    this.sessions.push(session);
    this.rounds.push(new RoundRecord('r_demo_1', session.id, 1, {
      'u_host': 40,
      'u_lin': -10,
      'u_qi': -20,
      'u_yan': -10
    }, '自摸后手动录入', this.user.id, now() - 3200000, 'synced'));
    this.rounds.push(new RoundRecord('r_demo_2', session.id, 2, {
      'u_host': -30,
      'u_lin': 50,
      'u_qi': -10,
      'u_yan': -10
    }, '点炮后手动录入', this.user.id, now() - 2800000, 'synced'));
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

  createSession(groupId: string, title: string, basePoint: number, note: string, playerIds: string[]): GameSession {
    const session = new GameSession(makeId('s'), groupId, title, basePoint, note, playerIds, now(), 'pending');
    this.sessions.unshift(session);
    this.enqueue(groupId, session.id, 'create_session', JSON.stringify(session));
    return session;
  }

  addRound(groupId: string, sessionId: string, scores: Record<string, number>, note: string): RoundRecord {
    const session = this.sessions.find((item: GameSession) => item.id === sessionId);
    if (!session) {
      throw new Error('牌局不存在');
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

  pendingOperations(): LedgerOperation[] {
    return this.operations.filter((item: LedgerOperation) => item.syncState === 'pending');
  }

  markOperationSynced(operationId: string): void {
    const operation = this.operations.find((item: LedgerOperation) => item.id === operationId);
    if (operation) {
      operation.syncState = 'synced';
    }
  }

  private enqueue(groupId: string, entityId: string, type: 'create_group' | 'create_session' | 'create_round' | 'void_round' | 'update_round', payload: string): void {
    this.operations.unshift(new LedgerOperation(makeId('op'), groupId, entityId, type, this.user.id, now(), payload));
  }
}

export const ledgerRepository: LedgerRepository = new InMemoryLedgerRepository();
