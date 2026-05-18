import { PlayerSummary, RoundRecord, User } from '../common/Models';

export class RoundValidationResult {
  valid: boolean = false;
  message: string = '';

  constructor(valid: boolean, message: string) {
    this.valid = valid;
    this.message = message;
  }
}

export function validateRound(playerIds: string[], scores: Record<string, number>): RoundValidationResult {
  if (playerIds.length !== 4) {
    return new RoundValidationResult(false, '每局必须选择 4 位玩家');
  }

  let total = 0;
  for (let index = 0; index < playerIds.length; index++) {
    const playerId = playerIds[index];
    const score = Number(scores[playerId] ?? 0);
    if (Number.isNaN(score)) {
      return new RoundValidationResult(false, '输赢金额必须是数字');
    }
    total += score;
  }

  if (total !== 0) {
    return new RoundValidationResult(false, `四人输赢合计必须为 0，当前为 ${total}`);
  }
  return new RoundValidationResult(true, '校验通过');
}

export function buildPlayerSummaries(users: User[], rounds: RoundRecord[]): PlayerSummary[] {
  const summaries: PlayerSummary[] = [];
  for (let userIndex = 0; userIndex < users.length; userIndex++) {
    const user = users[userIndex];
    summaries.push(new PlayerSummary(user.id, user.displayName));
  }

  for (let roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
    const round = rounds[roundIndex];
    if (round.isVoided) {
      continue;
    }

    for (let summaryIndex = 0; summaryIndex < summaries.length; summaryIndex++) {
      const summary = summaries[summaryIndex];
      const score = Number(round.playerScores[summary.userId] ?? 0);
      summary.total += score;
      summary.rounds += 1;
      summary.maxWin = Math.max(summary.maxWin, score);
      summary.maxLoss = Math.min(summary.maxLoss, score);
    }
  }
  return summaries;
}

export function formatMoney(value: number): string {
  if (value > 0) {
    return `+${value}`;
  }
  return `${value}`;
}
