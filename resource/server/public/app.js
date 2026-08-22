/* ============================================================
   爸爸妈妈讲故事 - 前端应用
   ============================================================ */

// ========== 全局状态 ==========
const API_BASE = '/api';

const state = {
  token: localStorage.getItem('token') || '',
  tokenEpoch: 0, // 用于防止旧请求的 401/403 响应清除新 token
  user: null,
  currentPage: '',
  categories: [],
  stories: { page: 1, pageSize: 12, total: 0, list: [] },
  users: { page: 1, pageSize: 10, total: 0, list: [] },
  voices: { page: 1, pageSize: 10, total: 0, list: [] },
  myVoices: [],
  myAIStories: [],
  children: [],
  selectedCategory: null,
  storyFilter: { keyword: '', theme: '', status: '' },
  userFilter: { keyword: '', role: '', status: '' },
  voiceFilter: { status: '' },
  fileGroup: 'audio',
  fileList: [],
  favorites: [],
  history: [],
  playlists: [],
  currentStory: null,
  aiGeneratedStory: null,
};

// ========== 菜单配置 ==========
const ADMIN_MENU = [
  { id: 'admin-dashboard', icon: '📊', label: '数据概览' },
  { id: 'admin-stories', icon: '📚', label: '故事管理' },
  { id: 'admin-upload', icon: '📤', label: '上传故事' },
  { id: 'admin-categories', icon: '🏷️', label: '分类管理' },
  { id: 'admin-users', icon: '👥', label: '用户管理' },
  { id: 'admin-voices', icon: '🎙️', label: '声音模型' },
  { id: 'admin-files', icon: '📁', label: '文件管理' },
  { id: 'user-profile', icon: '👤', label: '个人中心' },
];

const USER_MENU = [
  { id: 'user-home', icon: '🏠', label: '故事首页' },
  { id: 'user-favorites', icon: '❤️', label: '我的收藏' },
  { id: 'user-history', icon: '🕐', label: '播放历史' },
  { id: 'user-ai', icon: '🤖', label: 'AI创作' },
  { id: 'user-voices', icon: '🎙️', label: '我的声音' },
  { id: 'user-playlists', icon: '📋', label: '播放列表' },
  { id: 'user-profile', icon: '👤', label: '个人中心' },
];

const pageLoaders = {};

// ========== 工具函数 ==========

function escapeHtml(str) {
  if (str == null) return '';
  const div = document.createElement('div');
  div.textContent = String(str);
  return div.innerHTML;
}

function fmtDate(iso) {
  if (!iso) return '-';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '-';
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function fmtDateShort(iso) {
  if (!iso) return '-';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '-';
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function parseJsonField(val, fallback) {
  if (val == null) return fallback;
  if (typeof val === 'object') return val;
  try {
    return JSON.parse(val);
  } catch (e) {
    return fallback;
  }
}

function statusBadge(status) {
  const map = {
    active: { text: '正常', cls: 'badge-success' },
    inactive: { text: '禁用', cls: 'badge-danger' },
    banned: { text: '封禁', cls: 'badge-danger' },
    pending: { text: '待审核', cls: 'badge-warning' },
    published: { text: '已发布', cls: 'badge-success' },
    draft: { text: '草稿', cls: 'badge-secondary' },
    recording: { text: '录音中', cls: 'badge-warning' },
    training: { text: '训练中', cls: 'badge-warning' },
    ready: { text: '就绪', cls: 'badge-success' },
    failed: { text: '失败', cls: 'badge-danger' },
    processing: { text: '处理中', cls: 'badge-warning' },
    completed: { text: '已完成', cls: 'badge-success' },
  };
  const s = map[status] || { text: status || '未知', cls: 'badge-secondary' };
  return `<span class="badge ${s.cls}">${s.text}</span>`;
}

function themeLabel(theme) {
  const map = {
    adventure: '冒险', fantasy: '奇幻', animal: '动物', animals: '动物', friendship: '友谊',
    family: '家庭', science: '科学', bedtime: '睡前', fable: '寓言',
    courage: '勇气', magic: '魔法', custom: '自定义',
  };
  return map[theme] || theme || '-';
}

function ageLabel(age) {
  const map = {
    '0-3': '0-3岁', '3-6': '3-6岁', '6-9': '6-9岁', '9-12': '9-12岁', 'all': '全年龄',
    'toddler': '0-3岁', 'preschool': '3-6岁', 'earlyElementary': '6-9岁',
  };
  return map[age] || age || '-';
}

function ownerTypeLabel(type) {
  const map = { system: '系统', user: '用户', ai: 'AI生成', mom: '妈妈', dad: '爸爸', child: '孩子', custom: '自定义', female: '女声', male: '男声' };
  return map[type] || type || '-';
}

function fmtFileSize(bytes) {
  if (!bytes && bytes !== 0) return '-';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let n = bytes;
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
  return n.toFixed(i === 0 ? 0 : 1) + ' ' + units[i];
}

function renderPagination(pagination, onPageChange) {
  const { page, pageSize, total, totalPages } = pagination;
  if (totalPages <= 1) return '';
  let html = '<div class="pagination">';
  html += `<button class="page-btn" ${page <= 1 ? 'disabled' : ''} data-page="${page - 1}">上一页</button>`;
  const maxBtns = 7;
  let start = Math.max(1, page - 3);
  let end = Math.min(totalPages, start + maxBtns - 1);
  start = Math.max(1, end - maxBtns + 1);
  for (let i = start; i <= end; i++) {
    html += `<button class="page-btn ${i === page ? 'active' : ''}" data-page="${i}">${i}</button>`;
  }
  html += `<button class="page-btn" ${page >= totalPages ? 'disabled' : ''} data-page="${page + 1}">下一页</button>`;
  html += `<span class="page-info">共 ${total} 条，第 ${page}/${totalPages} 页</span>`;
  html += '</div>';
  return html;
}

// ========== Toast ==========
function toast(message, type = 'info', duration = 3000) {
  const container = document.getElementById('toastContainer');
  const el = document.createElement('div');
  const iconMap = { success: '✅', error: '❌', warning: '⚠️', info: 'ℹ️' };
  el.className = `toast toast-${type}`;
  el.innerHTML = `<span class="toast-icon">${iconMap[type] || 'ℹ️'}</span><span>${escapeHtml(message)}</span>`;
  container.appendChild(el);
  requestAnimationFrame(() => el.classList.add('show'));
  setTimeout(() => {
    el.classList.remove('show');
    setTimeout(() => el.remove(), 300);
  }, duration);
}

// ========== Modal ==========
let modalCallback = null;

function openModal(title, bodyHtml, onOk, okText = '确定') {
  document.getElementById('modalTitle').textContent = title;
  document.getElementById('modalBody').innerHTML = bodyHtml;
  const okBtn = document.getElementById('modalOkBtn');
  okBtn.textContent = okText;
  modalCallback = onOk;
  document.getElementById('genericModal').classList.add('active');
}

function closeModal(id) {
  const m = document.getElementById(id || 'genericModal');
  if (m) m.classList.remove('active');
  modalCallback = null;
}

// ========== Confirm Dialog ==========
let confirmCallback = null;

function showConfirm(message, onOk, title = '确认操作', okText = '确认') {
  document.getElementById('confirmTitle').textContent = title;
  document.getElementById('confirmMessage').textContent = message;
  const okBtn = document.getElementById('confirmOkBtn');
  okBtn.textContent = okText;
  confirmCallback = onOk;
  document.getElementById('confirmDialog').classList.add('active');
}

// ========== API 请求封装 ==========
// 不需要携带 token 的公开接口
const NO_AUTH_PATHS = ['/auth/login', '/auth/register', '/auth/send-code', '/auth/phone-login', '/auth/wechat-login'];

async function api(path, options = {}) {
  const url = API_BASE + path;
  const opts = {
    method: options.method || 'GET',
    headers: {},
  };
  // 登录/注册等公开接口不附加 Authorization 头，避免旧 token 干扰
  const isAuthEndpoint = NO_AUTH_PATHS.some(p => path === p);
  if (state.token && !isAuthEndpoint) {
    opts.headers['Authorization'] = 'Bearer ' + state.token;
  }
  if (options.body instanceof FormData) {
    opts.body = options.body;
  } else if (options.body !== undefined) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(options.body);
  }
  if (options.params) {
    const qs = new URLSearchParams();
    Object.entries(options.params).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== '') qs.append(k, v);
    });
    const qsStr = qs.toString();
    if (qsStr) opts.url = url + '?' + qsStr;
  }
  const finalUrl = opts.url || url;
  delete opts.url;

  // 记录请求发起时的 token epoch，用于防止旧请求的 401/403 清除新 token
  const requestEpoch = state.tokenEpoch;

  try {
    const res = await fetch(finalUrl, opts);
    const ct = res.headers.get('content-type') || '';
    if (res.status === 401) {
      // 登录/注册接口的 401 是凭据错误，不是 token 过期
      if (isAuthEndpoint) {
        const data = ct.includes('application/json') ? await res.json().catch(() => ({})) : {};
        toast(data.message || '登录失败', 'error');
        return null;
      }
      // 只有 token epoch 未变时才 logout，避免旧请求干扰新登录
      if (requestEpoch === state.tokenEpoch) {
        toast('登录已过期，请重新登录', 'warning');
        logout();
      }
      return null;
    }
    if (res.status === 403) {
      const data = ct.includes('application/json') ? await res.json().catch(() => ({})) : {};
      // 只有 token epoch 未变时才 logout
      if (requestEpoch === state.tokenEpoch) {
        toast(data.message || '该账号已被禁用', 'error');
        logout();
      }
      return null;
    }
    if (ct.includes('application/json')) {
      const data = await res.json();
      if (data.code !== undefined && data.code !== 0) {
        toast(data.message || '请求失败', 'error');
        return null;
      }
      // 成功响应：data 为 null/undefined 时返回 true（表示成功但无数据），否则返回 data
      return data.data != null ? data.data : true;
    }
    return res;
  } catch (err) {
    toast('网络错误: ' + err.message, 'error');
    return null;
  }
}

// ========== 认证 ==========
function logout() {
  state.token = '';
  state.tokenEpoch++; // 递增 epoch，使旧请求的 401/403 不再触发 logout
  state.user = null;
  localStorage.removeItem('token');
  document.getElementById('appLayout').style.display = 'none';
  document.getElementById('appLayout').classList.remove('active');
  const authPage = document.getElementById('authPage');
  authPage.style.display = 'flex';
  authPage.classList.add('visible');
  document.getElementById('loginForm').reset();
  document.getElementById('registerForm').reset();
  document.getElementById('loginError').textContent = '';
  document.getElementById('registerError').textContent = '';
  switchAuthTab('login');
}

