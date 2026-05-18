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
  createSession(groupId: string, title: string, basePoint: number, note: string, playerIds: string[]): GameSession;
  addRound(groupId: string, sessionId: string, scores: Record<string, number>, note: string): RoundRecord;
  voidRound(groupId: string, roundId: string): void;
  pendingOperations(): LedgerOperation[];
  markOperationSynced(operationId: string): void;
}
