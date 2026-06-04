const $app = document.querySelector('#app');

const colors = ['#126A50', '#C43E32', '#2A6FB3', '#D2902F', '#7355A5', '#C6A85A'];
const now = () => Date.now();
const uid = (prefix) => `${prefix}_${Math.random().toString(36).slice(2, 8)}`;

const state = {
  tab: 'game',
  view: 'main',
  statsMode: 'all',
  entryMode: 'single',
  cashflowFilter: 'all',
  sheet: null,
  toast: '',
  selectedHistoryId: '',
  searchActive: false,
  searchQuery: '',
  users: [],
  currentUserId: 'u_host',
  activeSession: null,
  settledSessions: [],
  draft: {
    title: '今天的牌局',
    basePoint: 10,
    players: [
      { name: '我', buyIn: '' },
      { name: '', buyIn: '' },
      { name: '', buyIn: '' },
      { name: '', buyIn: '' },
    ],
  },
  entryDraft: {
    winnerId: '',
    singleAmount: '',
    payerId: '',
    aaAmount: '',
    aaNote: '',
    adjustPlayerId: '',
    adjustAmount: '',
    adjustReason: '',
  },
};

function resetDemo() {
  state.tab = 'game';
  state.view = 'main';
  state.statsMode = 'all';
  state.entryMode = 'single';
  state.cashflowFilter = 'all';
  state.sheet = null;
  state.searchActive = false;
  state.searchQuery = '';
  state.selectedHistoryId = '';
  state.users = [{ id: 'u_host', name: '我', color: colors[0] }];
  state.activeSession = null;
  state.settledSessions = [];
  resetCreateDraft();
  resetEntryDraft();
  render();
}

function resetCreateDraft() {
  state.draft = {
    title: '今天的牌局',
    basePoint: 10,
    players: [
      { name: '我', buyIn: '' },
      { name: '', buyIn: '' },
      { name: '', buyIn: '' },
      { name: '', buyIn: '' },
    ],
  };
}

function resetEntryDraft() {
  const firstId = state.activeSession?.players[0]?.id || '';
  state.entryDraft = {
    winnerId: firstId,
    singleAmount: '',
    payerId: firstId,
    aaAmount: '',
    aaNote: '',
    adjustPlayerId: firstId,
    adjustAmount: '',
    adjustReason: '',
  };
}

function seedActive() {
  ensureFriend('阿林');
  ensureFriend('老周');
  ensureFriend('小何');
  const players = ['我', '阿林', '老周', '小何'].map((name) => {
    const user = ensureFriend(name);
    return { id: user.id, buyIn: 200 };
  });
  state.activeSession = makeSession('今晚南山局', players, 'active');
  state.activeSession.rounds = [
    makeRound('single', { [players[0].id]: 84, [players[1].id]: -28, [players[2].id]: -28, [players[3].id]: -28 }, '我 单家收分，老周/阿林/小何各 -28'),
    makeRound('aa', { [players[0].id]: -12, [players[1].id]: 36, [players[2].id]: -12, [players[3].id]: -12 }, '茶水 AA，阿林付款，4 人平摊'),
    makeRound('adjust', { [players[0].id]: -16, [players[2].id]: 16 }, '手动调整，修正老周入账'),
  ];
  resetEntryDraft();
  state.tab = 'game';
  state.view = 'main';
  toast('已载入进行中牌局');
  render();
}

function seedHistory() {
  seedActive();
  closeBook(false);
  const playerNames = ['我', '陈姐', '王哥', '阿敏'];
  playerNames.slice(1).forEach(ensureFriend);
  const players = playerNames.map((name) => ({ id: ensureFriend(name).id, buyIn: 200 }));
  const session = makeSession('午后茶楼局', players, 'settled');
  session.createdAt = now() - 1000 * 60 * 60 * 24 * 4;
  session.settledAt = session.createdAt + 1000 * 60 * 60 * 2;
  session.rounds = [
    makeRound('single', { [players[2].id]: 96, [players[0].id]: -32, [players[1].id]: -32, [players[3].id]: -32 }, '王哥 单家收分'),
    makeRound('aa', { [players[1].id]: 45, [players[0].id]: -15, [players[2].id]: -15, [players[3].id]: -15 }, '包间 AA，陈姐付款'),
  ];
  state.settledSessions.push(session);
  state.view = 'main';
  state.tab = 'stats';
  state.statsMode = 'history';
  toast('已载入封账历史');
  render();
}

function makeSession(title, players, status) {
  return {
    id: uid('s'),
    title,
    basePoint: 10,
    note: '线下离线牌局',
    players,
    rounds: [],
    createdAt: now(),
    settledAt: status === 'settled' ? now() : 0,
    status,
  };
}

function makeRound(type, scores, note) {
  return {
    id: uid('r'),
    type,
    scores,
    note,
    createdAt: now(),
    voided: false,
  };
}

function ensureFriend(name) {
  const normalized = name.trim().toLowerCase();
  let user = state.users.find((item) => item.name.trim().toLowerCase() === normalized);
  if (!user) {
    user = { id: uid('u'), name: name.trim(), color: colors[state.users.length % colors.length] };
    state.users.push(user);
  }
  return user;
}

