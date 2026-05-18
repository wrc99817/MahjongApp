import { LedgerOperation } from '../common/Models';
import { LedgerRepository } from '../repositories/LedgerRepository';

export class SyncResult {
  syncedCount: number = 0;
  failedCount: number = 0;
  message: string = '';

  constructor(syncedCount: number, failedCount: number, message: string) {
    this.syncedCount = syncedCount;
    this.failedCount = failedCount;
    this.message = message;
  }
}

export class SyncService {
  sync(repository: LedgerRepository): SyncResult {
    const pending = repository.pendingOperations();
    for (let index = 0; index < pending.length; index++) {
      const operation: LedgerOperation = pending[index];
      repository.markOperationSynced(operation.id);
    }

    if (pending.length === 0) {
      return new SyncResult(0, 0, '没有待同步操作');
    }
    return new SyncResult(pending.length, 0, `已模拟同步 ${pending.length} 条操作`);
  }
}