async function login(email, password) {
  const data = await api('/auth/login', { method: 'POST', body: { email, password } });
  if (data && data.token) {
    state.token = data.token;
    state.tokenEpoch++; // 新 token，递增 epoch 使旧请求失效
    localStorage.setItem('token', data.token);
    state.user = data.user || null;
    toast('登录成功', 'success');
    await initApp();
    return true;
  }
  return false;
}

async function register(email, password, nickname) {
  const data = await api('/auth/register', { method: 'POST', body: { email, password, nickname } });
  if (data && data.token) {
    state.token = data.token;
    state.tokenEpoch++;
    localStorage.setItem('token', data.token);
    state.user = data.user || null;
    toast('注册成功', 'success');
    await initApp();
    return true;
  }
  return false;
}

async function checkAuth() {
  if (!state.token) return false;
  const data = await api('/auth/me');
  if (data) {
    state.user = data;
    return true;
  }
  return false;
}

// ========== 认证标签切换 ==========
function switchAuthTab(tab) {
  document.querySelectorAll('.auth-tab').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  document.getElementById('loginForm').style.display = tab === 'login' ? '' : 'none';
  document.getElementById('registerForm').style.display = tab === 'register' ? '' : 'none';
  document.getElementById('loginError').textContent = '';
  document.getElementById('registerError').textContent = '';
}

// ========== 初始化应用 ==========
async function initApp() {
  const authPage = document.getElementById('authPage');
  authPage.style.display = 'none';
  authPage.classList.remove('visible');
  const appLayout = document.getElementById('appLayout');
  appLayout.style.display = 'flex';
  appLayout.classList.add('active');

  const menu = state.user.role === 'admin' ? ADMIN_MENU : USER_MENU;
  renderSidebar(menu);
  renderUserHeader();

  if (state.user.role === 'admin') {
    renderAdminPages();
  } else {
    renderUserPages();
  }

  // 个人中心页面（管理员和普通用户都可用）
  registerProfilePage();

  // 加载分类
  const cats = await api('/stories/categories');
  state.categories = cats || [];

  // 导航到第一个页面
  const firstPage = menu[0].id;
  navigateTo(firstPage);
}

function renderSidebar(menu) {
  const el = document.getElementById('sidebarMenu');
  el.innerHTML = menu.map(item =>
    `<a class="menu-item" data-page="${item.id}" href="javascript:void(0)">
      <span class="menu-icon">${item.icon}</span>
      <span class="menu-label">${item.label}</span>
    </a>`
  ).join('');
  el.querySelectorAll('.menu-item').forEach(a => {
    a.addEventListener('click', () => navigateTo(a.dataset.page));
  });
}

function renderUserHeader() {
  const u = state.user;
  document.getElementById('userName').textContent = u.nickname || u.email || '用户';
  document.getElementById('userAvatar').textContent = (u.nickname || u.email || 'U').charAt(0).toUpperCase();
  const badge = document.getElementById('userRoleBadge');
  if (u.role === 'admin') {
    badge.textContent = '管理员';
    badge.className = 'role-badge role-admin';
  } else {
    const tier = u.membershipTier || 'free';
    const tierMap = { free: '普通会员', premium: '高级会员', vip: 'VIP会员' };
    badge.textContent = tierMap[tier] || '普通用户';
    badge.className = 'role-badge role-user';
  }
}

function navigateTo(pageId) {
  state.currentPage = pageId;
  // 更新菜单激活状态
  document.querySelectorAll('.menu-item').forEach(a => {
    a.classList.toggle('active', a.dataset.page === pageId);
  });
  // 更新标题
  const menu = state.user.role === 'admin' ? ADMIN_MENU : USER_MENU;
  const item = menu.find(m => m.id === pageId);
  document.getElementById('headerTitle').textContent = item ? item.label : '';
  // 加载页面内容
  const main = document.getElementById('mainContent');
  if (pageLoaders[pageId]) {
    pageLoaders[pageId](main);
  } else {
    main.innerHTML = '<div class="empty-state">页面开发中...</div>';
  }
}

// ========== 故事卡片渲染 ==========
function renderStoryCard(s) {
  const gradient = parseJsonField(s.coverGradient, ['#667eea', '#764ba2']);
  const bg = `linear-gradient(135deg, ${gradient[0]}, ${gradient[1]})`;
  const emoji = s.coverEmoji || '📖';
  const isFav = state.favorites.some(f => f.id === s.id || f.storyId === s.id);
  return `
    <div class="story-card" data-story-id="${s.id}">
      <div class="story-cover" style="background:${bg}">
        <span class="story-emoji">${escapeHtml(emoji)}</span>
        <button class="fav-btn ${isFav ? 'faved' : ''}" data-story-id="${s.id}" title="收藏">
          ${isFav ? '❤️' : '🤍'}
        </button>
      </div>
      <div class="story-info">
        <div class="story-title">${escapeHtml(s.title)}</div>
        <div class="story-summary">${escapeHtml(s.summary || '')}</div>
        <div class="story-meta">
          <span>${themeLabel(s.theme)}</span>
          <span>${ageLabel(s.targetAgeGroup || s.targetAge)}</span>
          <span>▶ ${s.playCount || 0}</span>
        </div>
      </div>
    </div>`;
}

// ========== 收藏切换 ==========
async function toggleFavorite(storyId, btnEl) {
  const data = await api('/stories/favorites', { method: 'POST', body: { storyId } });
  if (data) {
    const isFav = data.isFavorited;
    if (btnEl) {
      btnEl.classList.toggle('faved', isFav);
      btnEl.innerHTML = isFav ? '❤️' : '🤍';
    }
    // 更新收藏列表
    const idx = state.favorites.findIndex(f => f.id === storyId || f.storyId === storyId);
    if (isFav && idx === -1) {
      state.favorites.push({ id: storyId });
    } else if (!isFav && idx !== -1) {
      state.favorites.splice(idx, 1);
    }
    toast(isFav ? '已收藏' : '已取消收藏', 'success');
  }
}

// ========== 故事详情 ==========
function showStoryDetail(storyId) {
  api('/stories/' + storyId).then(s => {
    if (!s) return;
    state.currentStory = s;
    const gradient = parseJsonField(s.coverGradient, ['#667eea', '#764ba2']);
    const bg = `linear-gradient(135deg, ${gradient[0]}, ${gradient[1]})`;
    const isFav = state.favorites.some(f => f.id === s.id || f.storyId === s.id);
    const audioHtml = s.audioUrl ? `
      <div class="audio-player">
        <audio controls src="${escapeHtml(s.audioUrl)}" style="width:100%;"></audio>
      </div>` : '';
    const content = s.content || '';
    const paragraphs = content.split('\n').filter(p => p.trim()).map(p => `<p>${escapeHtml(p)}</p>`).join('');

    openModal(escapeHtml(s.title), `
      <div class="story-detail">
        <div class="story-detail-cover" style="background:${bg}">
          <span style="font-size:64px;">${escapeHtml(s.coverEmoji || '📖')}</span>
        </div>
        <div class="story-detail-meta">
          <span class="badge badge-primary">${themeLabel(s.theme)}</span>
          <span class="badge badge-secondary">${ageLabel(s.targetAgeGroup || s.targetAge)}</span>
          <span>▶ ${s.playCount || 0} 次播放</span>
          <span>❤️ ${s.favoriteCount || 0} 收藏</span>
        </div>
        <div class="story-detail-summary">${escapeHtml(s.summary || '')}</div>
        ${audioHtml}
        <div class="story-detail-content">${paragraphs}</div>
      </div>
    `, null, '关闭');
    // 替换确定按钮为收藏按钮
    const footer = document.getElementById('modalFooter');
    footer.innerHTML = `
      <button class="btn btn-secondary" onclick="closeModal('genericModal')">关闭</button>
      <button class="btn ${isFav ? 'btn-danger' : 'btn-primary'}" id="detailFavBtn">${isFav ? '取消收藏' : '❤️ 收藏'}</button>
    `;
    document.getElementById('detailFavBtn').addEventListener('click', () => {
      toggleFavorite(s.id, null).then(() => {
        const newIsFav = state.favorites.some(f => f.id === s.id || f.storyId === s.id);
        const btn = document.getElementById('detailFavBtn');
        btn.textContent = newIsFav ? '取消收藏' : '❤️ 收藏';
        btn.className = `btn ${newIsFav ? 'btn-danger' : 'btn-primary'}`;
      });
    });
  });
}

