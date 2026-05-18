export type SyncState = 'synced' | 'pending' | 'failed';
export type MemberRole = 'owner' | 'member';
export type OperationType = 'create_group' | 'create_session' | 'create_round' | 'void_round' | 'update_round';

export class User {
  id: string = '';
  displayName: string = '';
  avatarColor: string = '#126A50';

  constructor(id: string, displayName: string, avatarColor: string) {
    this.id = id;
    this.displayName = displayName;
    this.avatarColor = avatarColor;
  }
}

export class Group {
  id: string = '';
  name: string = '';
  ownerId: string = '';
  inviteCode: string = '';
  createdAt: number = 0;
  syncState: SyncState = 'synced';

  constructor(id: string, name: string, ownerId: string, inviteCode: string, createdAt: number, syncState: SyncState) {
    this.id = id;
    this.name = name;
    this.ownerId = ownerId;
    this.inviteCode = inviteCode;
    this.createdAt = createdAt;
    this.syncState = syncState;
  }
}

export class GroupMember {
  groupId: string = '';
  userId: string = '';
  role: MemberRole = 'member';
  joinedAt: number = 0;

  constructor(groupId: string, userId: string, role: MemberRole, joinedAt: number) {
    this.groupId = groupId;
    this.userId = userId;
    this.role = role;
    this.joinedAt = joinedAt;
  }
}

export class GameSession {
  id: string = '';
  groupId: string = '';
  title: string = '';
  basePoint: number = 1;
  note: string = '';
  playerIds: string[] = [];
  createdAt: number = 0;
  syncState: SyncState = 'synced';

  constructor(id: string, groupId: string, title: string, basePoint: number, note: string, playerIds: string[], createdAt: number, syncState: SyncState) {
    this.id = id;
    this.groupId = groupId;
    this.title = title;
    this.basePoint = basePoint;
    this.note = note;
    this.playerIds = playerIds;
    this.createdAt = createdAt;
    this.syncState = syncState;
  }
}

export class RoundRecord {
  id: string = '';
  sessionId: string = '';
  index: number = 0;
  playerScores: Record<string, number> = {};
  note: string = '';
  createdBy: string = '';
  createdAt: number = 0;
  version: number = 1;
  isVoided: boolean = false;
  syncState: SyncState = 'synced';

  constructor(id: string, sessionId: string, index: number, playerScores: Record<string, number>, note: string, createdBy: string, createdAt: number, syncState: SyncState) {
    this.id = id;
    this.sessionId = sessionId;
    this.index = index;
    this.playerScores = playerScores;
    this.note = note;
    this.createdBy = createdBy;
    this.createdAt = createdAt;
    this.syncState = syncState;
  }
}

export class LedgerOperation {
  id: string = '';
  groupId: string = '';
  entityId: string = '';
  type: OperationType = 'create_round';
  actorId: string = '';
  createdAt: number = 0;
  payload: string = '';
  version: number = 1;
  syncState: SyncState = 'pending';

  constructor(id: string, groupId: string, entityId: string, type: OperationType, actorId: string, createdAt: number, payload: string) {
    this.id = id;
    this.groupId = groupId;
    this.entityId = entityId;
    this.type = type;
    this.actorId = actorId;
    this.createdAt = createdAt;
    this.payload = payload;
  }
}

export class PlayerSummary {
  userId: string = '';
  name: string = '';
  total: number = 0;
  rounds: number = 0;
  maxWin: number = 0;
  maxLoss: number = 0;

  constructor(userId: string, name: string) {
    this.userId = userId;
    this.name = name;
  }
}