function createSession() {
  const title = state.draft.title.trim() || '今天的牌局';
  const rows = state.draft.players.map((row) => ({ name: row.name.trim(), buyIn: Number(row.buyIn) }));
  if (rows.some((row) => !row.name || Number.isNaN(row.buyIn) || row.buyIn < 0)) {
    toast('请补齐四位牌友和非负入场金额');
    return;
  }
  const names = rows.map((row) => row.name.trim().toLowerCase());
  if (new Set(names).size !== names.length) {
    toast('同一场牌局不能重复选择牌友');
    return;
  }
  const players = rows.map((row) => {
    const user = ensureFriend(row.name);
    return { id: user.id, buyIn: row.buyIn };
  });
  state.activeSession = makeSession(title, players, 'active');
  state.view = 'main';
  state.tab = 'game';
  resetEntryDraft();
  resetCreateDraft();
  toast('牌局已创建，可以开始记账');
  render();
}

function addRound() {
  const session = state.activeSession;
  if (!session) return;
  let round;
  if (state.entryMode === 'single') {
    const amount = Number(state.entryDraft.singleAmount);
    const winnerId = state.entryDraft.winnerId;
    if (!winnerId || Number.isNaN(amount) || amount <= 0) {
      toast('请选择赢家并输入每位输分');
      return;
    }
    const losers = session.players.filter((player) => player.id !== winnerId);
    const scores = Object.fromEntries(session.players.map((player) => [player.id, player.id === winnerId ? amount * losers.length : -amount]));
    round = makeRound('single', scores, `${userName(winnerId)} 单家收分，每位输分 ${amount}`);
  } else if (state.entryMode === 'aa') {
    const amount = Number(state.entryDraft.aaAmount);
    const payerId = state.entryDraft.payerId;
    if (!payerId || Number.isNaN(amount) || amount <= 0) {
      toast('请选择付款人并输入开销总额');
      return;
    }
    const share = amount / session.players.length;
    const scores = Object.fromEntries(session.players.map((player) => [player.id, player.id === payerId ? amount - share : -share]));
    const note = state.entryDraft.aaNote.trim() || '共同开销';
    round = makeRound('aa', scores, `${note} AA，${userName(payerId)}付款，${session.players.length} 人平摊`);
  } else {
    const amount = Number(state.entryDraft.adjustAmount);
    const targetId = state.entryDraft.adjustPlayerId;
    if (!targetId || Number.isNaN(amount) || amount === 0) {
      toast('请选择调整对象并输入非 0 金额');
      return;
    }
    const hostId = state.currentUserId;
    if (targetId === hostId) {
      const other = session.players.find((player) => player.id !== hostId)?.id;
      round = makeRound('adjust', { [hostId]: amount, [other]: -amount }, `手动调整：${state.entryDraft.adjustReason || '未填写原因'}`);
    } else {
      round = makeRound('adjust', { [targetId]: amount, [hostId]: -amount }, `手动调整：${state.entryDraft.adjustReason || '未填写原因'}`);
    }
  }
  session.rounds.unshift(round);
  resetEntryDraft();
  toast('已写入进出账流水');
  render();
}

function voidRound(roundId) {
  const round = state.activeSession?.rounds.find((item) => item.id === roundId);
  if (round) {
    round.voided = true;
    toast('流水已撤回，账面已重新计算');
    render();
  }
}

function closeBook(showDone = true) {
  if (!state.activeSession) return;
  const session = state.activeSession;
  session.status = 'settled';
  session.settledAt = now();
  state.settledSessions.unshift(session);
  state.activeSession = null;
  state.sheet = null;
  state.view = showDone ? 'settlementDone' : 'main';
  state.tab = 'game';
  render();
}

function balances(session = state.activeSession) {
  const result = {};
  if (!session) return result;
  session.players.forEach((player) => {
    result[player.id] = 0;
  });
  session.rounds.filter((round) => !round.voided).forEach((round) => {
    Object.entries(round.scores).forEach(([id, value]) => {
      result[id] = (result[id] || 0) + value;
    });
  });
  return result;
}

function userName(id) {
  return state.users.find((user) => user.id === id)?.name || '玩家';
}

function userColor(id) {
  return state.users.find((user) => user.id === id)?.color || colors[0];
}

function money(value) {
  const rounded = Math.round(value * 100) / 100;
  if (rounded > 0) return `+${formatNumber(rounded)}`;
  if (rounded < 0) return `${formatNumber(rounded)}`;
  return '0';
}

function formatNumber(value) {
  return Number.isInteger(value) ? `${value}` : value.toFixed(2);
}

function moneyClass(value) {
  if (value > 0) return 'positive';
  if (value < 0) return 'negative';
  return 'neutral';
}

function totalBuyIn(session = state.activeSession) {
  return session ? session.players.reduce((sum, player) => sum + Number(player.buyIn || 0), 0) : 0;
}

function winner(session) {
  const b = balances(session);
  return session?.players.reduce((best, player) => (b[player.id] > b[best.id] ? player : best), session.players[0]);
}

function loser(session) {
  const b = balances(session);
  return session?.players.reduce((worst, player) => (b[player.id] < b[worst.id] ? player : worst), session.players[0]);
}