// ============================================================
//   管理员页面
// ============================================================
function renderAdminPages() {

  // ----- 数据概览 -----
  pageLoaders['admin-dashboard'] = async (main) => {
    main.innerHTML = `
      <div class="page-loading">加载中...</div>
    `;
    const [stats, usersRes, voicesRes] = await Promise.all([
      api('/users/stats'),
      api('/users', { params: { page: 1, pageSize: 10 } }),
      api('/voices/all', { params: { page: 1, pageSize: 10 } }),
    ]);
    const s = stats || {};
    const recentUsers = (usersRes && usersRes.list) || [];
    const recentVoices = (voicesRes && voicesRes.list) || [];

    main.innerHTML = `
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-icon">👥</div>
          <div class="stat-value">${s.totalUsers || 0}</div>
          <div class="stat-label">总用户数</div>
        </div>
        <div class="stat-card">
          <div class="stat-icon">📚</div>
          <div class="stat-value">${s.totalStories || 0}</div>
          <div class="stat-label">总故事数</div>
        </div>
        <div class="stat-card">
          <div class="stat-icon">🎙️</div>
          <div class="stat-value">${s.totalVoiceModels || 0}</div>
          <div class="stat-label">声音模型</div>
        </div>
        <div class="stat-card">
          <div class="stat-icon">🤖</div>
          <div class="stat-value">${s.totalAIStories || 0}</div>
          <div class="stat-label">AI故事</div>
        </div>
        <div class="stat-card">
          <div class="stat-icon">❤️</div>
          <div class="stat-value">${s.totalFavorites || 0}</div>
          <div class="stat-label">总收藏数</div>
        </div>
        <div class="stat-card">
          <div class="stat-icon">🆕</div>
          <div class="stat-value">${s.todayNewUsers || 0}</div>
          <div class="stat-label">今日新增</div>
        </div>
      </div>
      <div class="admin-panels">
        <div class="panel">
          <div class="panel-header">
            <h3>最近注册用户</h3>
          </div>
          <div class="panel-body">
            <table class="data-table">
              <thead><tr><th>昵称</th><th>邮箱</th><th>角色</th><th>注册时间</th></tr></thead>
              <tbody>
                ${recentUsers.length ? recentUsers.map(u => `
                  <tr>
                    <td>${escapeHtml(u.nickname || '-')}</td>
                    <td>${escapeHtml(u.email || '-')}</td>
                    <td>${u.role === 'admin' ? '<span class="badge badge-danger">管理员</span>' : '<span class="badge badge-secondary">用户</span>'}</td>
                    <td>${fmtDate(u.createdAt)}</td>
                  </tr>
                `).join('') : '<tr><td colspan="4" class="empty-row">暂无数据</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
        <div class="panel">
          <div class="panel-header">
            <h3>最近声音模型</h3>
          </div>
          <div class="panel-body">
            <table class="data-table">
              <thead><tr><th>名称</th><th>用户</th><th>类型</th><th>状态</th><th>创建时间</th></tr></thead>
              <tbody>
                ${recentVoices.length ? recentVoices.map(v => `
                  <tr>
                    <td>${escapeHtml(v.name || '-')}</td>
                    <td>${escapeHtml(v.userNickname || v.userId || '-')}</td>
                    <td>${escapeHtml(v.type || '-')}</td>
                    <td>${statusBadge(v.status)}</td>
                    <td>${fmtDate(v.createdAt)}</td>
                  </tr>
                `).join('') : '<tr><td colspan="5" class="empty-row">暂无数据</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    `;
  };

  // ----- 故事管理 -----
  pageLoaders['admin-stories'] = async (main) => {
    main.innerHTML = `
      <div class="toolbar">
        <input type="text" class="form-input" id="storySearchInput" placeholder="搜索故事标题..." style="width:240px;">
        <select class="form-input" id="storyThemeFilter" style="width:140px;">
          <option value="">全部主题</option>
          <option value="adventure">冒险</option>
          <option value="fantasy">奇幻</option>
          <option value="animal">动物</option>
          <option value="friendship">友谊</option>
          <option value="family">家庭</option>
          <option value="science">科学</option>
          <option value="bedtime">睡前</option>
          <option value="fable">寓言</option>
        </select>
        <select class="form-input" id="storyStatusFilter" style="width:120px;">
          <option value="">全部状态</option>
          <option value="published">已发布</option>
          <option value="draft">草稿</option>
          <option value="pending">待审核</option>
        </select>
        <button class="btn btn-primary" id="newStoryBtn">+ 新建故事</button>
      </div>
      <div id="storyTableWrap"></div>
    `;

    const loadStories = async (page = 1) => {
      const wrap = document.getElementById('storyTableWrap');
      wrap.innerHTML = '<div class="page-loading">加载中...</div>';
      const params = {
        page, pageSize: state.stories.pageSize,
        keyword: state.storyFilter.keyword,
        theme: state.storyFilter.theme,
        status: state.storyFilter.status,
      };
      const data = await api('/stories', { params });
      if (!data) { wrap.innerHTML = '<div class="empty-state">加载失败</div>'; return; }
      state.stories = { ...state.stories, ...data.pagination, list: data.list || [] };
      const list = data.list || [];
      wrap.innerHTML = `
        <table class="data-table">
          <thead><tr><th>标题</th><th>主题</th><th>年龄</th><th>播放</th><th>收藏</th><th>状态</th><th>操作</th></tr></thead>
          <tbody>
            ${list.length ? list.map(s => `
              <tr>
                <td>${escapeHtml(s.title)}</td>
                <td>${themeLabel(s.theme)}</td>
                <td>${ageLabel(s.targetAgeGroup || s.targetAge)}</td>
                <td>${s.playCount || 0}</td>
                <td>${s.favoriteCount || 0}</td>
                <td>${statusBadge(s.status)}</td>
                <td>
                  <button class="btn btn-sm btn-secondary" data-action="edit" data-id="${s.id}">编辑</button>
                  <button class="btn btn-sm btn-danger" data-action="delete" data-id="${s.id}">删除</button>
                </td>
              </tr>
            `).join('') : '<tr><td colspan="7" class="empty-row">暂无故事</td></tr>'}
          </tbody>
        </table>
        ${renderPagination(data.pagination || state.stories, loadStories)}
      `;
      wrap.querySelectorAll('button[data-action]').forEach(btn => {
        btn.addEventListener('click', () => {
          const id = btn.dataset.id;
          if (btn.dataset.action === 'edit') editStory(id);
          else if (btn.dataset.action === 'delete') deleteStory(id);
        });
      });
      wrap.querySelectorAll('.page-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          if (btn.disabled) return;
          loadStories(parseInt(btn.dataset.page));
        });
      });
    };

    document.getElementById('storySearchInput').addEventListener('input', (e) => {
      state.storyFilter.keyword = e.target.value;
    });
    document.getElementById('storySearchInput').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') loadStories(1);
    });
    document.getElementById('storyThemeFilter').addEventListener('change', (e) => {
      state.storyFilter.theme = e.target.value;
      loadStories(1);
    });
    document.getElementById('storyStatusFilter').addEventListener('change', (e) => {
      state.storyFilter.status = e.target.value;
      loadStories(1);
    });
    document.getElementById('newStoryBtn').addEventListener('click', () => editStory(null));

    loadStories(1);
  };

  async function editStory(id) {
    const isEdit = !!id;
    let story = { title: '', theme: 'adventure', style: 'warm', targetAgeGroup: '3-6', categoryId: '', summary: '', content: '', coverEmoji: '📖', status: 'draft' };
    if (isEdit) {
      const data = await api('/stories/' + id);
      if (data) { story = { ...story, ...data }; }
    }
    const openForm = () => {
      const catOptions = state.categories.map(c => `<option value="${c.id}" ${story.categoryId === c.id ? 'selected' : ''}>${escapeHtml(c.name)}</option>`).join('');
      openModal(isEdit ? '编辑故事' : '新建故事', `
        <div class="form-group"><label class="form-label">标题</label><input type="text" class="form-input" id="f_title" value="${escapeHtml(story.title)}"></div>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;">
          <div class="form-group"><label class="form-label">主题</label>
            <select class="form-input" id="f_theme">
              <option value="adventure" ${story.theme==='adventure'?'selected':''}>冒险</option>
              <option value="fantasy" ${story.theme==='fantasy'?'selected':''}>奇幻</option>
              <option value="animals" ${story.theme==='animals'?'selected':''}>动物</option>
              <option value="friendship" ${story.theme==='friendship'?'selected':''}>友谊</option>
              <option value="family" ${story.theme==='family'?'selected':''}>家庭</option>
              <option value="science" ${story.theme==='science'?'selected':''}>科学</option>
              <option value="bedtime" ${story.theme==='bedtime'?'selected':''}>睡前</option>
              <option value="fable" ${story.theme==='fable'?'selected':''}>寓言</option>
              <option value="courage" ${story.theme==='courage'?'selected':''}>勇气</option>
              <option value="magic" ${story.theme==='magic'?'selected':''}>魔法</option>
            </select>
          </div>
          <div class="form-group"><label class="form-label">风格</label>
            <select class="form-input" id="f_style">
              <option value="warm" ${story.style==='warm'?'selected':''}>温馨</option>
              <option value="funny" ${story.style==='funny'?'selected':''}>幽默</option>
              <option value="poetic" ${story.style==='poetic'?'selected':''}>诗意</option>
              <option value="fairy" ${story.style==='fairy'?'selected':''}>童话</option>
              <option value="humorous" ${story.style==='humorous'?'selected':''}>诙谐</option>
              <option value="adventure" ${story.style==='adventure'?'selected':''}>冒险</option>
              <option value="educational" ${story.style==='educational'?'selected':''}>教育</option>
            </select>
          </div>
          <div class="form-group"><label class="form-label">年龄段</label>
            <select class="form-input" id="f_age">
              <option value="toddler" ${(story.targetAgeGroup||story.targetAge)==='toddler'?'selected':''}>0-3岁</option>
              <option value="preschool" ${(story.targetAgeGroup||story.targetAge)==='preschool'?'selected':''}>3-6岁</option>
              <option value="earlyElementary" ${(story.targetAgeGroup||story.targetAge)==='earlyElementary'?'selected':''}>6-9岁</option>
              <option value="0-3" ${(story.targetAgeGroup||story.targetAge)==='0-3'?'selected':''}>0-3岁(数字)</option>
              <option value="3-6" ${(story.targetAgeGroup||story.targetAge)==='3-6'?'selected':''}>3-6岁(数字)</option>
              <option value="6-9" ${(story.targetAgeGroup||story.targetAge)==='6-9'?'selected':''}>6-9岁(数字)</option>
              <option value="9-12" ${(story.targetAgeGroup||story.targetAge)==='9-12'?'selected':''}>9-12岁</option>
              <option value="all" ${(story.targetAgeGroup||story.targetAge)==='all'?'selected':''}>全年龄</option>
            </select>
          </div>
        </div>
        <div class="form-group"><label class="form-label">分类</label><select class="form-input" id="f_category"><option value="">无</option>${catOptions}</select></div>
        <div class="form-group"><label class="form-label">封面Emoji</label><input type="text" class="form-input" id="f_emoji" value="${escapeHtml(story.coverEmoji || '📖')}" maxlength="4"></div>
        <div class="form-group"><label class="form-label">简介</label><textarea class="form-input" id="f_summary" rows="2">${escapeHtml(story.summary || '')}</textarea></div>
        <div class="form-group"><label class="form-label">故事内容</label><textarea class="form-input" id="f_content" rows="8">${escapeHtml(story.content || '')}</textarea></div>
        <div class="form-group"><label class="form-label">状态</label>
          <select class="form-input" id="f_status">
            <option value="draft" ${story.status==='draft'?'selected':''}>草稿</option>
            <option value="published" ${story.status==='published'?'selected':''}>已发布</option>
          </select>
        </div>
      `, async () => {
        const body = {
          title: document.getElementById('f_title').value.trim(),
          theme: document.getElementById('f_theme').value,
          style: document.getElementById('f_style').value,
          targetAgeGroup: document.getElementById('f_age').value,
          categoryId: document.getElementById('f_category').value || null,
          summary: document.getElementById('f_summary').value.trim(),
          content: document.getElementById('f_content').value.trim(),
          coverEmoji: document.getElementById('f_emoji').value.trim() || '📖',
          status: document.getElementById('f_status').value,
        };
        if (!body.title) { toast('请输入标题', 'warning'); return false; }
        let res;
        if (isEdit) {
          res = await api('/stories/' + id, { method: 'PUT', body });
        } else {
          res = await api('/stories', { method: 'POST', body });
        }
        if (res) {
          toast(isEdit ? '更新成功' : '创建成功', 'success');
          closeModal('genericModal');
          pageLoaders['admin-stories'](document.getElementById('mainContent'));
        }
      }, '保存');
    };
    openForm();
  }

  function deleteStory(id) {
    showConfirm('确定要删除这个故事吗？此操作不可恢复。', async () => {
      const res = await api('/stories/' + id, { method: 'DELETE' });
      if (res !== null) {
        toast('删除成功', 'success');
        pageLoaders['admin-stories'](document.getElementById('mainContent'));
      }
    }, '删除故事', '删除');
  }

  // ----- 上传故事 -----
  pageLoaders['admin-upload'] = (main) => {
    main.innerHTML = `
      <div class="panel">
        <div class="panel-header"><h3>上传故事音频</h3></div>
        <div class="panel-body">
          <form id="uploadForm" class="form-grid">
            <div class="form-group"><label class="form-label">标题 *</label><input type="text" class="form-input" id="up_title" required></div>
            <div style="display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:12px;">
              <div class="form-group"><label class="form-label">主题</label>
                <select class="form-input" id="up_theme">
                  <option value="adventure">冒险</option><option value="fantasy">奇幻</option>
                  <option value="animals">动物</option><option value="friendship">友谊</option>
                  <option value="family">家庭</option><option value="science">科学</option>
                  <option value="bedtime">睡前</option><option value="fable">寓言</option>
                  <option value="courage">勇气</option><option value="magic">魔法</option>
                </select>
              </div>
              <div class="form-group"><label class="form-label">风格</label>
                <select class="form-input" id="up_style">
                  <option value="warm">温馨</option><option value="funny">幽默</option>
                  <option value="poetic">诗意</option><option value="fairy">童话</option>
                  <option value="humorous">诙谐</option><option value="adventure">冒险</option>
                  <option value="educational">教育</option>
                </select>
              </div>
              <div class="form-group"><label class="form-label">年龄段</label>
                <select class="form-input" id="up_age">
                  <option value="toddler">0-3岁</option><option value="preschool" selected>3-6岁</option>
                  <option value="earlyElementary">6-9岁</option><option value="9-12">9-12岁</option><option value="all">全年龄</option>
                </select>
              </div>
              <div class="form-group"><label class="form-label">分类</label>
                <select class="form-input" id="up_category"><option value="">无</option>
                  ${state.categories.map(c => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join('')}
                </select>
              </div>
            </div>
            <div class="form-group"><label class="form-label">封面Emoji</label><input type="text" class="form-input" id="up_emoji" value="📖" maxlength="4"></div>
            <div class="form-group"><label class="form-label">简介</label><textarea class="form-input" id="up_summary" rows="2"></textarea></div>
            <div class="form-group"><label class="form-label">故事内容（文本）</label><textarea class="form-input" id="up_content" rows="6"></textarea></div>
            <div class="form-group"><label class="form-label">状态</label>
              <select class="form-input" id="up_status">
                <option value="draft">草稿</option><option value="published" selected>已发布</option>
              </select>
            </div>
            <div class="form-group"><label class="form-label">音频文件 *</label>
              <input type="file" class="form-input" id="up_audio" accept="audio/*" required>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary btn-lg" id="up_submit">📤 上传故事</button>
            </div>
            <div id="up_progress" style="display:none;"><div class="progress-bar"><div class="progress-fill" id="up_progress_fill" style="width:0%"></div></div><div id="up_progress_text">0%</div></div>
          </form>
        </div>
      </div>
    `;
    document.getElementById('uploadForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData();
      fd.append('title', document.getElementById('up_title').value.trim());
      fd.append('theme', document.getElementById('up_theme').value);
      fd.append('style', document.getElementById('up_style').value);
      fd.append('targetAgeGroup', document.getElementById('up_age').value);
      const catId = document.getElementById('up_category').value;
      if (catId) fd.append('categoryId', catId);
      fd.append('coverEmoji', document.getElementById('up_emoji').value.trim() || '📖');
      fd.append('summary', document.getElementById('up_summary').value.trim());
      fd.append('content', document.getElementById('up_content').value.trim());
      fd.append('status', document.getElementById('up_status').value);
      const file = document.getElementById('up_audio').files[0];
      if (!file) { toast('请选择音频文件', 'warning'); return; }
      fd.append('audio', file);

      const progressEl = document.getElementById('up_progress');
      const fillEl = document.getElementById('up_progress_fill');
      const textEl = document.getElementById('up_progress_text');
      progressEl.style.display = 'block';
      const submitBtn = document.getElementById('up_submit');
      submitBtn.disabled = true;

      // 使用 XHR 以支持进度
      const xhr = new XMLHttpRequest();
      xhr.open('POST', API_BASE + '/stories/upload');
      xhr.setRequestHeader('Authorization', 'Bearer ' + state.token);
      xhr.upload.onprogress = (ev) => {
        if (ev.lengthComputable) {
          const pct = Math.round(ev.loaded / ev.total * 100);
          fillEl.style.width = pct + '%';
          textEl.textContent = pct + '%';
        }
      };
      xhr.onload = () => {
        submitBtn.disabled = false;
        progressEl.style.display = 'none';
        fillEl.style.width = '0%';
        try {
          const resp = JSON.parse(xhr.responseText);
          if (resp.code === 0) {
            toast('上传成功', 'success');
            document.getElementById('uploadForm').reset();
            document.getElementById('up_emoji').value = '📖';
          } else {
            toast(resp.message || '上传失败', 'error');
          }
        } catch (err) {
          toast('上传失败', 'error');
        }
      };
      xhr.onerror = () => {
        submitBtn.disabled = false;
        progressEl.style.display = 'none';
        toast('网络错误', 'error');
      };
      xhr.send(fd);
    });
  };

  // ----- 分类管理 -----
  pageLoaders['admin-categories'] = async (main) => {
    main.innerHTML = `
      <div class="toolbar">
        <button class="btn btn-primary" id="newCatBtn">+ 新建分类</button>
      </div>
      <div id="catTableWrap"></div>
    `;
    const loadCats = async () => {
      const wrap = document.getElementById('catTableWrap');
      wrap.innerHTML = '<div class="page-loading">加载中...</div>';
      const cats = await api('/stories/categories');
      state.categories = cats || [];
      wrap.innerHTML = `
        <table class="data-table">
          <thead><tr><th>名称</th><th>排序</th><th>故事数</th><th>操作</th></tr></thead>
          <tbody>
            ${state.categories.length ? state.categories.map(c => `
              <tr>
                <td>${escapeHtml(c.name)}</td>
                <td>${c.sortOrder || 0}</td>
                <td>${c.storyCount || 0}</td>
                <td>
                  <button class="btn btn-sm btn-secondary" data-action="edit" data-id="${c.id}">编辑</button>
                  <button class="btn btn-sm btn-danger" data-action="delete" data-id="${c.id}">删除</button>
                </td>
              </tr>
            `).join('') : '<tr><td colspan="4" class="empty-row">暂无分类</td></tr>'}
          </tbody>
        </table>
      `;
      wrap.querySelectorAll('button[data-action]').forEach(btn => {
        btn.addEventListener('click', () => {
          const id = btn.dataset.id;
          if (btn.dataset.action === 'edit') editCategory(id);
          else deleteCategory(id);
        });
      });
    };
    document.getElementById('newCatBtn').addEventListener('click', () => editCategory(null));
    loadCats();
  };

  function editCategory(id) {
    const isEdit = !!id;
    const cat = isEdit ? state.categories.find(c => c.id === id) || { name: '', sortOrder: 0 } : { name: '', sortOrder: 0 };
    openModal(isEdit ? '编辑分类' : '新建分类', `
      <div class="form-group"><label class="form-label">分类名称</label><input type="text" class="form-input" id="cat_name" value="${escapeHtml(cat.name)}"></div>
      <div class="form-group"><label class="form-label">排序</label><input type="number" class="form-input" id="cat_sort" value="${cat.sortOrder || 0}"></div>
    `, async () => {
      const name = document.getElementById('cat_name').value.trim();
      const sortOrder = parseInt(document.getElementById('cat_sort').value) || 0;
      if (!name) { toast('请输入名称', 'warning'); return false; }
      let res;
      if (isEdit) {
        res = await api('/stories/categories/' + id, { method: 'PUT', body: { name, sortOrder } });
      } else {
        res = await api('/stories/categories', { method: 'POST', body: { name, sortOrder } });
      }
      if (res) {
        toast(isEdit ? '更新成功' : '创建成功', 'success');
        closeModal('genericModal');
        pageLoaders['admin-categories'](document.getElementById('mainContent'));
      }
    }, '保存');
  }

  function deleteCategory(id) {
    showConfirm('确定要删除此分类吗？', async () => {
      const res = await api('/stories/categories/' + id, { method: 'DELETE' });
      if (res !== null) {
        toast('删除成功', 'success');
        pageLoaders['admin-categories'](document.getElementById('mainContent'));
      }
    }, '删除分类', '删除');
  }

  // ----- 用户管理 -----
  pageLoaders['admin-users'] = async (main) => {
    main.innerHTML = `
      <div class="toolbar">
        <input type="text" class="form-input" id="userSearchInput" placeholder="搜索昵称/邮箱..." style="width:240px;">
        <select class="form-input" id="userRoleFilter" style="width:120px;">
          <option value="">全部角色</option>
          <option value="admin">管理员</option>
          <option value="user">普通用户</option>
        </select>
        <select class="form-input" id="userStatusFilter" style="width:120px;">
          <option value="">全部状态</option>
          <option value="active">正常</option>
          <option value="inactive">禁用</option>
          <option value="banned">封禁</option>
        </select>
      </div>
      <div id="userTableWrap"></div>
    `;
    const loadUsers = async (page = 1) => {
      const wrap = document.getElementById('userTableWrap');
      wrap.innerHTML = '<div class="page-loading">加载中...</div>';
      const data = await api('/users', {
        params: {
          page, pageSize: state.users.pageSize,
          keyword: state.userFilter.keyword,
          role: state.userFilter.role,
          status: state.userFilter.status,
        }
      });
      if (!data) { wrap.innerHTML = '<div class="empty-state">加载失败</div>'; return; }
      state.users = { ...state.users, ...data.pagination, list: data.list || [] };
      const list = data.list || [];
      wrap.innerHTML = `
        <table class="data-table">
          <thead><tr><th>昵称</th><th>邮箱</th><th>角色</th><th>状态</th><th>会员</th><th>最后登录</th><th>操作</th></tr></thead>
          <tbody>
            ${list.length ? list.map(u => `
              <tr>
                <td>${escapeHtml(u.nickname || '-')}</td>
                <td>${escapeHtml(u.email || '-')}</td>
                <td>${u.role === 'admin' ? '<span class="badge badge-danger">管理员</span>' : '<span class="badge badge-secondary">用户</span>'}</td>
                <td>${statusBadge(u.status)}</td>
                <td>${escapeHtml(u.membershipTier || 'free')}</td>
                <td>${fmtDate(u.lastLoginAt)}</td>
                <td>
                  <button class="btn btn-sm btn-secondary" data-action="edit" data-id="${u.id}">编辑</button>
                  <button class="btn btn-sm btn-warning" data-action="ban" data-id="${u.id}">${u.status === 'banned' ? '解封' : '封禁'}</button>
                  <button class="btn btn-sm btn-danger" data-action="delete" data-id="${u.id}">删除</button>
                </td>
              </tr>
            `).join('') : '<tr><td colspan="7" class="empty-row">暂无用户</td></tr>'}
          </tbody>
        </table>
        ${renderPagination(data.pagination || state.users, loadUsers)}
      `;
      wrap.querySelectorAll('button[data-action]').forEach(btn => {
        btn.addEventListener('click', () => {
          const id = btn.dataset.id;
          const u = list.find(x => x.id === id);
          if (btn.dataset.action === 'edit') editUser(id);
          else if (btn.dataset.action === 'ban') toggleBan(u);
          else if (btn.dataset.action === 'delete') deleteUser(id);
        });
      });
      wrap.querySelectorAll('.page-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          if (btn.disabled) return;
          loadUsers(parseInt(btn.dataset.page));
        });
      });
    };
    document.getElementById('userSearchInput').addEventListener('input', (e) => { state.userFilter.keyword = e.target.value; });
    document.getElementById('userSearchInput').addEventListener('keydown', (e) => { if (e.key === 'Enter') loadUsers(1); });
    document.getElementById('userRoleFilter').addEventListener('change', (e) => { state.userFilter.role = e.target.value; loadUsers(1); });
    document.getElementById('userStatusFilter').addEventListener('change', (e) => { state.userFilter.status = e.target.value; loadUsers(1); });
    loadUsers(1);
  };

  function editUser(id) {
    const u = state.users.list.find(x => x.id === id) || {};
    openModal('编辑用户', `
      <div class="form-group"><label class="form-label">昵称</label><input type="text" class="form-input" id="u_nickname" value="${escapeHtml(u.nickname || '')}"></div>
      <div class="form-group"><label class="form-label">邮箱</label><input type="email" class="form-input" id="u_email" value="${escapeHtml(u.email || '')}" disabled></div>
      <div class="form-group"><label class="form-label">角色</label>
        <select class="form-input" id="u_role">
          <option value="user" ${u.role!=='admin'?'selected':''}>普通用户</option>
          <option value="admin" ${u.role==='admin'?'selected':''}>管理员</option>
        </select>
      </div>
      <div class="form-group"><label class="form-label">会员等级</label>
        <select class="form-input" id="u_tier">
          <option value="free" ${u.membershipTier!=='premium'&&u.membershipTier!=='vip'?'selected':''}>免费</option>
          <option value="premium" ${u.membershipTier==='premium'?'selected':''}>高级</option>
          <option value="vip" ${u.membershipTier==='vip'?'selected':''}>VIP</option>
        </select>
      </div>
      <div class="form-group"><label class="form-label">会员到期时间</label><input type="date" class="form-input" id="u_expire" value="${u.membershipExpireAt ? new Date(u.membershipExpireAt).toISOString().slice(0,10) : ''}"></div>
      <div class="form-group"><label class="form-label">状态</label>
        <select class="form-input" id="u_status">
          <option value="active" ${u.status==='active'?'selected':''}>正常</option>
          <option value="inactive" ${u.status==='inactive'?'selected':''}>禁用</option>
          <option value="banned" ${u.status==='banned'?'selected':''}>封禁</option>
        </select>
      </div>
    `, async () => {
      const body = {
        nickname: document.getElementById('u_nickname').value.trim(),
        role: document.getElementById('u_role').value,
        membershipTier: document.getElementById('u_tier').value,
        membershipExpireAt: document.getElementById('u_expire').value || null,
        status: document.getElementById('u_status').value,
      };
      const res = await api('/users/' + id, { method: 'PUT', body });
      if (res) {
        toast('更新成功', 'success');
        closeModal('genericModal');
        pageLoaders['admin-users'](document.getElementById('mainContent'));
      }
    }, '保存');
  }

  function toggleBan(u) {
    const newStatus = u.status === 'banned' ? 'active' : 'banned';
    const action = newStatus === 'banned' ? '封禁' : '解封';
    showConfirm(`确定要${action}用户 "${u.nickname || u.email}" 吗？`, async () => {
      const res = await api('/users/' + u.id, { method: 'PUT', body: { status: newStatus } });
      if (res) {
        toast(action + '成功', 'success');
        pageLoaders['admin-users'](document.getElementById('mainContent'));
      }
    }, action + '用户', action);
  }

  function deleteUser(id) {
    showConfirm('确定要删除此用户吗？此操作不可恢复。', async () => {
      const res = await api('/users/' + id, { method: 'DELETE' });
      if (res !== null) {
        toast('删除成功', 'success');
        pageLoaders['admin-users'](document.getElementById('mainContent'));
      }
    }, '删除用户', '删除');
  }

  // ----- 声音模型管理 -----
  pageLoaders['admin-voices'] = async (main) => {
    main.innerHTML = `
      <div class="toolbar">
        <select class="form-input" id="voiceStatusFilter" style="width:160px;">
          <option value="">全部状态</option>
          <option value="draft">草稿</option>
          <option value="recording">录音中</option>
          <option value="ready">就绪</option>
          <option value="training">训练中</option>
          <option value="failed">失败</option>
        </select>
      </div>
      <div id="voiceTableWrap"></div>
    `;
    const loadVoices = async (page = 1) => {
      const wrap = document.getElementById('voiceTableWrap');
      wrap.innerHTML = '<div class="page-loading">加载中...</div>';
      const params = { page, pageSize: state.voices.pageSize };
      if (state.voiceFilter.status) params.status = state.voiceFilter.status;
      const data = await api('/voices/all', { params });
      if (!data) { wrap.innerHTML = '<div class="empty-state">加载失败</div>'; return; }
      state.voices = { ...state.voices, ...data.pagination, list: data.list || [] };
      const list = data.list || [];
      wrap.innerHTML = `
        <table class="data-table">
          <thead><tr><th>名称</th><th>用户</th><th>类型</th><th>状态</th><th>进度</th><th>录音数</th><th>创建时间</th><th>操作</th></tr></thead>
          <tbody>
            ${list.length ? list.map(v => `
              <tr>
                <td>${escapeHtml(v.name || '-')}</td>
                <td>${escapeHtml(v.userNickname || v.userId || '-')}</td>
                <td>${ownerTypeLabel(v.ownerType)}</td>
                <td>${statusBadge(v.status)}</td>
                <td>${Math.round((v.progress || 0) * 100)}%</td>
                <td>${v.recordingCount || 0}</td>
                <td>${fmtDate(v.createdAt)}</td>
                <td>
                  <button class="btn btn-sm btn-secondary" data-action="view" data-id="${v.id}">查看</button>
                  <button class="btn btn-sm btn-danger" data-action="delete" data-id="${v.id}">删除</button>
                </td>
              </tr>
            `).join('') : '<tr><td colspan="8" class="empty-row">暂无声音模型</td></tr>'}
          </tbody>
        </table>
        ${renderPagination(data.pagination || state.voices, loadVoices)}
      `;
      wrap.querySelectorAll('button[data-action]').forEach(btn => {
        btn.addEventListener('click', () => {
          const id = btn.dataset.id;
          if (btn.dataset.action === 'view') viewVoice(id);
          else deleteVoiceAdmin(id);
        });
      });
      wrap.querySelectorAll('.page-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          if (btn.disabled) return;
          loadVoices(parseInt(btn.dataset.page));
        });
      });
    };
    document.getElementById('voiceStatusFilter').addEventListener('change', (e) => {
      state.voiceFilter.status = e.target.value;
      loadVoices(1);
    });
    loadVoices(1);
  };

  function viewVoice(id) {
    const v = state.voices.list.find(x => x.id === id);
    if (!v) return;
    openModal('声音模型详情', `
      <div class="detail-list">
        <div class="detail-row"><label>名称</label><span>${escapeHtml(v.name)}</span></div>
        <div class="detail-row"><label>用户</label><span>${escapeHtml(v.userNickname || v.userId)}</span></div>
        <div class="detail-row"><label>类型</label><span>${ownerTypeLabel(v.ownerType)}</span></div>
        <div class="detail-row"><label>状态</label><span>${statusBadge(v.status)}</span></div>
        <div class="detail-row"><label>进度</label><span>${Math.round((v.progress || 0) * 100)}%</span></div>
        <div class="detail-row"><label>录音数</label><span>${v.recordingCount || 0}</span></div>
        <div class="detail-row"><label>创建时间</label><span>${fmtDate(v.createdAt)}</span></div>
      </div>
    `, null, '关闭');
    document.getElementById('modalFooter').innerHTML = `<button class="btn btn-secondary" onclick="closeModal('genericModal')">关闭</button>`;
  }

  async function deleteVoiceAdmin(id) {
    showConfirm('确定要删除此声音模型吗？', async () => {
      const res = await api('/voices/' + id, { method: 'DELETE' });
      if (res !== null) {
        toast('删除成功', 'success');
        pageLoaders['admin-voices'](document.getElementById('mainContent'));
      }
    }, '删除声音模型', '删除');
  }

  // ----- 文件管理 -----
  pageLoaders['admin-files'] = async (main) => {
    const groups = [
      { id: 'audio', label: '音频文件', icon: '🎵' },
      { id: 'recordings', label: '录音文件', icon: '🎙️' },
      { id: 'covers', label: '封面图片', icon: '🖼️' },
      { id: 'subtitles', label: '字幕文件', icon: '📝' },
    ];
    main.innerHTML = `
      <div class="tabs" id="fileTabs">
        ${groups.map(g => `<button class="tab-btn ${g.id === state.fileGroup ? 'active' : ''}" data-group="${g.id}">${g.icon} ${g.label}</button>`).join('')}
      </div>
      <div id="fileListWrap"></div>
    `;
    const loadFiles = async (group) => {
      state.fileGroup = group;
      const wrap = document.getElementById('fileListWrap');
      wrap.innerHTML = '<div class="page-loading">加载中...</div>';
      const data = await api('/files/list/' + group);
      state.fileList = data || [];
      const list = state.fileList;
      wrap.innerHTML = `
        <table class="data-table">
          <thead><tr><th>文件名</th><th>大小</th><th>修改时间</th><th>操作</th></tr></thead>
          <tbody>
            ${list.length ? list.map(f => `
              <tr>
                <td>${escapeHtml(f.name || f.filename || '-')}</td>
                <td>${fmtFileSize(f.size)}</td>
                <td>${fmtDate(f.modifiedAt || f.updatedAt || f.createdAt)}</td>
                <td>
                  ${f.url ? `<a class="btn btn-sm btn-secondary" href="${escapeHtml(f.url)}" target="_blank">查看</a>` : ''}
                </td>
              </tr>
            `).join('') : '<tr><td colspan="4" class="empty-row">暂无文件</td></tr>'}
          </tbody>
        </table>
      `;
    };
    main.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        main.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        loadFiles(btn.dataset.group);
      });
    });
    loadFiles(state.fileGroup);
  };
}

