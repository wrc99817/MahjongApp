import { GameSession, Group, GroupMember, LedgerOperation, RoundRecord, User } from '../common/Models';

export interface LedgerRepository {
  currentUser(): User;
  listUsers(): User[];
  listGroups(): Group[];
  listMembers(groupId: string): GroupMember[];
  listSessions(groupId: string): GameSession[];
  listRounds(sessionId: string): RoundRecord[];
  listOperations(groupId: string): LedgerOperation[];
  createGroup(name: string): Group;
  findOrCreateUser(displayName: string): User;
  updateUser(userId: string, displayName: string): User;
  createSession(groupId: string, title: string, basePoint: number, note: string, playerIds: string[], buyIns?: Record<string, number>): GameSession;
  updateSession(groupId: string, sessionId: string, title: string, basePoint: number, note: string, playerIds: string[], buyIns: Record<string, number>): GameSession;
  settleSession(groupId: string, sessionId: string): GameSession;
  addRound(groupId: string, sessionId: string, scores: Record<string, number>, note: string): RoundRecord;
  voidRound(groupId: string, roundId: string): void;
  clearAllData(): void;
  pendingOperations(): LedgerOperation[];
  markOperationSynced(operationId: string): void;
}