function visibleRounds() {
  const rounds = state.activeSession?.rounds || [];
  return rounds.filter((round) => !round.voided && (state.cashflowFilter === 'all' || round.type === state.cashflowFilter));
}

function transferPlan(session = state.activeSession) {
  const b = balances(session);
  const debtors = session.players.map((p) => ({ id: p.id, amount: -b[p.id] })).filter((x) => x.amount > 0).sort((a, b) => b.amount - a.amount);
  const creditors = session.players.map((p) => ({ id: p.id, amount: b[p.id] })).filter((x) => x.amount > 0).sort((a, b) => b.amount - a.amount);
  const rows = [];
  let d = 0;
  let c = 0;
  while (d < debtors.length && c < creditors.length) {
    const amount = Math.min(debtors[d].amount, creditors[c].amount);
    rows.push({ from: debtors[d].id, to: creditors[c].id, amount });
    debtors[d].amount -= amount;
    creditors[c].amount -= amount;
    if (debtors[d].amount <= 0.001) d += 1;
    if (creditors[c].amount <= 0.001) c += 1;
  }
  return rows;
}

function dateText(ts) {
  const date = new Date(ts);
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function timeText(ts) {
  const date = new Date(ts);
  return `${`${date.getHours()}`.padStart(2, '0')}:${`${date.getMinutes()}`.padStart(2, '0')}`;
}

function toast(message) {
  state.toast = message;
  clearTimeout(window.__toastTimer);
  window.__toastTimer = setTimeout(() => {
    state.toast = '';
    render();
  }, 1800);
}

function shell(content, nav = true) {
  return `
    <div class="screen">
      <div class="screen-scroll">
        <div class="status-bar"><span>20:08</span><span>5G 86%</span></div>
        ${content}
      </div>
      ${nav ? bottomNav() : ''}
      ${state.sheet ? renderSheet() : ''}
      ${state.toast ? `<div class="toast">${state.toast}</div>` : ''}
    </div>
  `;
}

function header(title, backAction = '') {
  return `
    <header class="page-header">
      ${backAction ? `<button class="back-button pressable" data-action="${backAction}" aria-label="返回"><svg><use href="#icon-back"></use></svg></button>` : ''}
      <h1>${title}</h1>
    </header>
  `;
}

function bottomNav() {
  const tabs = [
    ['game', '牌局', 'icon-game'],
    ['stats', '统计', 'icon-stats'],
    ['friends', '牌友', 'icon-friends'],
    ['mine', '我的', 'icon-mine'],
  ];
  return `<nav class="glass-nav">${tabs.map(([id, label, icon]) => `
    <button class="nav-item ${state.tab === id ? 'active' : ''}" data-tab="${id}">
      <svg><use href="#${icon}"></use></svg><span>${label}</span>
    </button>`).join('')}</nav>`;
}

function render() {
  if (state.view === 'create') {
    $app.innerHTML = shell(renderCreate(), false);
  } else if (state.view === 'settlement') {
    $app.innerHTML = shell(renderSettlement(), false);
  } else if (state.view === 'settlementDone') {
    $app.innerHTML = shell(renderSettlementDone(), false);
  } else if (state.view === 'historyDetail') {
    $app.innerHTML = shell(renderHistoryDetail(), false);
  } else if (state.searchActive) {
    $app.innerHTML = shell(renderFriendSearch(), false);
  } else if (state.tab === 'game') {
    $app.innerHTML = shell(renderGame());
  } else if (state.tab === 'stats') {
    $app.innerHTML = shell(renderStats());
  } else if (state.tab === 'friends') {
    $app.innerHTML = shell(renderFriends());
  } else {
    $app.innerHTML = shell(renderMine());
  }
}

function renderGame() {
  if (!state.activeSession) {
    return `
      ${header('牌局')}
      <button class="card create-card pressable" data-action="open-create">
        <span class="create-card-icon"><svg><use href="#icon-add"></use></svg></span>
        <strong>点击此处开启一场牌局</strong>
        <p>设置牌友和入场金额后，就可以开始记录输赢、开销和调整。</p>
      </button>
      ${state.settledSessions.length ? latestClosedCard() : ''}
    `;
  }
  return `
    ${header(state.activeSession.title)}
    ${gameSetup()}
    ${balanceBoard(state.activeSession)}
    ${entryPanel()}
    ${cashflowBlock()}
  `;
}

function gameSetup() {
  const s = state.activeSession;
  return `
    <section class="game-setup">
      <div class="section-title"><h2>牌友和入场金额</h2><span>总入场 ${totalBuyIn(s)}</span></div>
      <div class="player-chips">
        ${s.players.map((player) => `<div class="player-chip"><strong>${userName(player.id)}</strong><em>${player.buyIn}</em></div>`).join('')}
      </div>
      <div class="button-row">
        <button class="secondary-action" data-action="open-edit">编辑</button>
        <button class="primary-action" data-action="open-settlement">结算</button>
      </div>
    </section>
  `;
}

function balanceBoard(session) {
  const b = balances(session);
  return `
    <section class="balance-board">
      <div class="section-title"><h2>当前账面</h2><span>从有效流水派生</span></div>
      <div class="balance-grid">
        ${session.players.map((player) => `
          <article class="balance-cell">
            <span>${userName(player.id)}</span>
            <strong class="${moneyClass(b[player.id])}">${money(b[player.id])}</strong>
          </article>`).join('')}
      </div>
    </section>
  `;
}

function entryPanel() {
  const s = state.activeSession;
  const b = balances(s);
  return `
    <section class="entry-panel">
      <div class="section-title"><h2>记账输入</h2><span>合计校验为 0</span></div>
      <div class="segmented" style="--count: 3">
        ${entryTab('single', '单家收分')}
        ${entryTab('aa', 'AA 开销')}
        ${entryTab('adjust', '手动调整')}
      </div>
      <article class="entry-card">
        ${state.entryMode === 'single' ? singleForm(s) : state.entryMode === 'aa' ? aaForm(s) : adjustForm(s)}
        <div class="tags">
          ${s.players.map((player) => `<span>${userName(player.id)} ${money(b[player.id])}</span>`).join('')}
        </div>
        <button class="primary-action" data-action="add-round">${state.entryMode === 'single' ? '记一笔' : state.entryMode === 'aa' ? '平摊记账' : '保存调整'}</button>
      </article>
    </section>
  `;
}

function entryTab(id, label) {
  return `<button class="${state.entryMode === id ? 'active' : ''}" data-entry-mode="${id}">${label}</button>`;
}

function playerOptions(selected) {
  return state.activeSession.players.map((player) => `<option value="${player.id}" ${selected === player.id ? 'selected' : ''}>${userName(player.id)}</option>`).join('');
}

function singleForm() {
  return `
    <h3>单家收分</h3>
    <p>选择赢家，输入每位输家的分数，系统自动生成平衡流水。</p>
    <div class="form-grid">
      <label class="field"><span>收分牌友</span><select data-bind="entry.winnerId">${playerOptions(state.entryDraft.winnerId)}</select></label>
      <label class="field"><span>每位输分</span><input data-bind="entry.singleAmount" value="${state.entryDraft.singleAmount}" inputmode="decimal" placeholder="例如 28" /></label>
    </div>
  `;
}

function aaForm() {
  return `
    <h3>AA 开销</h3>
    <p>茶水、包间、外卖等共同支出，选择付款人后自动按四人平摊。</p>
    <div class="form-grid">
      <label class="field"><span>付款人</span><select data-bind="entry.payerId">${playerOptions(state.entryDraft.payerId)}</select></label>
      <label class="field"><span>总金额</span><input data-bind="entry.aaAmount" value="${state.entryDraft.aaAmount}" inputmode="decimal" placeholder="例如 48" /></label>
    </div>
    <label class="field"><span>备注</span><input data-bind="entry.aaNote" value="${state.entryDraft.aaNote}" placeholder="茶水 / 包间 / 外卖" /></label>
  `;
}

function adjustForm() {
  return `
    <h3>手动调整</h3>
    <p>用于修正录错、补录或特殊约定，流水中会保留调整原因。</p>
    <div class="form-grid">
      <label class="field"><span>调整对象</span><select data-bind="entry.adjustPlayerId">${playerOptions(state.entryDraft.adjustPlayerId)}</select></label>
      <label class="field"><span>调整金额</span><input data-bind="entry.adjustAmount" value="${state.entryDraft.adjustAmount}" inputmode="decimal" placeholder="-20 / 20" /></label>
    </div>
    <label class="field"><span>原因</span><input data-bind="entry.adjustReason" value="${state.entryDraft.adjustReason}" placeholder="修正上一笔录入" /></label>
  `;
}

function cashflowBlock() {
  return `
    <section class="section-block">
      <div class="section-title"><h2>进出账流水</h2><button data-action="cycle-filter">筛选：${filterText()}</button></div>
      ${visibleRounds().length ? `<div class="list">${visibleRounds().map(roundRow).join('')}</div>` : emptyState('暂无流水', '保存记账后会在这里显示，可按类型筛选或撤回。')}
    </section>
  `;
}

function filterText() {
  return { all: '全部', single: '收分', aa: '开销', adjust: '调整' }[state.cashflowFilter];
}

function roundRow(round) {
  const hostScore = round.scores[state.currentUserId] || 0;
  return `
    <article class="list-row actionable">
      <div class="list-row-main"><h3>${roundTitle(round)}</h3><p>${timeText(round.createdAt)} · ${round.note}</p></div>
      <strong class="money ${moneyClass(hostScore)}">${money(hostScore)}</strong>
      <button class="void-button" data-void="${round.id}" aria-label="撤回流水"><svg><use href="#icon-trash"></use></svg></button>
    </article>
  `;
}

function roundTitle(round) {
  return { single: '单家收分', aa: 'AA 开销', adjust: '手动调整' }[round.type];
}

function renderCreate() {
  return `
    ${header('新建牌局', 'back-main')}
    <section class="card">
      <h2>先把这场局搭起来</h2>
      <p class="hint">牌友 1 固定为“我”，其他牌友可以输入新名字，保存后会自动成为本地牌友。</p>
    </section>
    <section class="card">
      <div class="section-title"><h2>牌局信息</h2></div>
      <label class="field"><span>牌局名称</span><input data-bind="draft.title" value="${state.draft.title}" /></label>
    </section>
    <section class="card">
      <div class="section-title"><h2>牌友和入场金额</h2><span>4 人</span></div>
      <div class="player-form">
        ${state.draft.players.map((player, index) => createPlayerRow(player, index)).join('')}
      </div>
    </section>
    <button class="primary-action" data-action="create-session">开始记账</button>
  `;
}

function createPlayerRow(player, index) {
  const name = index === 0
    ? `<div class="fixed-name">我</div>`
    : `<div class="player-input"><input data-bind="draft.players.${index}.name" value="${player.name}" placeholder="输入或选择牌友" /><button class="picker-trigger" data-picker="${index}">⌄</button></div>`;
  return `
    <div class="player-row">
      <span>牌友${index + 1}</span>
      ${name}
      <input data-bind="draft.players.${index}.buyIn" value="${player.buyIn}" inputmode="decimal" placeholder="金额" />
    </div>
  `;
}

function renderSettlement() {
  const s = state.activeSession;
  if (!s) return `${header('结算', 'back-main')}${emptyState('暂无进行中牌局', '请先创建或载入一场牌局。')}`;
  const b = balances(s);
  const w = winner(s);
  return `
    ${header(s.title, 'back-main')}
    <section class="card winner-card">
      <span>大赢家</span>
      <h2>${userName(w.id)}</h2>
      <strong class="money ${moneyClass(b[w.id])}">${money(b[w.id])}</strong>
      <p class="hint">当前账面已由有效流水重新计算。</p>
    </section>
    <section class="section-block">
      <div class="section-title"><h2>整场统计</h2><span>4 人</span></div>
      <div class="settle-grid">
        <article class="settle-cell"><span>总入场</span><strong>${totalBuyIn(s)}</strong></article>
        <article class="settle-cell"><span>流水</span><strong>${s.rounds.filter((r) => !r.voided).length} 笔</strong></article>
        <article class="settle-cell"><span>AA 开销</span><strong>${s.rounds.filter((r) => !r.voided && r.type === 'aa').length} 笔</strong></article>
        <article class="settle-cell"><span>调整</span><strong>${s.rounds.filter((r) => !r.voided && r.type === 'adjust').length} 笔</strong></article>
      </div>
    </section>
    <section class="section-block">
      <div class="section-title"><h2>应收应付</h2></div>
      <div class="list">${s.players.map((p) => `<article class="list-row"><div class="list-row-main"><h3>${userName(p.id)}</h3><p>入场 ${p.buyIn}</p></div><strong class="money ${moneyClass(b[p.id])}">${money(b[p.id])}</strong></article>`).join('')}</div>
    </section>
    <section class="section-block">
      <div class="section-title"><h2>最佳转账路径</h2><span>最少步骤</span></div>
      ${transferPlan(s).length ? `<div class="list">${transferPlan(s).map((row) => `<article class="list-row"><div class="list-row-main"><h3>${userName(row.from)} 付给 ${userName(row.to)}</h3><p>结清后双方账面归零</p></div><strong class="money">${formatNumber(row.amount)}</strong></article>`).join('')}</div>` : emptyState('无需转账', '当前账面已经平衡。')}
    </section>
    <div class="button-row"><button class="secondary-action" data-action="close-book">封账</button><button class="primary-action" data-action="back-main">返回牌局</button></div>
  `;
}

function renderSettlementDone() {
  const latest = state.settledSessions[0];
  const w = latest ? winner(latest) : null;
  const b = latest ? balances(latest) : {};
  return `
    ${header('封账完成', 'back-main')}
    <section class="card done-card">
      <p class="eyebrow">已归档到统计和历史</p>
      <h2>恭喜 ${w ? userName(w.id) : '我'} 成为本场大赢家</h2>
      <strong class="money positive">${w ? money(b[w.id]) : '+0'}</strong>
      <button class="primary-action" data-action="back-main">返回牌局</button>
    </section>
  `;
}

function renderStats() {
  return `
    ${header('统计')}
    <div class="segmented" style="--count: 2">
      <button class="${state.statsMode === 'all' ? 'active' : ''}" data-stats-mode="all">全部</button>
      <button class="${state.statsMode === 'history' ? 'active' : ''}" data-stats-mode="history">历史牌局</button>
    </div>
    ${state.statsMode === 'all' ? statsAll() : statsHistory()}
  `;
}

function statsAll() {
  const total = state.settledSessions.reduce((sum, s) => sum + (balances(s)[state.currentUserId] || 0), 0);
  const wins = state.settledSessions.filter((s) => (balances(s)[state.currentUserId] || 0) > 0).length;
  const rate = state.settledSessions.length ? Math.round((wins * 100) / state.settledSessions.length) : 0;
  return `
    <section class="summary-panel">
      <div><p>总输赢</p><strong class="${moneyClass(total)}">${money(total)}</strong></div>
      <div><p>胜率</p><strong>${rate}%</strong></div>
      <div><p>牌局数</p><strong>${state.settledSessions.length}</strong></div>
    </section>
    ${latestClosedCard()}
    <section class="section-block">
      <div class="section-title"><h2>整体走势</h2><span>已封账</span></div>
      <div class="chart">${trendBars()}</div>
    </section>
    <section class="section-block">
      <div class="section-title"><h2>胜率最高牌友</h2></div>
      ${friendRows().length ? `<div class="list">${friendRows().slice(0, 2).map(friendListRow).join('')}</div>` : emptyState('暂无牌友统计', '封账后会从历史牌局中派生。')}
    </section>
  `;
}

function latestClosedCard() {
  const latest = state.settledSessions[0];
  if (!latest) {
    return `<section class="section-block">${emptyState('暂无封账牌局', '封账后会进入统计和历史。')}</section>`;
  }
  const b = balances(latest);
  return `
    <section class="section-block">
      <div class="section-title"><h2>最近封账</h2><span>${dateText(latest.settledAt)}</span></div>
      <article class="list-row"><div class="list-row-main"><h3>${latest.title}</h3><p>赢家：${userName(winner(latest).id)} · 已归档</p></div><strong class="money ${moneyClass(b[state.currentUserId] || 0)}">${money(b[state.currentUserId] || 0)}</strong></article>
    </section>
  `;
}

function trendBars() {
  const items = state.settledSessions.slice(0, 6).reverse();
  if (!items.length) {
    return '<div class="empty-state" style="grid-column: 1 / -1"><strong>暂无走势</strong><p>封账后生成日期趋势。</p></div>';
  }
  const values = items.map((s) => balances(s)[state.currentUserId] || 0);
  const max = Math.max(1, ...values.map((v) => Math.abs(v)));
  return items.map((s, index) => {
    const height = 22 + Math.abs(values[index]) / max * 76;
    return `<div class="chart-bar"><i style="height:${height}%"></i><em>${dateText(s.settledAt)}</em></div>`;
  }).join('');
}

function statsHistory() {
  if (!state.settledSessions.length) return `<section class="section-block">${emptyState('暂无历史牌局', '封账后会在这里展示完整牌局卡片。')}</section>`;
  return `<div class="history-list">${state.settledSessions.map(historyCard).join('')}</div>`;
}

function historyCard(session) {
  const b = balances(session);
  return `
    <button class="history-card" data-history="${session.id}">
      <div class="history-head">
        <div><h3>${session.title}</h3><p>${dateText(session.settledAt)} · ${session.players.map((p) => userName(p.id)).join('、')}</p></div>
        <strong class="money ${moneyClass(b[state.currentUserId] || 0)}">${money(b[state.currentUserId] || 0)}</strong>
      </div>
      <div class="tags"><span>赢家 ${userName(winner(session).id)} ${money(b[winner(session).id])}</span><span>输家 ${userName(loser(session).id)} ${money(b[loser(session).id])}</span><span>入场 ${totalBuyIn(session)}</span></div>
    </button>
  `;
}

function renderHistoryDetail() {
  const session = state.settledSessions.find((item) => item.id === state.selectedHistoryId) || state.settledSessions[0];
  if (!session) return `${header('历史详情', 'back-stats')}${emptyState('暂无历史详情', '请先封账一场牌局。')}`;
  return `
    ${header(session.title, 'back-stats')}
    <section class="card">
      <div class="section-title"><h2>牌局概览</h2><span>已封账</span></div>
      <div class="tags"><span>${dateText(session.settledAt)}</span><span>${session.players.length} 人</span><span>${session.rounds.filter((r) => !r.voided).length} 笔流水</span></div>
      <p class="hint">大赢家：${userName(winner(session).id)} ${money(balances(session)[winner(session).id])}。参与人：${session.players.map((p) => userName(p.id)).join('、')}。</p>
    </section>
    ${balanceBoard(session)}
    <section class="section-block">
      <div class="section-title"><h2>进出账流水</h2><span>${session.rounds.filter((r) => !r.voided).length} 笔</span></div>
      <div class="list">${session.rounds.filter((r) => !r.voided).map((round) => `<article class="list-row"><div class="list-row-main"><h3>${roundTitle(round)}</h3><p>${timeText(round.createdAt)} · ${round.note}</p></div><strong class="money ${moneyClass(round.scores[state.currentUserId] || 0)}">${money(round.scores[state.currentUserId] || 0)}</strong></article>`).join('')}</div>
    </section>
  `;
}

function renderFriends() {
  return `
    ${header('牌友')}
    <button class="search-input pressable" data-action="open-search"><span>搜</span><input value="搜索牌友或牌局" readonly /></button>
    <section class="section-block">
      <div class="section-title"><h2>牌友列表</h2><span>${state.users.length - 1} 位</span></div>
      ${friendRows().length ? `<div class="list">${friendRows().map(friendListRow).join('')}</div>` : emptyState('暂无牌友', '创建牌局时输入新名字后会自动保存。')}
    </section>
  `;
}

function friendRows() {
  return state.users.filter((u) => u.id !== state.currentUserId).map((u) => {
    const sessions = state.settledSessions.filter((s) => s.players.some((p) => p.id === u.id));
    const total = sessions.reduce((sum, s) => sum + (balances(s)[u.id] || 0), 0);
    const wins = sessions.filter((s) => (balances(s)[u.id] || 0) > 0).length;
    return { user: u, count: sessions.length, rate: sessions.length ? Math.round(wins * 100 / sessions.length) : 0, total };
  });
}

function friendListRow(row) {
  return `
    <article class="list-row">
      <span class="avatar" style="background:${row.user.color}">${row.user.name.slice(0, 1)}</span>
      <div class="list-row-main"><h3>${row.user.name}</h3><p>对局 ${row.count} 次 · 同桌胜率 ${row.rate}%</p></div>
      <strong class="money ${moneyClass(row.total)}">${money(row.total)}</strong>
    </article>
  `;
}

function renderFriendSearch() {
  const q = state.searchQuery.trim();
  const friendResults = friendRows().filter((row) => row.user.name.includes(q));
  const gameResults = state.settledSessions.filter((s) => s.title.includes(q) || s.players.some((p) => userName(p.id).includes(q)));
  return `
    <div class="search-top">
      <label class="search-input" style="position: static; margin: 0"><span>搜</span><input data-bind="searchQuery" value="${state.searchQuery}" autofocus placeholder="搜索牌友或牌局" /></label>
      <button data-action="close-search">取消</button>
    </div>
    <section class="section-block">
      <div class="section-title"><h2>${q ? '搜索结果' : '最近搜索'}</h2><span>${q ? friendResults.length + gameResults.length : 3} 条</span></div>
      ${q ? searchResults(friendResults, gameResults) : '<div class="tags"><span>阿林</span><span>今晚南山局</span><span>老周</span></div>'}
    </section>
  `;
}

function searchResults(friendResults, gameResults) {
  const rows = [
    ...friendResults.map(friendListRow),
    ...gameResults.map((s) => `<article class="list-row"><span class="avatar" style="background:var(--blue)">局</span><div class="list-row-main"><h3>${s.title}</h3><p>${s.players.map((p) => userName(p.id)).join('、')}</p></div><strong class="money ${moneyClass(balances(s)[state.currentUserId] || 0)}">${money(balances(s)[state.currentUserId] || 0)}</strong></article>`),
  ];
  return rows.length ? `<div class="list">${rows.join('')}</div>` : emptyState('没有匹配结果', '换个关键词试试看。');
}

function renderMine() {
  const total = state.settledSessions.reduce((sum, s) => sum + (balances(s)[state.currentUserId] || 0), 0);
  const wins = state.settledSessions.filter((s) => (balances(s)[state.currentUserId] || 0) > 0).length;
  return `
    ${header('我的')}
    <section class="section-block">
      <div class="mine-grid">
        <article class="mine-cell"><span>总输赢</span><strong class="${moneyClass(total)}">${money(total)}</strong></article>
        <article class="mine-cell"><span>胜率</span><strong>${state.settledSessions.length ? Math.round(wins * 100 / state.settledSessions.length) : 0}%</strong></article>
        <article class="mine-cell"><span>总牌局</span><strong>${state.settledSessions.length}</strong></article>
        <article class="mine-cell"><span>最大单局</span><strong class="positive">${money(Math.max(0, ...state.settledSessions.map((s) => balances(s)[state.currentUserId] || 0)))}</strong></article>
        <article class="mine-cell"><span>平均时长</span><strong>2.4h</strong></article>
        <article class="mine-cell"><span>同桌牌友</span><strong>${state.users.length - 1}</strong></article>
      </div>
    </section>
    <section class="section-block settings-list">
      <button class="settings-row"><span>本地隐私模式</span><em>已开启</em></button>
      <button class="settings-row"><span>数据与备份</span><em>V1.5 预留</em></button>
      <button class="settings-row"><span>关于</span><em>雀账 v0.1</em></button>
    </section>
    <section class="section-block settings-list">
      <button class="settings-row danger" data-action="confirm-clear"><span>${state.sheet === 'clear' ? '确认清空所有数据' : '清空所有数据'}</span><em>不可恢复</em></button>
    </section>
  `;
}

function renderSheet() {
  if (state.sheet === 'friendPicker') return friendPickerSheet();
  if (state.sheet === 'edit') return editSheet();
  if (state.sheet === 'clear') return clearSheet();
  return '';
}

function friendPickerSheet() {
  const options = state.users.filter((user) => user.id !== state.currentUserId);
  return `
    <div class="sheet-backdrop" data-action="close-sheet">
      <section class="sheet" data-sheet>
        <div class="sheet-handle"></div>
        <h2>选择牌友</h2>
        ${options.length ? `<div class="list">${options.map((user) => `<button class="list-row actionable" data-select-friend="${user.id}"><span class="avatar" style="background:${user.color}">${user.name.slice(0, 1)}</span><div class="list-row-main"><h3>${user.name}</h3><p>选择已有本地牌友</p></div></button>`).join('')}</div>` : emptyState('目前暂时还没有牌友', '可以先直接输入新牌友名字，创建牌局后会自动保存。')}
      </section>
    </div>
  `;
}

function editSheet() {
  const s = state.activeSession;
  return `
    <div class="sheet-backdrop" data-action="close-sheet">
      <section class="sheet" data-sheet>
        <div class="sheet-handle"></div>
        <h2>编辑牌局</h2>
        <label class="field"><span>牌局名称</span><input data-bind="active.title" value="${s.title}" /></label>
        <div class="player-form">${s.players.map((player, index) => `
          <div class="player-row">
            <span>牌友${index + 1}</span>
            <input data-bind="active.players.${index}.name" value="${userName(player.id)}" />
            <input data-bind="active.players.${index}.buyIn" value="${player.buyIn}" inputmode="decimal" />
          </div>`).join('')}</div>
        <button class="primary-action" data-action="save-edit">保存</button>
      </section>
    </div>
  `;
}

function clearSheet() {
  return `
    <div class="sheet-backdrop" data-action="close-sheet">
      <section class="sheet" data-sheet>
        <div class="sheet-handle"></div>
        <h2>清空所有数据</h2>
        <p class="hint">这会清空本地牌友、进行中牌局、流水和封账历史。Web demo 中会恢复到首次启动状态。</p>
        <div class="button-row" style="margin-top: 16px">
          <button class="secondary-action" data-action="close-sheet">取消</button>
          <button class="danger-action" data-action="clear-data">确认清空</button>
        </div>
      </section>
    </div>
  `;
}

function emptyState(title, desc) {
  return `<div class="empty-state"><strong>${title}</strong><p>${desc}</p></div>`;
}

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action], [data-tab], [data-entry-mode], [data-stats-mode], [data-void], [data-picker], [data-select-friend], [data-history]');
  if (!target) return;
  if (event.target.closest('[data-sheet]') && target.dataset.action === 'close-sheet' && !target.matches('button')) return;
  if (target.dataset.tab) {
    state.tab = target.dataset.tab;
    state.view = 'main';
    state.searchActive = false;
  }
  if (target.dataset.entryMode) state.entryMode = target.dataset.entryMode;
  if (target.dataset.statsMode) state.statsMode = target.dataset.statsMode;
  if (target.dataset.void) voidRound(target.dataset.void);
  if (target.dataset.picker) {
    state.sheet = 'friendPicker';
    state.pickerIndex = Number(target.dataset.picker);
  }
  if (target.dataset.selectFriend) {
    const user = state.users.find((u) => u.id === target.dataset.selectFriend);
    if (user && Number.isInteger(state.pickerIndex)) {
      state.draft.players[state.pickerIndex].name = user.name;
    }
    state.sheet = null;
  }
  if (target.dataset.history) {
    state.selectedHistoryId = target.dataset.history;
    state.view = 'historyDetail';
  }
  handleAction(target.dataset.action);
  render();
});