// ============================================================
//   用户页面
// ============================================================
function renderUserPages() {

  // ----- 故事首页 -----
  pageLoaders['user-home'] = async (main) => {
    main.innerHTML = `
      <div class="search-bar">
        <input type="text" class="form-input" id="homeSearchInput" placeholder="搜索故事..." style="flex:1;">
        <button class="btn btn-primary" id="homeSearchBtn">🔍 搜索</button>
      </div>
      <div class="category-chips" id="categoryChips"></div>
      <div id="storyGridWrap"></div>
    `;

    // 渲染分类
    const chipsEl = document.getElementById('categoryChips');
    const renderChips = () => {
      let html = `<button class="chip ${!state.selectedCategory ? 'active' : ''}" data-cat="">全部</button>`;
      html += state.categories.map(c =>
        `<button class="chip ${state.selectedCategory === c.id ? 'active' : ''}" data-cat="${c.id}">${escapeHtml(c.name)}</button>`
      ).join('');
      chipsEl.innerHTML = html;
      chipsEl.querySelectorAll('.chip').forEach(chip => {
        chip.addEventListener('click', () => {
          state.selectedCategory = chip.dataset.cat || null;
          renderChips();
          loadStories(1);
        });
      });
    };
    renderChips();

    const loadStories = async (page = 1) => {
      const wrap = document.getElementById('storyGridWrap');
      wrap.innerHTML = '<div class="page-loading">加载中...</div>';
      const keyword = document.getElementById('homeSearchInput').value.trim();
      const params = { page, pageSize: state.stories.pageSize };
      if (keyword) params.keyword = keyword;
      if (state.selectedCategory) params.categoryId = state.selectedCategory;
      const data = await api('/stories', { params });
      if (!data) { wrap.innerHTML = '<div class="empty-state">加载失败</div>'; return; }
      state.stories = { ...state.stories, ...data.pagination, list: data.list || [] };
      const list = data.list || [];
      wrap.innerHTML = `
        <div class="story-grid">
          ${list.length ? list.map(s => renderStoryCard(s)).join('') : '<div class="empty-state">暂无故事</div>'}
        </div>
        ${renderPagination(data.pagination || state.stories, loadStories)}
      `;
      wrap.querySelectorAll('.story-card').forEach(card => {
        card.addEventListener('click', (e) => {
          if (e.target.closest('.fav-btn')) return;
          showStoryDetail(card.dataset.storyId);
        });
      });
      wrap.querySelectorAll('.fav-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          toggleFavorite(btn.dataset.storyId, btn);
        });
      });
      wrap.querySelectorAll('.page-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          if (btn.disabled) return;
          loadStories(parseInt(btn.dataset.page));
        });
      });
    };

    document.getElementById('homeSearchBtn').addEventListener('click', () => loadStories(1));
    document.getElementById('homeSearchInput').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') loadStories(1);
    });

    // 加载收藏列表用于判断收藏状态
    api('/stories/favorites').then(data => {
      state.favorites = data || [];
    });

    loadStories(1);
  };

  // ----- 我的收藏 -----
  pageLoaders['user-favorites'] = async (main) => {
    main.innerHTML = `<h2 style="margin-bottom:16px;">❤️ 我的收藏</h2><div id="favGridWrap"><div class="page-loading">加载中...</div></div>`;
    const data = await api('/stories/favorites');
    const favList = (data && data.list) ? data.list : (data || []);
    state.favorites = favList;
    const wrap = document.getElementById('favGridWrap');
    if (!state.favorites.length) {
      wrap.innerHTML = '<div class="empty-state">还没有收藏任何故事</div>';
      return;
    }
    wrap.innerHTML = `<div class="story-grid">${state.favorites.map(s => renderStoryCard(s)).join('')}</div>`;
    wrap.querySelectorAll('.story-card').forEach(card => {
      card.addEventListener('click', (e) => {
        if (e.target.closest('.fav-btn')) return;
        showStoryDetail(card.dataset.storyId);
      });
    });
    wrap.querySelectorAll('.fav-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleFavorite(btn.dataset.storyId, btn).then(() => {
          pageLoaders['user-favorites'](main);
        });
      });
    });
  };

  // ----- 播放历史 -----
  pageLoaders['user-history'] = async (main) => {
    main.innerHTML = `<h2 style="margin-bottom:16px;">🕐 播放历史</h2><div id="historyWrap"><div class="page-loading">加载中...</div></div>`;
    const data = await api('/stories/history');
    const histList = (data && data.list) ? data.list : (data || []);
    state.history = histList;
    const wrap = document.getElementById('historyWrap');
    if (!state.history.length) {
      wrap.innerHTML = '<div class="empty-state">暂无播放记录</div>';
      return;
    }
    wrap.innerHTML = `
      <div class="history-list">
        ${state.history.map(h => {
          const s = h.story || h;
          const gradient = parseJsonField(s.coverGradient, ['#667eea','#764ba2']);
          return `
            <div class="history-item" data-story-id="${s.id}">
              <div class="history-cover" style="background:linear-gradient(135deg,${gradient[0]},${gradient[1]})">
                <span>${escapeHtml(s.coverEmoji || '📖')}</span>
              </div>
              <div class="history-info">
                <div class="history-title">${escapeHtml(s.title)}</div>
                <div class="history-meta">${themeLabel(s.theme)} · ${ageLabel(s.targetAgeGroup || s.targetAge)} · ${fmtDate(h.updatedAt || h.createdAt)}</div>
              </div>
              <button class="btn btn-sm btn-primary">▶ 播放</button>
            </div>`;
        }).join('')}
      </div>`;
    wrap.querySelectorAll('.history-item').forEach(item => {
      item.addEventListener('click', () => showStoryDetail(item.dataset.storyId));
    });
  };

  // ----- AI创作 -----
  pageLoaders['user-ai'] = async (main) => {
    main.innerHTML = `
      <div class="ai-layout">
        <div class="panel">
          <div class="panel-header"><h3>🤖 AI故事生成器</h3></div>
          <div class="panel-body">
            <form id="aiForm">
              <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;">
                <div class="form-group"><label class="form-label">主题</label>
                  <select class="form-input" id="ai_theme">
                    <option value="adventure">冒险</option><option value="fantasy">奇幻</option>
                    <option value="animal">动物</option><option value="friendship">友谊</option>
                    <option value="family">家庭</option><option value="science">科学</option>
                    <option value="bedtime">睡前</option><option value="fable">寓言</option>
                  </select>
                </div>
                <div class="form-group"><label class="form-label">风格</label>
                  <select class="form-input" id="ai_style">
                    <option value="warm">温馨</option><option value="funny">幽默</option>
                    <option value="adventure">冒险</option><option value="educational">教育</option>
                  </select>
                </div>
                <div class="form-group"><label class="form-label">目标年龄</label>
                  <select class="form-input" id="ai_age">
                    <option value="toddler">0-3岁</option><option value="preschool" selected>3-6岁</option>
                    <option value="earlyElementary">6-9岁</option><option value="9-12">9-12岁</option>
                  </select>
                </div>
              </div>
              <div class="form-group"><label class="form-label">字数</label>
                <input type="number" class="form-input" id="ai_words" value="500" min="100" max="3000">
              </div>
              <div class="form-group"><label class="form-label">角色（用逗号分隔）</label>
                <input type="text" class="form-input" id="ai_chars" placeholder="例如：小兔子, 小熊, 月亮姐姐">
              </div>
              <div class="form-group"><label class="form-label">自定义提示（可选）</label>
                <textarea class="form-input" id="ai_prompt" rows="3" placeholder="描述你想要的故事情节或特殊要求..."></textarea>
              </div>
              <button type="submit" class="btn btn-primary btn-lg" id="ai_submit">✨ 生成故事</button>
            </form>
            <div id="ai_result" style="margin-top:20px;display:none;">
              <div class="ai-story-result">
                <h3 id="ai_result_title"></h3>
                <div id="ai_result_content" style="white-space:pre-wrap;line-height:1.8;"></div>
                <div style="margin-top:12px;display:flex;gap:8px;">
                  <button class="btn btn-secondary" id="ai_save_btn">💾 保存到我的故事</button>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="panel">
          <div class="panel-header"><h3>📚 我的AI故事</h3></div>
          <div class="panel-body" id="myAIList"><div class="page-loading">加载中...</div></div>
        </div>
      </div>
    `;

    document.getElementById('aiForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn = document.getElementById('ai_submit');
      btn.disabled = true;
      btn.textContent = '⏳ 生成中...';
      const body = {
        theme: document.getElementById('ai_theme').value,
        style: document.getElementById('ai_style').value,
        targetAge: document.getElementById('ai_age').value,
        wordCount: parseInt(document.getElementById('ai_words').value) || 500,
        characters: document.getElementById('ai_chars').value.trim(),
        customPrompt: document.getElementById('ai_prompt').value.trim(),
      };
      const data = await api('/ai/generate', { method: 'POST', body });
      btn.disabled = false;
      btn.textContent = '✨ 生成故事';
      if (data) {
        state.aiGeneratedStory = data;
        document.getElementById('ai_result').style.display = 'block';
        document.getElementById('ai_result_title').textContent = data.title || 'AI生成的故事';
        document.getElementById('ai_result_content').textContent = data.content || '';
        toast('故事生成成功！', 'success');
      }
    });

    document.getElementById('ai_save_btn').addEventListener('click', async () => {
      toast('故事已保存在"我的AI故事"列表中', 'success');
    });

    const loadMyAIStories = async () => {
      const wrap = document.getElementById('myAIList');
      const data = await api('/ai/my-stories');
      state.myAIStories = data || [];
      if (!state.myAIStories.length) {
        wrap.innerHTML = '<div class="empty-state">还没有AI故事</div>';
        return;
      }
      wrap.innerHTML = `<div class="ai-story-list">
        ${state.myAIStories.map(s => `
          <div class="ai-story-item" data-id="${s.id}">
            <div class="ai-story-title">${escapeHtml(s.title)}</div>
            <div class="ai-story-meta">${themeLabel(s.theme)} · ${fmtDateShort(s.createdAt)}</div>
            <div class="ai-story-preview">${escapeHtml((s.content || '').slice(0, 80))}...</div>
          </div>
        `).join('')}
      </div>`;
      wrap.querySelectorAll('.ai-story-item').forEach(item => {
        item.addEventListener('click', () => {
          const s = state.myAIStories.find(x => x.id === item.dataset.id);
          if (s) showStoryDetail(s.storyId || s.id);
        });
      });
    };

    loadMyAIStories();
  };

  // ----- 我的声音 -----
  pageLoaders['user-voices'] = async (main) => {
    main.innerHTML = `
      <div class="toolbar">
        <button class="btn btn-primary" id="newVoiceBtn">🎙️ 创建声音模型</button>
        <button class="btn btn-secondary" id="refreshVoicesBtn">🔄 刷新</button>
      </div>
      <div id="voiceListWrap"><div class="page-loading">加载中...</div></div>
    `;

    const loadVoices = async () => {
      const wrap = document.getElementById('voiceListWrap');
      const data = await api('/voices');
      state.myVoices = data || [];
      if (!state.myVoices.length) {
        wrap.innerHTML = '<div class="empty-state">还没有声音模型，点击上方按钮创建</div>';
        return;
      }
      wrap.innerHTML = `<div class="voice-grid">
        ${state.myVoices.map(v => {
          const progress = Math.round((v.progress || 0) * 100);
          const canTrain = v.status === 'recording' && (v.recordingCount || 0) >= 1;
          return `
            <div class="voice-card">
              <div class="voice-icon">${v.emoji || '🎙️'}</div>
              <div class="voice-name">${escapeHtml(v.name)}</div>
              <div class="voice-status">${statusBadge(v.status)}</div>
              <div class="voice-progress">
                <div class="progress-bar"><div class="progress-fill" style="width:${progress}%"></div></div>
                <span>${progress}%</span>
              </div>
              <div class="voice-meta">录音: ${v.recordingCount || 0} 段 · ${ownerTypeLabel(v.ownerType)}</div>
              <div class="voice-actions">
                <label class="btn btn-sm btn-secondary">
                  📤 上传录音
                  <input type="file" accept="audio/*" multiple style="display:none;" data-voice-id="${v.id}" class="voice-upload-input">
                </label>
                <button class="btn btn-sm btn-primary" data-action="train" data-id="${v.id}" ${canTrain ? '' : 'disabled'}>▶ 开始训练</button>
                <button class="btn btn-sm btn-danger" data-action="delete" data-id="${v.id}">🗑️</button>
              </div>
            </div>`;
        }).join('')}
      </div>`;

      wrap.querySelectorAll('.voice-upload-input').forEach(inp => {
        inp.addEventListener('change', async (e) => {
          const voiceId = inp.dataset.voiceId;
          const files = e.target.files;
          if (!files.length) return;
          const fd = new FormData();
          for (let i = 0; i < files.length; i++) fd.append('recordings', files[i]);
          toast('上传中...', 'info');
          const res = await api('/voices/' + voiceId + '/recordings', { method: 'POST', body: fd });
          if (res) {
            toast('录音上传成功', 'success');
            loadVoices();
          }
        });
      });
      wrap.querySelectorAll('button[data-action]').forEach(btn => {
        btn.addEventListener('click', async () => {
          const id = btn.dataset.id;
          if (btn.dataset.action === 'train') {
            btn.disabled = true;
            btn.textContent = '⏳ 训练中...';
            const res = await api('/voices/' + id + '/train', { method: 'POST' });
            if (res) {
              toast('训练已开始，请稍后刷新查看进度', 'success');
              setTimeout(loadVoices, 3000);
            } else {
              btn.disabled = false;
              btn.textContent = '▶ 开始训练';
            }
          } else if (btn.dataset.action === 'delete') {
            showConfirm('确定要删除此声音模型吗？', async () => {
              const res = await api('/voices/' + id, { method: 'DELETE' });
              if (res !== null) {
                toast('删除成功', 'success');
                loadVoices();
              }
            }, '删除声音模型', '删除');
          }
        });
      });
    };

    document.getElementById('newVoiceBtn').addEventListener('click', () => {
      openModal('创建声音模型', `
        <div class="form-group"><label class="form-label">声音名称</label><input type="text" class="form-input" id="vn_name" placeholder="例如：妈妈的声音"></div>
        <div class="form-group"><label class="form-label">类型</label>
          <select class="form-input" id="vn_type">
            <option value="mom">妈妈的声音</option><option value="dad">爸爸的声音</option>
            <option value="child">孩子的声音</option><option value="custom">自定义</option>
          </select>
        </div>
        <div class="form-group"><label class="form-label">描述（可选）</label><textarea class="form-input" id="vn_desc" rows="2"></textarea></div>
        <div style="font-size:13px;color:#666;background:#f5f5f5;padding:10px;border-radius:8px;">
          💡 创建后请上传至少3段清晰的录音（每段10-60秒），然后点击"开始训练"。
        </div>
      `, async () => {
        const name = document.getElementById('vn_name').value.trim();
        if (!name) { toast('请输入声音名称', 'warning'); return false; }
        const body = {
          name,
          ownerType: document.getElementById('vn_type').value,
          description: document.getElementById('vn_desc').value.trim(),
        };
        const res = await api('/voices', { method: 'POST', body });
        if (res) {
          toast('创建成功，请上传录音', 'success');
          closeModal('genericModal');
          loadVoices();
        }
      }, '创建');
    });

    document.getElementById('refreshVoicesBtn').addEventListener('click', loadVoices);
    loadVoices();
  };

  // ----- 播放列表 -----
  pageLoaders['user-playlists'] = async (main) => {
    main.innerHTML = `
      <div class="toolbar">
        <button class="btn btn-primary" id="newPlaylistBtn">📋 新建播放列表</button>
      </div>
      <div id="playlistWrap"><div class="page-loading">加载中...</div></div>
    `;

    const loadPlaylists = async () => {
      const wrap = document.getElementById('playlistWrap');
      const data = await api('/stories/playlists');
      state.playlists = data || [];
      if (!state.playlists.length) {
        wrap.innerHTML = '<div class="empty-state">还没有播放列表</div>';
        return;
      }
      wrap.innerHTML = `<div class="playlist-grid">
        ${state.playlists.map(p => `
          <div class="playlist-card" data-id="${p.id}">
            <div class="playlist-cover">📋</div>
            <div class="playlist-name">${escapeHtml(p.name)}</div>
            <div class="playlist-count">${p.storyCount || 0} 个故事</div>
            <div class="playlist-actions">
              <button class="btn btn-sm btn-secondary" data-action="view" data-id="${p.id}">查看</button>
              <button class="btn btn-sm btn-danger" data-action="delete" data-id="${p.id}">删除</button>
            </div>
          </div>
        `).join('')}
      </div>`;
      wrap.querySelectorAll('button[data-action]').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const id = btn.dataset.id;
          if (btn.dataset.action === 'view') viewPlaylist(id);
          else if (btn.dataset.action === 'delete') deletePlaylist(id);
        });
      });
    };

    const viewPlaylist = (id) => {
      const p = state.playlists.find(x => x.id === id);
      if (!p) return;
      openModal(escapeHtml(p.name), `
        <div class="playlist-detail">
          <div class="form-group" style="margin-bottom:12px;">
            <label class="form-label">列表名称</label>
            <input type="text" class="form-input" id="pl_name" value="${escapeHtml(p.name)}">
          </div>
          <button class="btn btn-sm btn-primary" id="pl_rename_btn" style="margin-bottom:12px;">保存名称</button>
          <div id="pl_stories">
            ${(p.stories || []).length ? (p.stories || []).map(s => `
              <div class="pl-story-item">
                <span>${escapeHtml(s.title)}</span>
                <button class="btn btn-sm btn-danger" data-remove-story="${s.id}">移除</button>
              </div>
            `).join('') : '<div class="empty-state" style="padding:20px;">列表为空</div>'}
          </div>
        </div>
      `, null, '关闭');
      document.getElementById('modalFooter').innerHTML = `<button class="btn btn-secondary" onclick="closeModal('genericModal')">关闭</button>`;
      document.getElementById('pl_rename_btn').addEventListener('click', async () => {
        const name = document.getElementById('pl_name').value.trim();
        if (!name) return;
        const res = await api('/stories/playlists/' + id, { method: 'PUT', body: { name } });
        if (res) { toast('已更新', 'success'); loadPlaylists(); }
      });
    };

    const deletePlaylist = (id) => {
      showConfirm('确定要删除此播放列表吗？', async () => {
        const res = await api('/stories/playlists/' + id, { method: 'DELETE' });
        if (res !== null) { toast('删除成功', 'success'); loadPlaylists(); }
      }, '删除播放列表', '删除');
    };

    document.getElementById('newPlaylistBtn').addEventListener('click', () => {
      openModal('新建播放列表', `
        <div class="form-group"><label class="form-label">列表名称</label><input type="text" class="form-input" id="pl_new_name" placeholder="我的最爱"></div>
      `, async () => {
        const name = document.getElementById('pl_new_name').value.trim();
        if (!name) { toast('请输入名称', 'warning'); return false; }
        const res = await api('/stories/playlists', { method: 'POST', body: { name } });
        if (res) { toast('创建成功', 'success'); closeModal('genericModal'); loadPlaylists(); }
      }, '创建');
    });

    loadPlaylists();
  };

  // 个人中心页面由 registerProfilePage() 统一注册
}

// ========== 个人中心页面（管理员和普通用户共用） ==========
function registerProfilePage() {
  pageLoaders['user-profile'] = async (main) => {
    const u = state.user;
    const isAdmin = u.role === 'admin';
    main.innerHTML = `
      <div class="profile-layout">
        <div class="panel">
          <div class="panel-header"><h3>👤 个人信息</h3></div>
          <div class="panel-body">
            <div class="avatar-circle">${(u.nickname || u.email || 'U').charAt(0).toUpperCase()}</div>
            <div class="form-group"><label class="form-label">昵称</label><input type="text" class="form-input" id="pf_nickname" value="${escapeHtml(u.nickname || '')}"></div>
            <div class="form-group"><label class="form-label">邮箱</label><input type="email" class="form-input" value="${escapeHtml(u.email || '')}" disabled></div>
            <div class="form-group"><label class="form-label">角色</label><input type="text" class="form-input" value="${isAdmin ? '管理员' : '普通用户'}" disabled></div>
            <div class="form-group"><label class="form-label">会员等级</label><input type="text" class="form-input" value="${u.membershipTier || '免费'}" disabled></div>
            ${u.membershipExpireAt ? `<div class="form-group"><label class="form-label">会员到期</label><input type="text" class="form-input" value="${fmtDate(u.membershipExpireAt)}" disabled></div>` : ''}
            <button class="btn btn-primary" id="pf_save_btn">💾 保存修改</button>
          </div>
        </div>
        <div class="panel">
          <div class="panel-header"><h3>🔒 修改密码</h3></div>
          <div class="panel-body">
            <div class="form-group"><label class="form-label">当前密码</label><input type="password" class="form-input" id="pf_old_pw"></div>
            <div class="form-group"><label class="form-label">新密码</label><input type="password" class="form-input" id="pf_new_pw" placeholder="至少6位"></div>
            <div class="form-group"><label class="form-label">确认新密码</label><input type="password" class="form-input" id="pf_new_pw2" placeholder="再次输入新密码"></div>
            <button class="btn btn-primary" id="pf_pw_btn">🔑 修改密码</button>
          </div>
        </div>
        ${!isAdmin ? `
        <div class="panel" style="grid-column:1/-1;">
          <div class="panel-header">
            <h3>👶 孩子档案</h3>
            <button class="btn btn-primary btn-sm" id="addChildBtn">+ 添加孩子</button>
          </div>
          <div class="panel-body" id="childrenList"></div>
        </div>` : ''}
      </div>
    `;

    document.getElementById('pf_save_btn').addEventListener('click', async () => {
      const nickname = document.getElementById('pf_nickname').value.trim();
      if (!nickname) { toast('请输入昵称', 'warning'); return; }
      const res = await api('/auth/profile', { method: 'PUT', body: { nickname } });
      if (res) {
        state.user.nickname = nickname;
        renderUserHeader();
        toast('个人信息已更新', 'success');
      }
    });

    document.getElementById('pf_pw_btn').addEventListener('click', async () => {
      const oldPassword = document.getElementById('pf_old_pw').value;
      const newPassword = document.getElementById('pf_new_pw').value;
      const newPassword2 = document.getElementById('pf_new_pw2').value;
      if (!oldPassword || !newPassword) { toast('请填写密码', 'warning'); return; }
      if (newPassword !== newPassword2) { toast('两次密码不一致', 'error'); return; }
      if (newPassword.length < 6) { toast('新密码至少6位', 'warning'); return; }
      const res = await api('/auth/change-password', { method: 'POST', body: { oldPassword, newPassword } });
      if (res) {
        toast('密码修改成功', 'success');
        document.getElementById('pf_old_pw').value = '';
        document.getElementById('pf_new_pw').value = '';
        document.getElementById('pf_new_pw2').value = '';
      }
    });

    if (!isAdmin) {
      const loadChildren = async () => {
        const wrap = document.getElementById('childrenList');
        const data = await api('/users/children');
        state.children = data || [];
        if (!state.children.length) {
          wrap.innerHTML = '<div class="empty-state">还没有添加孩子档案</div>';
          return;
        }
        wrap.innerHTML = `<div class="children-grid">
          ${state.children.map(c => `
            <div class="child-card">
              <div class="child-avatar">${c.gender === 'female' || c.gender === 'girl' ? '👧' : '👦'}</div>
              <div class="child-name">${escapeHtml(c.name)}</div>
              <div class="child-info">${c.ageGroup ? ageLabel(c.ageGroup) : ''} · ${(c.gender === 'female' || c.gender === 'girl') ? '女孩' : '男孩'}</div>
              <div class="child-actions">
                <button class="btn btn-sm btn-secondary" data-action="edit-child" data-id="${c.id}">编辑</button>
                <button class="btn btn-sm btn-danger" data-action="delete-child" data-id="${c.id}">删除</button>
              </div>
            </div>
          `).join('')}
        </div>`;
        wrap.querySelectorAll('button[data-action]').forEach(btn => {
          btn.addEventListener('click', () => {
            const id = btn.dataset.id;
            if (btn.dataset.action === 'edit-child') editChild(id);
            else deleteChild(id);
          });
        });
      };

      const editChild = (id) => {
        const isEdit = !!id;
        const c = isEdit ? state.children.find(x => x.id === id) || {} : {};
        openModal(isEdit ? '编辑孩子档案' : '添加孩子', `
          <div class="form-group"><label class="form-label">名字</label><input type="text" class="form-input" id="ch_name" value="${escapeHtml(c.name || '')}"></div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <div class="form-group"><label class="form-label">年龄段</label>
              <select class="form-input" id="ch_age">
                <option value="toddler" ${c.ageGroup==='toddler'?'selected':''}>0-3岁</option>
                <option value="preschool" ${c.ageGroup==='preschool'?'selected':''}>3-6岁</option>
                <option value="earlyElementary" ${c.ageGroup==='earlyElementary'?'selected':''}>6-9岁</option>
                <option value="9-12" ${c.ageGroup==='9-12'?'selected':''}>9-12岁</option>
              </select>
            </div>
            <div class="form-group"><label class="form-label">性别</label>
              <select class="form-input" id="ch_gender">
                <option value="boy" ${c.gender !== 'girl' && c.gender !== 'female' ? 'selected' : ''}>男孩</option>
                <option value="girl" ${c.gender === 'girl' || c.gender === 'female' ? 'selected' : ''}>女孩</option>
              </select>
            </div>
          </div>
          <div class="form-group"><label class="form-label">兴趣爱好（可选）</label><input type="text" class="form-input" id="ch_interests" value="${escapeHtml(c.interests || '')}" placeholder="例如：恐龙、公主、太空"></div>
        `, async () => {
          const name = document.getElementById('ch_name').value.trim();
          if (!name) { toast('请输入名字', 'warning'); return false; }
          const body = {
            name,
            ageGroup: document.getElementById('ch_age').value,
            gender: document.getElementById('ch_gender').value,
            interests: document.getElementById('ch_interests').value.trim(),
          };
          let res;
          if (isEdit) {
            res = await api('/users/children/' + id, { method: 'PUT', body });
          } else {
            res = await api('/users/children', { method: 'POST', body });
          }
          if (res) {
            toast(isEdit ? '更新成功' : '添加成功', 'success');
            closeModal('genericModal');
            loadChildren();
          }
        }, '保存');
      };

      const deleteChild = (id) => {
        showConfirm('确定要删除此孩子档案吗？', async () => {
          const res = await api('/users/children/' + id, { method: 'DELETE' });
          if (res) { toast('删除成功', 'success'); loadChildren(); }
        }, '删除档案', '删除');
      };

      document.getElementById('addChildBtn').addEventListener('click', () => editChild(null));
      loadChildren();
    }
  };
}