function handleAction(action) {
  if (!action) return;
  const map = {
    'open-create': () => { state.view = 'create'; },
    'back-main': () => { state.view = 'main'; state.sheet = null; state.searchActive = false; },
    'back-stats': () => { state.view = 'main'; state.tab = 'stats'; state.statsMode = 'history'; },
    'create-session': createSession,
    'add-round': addRound,
    'cycle-filter': () => {
      const order = ['all', 'single', 'aa', 'adjust'];
      state.cashflowFilter = order[(order.indexOf(state.cashflowFilter) + 1) % order.length];
    },
    'open-edit': () => { state.sheet = 'edit'; },
    'open-settlement': () => { state.view = 'settlement'; },
    'close-book': () => closeBook(true),
    'open-search': () => { state.searchActive = true; },
    'close-search': () => { state.searchActive = false; state.searchQuery = ''; },
    'confirm-clear': () => { state.sheet = 'clear'; },
    'clear-data': resetDemo,
    'close-sheet': () => { state.sheet = null; },
    'save-edit': saveEdit,
    'seed-active': seedActive,
    'seed-history': seedHistory,
    'reset-demo': resetDemo,
  };
  map[action]?.();
}

document.addEventListener('input', (event) => {
  const input = event.target.closest('[data-bind]');
  if (!input) return;
  setPath(input.dataset.bind, input.value);
});

document.addEventListener('change', (event) => {
  const input = event.target.closest('[data-bind]');
  if (!input) return;
  setPath(input.dataset.bind, input.value);
  render();
});

function setPath(path, value) {
  const parts = path.split('.');
  if (parts[0] === 'draft') {
    if (parts[1] === 'players') state.draft.players[Number(parts[2])][parts[3]] = value;
    else state.draft[parts[1]] = value;
  } else if (parts[0] === 'entry') {
    state.entryDraft[parts[1]] = value;
  } else if (parts[0] === 'searchQuery') {
    state.searchQuery = value;
    render();
  } else if (parts[0] === 'active') {
    if (parts[1] === 'title') state.activeSession.title = value;
    if (parts[1] === 'players') {
      const index = Number(parts[2]);
      if (parts[3] === 'buyIn') state.activeSession.players[index].buyIn = Number(value) || 0;
      if (parts[3] === 'name') {
        const user = ensureFriend(value);
        state.activeSession.players[index].id = user.id;
      }
    }
  }
}

function saveEdit() {
  state.sheet = null;
  toast('编辑已保存，页面已刷新');
}

resetDemo();