// ============================================================
//   应用启动
// ============================================================

// Modal 事件绑定
document.getElementById('genericModal').addEventListener('click', (e) => {
  if (e.target.classList.contains('modal-overlay')) closeModal('genericModal');
});
document.getElementById('confirmDialog').addEventListener('click', (e) => {
  if (e.target.classList.contains('modal-overlay')) closeModal('confirmDialog');
});
document.getElementById('modalOkBtn').addEventListener('click', async () => {
  if (modalCallback) {
    const okBtn = document.getElementById('modalOkBtn');
    okBtn.disabled = true;
    const originalText = okBtn.textContent;
    okBtn.textContent = '处理中...';
    try {
      const result = await modalCallback();
      if (result !== false) closeModal('genericModal');
    } finally {
      okBtn.disabled = false;
      okBtn.textContent = originalText;
    }
  } else {
    closeModal('genericModal');
  }
});
document.getElementById('confirmCancelBtn').addEventListener('click', () => {
  confirmCallback = null;
  closeModal('confirmDialog');
});
document.getElementById('confirmOkBtn').addEventListener('click', () => {
  if (confirmCallback) confirmCallback();
  confirmCallback = null;
  closeModal('confirmDialog');
});

// 认证标签切换
document.querySelectorAll('.auth-tab').forEach(tab => {
  tab.addEventListener('click', () => switchAuthTab(tab.dataset.tab));
});

// 登录表单
document.getElementById('loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;
  const errEl = document.getElementById('loginError');
  errEl.textContent = '';
  if (!email || !password) { errEl.textContent = '请填写邮箱和密码'; return; }
  const btn = document.getElementById('loginBtn');
  btn.disabled = true;
  btn.textContent = '登录中...';
  const ok = await login(email, password);
  btn.disabled = false;
  btn.textContent = '登 录';
  if (!ok) errEl.textContent = '登录失败，请检查邮箱和密码';
});

// 注册表单
document.getElementById('registerForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const nickname = document.getElementById('regNickname').value.trim();
  const email = document.getElementById('regEmail').value.trim();
  const password = document.getElementById('regPassword').value;
  const errEl = document.getElementById('registerError');
  errEl.textContent = '';
  if (!nickname || !email || !password) { errEl.textContent = '请填写所有字段'; return; }
  if (password.length < 6) { errEl.textContent = '密码至少6位'; return; }
  const btn = document.getElementById('registerBtn');
  btn.disabled = true;
  btn.textContent = '注册中...';
  const ok = await register(email, password, nickname);
  btn.disabled = false;
  btn.textContent = '注 册';
  if (!ok) errEl.textContent = '注册失败，邮箱可能已被使用';
});

// 退出按钮
document.getElementById('logoutBtn').addEventListener('click', () => {
  showConfirm('确定要退出登录吗？', () => logout(), '退出登录', '退出');
});

// 启动
(async function boot() {
  const authPage = document.getElementById('authPage');
  const appLayout = document.getElementById('appLayout');
  // 初始状态：隐藏两个页面，等待 checkAuth 完成
  authPage.style.display = 'none';
  authPage.classList.remove('visible');
  appLayout.style.display = 'none';
  appLayout.classList.remove('active');

  if (state.token) {
    const ok = await checkAuth();
    if (ok) {
      await initApp();
    } else {
      // checkAuth 失败（token 过期/用户被禁用），清空 token 显示登录页
      state.token = '';
      state.user = null;
      localStorage.removeItem('token');
      authPage.style.display = 'flex';
      authPage.classList.add('visible');
      switchAuthTab('login');
    }
  } else {
    authPage.style.display = 'flex';
    authPage.classList.add('visible');
    appLayout.style.display = 'none';
  }
})();