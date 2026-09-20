(function () {
  'use strict';

  const app = document.getElementById('app');
  const root = document.getElementById('screen-root');

  let LOCALE = {};
  let NOTIF_CFG = { position: 'top-right', duration: 5000, maxVisible: 5 };

  function t(key, ...args) {
    let value = LOCALE[key] || key;
    args.forEach((a) => { value = value.replace('%s', a); });
    return value;
  }

  function resourceName() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'X1S-LifeSystem';
  }

  function post(endpoint, data) {
    return fetch(`https://${resourceName()}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    }).then((r) => r.json ? r.json().catch(() => ({})) : {}).catch(() => ({}));
  }

  function show() { app.classList.remove('hidden'); }
  function hideApp() { app.classList.add('hidden'); setBgMusicPhase(false); }

  document.addEventListener('click', () => {
    const menu = document.getElementById('cadStatusMenu');
    if (menu) menu.classList.remove('open');
  });

  let clickAudioCtx = null;
  function playClickSound() {
    const gainLevel = (window.X1SSettings && typeof window.X1SSettings.gain === 'function') ? window.X1SSettings.gain('ui') : 1;
    if (gainLevel <= 0) return;
    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) return;
      if (!clickAudioCtx) clickAudioCtx = new AudioContextClass();
      if (clickAudioCtx.state === 'suspended') clickAudioCtx.resume();
      const oscillator = clickAudioCtx.createOscillator();
      const gain = clickAudioCtx.createGain();
      oscillator.type = 'square';
      oscillator.frequency.value = 880;
      gain.gain.setValueAtTime(0.02 * gainLevel, clickAudioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, clickAudioCtx.currentTime + 0.06);
      oscillator.connect(gain);
      gain.connect(clickAudioCtx.destination);
      oscillator.start();
      oscillator.stop(clickAudioCtx.currentTime + 0.06);
    } catch (_) {
    }
  }
  document.addEventListener('click', (e) => {
    const target = e.target.closest('button, .btn, .cad-nav-btn, .cad-status-option, [role="button"]');
    if (target && !target.disabled) playClickSound();
  });

  const setBgMusicPhase = (function () {
    const audioEl = document.getElementById('bgMusic');
    const controlsEl = document.getElementById('bgMusicControls');
    const toggleBtn = document.getElementById('bgMusicToggle');
    const volumeSlider = document.getElementById('bgMusicVolume');
    let active = false;

    function applyVolume() {
      if (!audioEl || !window.X1SSettings) return;
      const s = window.X1SSettings.get();
      const gain = window.X1SSettings.gain('music');
      audioEl.volume = Math.max(0, Math.min(1, gain));
      if (controlsEl) controlsEl.classList.toggle('muted', gain <= 0);
      if (volumeSlider) volumeSlider.value = s.musicVolume;
    }

    function tryPlay() {
      if (!audioEl) return;
      const p = audioEl.play();
      if (p && typeof p.catch === 'function') p.catch(() => {});
    }

    if (toggleBtn) {
      toggleBtn.addEventListener('click', () => {
        const s = window.X1SSettings.get();
        window.X1SSettings.set({ musicMuted: !s.musicMuted });
      });
    }
    if (volumeSlider) {
      volumeSlider.addEventListener('input', () => {
        window.X1SSettings.set({ musicVolume: parseInt(volumeSlider.value, 10) || 0 });
      });
    }
    if (window.X1SSettings) window.X1SSettings.onChange(applyVolume);
    applyVolume();

    document.addEventListener('click', () => {
      if (active && audioEl && audioEl.paused) tryPlay();
    });

    return function setBgMusicPhase(next) {
      active = next;
      if (controlsEl) controlsEl.classList.toggle('hidden', !active);
      if (!audioEl) return;
      if (active) { applyVolume(); tryPlay(); } else { audioEl.pause(); }
    };
  })();

  const initCustomCursor = (function () {
    const cursorEl = document.getElementById('x1s-cursor');
    let phaseActive = true;
    let visible = false;

    function applyVisibility() {
      const appVisible = app && !app.classList.contains('hidden');
      const next = phaseActive && appVisible;
      if (next === visible) return;
      visible = next;
      if (cursorEl) cursorEl.style.display = visible ? 'block' : 'none';
      document.body.classList.toggle('x1s-hide-native-cursor', visible);
    }

    if (cursorEl) {
      document.addEventListener('mousemove', (e) => {
        cursorEl.style.left = e.clientX + 'px';
        cursorEl.style.top = e.clientY + 'px';
      }, { passive: true });
      new MutationObserver(applyVisibility).observe(app, { attributes: true, attributeFilter: ['class'] });
    }

    return function setCustomCursorPhase(active) {
      phaseActive = active;
      applyVisibility();
    };
  })();

  function el(html) {
    const div = document.createElement('div');
    div.innerHTML = html.trim();
    return div.firstElementChild;
  }

  function esc(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  function renderRoot(html) {
    root.innerHTML = html;
    show();
  }

  function screenBootLoading() {
    initCustomCursor(true);
    setBgMusicPhase(false);
    renderRoot(`
      <div class="screen centered-screen boot-loading">
        <div class="boot-ring"></div>
        <span>Loading Character Data</span>
      </div>
    `);
  }

  const creator = {
    context: null,
    tab: 'identity',
    data: null
  };

  function defaultCreatorData(genderKey) {
    return {
      firstName: '', lastName: '', dob: '', gender: genderKey, height: 178
    };
  }

  function previewLive(skipModelSwap) {
    post('previewAppearance', {
      gender: skipModelSwap ? undefined : creator.data.gender
    });
  }

  function screenCharacterCreator(context) {
    setBgMusicPhase(true);
    creator.context = context;
    creator.tab = 'identity';
    creator.data = defaultCreatorData(context.genders[0].key);

    renderRoot(`
      <div class="screen creator-screen char-creator-screen">
        <div class="panel creator-panel">
          <div>
            <span class="eyebrow">${esc(t('char_new_character'))}</span>
            <h1>${esc(t('char_creator_title'))}</h1>
          </div>
          <div class="creator-tabs tab-row" id="creatorTabs"></div>
          <div class="scroll-y" id="creatorBody" style="flex:1;"></div>
          <div id="creatorErr" class="hint" style="color:var(--red-bright);"></div>
          <div class="creator-actions">
            ${context.canCancel ? `<button class="btn btn-ghost" id="creatorBackBtn">${esc(t('cancel'))}</button>` : `<span class="hint">${esc(t('char_creator_hint'))}</span>`}
            <button class="btn btn-primary" id="createBtn">${esc(t('char_create_button'))}</button>
          </div>
        </div>
      </div>
    `);

    renderCreatorTabs();
    renderCreatorBody();
    previewLive(false);

    document.getElementById('createBtn').addEventListener('click', submitCharacter);
    if (context.canCancel) {
      document.getElementById('creatorBackBtn').addEventListener('click', () => post('cancelCreatorToSelector', {}));
    }
  }

  const CREATOR_TABS = [
    { key: 'identity', label: 'char_tab_identity' }
  ];

  function renderCreatorTabs() {
    const wrap = document.getElementById('creatorTabs');
    wrap.innerHTML = '';
    if (CREATOR_TABS.length <= 1) { wrap.classList.add('hidden'); return; }
    wrap.classList.remove('hidden');
    CREATOR_TABS.forEach((tab) => {
      const btn = el(`<button class="tab-btn ${tab.key === creator.tab ? 'active' : ''}">${esc(t(tab.label))}</button>`);
      btn.addEventListener('click', () => { creator.tab = tab.key; renderCreatorTabs(); renderCreatorBody(); });
      wrap.appendChild(btn);
    });
  }

  function sliderRow(label, value, min, max, step, onInput) {
    const row = el(`
      <div class="slider-field">
        <div class="slider-head"><span>${esc(label)}</span><span class="val">${value}</span></div>
        <input type="range" min="${min}" max="${max}" step="${step || 1}" value="${value}">
      </div>
    `);
    const input = row.querySelector('input');
    const val = row.querySelector('.val');
    input.addEventListener('input', () => {
      val.textContent = input.value;
      onInput(parseFloat(input.value));
    });
    return row;
  }

  function renderCreatorBody() {
    const body = document.getElementById('creatorBody');
    body.innerHTML = '';
    const ctx = creator.context;
    const d = creator.data;

    if (creator.tab === 'identity') {
      body.appendChild(el(`
        <div class="identity-section">
          <div class="gender-toggle">
            ${ctx.genders.map((g) => `<button class="btn ${g.key === d.gender ? 'active' : ''}" data-gender="${g.key}">${esc(g.label)}</button>`).join('')}
          </div>
          <div class="field-row">
            <div class="field"><label>${esc(t('char_first_name'))}</label><input id="fFirst" maxlength="24" value="${esc(d.firstName)}"></div>
            <div class="field"><label>${esc(t('char_last_name'))}</label><input id="fLast" maxlength="24" value="${esc(d.lastName)}"></div>
          </div>
          <div class="field-row">
            <div class="field"><label>${esc(t('char_dob'))}</label><input id="fDob" type="date" value="${esc(d.dob)}"></div>
            <div class="field"><label>${esc(t('char_height'))}</label><input id="fHeight" type="number" min="${ctx.minHeight}" max="${ctx.maxHeight}" value="${d.height}"></div>
          </div>
          <p class="hint">${esc(t('char_age_hint', ctx.minAge, ctx.maxAge))}</p>
        </div>
      `));
      body.querySelectorAll('[data-gender]').forEach((btn) => {
        btn.addEventListener('click', () => {
          d.gender = btn.dataset.gender;
          renderCreatorBody();
          previewLive(false);
        });
      });
      body.querySelector('#fFirst').addEventListener('input', (e) => { d.firstName = e.target.value; });
      body.querySelector('#fLast').addEventListener('input', (e) => { d.lastName = e.target.value; });
      body.querySelector('#fDob').addEventListener('input', (e) => { d.dob = e.target.value; });
      body.querySelector('#fHeight').addEventListener('input', (e) => { d.height = parseInt(e.target.value, 10) || d.height; });
    }
  }

  function submitCharacter() {
    const errEl = document.getElementById('creatorErr');
    errEl.textContent = '';
    post('submitCharacter', creator.data);
  }

  function onCreatorError(message) {
    const errEl = document.getElementById('creatorErr');
    if (errEl) errEl.textContent = message;
  }

  const selector = { payload: null, selectedIndex: 0 };

  function fmtDate(d) {
    if (!d) return '';
    return String(d).split(' ')[0].split('T')[0];
  }

  function screenCharacterSelector(payload) {
    setBgMusicPhase(true);
    selector.payload = payload;
    selector.selectedIndex = 0;

    const chars = payload.characters || [];

    renderRoot(`
      <div class="screen selector-screen">
        <div class="panel selector-list-panel">
          <div>
            <span class="eyebrow">${esc(t('char_selector_eyebrow'))}</span>
            <h1>${esc(t('char_selector_title'))}</h1>
          </div>
          <div class="selector-cards scroll-y" id="charCards"></div>
          ${payload.allowCreate ? `<button class="btn btn-block" id="newCharBtn">+ ${esc(t('char_create_new'))}</button>` : `<p class="hint">${esc(t('char_limit_reached'))}</p>`}
        </div>
        <div class="selector-detail-panel" id="selectorDetail"></div>
      </div>
    `);

    renderCharCards();
    renderSelectorDetail();

    if (payload.allowCreate) {
      document.getElementById('newCharBtn').addEventListener('click', () => post('requestCreatorFromSelector', {}));
    }
  }

  function renderCharCards() {
    const wrap = document.getElementById('charCards');
    wrap.innerHTML = '';
    const chars = selector.payload.characters || [];
    if (chars.length === 0) {
      wrap.appendChild(el(`<div class="list-empty">${esc(t('char_none_yet'))}</div>`));
      return;
    }
    chars.forEach((c, i) => {
      const card = el(`
        <div class="char-card ${i === selector.selectedIndex ? 'selected' : ''}">
          <div>
            <div class="char-name">${esc(c.firstName)} ${esc(c.lastName)}</div>
            <div class="char-meta">${esc(c.stateId)} • ${fmtDate(c.dob)}</div>
          </div>
          ${selector.payload.allowDelete ? '<span class="char-del" title="Delete">&times;</span>' : ''}
        </div>
      `);
      card.addEventListener('click', (e) => {
        if (e.target.classList.contains('char-del')) return;
        selector.selectedIndex = i;
        renderCharCards();
        renderSelectorDetail();
        post('previewCharacterSlot', { gender: c.gender });
      });
      const delBtn = card.querySelector('.char-del');
      if (delBtn) {
        delBtn.addEventListener('click', () => {
          post('deleteCharacter', { characterId: c.id });
        });
      }
      wrap.appendChild(card);
    });
  }

  function renderSelectorDetail() {
    const wrap = document.getElementById('selectorDetail');
    const chars = selector.payload.characters || [];
    const c = chars[selector.selectedIndex];
    if (!c) {
      wrap.innerHTML = '';
      return;
    }
    wrap.innerHTML = `
      <div class="name-huge">${esc(c.firstName)} ${esc(c.lastName)}</div>
      <div class="detail-row">
        <span>${esc(t('char_dob'))}: ${fmtDate(c.dob)}</span>
        <span>${esc(t('char_gender_label'))}: ${esc(c.gender)}</span>
        <span>${esc(t('char_id_label'))}: ${esc(c.stateId)}</span>
      </div>
      <div style="margin-top:18px; display:flex; gap:12px;">
        <button class="btn btn-primary" id="playBtn">${esc(t('char_play_button'))}</button>
      </div>
    `;
    document.getElementById('playBtn').addEventListener('click', () => {
      post('selectCharacter', { characterId: c.id });
    });
  }

  function screenSpawnLoading() {
    setBgMusicPhase(true);
    renderRoot(`
      <div id="loading-screen" class="screen">
        <div class="loading-grid"></div>
        <div class="pulse-rings"><span></span><span></span><span></span></div>
        <div class="particles"><span></span><span></span><span></span><span></span><span></span><span></span></div>
        <div class="loading-inner">
          <div class="logo-frame">
            <div class="logo-ring logo-ring-outer"></div>
            <div class="logo-ring logo-ring-inner"></div>
            <img class="server-logo" src="logo.png" alt="Server logo">
          </div>
          <div class="loading-bar"><div class="loading-bar-fill"></div></div>
          <span class="loading-status">ESTABLISHING UPLINK<span class="dots"><span>.</span><span>.</span><span>.</span></span></span>
        </div>
      </div>
    `);
  }

  const spawnState = { locations: [], selected: null, allowClose: false };

  function screenSpawnSelector(payload) {
    setBgMusicPhase(true);
    spawnState.locations = payload.locations || [];
    spawnState.selected = null;
    spawnState.allowClose = payload.allowClose === true;

    renderRoot(`
      <div id="selector-screen" class="screen">
        <aside class="sidebar">
          <div class="sidebar-header">
            <span class="eyebrow">// X1Studios FiveM Development</span>
            <h1>SPAWN<span class="accent"> </span>SELECTOR</h1>
            <div class="rule"></div>
          </div>
          <ul id="location-list"></ul>
          <div class="sidebar-footer">
            <span class="hint-key">&uarr; / &darr;</span>
            <span class="hint-label">or click to preview a location</span>
          </div>
        </aside>
        <div class="infobar">
          <div class="infobar-left">
            <div class="ping"><span></span></div>
            <div class="infobar-text">
              <span class="loc-name" id="selected-name">&mdash;</span>
              <span class="loc-coords" id="selected-coords">X 0.0&nbsp;&nbsp;Y 0.0</span>
            </div>
          </div>
          <button id="spawn-btn" class="spawn-btn" disabled>
            <span class="spawn-btn-bracket">[</span> <span class="spawn-btn-label">SPAWN HERE</span> <span class="spawn-btn-bracket">]</span>
          </button>
        </div>
      </div>
    `);

    renderLocationList();
    if (spawnState.locations.length) selectLocation(0);
  }

  function renderLocationList() {
    const listEl = document.getElementById('location-list');
    listEl.innerHTML = '';
    spawnState.locations.forEach((loc, i) => {
      const li = el(`
        <li class="location-card" style="${loc.image ? `background-image:url('${loc.image}')` : ''}">
          <span class="loc-index">${String(i + 1).padStart(2, '0')}</span>
          <span class="loc-title">${esc(loc.name)}</span>
          <span class="loc-district">${esc(loc.district || '')}</span>
          <span class="loc-chevron">&rsaquo;</span>
        </li>
      `);
      li.addEventListener('click', () => selectLocation(i));
      listEl.appendChild(li);
    });
  }

  function selectLocation(i) {
    const loc = spawnState.locations[i];
    if (!loc) return;
    spawnState.selected = i;

    const [xText, yText] = loc.coordsText.split(',');
    document.getElementById('selected-name').textContent = loc.name;
    document.getElementById('selected-coords').innerHTML = `X ${xText.trim()}&nbsp;&nbsp;Y ${yText.trim()}`;

    const spawnBtn = document.getElementById('spawn-btn');
    spawnBtn.disabled = false;

    [...document.getElementById('location-list').children].forEach((elm, idx) => {
      elm.classList.toggle('selected', idx === i);
    });

    post('previewSpawn', { index: loc.index });
  }

  document.addEventListener('click', (e) => {
    if (e.target && e.target.id === 'spawn-btn' && !e.target.disabled) {
      e.target.disabled = true;
      post('confirmSpawn', { index: spawnState.locations[spawnState.selected].index });
    }
  });

  const cad = {
    context: null,
    nav: 'home',
    results: [],
    profile: null,
    vehicles: [],
    warrants: [],
    incidents: [],
    dispatchCalls: [],
    panicAlerts: [],
    isPanicSupervisor: false,
    warrantStatus: 'active',
    vehicleBoloStatus: 'active',
    roster: [],
    adminSection: 'tencodes'
  };

  let cadOpenToken = 0;

  const CAD_NAV = [
    { key: 'home', label: 'cad_nav_home' },
    { key: 'roster', label: 'cad_nav_roster' },
    { key: 'citizens', label: 'cad_nav_citizens' },
    { key: 'vehicles', label: 'cad_nav_vehicles' },
    { key: 'warrants', label: 'cad_nav_warrants' },
    { key: 'vehiclebolos', label: 'cad_nav_vehiclebolos' },
    { key: 'incidents', label: 'cad_nav_incidents' },
    { key: 'dispatch', label: 'cad_nav_dispatch' },
    { key: 'panic', label: 'cad_nav_panic' },
    { key: 'tencodes', label: 'cad_nav_tencodes' },
    { key: 'penalcodes', label: 'cad_nav_penalcodes' }
  ];

  const CAD_TRANSPARENCY_ICON = '<svg viewBox="0 0 24 24" width="16" height="16"><circle cx="12" cy="12" r="8.4" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 3.6a8.4 8.4 0 0 0 0 16.8Z" fill="currentColor"/></svg>';

  let cadTransparentFallback = false;
  function getCadTransparency() {
    try { return localStorage.getItem('x1s_cad_transparent') === '1'; } catch (e) { return cadTransparentFallback; }
  }
  function setCadTransparency(value) {
    cadTransparentFallback = value;
    try { localStorage.setItem('x1s_cad_transparent', value ? '1' : '0'); } catch (e) { /* storage unavailable - in-memory only */ }
  }
  function toggleCadTransparency() {
    const shell = document.querySelector('.cad-shell');
    const tabletScreen = document.querySelector('.cad-tablet-screen');
    const btn = document.getElementById('cadTransparencyBtn');
    const next = !(shell && shell.classList.contains('cad-transparent'));
    if (shell) shell.classList.toggle('cad-transparent', next);
    if (tabletScreen) tabletScreen.classList.toggle('cad-transparent', next);
    if (btn) btn.classList.toggle('active', next);
    setCadTransparency(next);
  }

  function cadTabletFrame(screenInnerHtml, withHome, extraHtml, transparent) {
    return `
      <div class="cad-tablet">
        <div class="cad-tablet-title"><span class="cad-tablet-cam"></span><strong>${esc(t('cad_tablet_title'))}</strong></div>
        <div class="cad-tablet-screen ${transparent ? 'cad-transparent' : ''}">${screenInnerHtml}</div>
        ${withHome ? `<button class="cad-tablet-home" id="cadTabletHomeBtn" type="button" title="${esc(t('cad_tablet_home'))}"></button>` : ''}
        ${extraHtml || ''}
      </div>
    `;
  }

  function screenCadLoading(onDone) {
    initCustomCursor(false);
    setBgMusicPhase(false);
    renderRoot(`
      <div class="screen cad-screen">
        ${cadTabletFrame(`
          <div id="loading-screen" class="cad-boot-loading">
            <div class="loading-grid"></div>
            <div class="pulse-rings"><span></span><span></span><span></span></div>
            <div class="particles"><span></span><span></span><span></span><span></span><span></span><span></span></div>
            <div class="loading-inner">
              <div class="logo-frame">
                <div class="logo-ring logo-ring-outer"></div>
                <div class="logo-ring logo-ring-inner"></div>
                <img class="cad-logo" src="x1scad.png" alt="CAD">
              </div>
              <div class="loading-bar"><div class="loading-bar-fill"></div></div>
              <span class="loading-status">${esc(t('cad_loading_status'))}<span class="dots"><span>.</span><span>.</span><span>.</span></span></span>
            </div>
          </div>
        `, false)}
      </div>
    `);
    if (typeof onDone === 'function') setTimeout(onDone, 2200);
  }

  function screenCad(context) {
    initCustomCursor(false);
    cad.context = Object.assign({}, cad.context, context);
    cad.nav = context && context.focusCall ? 'dispatch' : 'home';
    cad.focusCallId = (context && context.focusCall) || null;
    cad.profile = null;
    cad.results = [];

    const transparent = getCadTransparency();
    const ctx = cad.context;

    renderRoot(`
      <div class="screen cad-screen">
        ${cadTabletFrame(`
          <div class="panel cad-shell ${transparent ? 'cad-transparent' : ''}">
            <div class="cad-header">
              <div class="cad-title">
                <img class="cad-dept-logo hidden" id="cadDeptLogo" alt="">
                <div class="cad-title-text">
                  <span class="cad-dept-fullname" id="cadDeptFullName">${esc(ctx.departmentLabel || ctx.department)}</span>
                  <span class="cad-dept-sub">
                    <span class="pill pill-red" id="cadDeptCode">${esc(ctx.department)}</span>
                    <span>X1S CAD/MDT</span>
                  </span>
                </div>
              </div>
              <div class="cad-officer" id="cadOfficerInfo">
                <div class="cad-officer-name" id="cadOfficerName">${esc(ctx.name || (ctx.character ? ctx.character.firstName + ' ' + ctx.character.lastName : ''))}</div>
                <div class="cad-officer-meta" id="cadOfficerMeta">${esc(t('cad_officer_label'))}</div>
                <button class="cad-status" id="cadStatusBtn" type="button" data-status="${esc(ctx.status || 'active')}">
                  <span class="cad-status-dot"></span>
                  <span id="cadStatusLabel"></span>
                </button>
                <div class="cad-status-menu" id="cadStatusMenu"></div>
              </div>
              <div class="cad-clock" id="cadClock">
                <span class="cad-clock-time" id="cadClockTime">--:--:--</span>
                <span class="cad-clock-date" id="cadClockDate">----</span>
              </div>
              <div class="cad-header-actions">
                <button class="btn btn-ghost btn-sm" id="cadOffDutyBtn">${esc(t('go_off_duty'))}</button>
                <button class="btn btn-ghost btn-sm" id="cadCloseBtn">${esc(t('close'))}</button>
              </div>
            </div>
            <div class="cad-body">
              <div class="cad-sidebar" id="cadSidebar"></div>
              <div class="cad-content" id="cadContent"></div>
            </div>
          </div>
        `, true, `<button class="cad-transparency-btn ${transparent ? 'active' : ''}" id="cadTransparencyBtn" type="button" title="${esc(t('cad_toggle_transparency'))}">${CAD_TRANSPARENCY_ICON}</button>`, transparent)}
      </div>
    `);

    document.getElementById('cadCloseBtn').addEventListener('click', () => post('closeCad', {}));
    document.getElementById('cadOffDutyBtn').addEventListener('click', () => { post('offDuty', {}); post('closeCad', {}); });
    document.getElementById('cadTransparencyBtn').addEventListener('click', toggleCadTransparency);
    document.getElementById('cadStatusBtn').addEventListener('click', (e) => {
      e.stopPropagation();
      document.getElementById('cadStatusMenu').classList.toggle('open');
    });
    document.getElementById('cadTabletHomeBtn').addEventListener('click', () => {
      cad.nav = 'home';
      cad.profile = null;
      renderCadSidebar();
      renderCadNav();
    });
    renderCadHeader();
    renderCadSidebar();
    renderCadNav();
    startCadClock();
  }

  let cadClockTimer = null;
  function startCadClock() {
    stopCadClock();
    updateCadClock();
    cadClockTimer = setInterval(updateCadClock, 1000);
  }
  function stopCadClock() {
    if (cadClockTimer) { clearInterval(cadClockTimer); cadClockTimer = null; }
  }
  function updateCadClock() {
    const timeEl = document.getElementById('cadClockTime');
    const dateEl = document.getElementById('cadClockDate');
    if (!timeEl && !dateEl) return;
    const now = new Date();
    if (timeEl) {
      const pad = (n) => String(n).padStart(2, '0');
      timeEl.textContent = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
    }
    if (dateEl) {
      dateEl.textContent = now.toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' }).toUpperCase();
    }
  }

  function renderCadHeader() {
    const ctx = cad.context || {};
    const deptFullEl = document.getElementById('cadDeptFullName');
    const deptCodeEl = document.getElementById('cadDeptCode');
    const logoEl = document.getElementById('cadDeptLogo');
    const nameEl = document.getElementById('cadOfficerName');
    const metaEl = document.getElementById('cadOfficerMeta');

    if (deptFullEl) deptFullEl.textContent = ctx.departmentLabel || ctx.department || '';
    if (deptCodeEl) deptCodeEl.textContent = ctx.department || '';
    if (logoEl) {
      if (ctx.logo) { logoEl.src = ctx.logo; logoEl.classList.remove('hidden'); }
      else { logoEl.classList.add('hidden'); logoEl.removeAttribute('src'); }
    }
    if (nameEl) nameEl.textContent = ctx.name || (ctx.character ? `${ctx.character.firstName} ${ctx.character.lastName}` : '');
    if (metaEl) {
      const parts = [];
      if (ctx.callsign) parts.push(`[${ctx.callsign}]`);
      if (ctx.rank) parts.push(ctx.rank);
      metaEl.textContent = parts.length ? parts.join(' \u2022 ') : t('cad_officer_label');
    }
    renderCadStatus();
  }

  const DEFAULT_CAD_STATUSES = [
    { key: 'active', label: 'Active', color: 'green' },
    { key: 'busy', label: 'Busy', color: 'amber' },
    { key: 'onscene', label: 'On Scene', color: 'red-bright' },
    { key: 'enroute', label: 'En Route', color: 'blue' },
    { key: 'outofservice', label: 'Out of Service', color: 'gray' }
  ];

  function cadStatusList() {
    const fromCtx = cad.context && cad.context.statuses;
    return Array.isArray(fromCtx) && fromCtx.length ? fromCtx : DEFAULT_CAD_STATUSES;
  }

  function cadStatusMeta(key) {
    return cadStatusList().find((s) => s.key === key) || { key: key, label: key || '', color: 'gray' };
  }

  function renderCadStatus() {
    const ctx = cad.context || {};
    const status = ctx.status || 'active';
    const btn = document.getElementById('cadStatusBtn');
    const labelEl = document.getElementById('cadStatusLabel');
    const menu = document.getElementById('cadStatusMenu');
    if (btn) btn.dataset.status = status;
    if (labelEl) labelEl.textContent = cadStatusMeta(status).label;
    if (menu) {
      menu.innerHTML = '';
      cadStatusList().forEach((s) => {
        const opt = el(`
          <button type="button" class="cad-status-option">
            <span class="cad-status-dot" style="background:var(--${esc(s.color || 'gray')});"></span>
            <span>${esc(s.label)}</span>
          </button>
        `);
        opt.addEventListener('click', (e) => {
          e.stopPropagation();
          menu.classList.remove('open');
          if (s.key === status) return;
          if (cad.context) cad.context.status = s.key;
          renderCadStatus();
          post('cadSetStatus', { status: s.key });
        });
        menu.appendChild(opt);
      });
    }
  }

  function renderCadSidebar() {
    const wrap = document.getElementById('cadSidebar');
    wrap.innerHTML = '';

    const scroll = el(`<div class="cad-sidebar-scroll"></div>`);
    CAD_NAV.forEach((item) => {
      const btn = el(`<button class="cad-nav-btn ${item.key === cad.nav ? 'active' : ''}">${esc(t(item.label))}</button>`);
      btn.addEventListener('click', () => { cad.nav = item.key; cad.profile = null; renderCadSidebar(); renderCadNav(); });
      scroll.appendChild(btn);
    });
    wrap.appendChild(scroll);

    const pinned = el(`<div class="cad-sidebar-pinned"></div>`);
    const settingsBtn = el(`<button class="cad-nav-btn ${cad.nav === 'settings' ? 'active' : ''}">${esc(t('cad_nav_settings'))}</button>`);
    settingsBtn.addEventListener('click', () => { cad.nav = 'settings'; cad.profile = null; renderCadSidebar(); renderCadNav(); });
    pinned.appendChild(settingsBtn);

    if (cad.context && cad.context.isAdmin) {
      const adminBtn = el(`<button class="cad-nav-btn ${cad.nav === 'admin' ? 'active' : ''}">${esc(t('cad_nav_admin'))}</button>`);
      adminBtn.addEventListener('click', () => { cad.nav = 'admin'; cad.profile = null; renderCadSidebar(); renderCadNav(); });
      pinned.appendChild(adminBtn);
    }

    wrap.appendChild(pinned);
  }

  function renderCadHome(content) {
    const ctx = cad.context || {};
    const fullName = ctx.name || (ctx.character ? `${ctx.character.firstName} ${ctx.character.lastName}` : '');
    const callsignPrefix = ctx.callsign ? `[${ctx.callsign}] ` : '';
    content.innerHTML = `
      <div class="cad-detail-col" style="width:100%;">
        <div class="cad-home-welcome">
          <span class="eyebrow">${esc(t('cad_home_eyebrow'))}</span>
          <div class="name-huge">${esc(t('cad_home_welcome', callsignPrefix + fullName))}</div>
          <div class="char-meta">${esc(ctx.departmentLabel || ctx.department || '')}${ctx.rank ? ' • ' + esc(ctx.rank) : ''}</div>
        </div>
        <div class="cad-home-widgets">
          <div class="home-widget">
            <div class="home-widget-head">
              <h3>${esc(t('cad_home_active_calls'))}</h3>
              <span class="pill pill-amber" id="homeCallsCount">0</span>
            </div>
            <div class="home-widget-body" id="homeCallsList"></div>
          </div>
          <div class="home-widget">
            <div class="home-widget-head">
              <h3>${esc(t('cad_home_active_warrants'))}</h3>
              <span class="pill pill-red" id="homeWarrantsCount">0</span>
            </div>
            <div class="home-widget-body" id="homeWarrantsList"></div>
          </div>
          <div class="home-widget">
            <div class="home-widget-head">
              <h3>${esc(t('cad_home_active_bolos'))}</h3>
              <span class="pill pill-red" id="homeBolosCount">0</span>
            </div>
            <div class="home-widget-body" id="homeBolosList"></div>
          </div>
        </div>
      </div>
    `;
    renderHomeCallsWidget();
    renderHomeWarrantsWidget();
    renderHomeVehicleBolosWidget();
    post('requestDispatchState', {});
    post('cadSearchWarrants', { status: 'active' });
    post('cadSearchVehicleBolos', { status: 'active' });
  }

  function renderHomeCallsWidget() {
    const wrap = document.getElementById('homeCallsList');
    if (!wrap) return;
    const calls = cad.dispatchCalls || [];
    const countEl = document.getElementById('homeCallsCount');
    if (countEl) countEl.textContent = calls.length;
    if (calls.length === 0) { wrap.innerHTML = `<div class="list-empty">${esc(t('no_active_calls'))}</div>`; return; }
    wrap.innerHTML = '';
    calls.slice(0, 5).forEach((c) => {
      const row = el(`
        <div class="call-card" ${c.coords ? 'data-selectable' : ''} title="${c.coords ? esc(t('cad_set_waypoint')) : ''}">
          <div class="call-top">
            <strong>${esc(c.reason)}</strong>
            <span class="pill ${c.status === 'active' ? 'pill-amber' : 'pill-red'}">${esc(c.status || 'pending')}</span>
          </div>
          <div class="char-meta">${esc(c.street)}</div>
        </div>
      `);
      if (c.coords) row.addEventListener('click', () => post('cadSetWaypoint', { coords: c.coords }));
      wrap.appendChild(row);
    });
  }

  function renderHomeWarrantsWidget(results) {
    if (results) cad.homeWarrants = results;
    const wrap = document.getElementById('homeWarrantsList');
    if (!wrap) return;
    const list = cad.homeWarrants || [];
    const countEl = document.getElementById('homeWarrantsCount');
    if (countEl) countEl.textContent = list.length;
    if (list.length === 0) { wrap.innerHTML = `<div class="list-empty">${esc(t('cad_no_results'))}</div>`; return; }
    wrap.innerHTML = '';
    list.slice(0, 5).forEach((w) => {
      const row = el(`
        <div class="list-row" style="cursor:default;">
          <div>
            <div style="font-weight:700;">${esc(w.first_name)} ${esc(w.last_name)} ${flagPills(w.is_armed, w.is_violent, w.is_mentally_ill)}</div>
            <div class="char-meta">${esc(w.reason)}</div>
          </div>
        </div>
      `);
      wrap.appendChild(row);
    });
  }

  function renderHomeVehicleBolosWidget(results) {
    if (results) cad.homeVehicleBolos = results;
    const wrap = document.getElementById('homeBolosList');
    if (!wrap) return;
    const list = cad.homeVehicleBolos || [];
    const countEl = document.getElementById('homeBolosCount');
    if (countEl) countEl.textContent = list.length;
    if (list.length === 0) { wrap.innerHTML = `<div class="list-empty">${esc(t('cad_no_results'))}</div>`; return; }
    wrap.innerHTML = '';
    list.slice(0, 5).forEach((b) => {
      const row = el(`
        <div class="list-row" style="cursor:default;">
          <div>
            <div style="font-weight:700;">${esc(b.plate || t('cad_no_plate'))} ${flagPills(b.is_armed, b.is_violent, b.is_mentally_ill)}</div>
            <div class="char-meta">${esc([b.brand, b.model].filter(Boolean).join(' ')) || esc(b.reason)}</div>
          </div>
        </div>
      `);
      wrap.appendChild(row);
    });
  }

  function renderCadNav() {
    const content = document.getElementById('cadContent');
    if (cad.nav === 'home') return renderCadHome(content);
    if (cad.nav === 'roster') return renderCadRoster(content);
    if (cad.nav === 'citizens') return renderCadCitizens(content);
    if (cad.nav === 'vehicles') return renderCadVehicles(content);
    if (cad.nav === 'warrants') return renderCadWarrants(content);
    if (cad.nav === 'vehiclebolos') return renderCadVehicleBolos(content);
    if (cad.nav === 'incidents') return renderCadIncidents(content);
    if (cad.nav === 'dispatch') return renderCadDispatch(content);
    if (cad.nav === 'panic') return renderCadPanic(content);
    if (cad.nav === 'tencodes') return renderCadTenCodes(content);
    if (cad.nav === 'penalcodes') return renderCadPenalCodes(content);
    if (cad.nav === 'settings') return renderCadSettings(content);
    if (cad.nav === 'admin') return renderCadAdmin(content);
  }

  function cadDetailEmpty(content, message) {
    content.querySelector('#cadDetailCol').innerHTML = `<div class="cad-detail-empty">${esc(message)}</div>`;
  }

  function renderCadAdmin(content) {
    content.innerHTML = `
      <div class="cad-detail-col" style="width:100%;">
        <div class="profile-header">
          <div>
            <span class="eyebrow">${esc(t('cad_nav_admin'))}</span>
            <div class="name-huge">${esc(t('cad_nav_admin'))}</div>
          </div>
        </div>
        <div style="display:flex; gap:8px; margin:16px 0;">
          <button class="btn btn-sm ${cad.adminSection === 'tencodes' ? 'btn-primary' : 'btn-ghost'}" id="adminTabTenCodes">${esc(t('cad_nav_tencodes'))}</button>
          <button class="btn btn-sm ${cad.adminSection === 'penalcodes' ? 'btn-primary' : 'btn-ghost'}" id="adminTabPenalCodes">${esc(t('cad_nav_penalcodes'))}</button>
        </div>
        <div id="adminSectionBody"></div>
      </div>
    `;

    document.getElementById('adminTabTenCodes').addEventListener('click', () => {
      cad.adminSection = 'tencodes';
      renderCadAdmin(content);
    });
    document.getElementById('adminTabPenalCodes').addEventListener('click', () => {
      cad.adminSection = 'penalcodes';
      renderCadAdmin(content);
    });

    const body = document.getElementById('adminSectionBody');
    if (cad.adminSection === 'penalcodes') renderAdminPenalCodes(body);
    else renderAdminTenCodes(body);
  }

  function refreshCadAdminIfOpen() {
    const body = document.getElementById('adminSectionBody');
    if (!body) return;
    if (cad.adminSection === 'penalcodes') renderAdminPenalCodes(body);
    else renderAdminTenCodes(body);
  }

  function openConfirmModal(message, onConfirm) {
    const modal = openModal(`
      <h2>${esc(t('confirm_action'))}</h2>
      <p style="margin:10px 0 18px;">${esc(message)}</p>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      modal.remove();
      onConfirm();
    });
  }

  function renderAdminTenCodes(body) {
    const codes = (cad.context && cad.context.tenCodes) || [];
    body.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:14px;">
        <div class="field" style="max-width:280px; margin-bottom:0;"><input id="adminTenCodeSearch" placeholder="${esc(t('cad_tencode_search'))}"></div>
        <button class="btn btn-primary btn-sm" id="adminAddTenCode">${esc(t('cad_admin_add_tencode'))}</button>
      </div>
      <div id="adminTenCodeList" class="cad-results-list" style="padding:0;"></div>
    `;

    function draw(filter) {
      const f = (filter || '').toLowerCase();
      const filtered = codes.filter((c) => !f || c.code.toLowerCase().includes(f) || c.label.toLowerCase().includes(f));
      const list = document.getElementById('adminTenCodeList');
      list.innerHTML = filtered.length ? filtered.map((c) => `
        <div class="list-row" style="cursor:default;">
          <div>
            <div style="font-weight:700;">${esc(c.code)}</div>
            <div class="char-meta">${esc(c.label)}</div>
          </div>
          <div style="display:flex; gap:6px;">
            <button class="btn btn-sm adminEditTenCode" data-id="${c.id}">${esc(t('cad_edit'))}</button>
            <button class="btn btn-sm btn-ghost adminDeleteTenCode" data-id="${c.id}">${esc(t('cad_delete'))}</button>
          </div>
        </div>
      `).join('') : `<div class="list-empty">${esc(t('cad_no_results'))}</div>`;

      list.querySelectorAll('.adminEditTenCode').forEach((btn) => btn.addEventListener('click', () => {
        const rec = codes.find((c) => String(c.id) === btn.dataset.id);
        if (rec) openTenCodeModal(rec);
      }));
      list.querySelectorAll('.adminDeleteTenCode').forEach((btn) => btn.addEventListener('click', () => {
        const rec = codes.find((c) => String(c.id) === btn.dataset.id);
        if (!rec) return;
        openConfirmModal(t('cad_admin_delete_tencode_confirm', rec.code), () => {
          post('cadAdminDeleteTenCode', { id: rec.id });
        });
      }));
    }

    draw('');
    document.getElementById('adminTenCodeSearch').addEventListener('input', (e) => draw(e.target.value));
    document.getElementById('adminAddTenCode').addEventListener('click', () => openTenCodeModal(null));
  }

  function openTenCodeModal(rec) {
    const isEdit = !!rec;
    const modal = openModal(`
      <h2>${esc(isEdit ? t('cad_admin_edit_tencode') : t('cad_admin_add_tencode'))}</h2>
      <div class="field"><label>${esc(t('cad_admin_tencode_code'))}</label><input id="modCode" maxlength="16" placeholder="10-99" value="${isEdit ? esc(rec.code) : ''}"></div>
      <div class="field"><label>${esc(t('cad_admin_tencode_label'))}</label><input id="modLabel" maxlength="128" value="${isEdit ? esc(rec.label) : ''}"></div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      post('cadAdminSaveTenCode', {
        id: isEdit ? rec.id : null,
        code: modal.querySelector('#modCode').value,
        label: modal.querySelector('#modLabel').value
      });
      modal.remove();
    });
  }

  function renderAdminPenalCodes(body) {
    const codes = (cad.context && cad.context.penalCodes) || [];
    body.innerHTML = `
      <div style="display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:14px;">
        <div class="field" style="max-width:280px; margin-bottom:0;"><input id="adminPenalCodeSearch" placeholder="${esc(t('cad_penalcode_search'))}"></div>
        <button class="btn btn-primary btn-sm" id="adminAddPenalCode">${esc(t('cad_admin_add_penalcode'))}</button>
      </div>
      <div id="adminPenalCodeList" class="cad-results-list" style="padding:0;"></div>
    `;

    function draw(filter) {
      const f = (filter || '').toLowerCase();
      const filtered = codes.filter((c) => !f || c.code.toLowerCase().includes(f) || c.title.toLowerCase().includes(f));
      const list = document.getElementById('adminPenalCodeList');
      list.innerHTML = filtered.length ? filtered.map((c) => `
        <div class="record-row penal-row">
          <div class="record-top">
            <span>${esc(c.code)}</span>
            <span class="pill ${c.type === 'Felony' ? 'pill-red' : 'pill-amber'}">${esc(c.type)}</span>
          </div>
          <div style="font-weight:700; margin-bottom:4px;">${esc(c.title)}</div>
          <div class="char-meta" style="margin-bottom:10px;">${esc(c.bondType)} • $${Number(c.bondAmount).toLocaleString()} • ${esc(c.jailTime)}</div>
          <div style="display:flex; gap:6px;">
            <button class="btn btn-sm adminEditPenalCode" data-id="${c.id}">${esc(t('cad_edit'))}</button>
            <button class="btn btn-sm btn-ghost adminDeletePenalCode" data-id="${c.id}">${esc(t('cad_delete'))}</button>
          </div>
        </div>
      `).join('') : `<div class="list-empty">${esc(t('cad_no_results'))}</div>`;

      list.querySelectorAll('.adminEditPenalCode').forEach((btn) => btn.addEventListener('click', () => {
        const rec = codes.find((c) => String(c.id) === btn.dataset.id);
        if (rec) openPenalCodeModal(rec);
      }));
      list.querySelectorAll('.adminDeletePenalCode').forEach((btn) => btn.addEventListener('click', () => {
        const rec = codes.find((c) => String(c.id) === btn.dataset.id);
        if (!rec) return;
        openConfirmModal(t('cad_admin_delete_penalcode_confirm', rec.code), () => {
          post('cadAdminDeletePenalCode', { id: rec.id });
        });
      }));
    }

    draw('');
    document.getElementById('adminPenalCodeSearch').addEventListener('input', (e) => draw(e.target.value));
    document.getElementById('adminAddPenalCode').addEventListener('click', () => openPenalCodeModal(null));
  }

  function openPenalCodeModal(rec) {
    const isEdit = !!rec;
    const modal = openModal(`
      <h2>${esc(isEdit ? t('cad_admin_edit_penalcode') : t('cad_admin_add_penalcode'))}</h2>
      <div class="field"><label>${esc(t('cad_admin_penalcode_code'))}</label><input id="modCode" maxlength="32" placeholder="(CA)487" value="${isEdit ? esc(rec.code) : ''}"></div>
      <div class="field"><label>${esc(t('cad_admin_penalcode_title'))}</label><input id="modTitle" maxlength="128" value="${isEdit ? esc(rec.title) : ''}"></div>
      <div class="field-row">
        <div class="field">
          <label>${esc(t('cad_type'))}</label>
          <select id="modType">
            <option value="Misdemeanor" ${(!isEdit || rec.type !== 'Felony') ? 'selected' : ''}>${esc(t('cad_type_misdemeanor'))}</option>
            <option value="Felony" ${(isEdit && rec.type === 'Felony') ? 'selected' : ''}>${esc(t('cad_type_felony'))}</option>
          </select>
        </div>
        <div class="field"><label>${esc(t('cad_bond_type'))}</label><input id="modBondType" maxlength="32" value="${isEdit ? esc(rec.bondType) : 'Personal Recognizance'}"></div>
      </div>
      <div class="field-row">
        <div class="field"><label>${esc(t('cad_bond_amount'))}</label><input id="modBondAmount" type="number" min="0" step="1" value="${isEdit ? Number(rec.bondAmount) : 0}"></div>
        <div class="field"><label>${esc(t('cad_jail_time'))}</label><input id="modJailTime" maxlength="64" placeholder="Up to 6 Months" value="${isEdit ? esc(rec.jailTime) : ''}"></div>
      </div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      post('cadAdminSavePenalCode', {
        id: isEdit ? rec.id : null,
        code: modal.querySelector('#modCode').value,
        title: modal.querySelector('#modTitle').value,
        type: modal.querySelector('#modType').value,
        bondType: modal.querySelector('#modBondType').value,
        bondAmount: modal.querySelector('#modBondAmount').value,
        jailTime: modal.querySelector('#modJailTime').value
      });
      modal.remove();
    });
  }

  function renderCadSettings(content) {
    const draft = X1SSettings.get();

    content.innerHTML = `
      <div class="cad-detail-col" style="width:100%; max-width:640px;">
        <div class="profile-header">
          <div>
            <span class="eyebrow">${esc(t('cad_settings_subtitle'))}</span>
            <div class="name-huge">${esc(t('cad_settings_title'))}</div>
            <p style="margin-top:4px;">${esc(t('cad_settings_hint_local'))}</p>
          </div>
        </div>

        <div class="settings-section">
          <h3>${esc(t('cad_settings_audio'))}</h3>
          <div id="setSlidersWrap" class="settings-sliders"></div>
          <label class="settings-toggle-row" for="setMuteAll">
            <span>${esc(t('cad_settings_mute_all'))}</span>
            <span class="switch">
              <input type="checkbox" id="setMuteAll" ${draft.muteAll ? 'checked' : ''}>
              <span class="switch-track"><span class="switch-thumb"></span></span>
            </span>
          </label>
        </div>

        <div class="settings-section">
          <h3>${esc(t('cad_settings_notifications'))}</h3>
          <label class="field" for="setNotificationPosition">
            <span>${esc(t('cad_settings_notification_position'))}</span>
            <select id="setNotificationPosition">
              <option value="top-right">${esc(t('cad_settings_position_top_right'))}</option>
              <option value="top-left">${esc(t('cad_settings_position_top_left'))}</option>
              <option value="bottom-right">${esc(t('cad_settings_position_bottom_right'))}</option>
              <option value="bottom-left">${esc(t('cad_settings_position_bottom_left'))}</option>
            </select>
          </label>
        </div>

        <div class="settings-actions">
          <button class="btn btn-ghost" id="setRestoreBtn">${esc(t('cad_settings_restore'))}</button>
          <button class="btn btn-primary" id="setSaveBtn">${esc(t('cad_settings_save'))}</button>
          <span class="settings-saved-msg" id="setSavedMsg"></span>
        </div>
      </div>
    `;

    const slidersWrap = document.getElementById('setSlidersWrap');
    const muteInput = document.getElementById('setMuteAll');
    const posSelect = document.getElementById('setNotificationPosition');
    const savedMsg = document.getElementById('setSavedMsg');
    posSelect.value = draft.notificationPosition;

    let sliderInputs = [];
    function buildSliders() {
      slidersWrap.innerHTML = '';
      sliderInputs = [];
      const rows = [
        sliderRow(t('cad_settings_master_volume'), draft.masterVolume, 0, 100, 1, (v) => { draft.masterVolume = v; clearSavedMsg(); }),
        sliderRow(t('cad_settings_notification_volume'), draft.notificationVolume, 0, 100, 1, (v) => { draft.notificationVolume = v; clearSavedMsg(); }),
        sliderRow(t('cad_settings_ui_volume'), draft.uiVolume, 0, 100, 1, (v) => { draft.uiVolume = v; clearSavedMsg(); })
      ];
      rows.forEach((row) => { slidersWrap.appendChild(row); sliderInputs.push(row.querySelector('input')); });
      syncSlidersDisabled();
    }
    function syncSlidersDisabled() {
      sliderInputs.forEach((input) => { input.disabled = draft.muteAll; });
      slidersWrap.classList.toggle('settings-sliders--disabled', draft.muteAll);
    }
    function clearSavedMsg() { savedMsg.classList.remove('show'); }
    function showSavedMsg(text) {
      savedMsg.textContent = text;
      savedMsg.classList.add('show');
      clearTimeout(content._settingsMsgTimer);
      content._settingsMsgTimer = setTimeout(() => savedMsg.classList.remove('show'), 2200);
    }

    buildSliders();

    muteInput.addEventListener('change', () => { draft.muteAll = muteInput.checked; syncSlidersDisabled(); clearSavedMsg(); });
    posSelect.addEventListener('change', () => { draft.notificationPosition = posSelect.value; clearSavedMsg(); });

    document.getElementById('setSaveBtn').addEventListener('click', () => {
      X1SSettings.set(draft);
      showSavedMsg(t('cad_settings_saved'));
    });

    document.getElementById('setRestoreBtn').addEventListener('click', () => {
      const defaults = X1SSettings.restoreDefaults();
      Object.assign(draft, defaults);
      buildSliders();
      muteInput.checked = draft.muteAll;
      posSelect.value = draft.notificationPosition;
      showSavedMsg(t('cad_settings_restored'));
    });
  }

  let cadRosterTimer = null;

  function renderCadRoster(content) {
    content.innerHTML = `
      <div class="cad-detail-col" style="width:100%;">
        <div class="profile-header">
          <div>
            <div class="name-huge">${esc(t('cad_roster_title'))}</div>
            <div class="char-meta" id="rosterCount"></div>
          </div>
          <button class="btn btn-sm" id="rosterRefreshBtn">${esc(t('cad_refresh'))}</button>
        </div>
        <div id="rosterList" class="cad-results-list" style="padding:0;"></div>
      </div>
    `;
    document.getElementById('rosterRefreshBtn').addEventListener('click', () => post('cadRequestRoster', {}));
    renderRosterList(cad.roster);
    post('cadRequestRoster', {});

    clearInterval(cadRosterTimer);
    cadRosterTimer = setInterval(() => {
      if (cad.nav !== 'roster') { clearInterval(cadRosterTimer); return; }
      post('cadRequestRoster', {});
    }, 12000);
  }

  function renderRosterList(list) {
    cad.roster = list || [];
    const wrap = document.getElementById('rosterList');
    const count = document.getElementById('rosterCount');
    if (!wrap) return;
    if (count) count.textContent = t('cad_roster_count', cad.roster.length);
    if (cad.roster.length === 0) { wrap.innerHTML = `<div class="list-empty">${esc(t('cad_roster_empty'))}</div>`; return; }
    wrap.innerHTML = '';
    cad.roster.forEach((o) => {
      const statusMeta = cadStatusMeta(o.status || 'active');
      const row = el(`
        <div class="list-row" style="cursor:default;">
          <div style="display:flex; align-items:center; gap:10px;">
            ${o.logo ? `<img class="roster-dept-logo" src="${esc(o.logo)}" alt="">` : ''}
            <div>
              <div style="font-weight:700;">${esc(o.name)} <span class="char-meta">[${esc(o.callsign)}]</span></div>
              <div class="char-meta">${esc(o.rank)}</div>
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:8px;">
            <span class="cad-status" data-status="${esc(statusMeta.key)}" style="cursor:default;">
              <span class="cad-status-dot" style="background:var(--${esc(statusMeta.color || 'gray')});"></span>
              <span>${esc(statusMeta.label)}</span>
            </span>
            <span class="pill pill-red">${esc(o.departmentLabel)}</span>
          </div>
        </div>
      `);
      wrap.appendChild(row);
    });
  }

  function renderCadCitizens(content) {
    content.innerHTML = `
      <div class="cad-results-col">
        <div class="cad-search-bar">
          <div class="field-row">
            <div class="field"><input id="qFirst" placeholder="${esc(t('char_first_name'))}"></div>
            <div class="field"><input id="qLast" placeholder="${esc(t('char_last_name'))}"></div>
          </div>
          <div class="field-row">
            <div class="field"><input id="qDob" type="date"></div>
            <div class="field"><input id="qState" placeholder="${esc(t('char_id_label'))}"></div>
          </div>
          <button class="btn btn-primary btn-sm" id="citizenSearchBtn">${esc(t('search_officers'))}</button>
        </div>
        <div class="cad-results-list" id="cadResultsList"><div class="list-empty">${esc(t('cad_start_search'))}</div></div>
      </div>
      <div class="cad-detail-col" id="cadDetailCol"><div class="cad-detail-empty">${esc(t('cad_select_result'))}</div></div>
    `;
    document.getElementById('citizenSearchBtn').addEventListener('click', () => {
      post('cadSearchCitizens', {
        firstName: document.getElementById('qFirst').value,
        lastName: document.getElementById('qLast').value,
        dob: document.getElementById('qDob').value,
        stateId: document.getElementById('qState').value
      });
    });
  }

  function renderCitizenResults(results) {
    const list = document.getElementById('cadResultsList');
    if (!list) return;
    list.innerHTML = '';
    if (results.length === 0) { list.appendChild(el(`<div class="list-empty">${esc(t('cad_no_results'))}</div>`)); return; }
    results.forEach((r) => {
      const flags = flagPills(r.isArmed, r.isViolent, r.isMentallyIll);
      const row = el(`
        <div class="list-row">
          <div>
            <div style="font-weight:700;">${esc(r.firstName)} ${esc(r.lastName)}</div>
            <div class="char-meta">${esc(r.stateId)} • ${fmtDate(r.dob)}</div>
            ${flags ? `<div style="margin-top:4px;">${flags}</div>` : ''}
          </div>
        </div>
      `);
      row.addEventListener('click', () => post('cadGetCitizenProfile', { characterId: r.id }));
      list.appendChild(row);
    });
  }

  function renderCitizenProfile(p) {
    cad.profile = p;
    const detail = document.getElementById('cadDetailCol');
    if (!detail) return;
    if (!p) { detail.innerHTML = `<div class="cad-detail-empty">${esc(t('char_not_found'))}</div>`; return; }

    const licenses = p.licenseDefs.map((def) => {
      const status = p.licenses[def.key] || 'none';
      return `
        <div class="license-row">
          <span>${esc(def.label)}</span>
          <select data-license="${esc(def.key)}">
            ${['none', 'pending', 'valid', 'suspended', 'revoked'].map((s) => `<option value="${s}" ${s === status ? 'selected' : ''}>${s}</option>`).join('')}
          </select>
        </div>
      `;
    }).join('');

    const flagDefs = [
      { key: 'armed', prop: 'isArmed', label: t('cad_flag_armed'), color: 'red' },
      { key: 'violent', prop: 'isViolent', label: t('cad_flag_violent'), color: 'amber' },
      { key: 'mentallyIll', prop: 'isMentallyIll', label: t('cad_flag_mentally_ill'), color: 'blue' }
    ];
    const flagToggles = flagDefs.map((f) => `
      <button type="button" class="chip-btn chip-${f.color} ${p[f.prop] ? 'active' : ''}" data-flag="${esc(f.key)}" data-active="${p[f.prop] ? '1' : '0'}">${esc(f.label)}</button>
    `).join('');

    detail.innerHTML = `
      <div class="profile-header">
        <div>
          <div class="name-huge">${esc(p.firstName)} ${esc(p.lastName)} ${flagPills(p.isArmed, p.isViolent, p.isMentallyIll)}</div>
          <div class="char-meta">${esc(p.stateId)} • ${esc(t('cad_internal_id'))} ${p.id}</div>
        </div>
        <div style="display:flex; gap:8px;">
          <button class="btn btn-sm" id="btnCitation">${esc(t('cad_file_citation'))}</button>
          <button class="btn btn-sm" id="btnArrest">${esc(t('cad_file_arrest'))}</button>
          <button class="btn btn-sm" id="btnWarrant">${esc(t('cad_new_warrant'))}</button>
        </div>
      </div>
      <div class="profile-meta-grid">
        <div class="meta-cell"><label>${esc(t('char_dob'))}</label>${fmtDate(p.dob)}</div>
        <div class="meta-cell"><label>${esc(t('char_gender_label'))}</label>${esc(p.gender)}</div>
        <div class="meta-cell"><label>${esc(t('char_height'))}</label>${p.height} cm</div>
        <div class="meta-cell"><label>${esc(t('cad_open_warrants'))}</label>${p.warrants.filter(w => w.status === 'active').length}</div>
      </div>

      <div class="profile-section">
        <div class="profile-section-head"><h3>${esc(t('cad_flags'))}</h3></div>
        <div class="chip-row" id="citizenFlagChips">${flagToggles}</div>
      </div>

      <div class="profile-section">
        <div class="profile-section-head"><h3>${esc(t('cad_licenses'))}</h3></div>
        <div class="license-grid">${licenses}</div>
      </div>

      <div class="profile-section">
        <div class="profile-section-head"><h3>${esc(t('cad_notes'))}</h3></div>
        <textarea id="citizenNotes" rows="3">${esc(p.notes || '')}</textarea>
        <button class="btn btn-sm" id="saveNotesBtn" style="margin-top:8px;">${esc(t('confirm'))}</button>
      </div>

      <div class="profile-section">
        <div class="profile-section-head">
          <h3>${esc(t('cad_vehicles'))}</h3>
          <button class="btn btn-sm" id="btnViewVehicles">${esc(t('cad_view_vehicles'))} (${p.vehicles.length})</button>
        </div>
        ${p.vehicles.length === 0 ? `<div class="hint">${esc(t('cad_vehicle_gallery_none'))}</div>` : ''}
      </div>
      ${renderRecordSection(t('cad_warrants'), p.warrants, (w) => `
        ${esc(w.reason)} <span class="pill ${w.status === 'active' ? 'pill-red' : 'pill-green'}">${esc(w.status)}</span>
        ${(w.charges || []).length ? `<div class="char-meta" style="margin-top:4px;">${w.charges.map(c => esc(c.label)).join(', ')}</div>` : ''}
        ${w.signature ? `<div class="char-meta" style="margin-top:4px;">${esc(t('cad_officer_signature'))}: <em>${esc(w.signature)}</em></div>` : ''}
      `, 'warrant')}
      ${renderRecordSection(t('cad_arrests'), p.arrests, (a) => `
        ${(a.charges || []).map(c => `${esc(c.label)} ($${c.fine} / ${c.jailMinutes}m)`).join(', ')} — ${esc(t('cad_arrest_total_fine'))} $${a.fine_total} · ${esc(t('cad_arrest_total_jail'))} ${a.jail_minutes}m
        ${a.signature ? `<div class="char-meta" style="margin-top:4px;">${esc(t('cad_officer_signature'))}: <em>${esc(a.signature)}</em></div>` : ''}
      `, 'arrest')}
      ${renderRecordSection(t('cad_citations'), p.citations, (c) => `
        ${(c.violations && c.violations.length) ? c.violations.map(v => `${esc(v.label)} ($${v.fine})`).join(', ') + ` — ${esc(t('cad_arrest_total_fine'))} $${c.fine_total}` : `${esc(c.violation || '')} — $${c.fine || 0}`}
        ${c.signature ? `<div class="char-meta" style="margin-top:4px;">${esc(t('cad_officer_signature'))}: <em>${esc(c.signature)}</em></div>` : ''}
      `, 'citation')}
    `;

    detail.querySelectorAll('[data-license]').forEach((sel) => {
      sel.addEventListener('change', () => {
        post('cadUpdateCitizenLicense', { characterId: p.id, license: sel.dataset.license, status: sel.value });
      });
    });
    const citizenFlags = { armed: !!p.isArmed, violent: !!p.isViolent, mentallyIll: !!p.isMentallyIll };
    let citizenFlagSaveTimer = null;
    detail.querySelectorAll('#citizenFlagChips [data-flag]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const nextActive = btn.dataset.active !== '1';
        btn.dataset.active = nextActive ? '1' : '0';
        btn.classList.toggle('active', nextActive);
        citizenFlags[btn.dataset.flag] = nextActive;
        clearTimeout(citizenFlagSaveTimer);
        citizenFlagSaveTimer = setTimeout(() => {
          post('cadUpdateCitizenFlags', {
            characterId: p.id,
            flags: { isArmed: citizenFlags.armed, isViolent: citizenFlags.violent, isMentallyIll: citizenFlags.mentallyIll }
          });
        }, 400);
      });
    });
    document.getElementById('saveNotesBtn').addEventListener('click', () => {
      post('cadUpdateCitizenNotes', { characterId: p.id, notes: document.getElementById('citizenNotes').value });
    });
    document.getElementById('btnCitation').addEventListener('click', () => openCitationModal(p));
    document.getElementById('btnArrest').addEventListener('click', () => openArrestModal(p));
    document.getElementById('btnWarrant').addEventListener('click', () => openWarrantModal(p));
    document.getElementById('btnViewVehicles').addEventListener('click', () => openVehicleGalleryModal(p.vehicles));

    detail.querySelectorAll('[data-admin-delete]').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        openConfirmModal(t('cad_admin_delete_record_confirm'), () => {
          post('cadAdminDeleteRecord', {
            type: btn.dataset.adminDelete,
            id: Number(btn.dataset.adminDeleteId),
            characterId: p.id
          });
        });
      });
    });
  }

  function flagPills(armed, violent, mentallyIll) {
    const out = [];
    if (armed) out.push(`<span class="pill pill-red">${esc(t('cad_flag_armed'))}</span>`);
    if (violent) out.push(`<span class="pill pill-amber">${esc(t('cad_flag_violent'))}</span>`);
    if (mentallyIll) out.push(`<span class="pill pill-blue">${esc(t('cad_flag_mentally_ill'))}</span>`);
    return out.join(' ');
  }

  function regPill(status) {
    const cls = status === 'valid' ? 'pill-green' : status === 'expired' ? 'pill-amber' : 'pill-red';
    return `<span class="pill ${cls}">${esc(status || 'unregistered')}</span>`;
  }

  function renderRecordSection(title, rows, lineFn, recordType) {
    const canDelete = recordType && cad.context && cad.context.isAdmin;
    return `
      <div class="profile-section">
        <div class="profile-section-head"><h3>${esc(title)}</h3></div>
        ${(!rows || rows.length === 0) ? `<div class="hint">${esc(t('cad_none_on_file'))}</div>` :
          rows.map((r) => `
            <div class="record-row">
              <div class="record-top">
                <span>${esc(r.department || '')}</span>
                <span style="display:flex; align-items:center; gap:8px;">
                  ${esc((r.created_at || '').split('.')[0])}
                  ${canDelete ? `<button type="button" class="btn btn-danger btn-sm" data-admin-delete="${esc(recordType)}" data-admin-delete-id="${r.id}">${esc(t('cad_remove'))}</button>` : ''}
                </span>
              </div>
              <div>${lineFn(r)}</div>
            </div>
          `).join('')}
      </div>
    `;
  }

  function openModal(html, extraClass) {
    const cls = extraClass ? `panel modal-panel ${extraClass}` : 'panel modal-panel';
    const backdrop = el(`<div class="modal-backdrop"><div class="${cls}">${html}</div></div>`);
    const host = document.querySelector('.cad-tablet-screen') || document.body;
    host.appendChild(backdrop);
    backdrop.addEventListener('click', (e) => { if (e.target === backdrop) backdrop.remove(); });
    return backdrop;
  }

  function openConfirmModal(message, onConfirm) {
    const modal = openModal(`
      <p>${esc(message)}</p>
      <div class="creator-actions">
        <button class="btn btn-ghost" id="modConfirmCancel">${esc(t('cancel'))}</button>
        <button class="btn btn-danger" id="modConfirmOk">${esc(t('confirm'))}</button>
      </div>
    `);
    modal.querySelector('#modConfirmCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modConfirmOk').addEventListener('click', () => {
      modal.remove();
      onConfirm();
    });
    return modal;
  }

  function openCitationModal(citizen) {
    const charges = (cad.context.charges || []).filter((c) => c.citable);
    const lineMaxFine = cad.context.citationLineMaxFine ?? 10000;
    let uidCounter = 0;
    const selected = [];

    const modal = openModal(`
      <h2>${esc(t('cad_file_citation'))}</h2>
      <div class="arrest-menu-grid">
        <div class="arrest-menu-col">
          <div class="field"><input id="chargeSearch" placeholder="${esc(t('cad_charge_search'))}"></div>
          <div class="charge-picker" id="chargePicker">
            ${charges.map((c) => `
              <div class="charge-option charge-option-add" data-code="${esc(c.code)}" data-search="${esc((c.code + ' ' + c.label).toLowerCase())}">
                <span class="charge-label">${esc(c.label)} <span class="charge-code">${esc(c.code)}</span></span>
                <span class="charge-fine">$${c.fine}</span>
                <span class="charge-add-btn">+</span>
              </div>
            `).join('')}
          </div>
          <div class="field-row">
            <div class="field"><label>${esc(t('cad_custom_violation'))}</label><input id="customViolation" maxlength="128" placeholder="${esc(t('cad_custom_violation_placeholder'))}"></div>
            <div class="field" style="max-width:110px;"><label>${esc(t('cad_fine'))}</label><input id="customFine" type="number" min="0" max="${lineMaxFine}" value="250"></div>
          </div>
          <button class="btn btn-sm" id="addCustomViolation">${esc(t('cad_add'))}</button>
        </div>
        <div class="arrest-menu-col">
          <div class="profile-section-head"><h3>${esc(t('cad_selected_violations'))}</h3></div>
          <div class="selected-charges" id="selectedCharges">
            <div class="hint" id="selectedChargesEmpty">${esc(t('cad_no_violations_selected'))}</div>
          </div>
          <div class="arrest-totals" id="citationTotals"></div>
        </div>
      </div>
      <div class="field-row creator-signature-row">
        <div class="field"><label>${esc(t('cad_officer_signature'))}</label><input id="modSignature" maxlength="64" placeholder="${esc(t('cad_signature_placeholder'))}"></div>
      </div>
      <div class="field"><label>${esc(t('cad_notes'))}</label><textarea id="modNotes" rows="2"></textarea></div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit" disabled>${esc(t('confirm'))}</button></div>
    `, 'modal-panel-wide');

    const selectedList = modal.querySelector('#selectedCharges');
    const selectedEmpty = modal.querySelector('#selectedChargesEmpty');
    const totalsEl = modal.querySelector('#citationTotals');
    const submitBtn = modal.querySelector('#modSubmit');
    const signatureInput = modal.querySelector('#modSignature');

    function clamp(n, max) { return Math.max(0, Math.min(max, isFinite(n) ? n : 0)); }

    function refresh() {
      selectedEmpty.style.display = selected.length ? 'none' : '';
      selectedList.querySelectorAll('.selected-charge-row').forEach((r) => r.remove());
      selected.forEach((line) => {
        const row = el(`
          <div class="selected-charge-row" data-uid="${line.uid}">
            <div class="selected-charge-head">
              <span class="charge-label">${esc(line.label)}${line.code ? ` <span class="charge-code">${esc(line.code)}</span>` : ''}</span>
              <span class="selected-charge-remove" title="${esc(t('cad_remove'))}">&times;</span>
            </div>
            <div class="selected-charge-inputs">
              <label>${esc(t('cad_fine'))}<input type="number" min="0" max="${lineMaxFine}" step="1" class="scFine" value="${line.fine}"></label>
            </div>
          </div>
        `);
        row.querySelector('.selected-charge-remove').addEventListener('click', () => {
          const i = selected.findIndex((s) => s.uid === line.uid);
          if (i !== -1) selected.splice(i, 1);
          refresh();
        });
        row.querySelector('.scFine').addEventListener('input', (e) => {
          line.fine = clamp(parseInt(e.target.value, 10), lineMaxFine);
          updateTotals();
        });
        selectedList.appendChild(row);
      });
      updateTotals();
      submitBtn.disabled = selected.length === 0 || !signatureInput.value.trim();
    }

    function updateTotals() {
      const fineTotal = selected.reduce((sum, s) => sum + (s.fine || 0), 0);
      totalsEl.innerHTML = `<span>${esc(t('cad_arrest_total_fine'))} <strong>$${fineTotal}</strong></span>`;
      submitBtn.disabled = selected.length === 0 || !signatureInput.value.trim();
    }

    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#chargeSearch').addEventListener('input', (e) => {
      const f = e.target.value.toLowerCase();
      modal.querySelectorAll('#chargePicker .charge-option').forEach((opt) => {
        opt.style.display = (!f || opt.dataset.search.includes(f)) ? '' : 'none';
      });
    });
    modal.querySelectorAll('#chargePicker .charge-option-add').forEach((opt) => {
      opt.addEventListener('click', () => {
        const def = charges.find((c) => c.code === opt.dataset.code);
        if (!def) return;
        uidCounter += 1;
        selected.push({ uid: uidCounter, code: def.code, label: def.label, fine: def.fine });
        refresh();
      });
    });
    modal.querySelector('#addCustomViolation').addEventListener('click', () => {
      const labelInput = modal.querySelector('#customViolation');
      const fineInput = modal.querySelector('#customFine');
      const label = labelInput.value.trim();
      if (!label) return;
      uidCounter += 1;
      selected.push({ uid: uidCounter, code: null, label, fine: clamp(parseInt(fineInput.value, 10), lineMaxFine) });
      labelInput.value = '';
      fineInput.value = 250;
      refresh();
    });
    signatureInput.addEventListener('input', () => {
      submitBtn.disabled = selected.length === 0 || !signatureInput.value.trim();
    });
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      if (selected.length === 0 || !signatureInput.value.trim()) return;
      post('cadCreateCitation', {
        characterId: citizen.id,
        violations: selected.map((s) => ({ code: s.code, label: s.label, fine: s.fine })),
        notes: modal.querySelector('#modNotes').value,
        signature: signatureInput.value
      });
      modal.remove();
    });

    refresh();
  }

  function openArrestModal(citizen) {
    const charges = cad.context.charges || [];
    const maxFine = cad.context.arrestChargeMaxFine ?? 100000;
    const maxJail = cad.context.arrestChargeMaxJailMinutes ?? 1440;
    let uidCounter = 0;
    const selected = [];

    const modal = openModal(`
      <h2>${esc(t('cad_file_arrest'))}</h2>
      <div class="arrest-menu-grid">
        <div class="arrest-menu-col">
          <div class="field"><input id="chargeSearch" placeholder="${esc(t('cad_charge_search'))}"></div>
          <div class="charge-picker" id="chargePicker">
            ${charges.map((c) => `
              <div class="charge-option charge-option-add" data-code="${esc(c.code)}" data-search="${esc((c.code + ' ' + c.label).toLowerCase())}">
                <span class="charge-label">${esc(c.label)} <span class="charge-code">${esc(c.code)}</span></span>
                <span class="charge-fine">$${c.fine} / ${c.jailMinutes}m</span>
                <span class="charge-add-btn">+</span>
              </div>
            `).join('')}
          </div>
        </div>
        <div class="arrest-menu-col">
          <div class="profile-section-head"><h3>${esc(t('cad_selected_charges'))}</h3></div>
          <div class="selected-charges" id="selectedCharges">
            <div class="hint" id="selectedChargesEmpty">${esc(t('cad_no_charges_selected'))}</div>
          </div>
          <div class="arrest-totals" id="arrestTotals"></div>
        </div>
      </div>
      <div class="field-row creator-signature-row">
        <div class="field"><label>${esc(t('cad_officer_signature'))}</label><input id="modSignature" maxlength="64" placeholder="${esc(t('cad_signature_placeholder'))}"></div>
      </div>
      <div class="field"><label>${esc(t('cad_notes'))}</label><textarea id="modNotes" rows="2"></textarea></div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit" disabled>${esc(t('confirm'))}</button></div>
    `, 'modal-panel-wide');

    const selectedList = modal.querySelector('#selectedCharges');
    const selectedEmpty = modal.querySelector('#selectedChargesEmpty');
    const totalsEl = modal.querySelector('#arrestTotals');
    const submitBtn = modal.querySelector('#modSubmit');
    const signatureInput = modal.querySelector('#modSignature');

    function clamp(n, max) { return Math.max(0, Math.min(max, isFinite(n) ? n : 0)); }

    function refresh() {
      selectedEmpty.style.display = selected.length ? 'none' : '';
      selectedList.querySelectorAll('.selected-charge-row').forEach((r) => r.remove());
      selected.forEach((line) => {
        const row = el(`
          <div class="selected-charge-row" data-uid="${line.uid}">
            <div class="selected-charge-head">
              <span class="charge-label">${esc(line.label)} <span class="charge-code">${esc(line.code)}</span></span>
              <span class="selected-charge-remove" title="${esc(t('cad_remove'))}">&times;</span>
            </div>
            <div class="selected-charge-inputs">
              <label>${esc(t('cad_fine'))}<input type="number" min="0" max="${maxFine}" step="1" class="scFine" value="${line.fine}"></label>
              <label>${esc(t('cad_jail_time'))}<input type="number" min="0" max="${maxJail}" step="1" class="scJail" value="${line.jailMinutes}"></label>
            </div>
          </div>
        `);
        row.querySelector('.selected-charge-remove').addEventListener('click', () => {
          const i = selected.findIndex((s) => s.uid === line.uid);
          if (i !== -1) selected.splice(i, 1);
          refresh();
        });
        row.querySelector('.scFine').addEventListener('input', (e) => {
          line.fine = clamp(parseInt(e.target.value, 10), maxFine);
          updateTotals();
        });
        row.querySelector('.scJail').addEventListener('input', (e) => {
          line.jailMinutes = clamp(parseInt(e.target.value, 10), maxJail);
          updateTotals();
        });
        selectedList.appendChild(row);
      });
      updateTotals();
      submitBtn.disabled = selected.length === 0 || !signatureInput.value.trim();
    }

    function updateTotals() {
      const fineTotal = selected.reduce((sum, s) => sum + (s.fine || 0), 0);
      const jailTotal = selected.reduce((sum, s) => sum + (s.jailMinutes || 0), 0);
      totalsEl.innerHTML = `<span>${esc(t('cad_arrest_total_fine'))} <strong>$${fineTotal}</strong></span><span>${esc(t('cad_arrest_total_jail'))} <strong>${jailTotal}m</strong></span>`;
      submitBtn.disabled = selected.length === 0 || !signatureInput.value.trim();
    }

    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#chargeSearch').addEventListener('input', (e) => {
      const f = e.target.value.toLowerCase();
      modal.querySelectorAll('#chargePicker .charge-option').forEach((opt) => {
        opt.style.display = (!f || opt.dataset.search.includes(f)) ? '' : 'none';
      });
    });
    modal.querySelectorAll('#chargePicker .charge-option-add').forEach((opt) => {
      opt.addEventListener('click', () => {
        const def = charges.find((c) => c.code === opt.dataset.code);
        if (!def) return;
        uidCounter += 1;
        selected.push({ uid: uidCounter, code: def.code, label: def.label, fine: def.fine, jailMinutes: def.jailMinutes });
        refresh();
      });
    });
    signatureInput.addEventListener('input', () => {
      submitBtn.disabled = selected.length === 0 || !signatureInput.value.trim();
    });
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      if (selected.length === 0 || !signatureInput.value.trim()) return;
      post('cadCreateArrest', {
        characterId: citizen.id,
        charges: selected.map((s) => ({ code: s.code, fine: s.fine, jailMinutes: s.jailMinutes })),
        notes: modal.querySelector('#modNotes').value,
        signature: signatureInput.value
      });
      modal.remove();
    });

    refresh();
  }

  function flagChipsMarkup(containerId) {
    const defs = [
      { key: 'armed', label: t('cad_flag_armed'), color: 'red' },
      { key: 'violent', label: t('cad_flag_violent'), color: 'amber' },
      { key: 'mentallyIll', label: t('cad_flag_mentally_ill'), color: 'blue' }
    ];
    return `
      <div class="field">
        <label>${esc(t('cad_flags'))}</label>
        <div class="chip-row" id="${containerId}">
          ${defs.map((f) => `<button type="button" class="chip-btn chip-${f.color}" data-flag="${esc(f.key)}" data-active="0">${esc(f.label)}</button>`).join('')}
        </div>
      </div>
    `;
  }

  function wireFlagChips(modal, containerId) {
    const flags = { armed: false, violent: false, mentallyIll: false };
    modal.querySelectorAll(`#${containerId} [data-flag]`).forEach((btn) => {
      btn.addEventListener('click', () => {
        const next = btn.dataset.active !== '1';
        btn.dataset.active = next ? '1' : '0';
        btn.classList.toggle('active', next);
        flags[btn.dataset.flag] = next;
      });
    });
    return flags;
  }

  function openWarrantModal(citizen) {
    const charges = cad.context.charges || [];
    const presets = cad.context.warrantDurationPresets || [7, 14, 30, 60, 90];
    const defaultDays = presets.includes(30) ? 30 : presets[0] || 30;
    let uidCounter = 0;
    const selected = [];

    const modal = openModal(`
      <h2>${esc(t('cad_new_warrant'))}</h2>
      <div class="arrest-menu-grid">
        <div class="arrest-menu-col">
          <div class="field"><input id="chargeSearch" placeholder="${esc(t('cad_charge_search'))}"></div>
          <div class="charge-picker" id="chargePicker">
            ${charges.map((c) => `
              <div class="charge-option charge-option-add" data-code="${esc(c.code)}" data-search="${esc((c.code + ' ' + c.label).toLowerCase())}">
                <span class="charge-label">${esc(c.label)} <span class="charge-code">${esc(c.code)}</span></span>
                <span class="charge-add-btn">+</span>
              </div>
            `).join('')}
          </div>
        </div>
        <div class="arrest-menu-col">
          <div class="profile-section-head"><h3>${esc(t('cad_selected_grounds'))}</h3></div>
          <div class="selected-charges" id="selectedCharges">
            <div class="hint" id="selectedChargesEmpty">${esc(t('cad_no_grounds_selected'))}</div>
          </div>
          <div class="field"><label>${esc(t('cad_reason'))}</label><input id="modReason" maxlength="255"></div>
          <div class="field">
            <label>${esc(t('cad_duration_days'))}</label>
            <div class="chip-row" id="durationChips">
              ${presets.map((d) => `<button type="button" class="chip-btn" data-days="${d}">${d}d</button>`).join('')}
            </div>
            <input id="modDuration" type="number" min="1" value="${defaultDays}" style="margin-top:8px;">
          </div>
          ${flagChipsMarkup('warrantFlagChips')}
        </div>
      </div>
      <div class="field-row creator-signature-row">
        <div class="field"><label>${esc(t('cad_officer_signature'))}</label><input id="modSignature" maxlength="64" placeholder="${esc(t('cad_signature_placeholder'))}"></div>
      </div>
      <div class="field"><label>${esc(t('cad_notes'))}</label><textarea id="modNotes" rows="2"></textarea></div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit" disabled>${esc(t('confirm'))}</button></div>
    `, 'modal-panel-wide');

    const selectedList = modal.querySelector('#selectedCharges');
    const selectedEmpty = modal.querySelector('#selectedChargesEmpty');
    const submitBtn = modal.querySelector('#modSubmit');
    const signatureInput = modal.querySelector('#modSignature');
    const reasonInput = modal.querySelector('#modReason');
    const durationInput = modal.querySelector('#modDuration');
    const warrantFlags = wireFlagChips(modal, 'warrantFlagChips');

    function refresh() {
      selectedEmpty.style.display = selected.length ? 'none' : '';
      selectedList.querySelectorAll('.selected-charge-row').forEach((r) => r.remove());
      selected.forEach((line) => {
        const row = el(`
          <div class="selected-charge-row" data-uid="${line.uid}">
            <div class="selected-charge-head">
              <span class="charge-label">${esc(line.label)} <span class="charge-code">${esc(line.code)}</span></span>
              <span class="selected-charge-remove" title="${esc(t('cad_remove'))}">&times;</span>
            </div>
          </div>
        `);
        row.querySelector('.selected-charge-remove').addEventListener('click', () => {
          const i = selected.findIndex((s) => s.uid === line.uid);
          if (i !== -1) selected.splice(i, 1);
          refresh();
        });
        selectedList.appendChild(row);
      });
      checkValid();
    }

    function checkValid() {
      submitBtn.disabled = !reasonInput.value.trim() || !signatureInput.value.trim();
    }

    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#chargeSearch').addEventListener('input', (e) => {
      const f = e.target.value.toLowerCase();
      modal.querySelectorAll('#chargePicker .charge-option').forEach((opt) => {
        opt.style.display = (!f || opt.dataset.search.includes(f)) ? '' : 'none';
      });
    });
    modal.querySelectorAll('#chargePicker .charge-option-add').forEach((opt) => {
      opt.addEventListener('click', () => {
        const def = charges.find((c) => c.code === opt.dataset.code);
        if (!def) return;
        uidCounter += 1;
        selected.push({ uid: uidCounter, code: def.code, label: def.label });
        refresh();
      });
    });
    modal.querySelectorAll('#durationChips .chip-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        durationInput.value = btn.dataset.days;
        modal.querySelectorAll('#durationChips .chip-btn').forEach((b) => b.classList.toggle('active', b === btn));
      });
    });
    reasonInput.addEventListener('input', checkValid);
    signatureInput.addEventListener('input', checkValid);
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      if (!reasonInput.value.trim() || !signatureInput.value.trim()) return;
      post('cadCreateWarrant', {
        characterId: citizen.id,
        reason: reasonInput.value,
        charges: selected.map((s) => ({ code: s.code })),
        notes: modal.querySelector('#modNotes').value,
        durationDays: parseInt(durationInput.value, 10) || defaultDays,
        signature: signatureInput.value,
        isArmed: warrantFlags.armed,
        isViolent: warrantFlags.violent,
        isMentallyIll: warrantFlags.mentallyIll
      });
      modal.remove();
    });

    refresh();
  }

  let vehicleHistoryModalState = null;

  const VEHICLE_HISTORY_EVENT_LABELS = {
    registered: 'cad_history_event_registered',
    renewed: 'cad_history_event_renewed',
    transferred: 'cad_history_event_transferred',
    retired: 'cad_history_event_retired',
    reinstated: 'cad_history_event_reinstated'
  };

  function renderCadVehicles(content) {
    content.innerHTML = `
      <div class="cad-results-col">
        <div class="cad-search-bar">
          <div class="field"><input id="qPlate" placeholder="${esc(t('cad_plate'))}"></div>
          <div style="display:flex; gap:8px;">
            <button class="btn btn-primary btn-sm" id="vehicleSearchBtn">${esc(t('search_officers'))}</button>
            <button class="btn btn-sm" id="vehicleNewBtn">${esc(t('cad_register_vehicle'))}</button>
          </div>
        </div>
        <div class="cad-results-list" id="cadResultsList"><div class="list-empty">${esc(t('cad_start_search'))}</div></div>
      </div>
      <div class="cad-detail-col" id="cadDetailCol"><div class="cad-detail-empty">${esc(t('cad_select_result'))}</div></div>
    `;
    document.getElementById('vehicleSearchBtn').addEventListener('click', () => {
      post('cadSearchVehicles', { plate: document.getElementById('qPlate').value });
    });
    document.getElementById('vehicleNewBtn').addEventListener('click', openVehicleModal);
  }

  function vehicleFormFieldsHtml(v) {
    v = v || {};
    return `
      <div class="field"><label>${esc(t('cad_plate'))}</label><input id="modPlate" maxlength="16" value="${esc(v.plate || '')}"></div>
      <div class="field"><label>${esc(t('cad_plate_state'))}</label><input id="modPlateState" maxlength="8" value="${esc(v.plate_state || '')}"></div>
      <div class="field"><label>${esc(t('cad_brand'))}</label><input id="modBrand" maxlength="32" value="${esc(v.brand || '')}"></div>
      <div class="field"><label>${esc(t('cad_model'))}</label><input id="modModel" maxlength="64" value="${esc(v.model || '')}"></div>
      <div class="field"><label>${esc(t('cad_type'))}</label><input id="modType" maxlength="64" value="${esc(v.vehicle_type || '')}"></div>
      <div class="field"><label>${esc(t('cad_vehicle_year'))}</label><input id="modYear" type="number" min="1900" max="2100" value="${v.vehicle_year != null ? v.vehicle_year : ''}"></div>
      <div class="field"><label>${esc(t('cad_color'))}</label><input id="modColor" maxlength="32" value="${esc(v.color || '')}"></div>
      <div class="field"><label>${esc(t('cad_owner_id'))}</label><input id="modOwner" type="number" value="${v.owner_id != null ? v.owner_id : ''}" placeholder="${esc(t('cad_internal_id'))}"></div>
      <div class="field"><label>${esc(t('cad_registration_date'))}</label><input id="modRegDate" type="date" value="${esc(v.registration_date || '')}"></div>
      <div class="field"><label>${esc(t('cad_expiration_date'))}</label><input id="modExpDate" type="date" value="${esc(v.expiration_date || '')}"></div>
    `;
  }

  function readVehicleFormFields(modal) {
    return {
      plate: modal.querySelector('#modPlate').value,
      plateState: modal.querySelector('#modPlateState').value,
      brand: modal.querySelector('#modBrand').value,
      model: modal.querySelector('#modModel').value,
      type: modal.querySelector('#modType').value,
      year: modal.querySelector('#modYear').value || null,
      color: modal.querySelector('#modColor').value,
      ownerId: modal.querySelector('#modOwner').value || null,
      registrationDate: modal.querySelector('#modRegDate').value || null,
      expirationDate: modal.querySelector('#modExpDate').value || null
    };
  }

  function openVehicleModal() {
    const modal = openModal(`
      <h2>${esc(t('cad_register_vehicle'))}</h2>
      ${vehicleFormFieldsHtml(null)}
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      post('cadCreateVehicle', readVehicleFormFields(modal));
      modal.remove();
    });
  }

  function vehicleBadges(v) {
    let badges = '';
    if (v.stolen) badges += ' <span class="pill pill-red">STOLEN</span>';
    if (v.retired_at) badges += ` <span class="pill pill-gray">${esc(t('cad_retired'))}</span>`;
    return badges;
  }

  function renderVehicleResults(results) {
    const list = document.getElementById('cadResultsList');
    if (!list) return;
    list.innerHTML = '';
    if (results.length === 0) { list.appendChild(el(`<div class="list-empty">${esc(t('cad_no_results'))}</div>`)); return; }
    results.forEach((v) => {
      const row = el(`
        <div class="list-row">
          <div>
            <div style="font-weight:700;">${esc(v.plate)}${vehicleBadges(v)}</div>
            <div class="char-meta">${esc([v.brand, v.model].filter(Boolean).join(' '))}${v.vehicle_type ? ' • ' + esc(v.vehicle_type) : ''}</div>
          </div>
        </div>
      `);
      row.addEventListener('click', () => renderVehicleDetail(v));
      list.appendChild(row);
    });
  }

  function vehicleDetailInnerHtml(v) {
    return `
      <div class="profile-header">
        <div>
          <div class="name-huge">${esc(v.plate)}${vehicleBadges(v)}</div>
          <div class="char-meta">${esc([v.vehicle_year, v.brand, v.model].filter(Boolean).join(' '))} • ${esc(v.color || '')}</div>
        </div>
        <div style="display:flex; gap:8px;">
          <button class="btn btn-sm" data-veh-action="edit">${esc(t('cad_edit_vehicle'))}</button>
          <button class="btn btn-sm ${v.stolen ? 'btn-danger' : ''}" data-veh-action="stolen">${v.stolen ? esc(t('cad_clear_stolen')) : esc(t('cad_mark_stolen'))}</button>
        </div>
      </div>
      <div class="profile-meta-grid">
        <div class="meta-cell"><label>${esc(t('cad_owner'))}</label>${v.first_name ? esc(v.first_name + ' ' + v.last_name) : esc(t('cad_unowned'))}</div>
        <div class="meta-cell"><label>${esc(t('cad_type'))}</label>${esc(v.vehicle_type || '—')}</div>
        <div class="meta-cell"><label>${esc(t('cad_vehicle_year'))}</label>${v.vehicle_year != null ? v.vehicle_year : '—'}</div>
        <div class="meta-cell"><label>${esc(t('cad_registration'))}</label>${regPill(v.registration)}</div>
        <div class="meta-cell"><label>${esc(t('cad_insured'))}</label>${v.insured ? 'Yes' : 'No'}</div>
        <div class="meta-cell"><label>${esc(t('cad_plate_state'))}</label>${esc(v.plate_state || '—')}</div>
        <div class="meta-cell"><label>${esc(t('cad_registration_date'))}</label>${v.registration_date ? fmtDate(v.registration_date) : '—'}</div>
        <div class="meta-cell"><label>${esc(t('cad_expiration_date'))}</label>${v.expiration_date ? fmtDate(v.expiration_date) : '—'}</div>
        <div class="meta-cell"><label>${esc(t('cad_owner_state_id'))}</label>${esc(v.owner_state_id || '—')}</div>
      </div>
      <div class="profile-section">
        <div class="profile-section-head"><h3>${esc(t('cad_registration_history'))}</h3></div>
        <div class="chip-row">
          <button class="btn btn-sm" data-veh-action="renew">${esc(t('cad_renew_registration'))}</button>
          <button class="btn btn-sm" data-veh-action="transfer">${esc(t('cad_transfer_ownership'))}</button>
          <button class="btn btn-sm" data-veh-action="retire">${v.retired_at ? esc(t('cad_reinstate_vehicle')) : esc(t('cad_retire_vehicle'))}</button>
          <button class="btn btn-sm" data-veh-action="history">${esc(t('cad_view_history'))}</button>
          ${cad.context && cad.context.isAdmin ? `<button class="btn btn-danger btn-sm" data-veh-action="delete">${esc(t('cad_delete_vehicle'))}</button>` : ''}
        </div>
      </div>
      <div class="profile-section">
        <div class="profile-section-head"><h3>${esc(t('cad_notes'))}</h3></div>
        <textarea data-veh-notes rows="3">${esc(v.notes || '')}</textarea>
        <button class="btn btn-sm" data-veh-action="save-notes" style="margin-top:8px;">${esc(t('confirm'))}</button>
      </div>
    `;
  }

  function wireVehicleDetailActions(container, v, onDeleted) {
    const btn = (action) => container.querySelector(`[data-veh-action="${action}"]`);
    btn('edit').addEventListener('click', () => openEditVehicleModal(v));
    btn('stolen').addEventListener('click', () => {
      post('cadSetVehicleStolen', { vehicleId: v.id, stolen: !v.stolen });
    });
    btn('renew').addEventListener('click', () => openRenewRegistrationModal(v));
    btn('transfer').addEventListener('click', () => openTransferOwnershipModal(v));
    btn('retire').addEventListener('click', () => {
      const confirmMsg = v.retired_at ? t('cad_reinstate_vehicle_confirm') : t('cad_retire_vehicle_confirm');
      openConfirmModal(confirmMsg, () => {
        post('cadSetVehicleRetired', { vehicleId: v.id, retired: !v.retired_at });
      });
    });
    btn('history').addEventListener('click', () => openVehicleHistoryModal(v));
    const notesArea = container.querySelector('[data-veh-notes]');
    btn('save-notes').addEventListener('click', () => {
      post('cadSetVehicleNotes', { vehicleId: v.id, notes: notesArea.value });
    });
    const deleteBtn = btn('delete');
    if (deleteBtn) deleteBtn.addEventListener('click', () => {
      openConfirmModal(t('cad_delete_vehicle_confirm'), () => {
        post('cadAdminDeleteRecord', { type: 'vehicle', id: v.id });
        if (onDeleted) onDeleted();
      });
    });
  }

  function renderVehicleDetail(v) {
    const detail = document.getElementById('cadDetailCol');
    if (!detail) return;
    detail.innerHTML = vehicleDetailInnerHtml(v);
    wireVehicleDetailActions(detail, v, () => {
      detail.innerHTML = `<div class="cad-detail-empty">${esc(t('cad_select_result'))}</div>`;
      cad.results = (cad.results || []).filter((r) => r.id !== v.id);
      renderVehicleResults(cad.results);
    });
  }

  function openEditVehicleModal(v) {
    const modal = openModal(`
      <h2>${esc(t('cad_edit_vehicle'))}</h2>
      ${vehicleFormFieldsHtml(v)}
      <div class="field">
        <label>${esc(t('cad_registration'))}</label>
        <select id="modRegistration">
          ${['valid', 'expired', 'unregistered'].map((s) => `<option value="${s}" ${s === v.registration ? 'selected' : ''}>${s}</option>`).join('')}
        </select>
      </div>
      <div class="field">
        <label>${esc(t('cad_insured'))}</label>
        <select id="modInsured">
          <option value="1" ${v.insured ? 'selected' : ''}>${esc(t('cad_insured'))}</option>
          <option value="0" ${!v.insured ? 'selected' : ''}>${esc(t('cad_not_insured'))}</option>
        </select>
      </div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      const fields = readVehicleFormFields(modal);
      fields.vehicleId = v.id;
      fields.registration = modal.querySelector('#modRegistration').value;
      fields.insured = modal.querySelector('#modInsured').value === '1';
      post('cadUpdateVehicle', fields);
      modal.remove();
    });
  }

  function openRenewRegistrationModal(v) {
    const presets = (cad.context && cad.context.vehicleRegistrationRenewalPresets) || [30, 90, 180, 365];
    const defaultDays = presets.includes(90) ? 90 : presets[0] || 90;
    const modal = openModal(`
      <h2>${esc(t('cad_renew_registration'))}</h2>
      <div class="char-meta">${esc(v.plate)} — ${esc([v.brand, v.model].filter(Boolean).join(' '))}</div>
      <div class="field">
        <label>${esc(t('cad_renewal_length'))}</label>
        <div class="chip-row" id="renewalChips">
          ${presets.map((d) => `<button type="button" class="chip-btn" data-days="${d}">${d}d</button>`).join('')}
        </div>
        <input id="modDays" type="number" min="1" max="3650" value="${defaultDays}" style="margin-top:8px;">
      </div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    const daysInput = modal.querySelector('#modDays');
    modal.querySelectorAll('#renewalChips .chip-btn').forEach((chip) => {
      chip.addEventListener('click', () => {
        daysInput.value = chip.dataset.days;
        modal.querySelectorAll('#renewalChips .chip-btn').forEach((b) => b.classList.toggle('active', b === chip));
      });
    });
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      post('cadRenewVehicleRegistration', { vehicleId: v.id, days: parseInt(daysInput.value, 10) || defaultDays });
      modal.remove();
    });
  }

  function openTransferOwnershipModal(v) {
    const modal = openModal(`
      <h2>${esc(t('cad_transfer_ownership'))}</h2>
      <div class="char-meta">${esc(v.plate)} — ${esc([v.brand, v.model].filter(Boolean).join(' '))}</div>
      <div class="char-meta">${esc(t('cad_owner'))}: ${v.first_name ? esc(v.first_name + ' ' + v.last_name) : esc(t('cad_unowned'))}</div>
      <div class="field">
        <label>${esc(t('cad_new_owner_id'))}</label>
        <input id="modNewOwner" type="number" placeholder="${esc(t('cad_internal_id'))}">
        <div class="hint">${esc(t('cad_transfer_ownership_help'))}</div>
      </div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      post('cadTransferVehicleOwnership', { vehicleId: v.id, newOwnerId: modal.querySelector('#modNewOwner').value || null });
      modal.remove();
    });
  }

  function renderVehicleHistoryList(modal, history) {
    const wrap = modal.querySelector('#vehHistoryList');
    if (!wrap) return;
    if (!history || history.length === 0) {
      wrap.innerHTML = `<div class="list-empty">${esc(t('cad_history_none'))}</div>`;
      return;
    }
    wrap.innerHTML = history.map((h) => `
      <div class="record-row">
        <div class="record-top">
          <span>${esc(t(VEHICLE_HISTORY_EVENT_LABELS[h.event_type] || h.event_type))}</span>
          <span>${esc((h.created_at || '').split('.')[0])}</span>
        </div>
        <div>${esc(h.details || '')}</div>
        ${h.performed_by ? `<div class="char-meta" style="margin-top:4px;">${esc(t('cad_officer_signature'))}: <em>${esc(h.performed_by)}</em></div>` : ''}
      </div>
    `).join('');
  }

  function openVehicleHistoryModal(v) {
    const modal = openModal(`
      <h2>${esc(t('cad_registration_history'))}</h2>
      <div class="char-meta">${esc(v.plate)}</div>
      <div id="vehHistoryList" class="scroll-y" style="max-height:400px;"><div class="list-empty">${esc(t('cad_loading'))}</div></div>
      <div class="creator-actions" style="justify-content:flex-end;"><button class="btn btn-ghost" id="modClose">${esc(t('close'))}</button></div>
    `);
    modal.querySelector('#modClose').addEventListener('click', () => {
      if (vehicleHistoryModalState && vehicleHistoryModalState.modal === modal) vehicleHistoryModalState = null;
      modal.remove();
    });
    vehicleHistoryModalState = { vehicleId: v.id, modal };
    post('cadGetVehicleHistory', { vehicleId: v.id });
  }

  function vehicleGalleryCardHtml(v) {
    return `
      <div class="vehicle-card">
        <div class="vehicle-card-top">
          <div class="vehicle-card-plate">${esc(v.plate)}${v.plate_state ? ` <span class="char-meta">(${esc(v.plate_state)})</span>` : ''}</div>
          <div>${vehicleBadges(v)}</div>
        </div>
        <div class="char-meta">${esc([v.vehicle_year, v.brand, v.model].filter(Boolean).join(' '))}${v.vehicle_type ? ' • ' + esc(v.vehicle_type) : ''}</div>
        <div class="char-meta">${esc(v.color || '—')}</div>
        <div class="vehicle-card-row">${regPill(v.registration)}${v.expiration_date ? `<span class="char-meta">${esc(t('cad_expiration_date'))}: ${fmtDate(v.expiration_date)}</span>` : ''}</div>
        <div class="char-meta">${v.insured ? esc(t('cad_insured')) : esc(t('cad_not_insured'))}</div>
        <button class="btn btn-sm btn-block" data-veh-manage="${v.id}" style="margin-top:10px;">${esc(t('cad_edit_vehicle'))}</button>
      </div>
    `;
  }

  function openVehicleGalleryModal(vehicles) {
    const cards = (vehicles && vehicles.length)
      ? vehicles.map(vehicleGalleryCardHtml).join('')
      : `<div class="list-empty">${esc(t('cad_vehicle_gallery_none'))}</div>`;
    const modal = openModal(`
      <h2>${esc(t('cad_vehicle_gallery_title'))}</h2>
      <div class="vehicle-gallery-grid">${cards}</div>
      <div class="creator-actions" style="justify-content:flex-end;"><button class="btn btn-ghost" id="modClose">${esc(t('close'))}</button></div>
    `, 'modal-panel-wide');
    modal.querySelector('#modClose').addEventListener('click', () => modal.remove());
    modal.querySelectorAll('[data-veh-manage]').forEach((manageBtn) => {
      const vehicle = vehicles.find((v) => String(v.id) === manageBtn.dataset.vehManage);
      if (!vehicle) return;
      manageBtn.addEventListener('click', () => {
        modal.remove();
        cad.nav = 'vehicles';
        cad.profile = null;
        renderCadSidebar();
        renderCadNav();
        renderVehicleResults([vehicle]);
        renderVehicleDetail(vehicle);
        post('cadSearchVehicles', { plate: vehicle.plate });
      });
    });
  }

  function renderCadWarrants(content) {
    content.innerHTML = `
      <div class="cad-results-col">
        <div class="cad-search-bar">
          <div class="tab-row" style="border:0;">
            <button class="tab-btn ${cad.warrantStatus === 'active' ? 'active' : ''}" data-status="active">${esc(t('cad_active'))}</button>
            <button class="tab-btn ${cad.warrantStatus === 'closed' ? 'active' : ''}" data-status="closed">${esc(t('cad_closed'))}</button>
          </div>
        </div>
        <div class="cad-results-list" id="cadResultsList"></div>
      </div>
      <div class="cad-detail-col" id="cadDetailCol"><div class="cad-detail-empty">${esc(t('cad_select_result'))}</div></div>
    `;
    content.querySelectorAll('[data-status]').forEach((btn) => {
      btn.addEventListener('click', () => { cad.warrantStatus = btn.dataset.status; renderCadWarrants(content); loadWarrants(); });
    });
    loadWarrants();
  }

  function loadWarrants() { post('cadSearchWarrants', { status: cad.warrantStatus }); }

  function renderWarrantResults(results) {
    const list = document.getElementById('cadResultsList');
    if (!list) return;
    list.innerHTML = '';
    if (results.length === 0) { list.appendChild(el(`<div class="list-empty">${esc(t('cad_no_results'))}</div>`)); return; }
    results.forEach((w) => {
      const flags = flagPills(w.is_armed, w.is_violent, w.is_mentally_ill);
      const row = el(`
        <div class="list-row">
          <div>
            <div style="font-weight:700;">${esc(w.first_name)} ${esc(w.last_name)} ${flags}</div>
            <div class="char-meta">${esc(w.reason)}</div>
          </div>
        </div>
      `);
      row.addEventListener('click', () => renderWarrantDetail(w));
      list.appendChild(row);
    });
  }

  function renderWarrantDetail(w) {
    const detail = document.getElementById('cadDetailCol');
    if (!detail) return;
    detail.innerHTML = `
      <div class="profile-header">
        <div>
          <div class="name-huge">${esc(w.first_name)} ${esc(w.last_name)} ${flagPills(w.is_armed, w.is_violent, w.is_mentally_ill)}</div>
          <div class="char-meta">${esc(w.state_id)}</div>
        </div>
        <div style="display:flex; gap:8px;">
          ${w.status === 'active' ? `<button class="btn btn-danger btn-sm" id="closeWarrantBtn">${esc(t('cad_close_warrant'))}</button>` : `<span class="pill pill-green">${esc(t('cad_closed'))}</span>`}
          ${cad.context && cad.context.isAdmin ? `<button class="btn btn-danger btn-sm" id="adminDeleteWarrantBtn">${esc(t('cad_remove'))}</button>` : ''}
        </div>
      </div>
      <div class="profile-meta-grid">
        <div class="meta-cell"><label>${esc(t('cad_issued_by'))}</label>${esc(w.issued_by)}</div>
        <div class="meta-cell"><label>${esc(t('department'))}</label>${esc(w.department)}</div>
        <div class="meta-cell"><label>${esc(t('cad_expires'))}</label>${fmtDate(w.expires_at)}</div>
        <div class="meta-cell"><label>${esc(t('cad_created'))}</label>${fmtDate(w.created_at)}</div>
      </div>
      <div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_reason'))}</h3></div><div class="record-row">${esc(w.reason)}</div></div>
      ${(w.charges && w.charges.length) ? `<div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_selected_grounds'))}</h3></div><div class="record-row">${w.charges.map(c => `${esc(c.label)} <span class="charge-code">${esc(c.code)}</span>`).join(', ')}</div></div>` : ''}
      ${w.notes ? `<div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_notes'))}</h3></div><div class="record-row">${esc(w.notes)}</div></div>` : ''}
      ${w.signature ? `<div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_officer_signature'))}</h3></div><div class="record-row">${esc(w.signature)}</div></div>` : ''}
    `;
    const btn = document.getElementById('closeWarrantBtn');
    if (btn) btn.addEventListener('click', () => { post('cadCloseWarrant', { warrantId: w.id }); loadWarrants(); });
    const delBtn = document.getElementById('adminDeleteWarrantBtn');
    if (delBtn) delBtn.addEventListener('click', () => {
      openConfirmModal(t('cad_admin_delete_record_confirm'), () => {
        post('cadAdminDeleteRecord', { type: 'warrant', id: w.id });
        detail.innerHTML = `<div class="cad-detail-empty">${esc(t('cad_select_result'))}</div>`;
        loadWarrants();
      });
    });
  }

  function renderCadVehicleBolos(content) {
    content.innerHTML = `
      <div class="cad-results-col">
        <div class="cad-search-bar">
          <div class="tab-row" style="border:0;">
            <button class="tab-btn ${cad.vehicleBoloStatus === 'active' ? 'active' : ''}" data-bolo-status="active">${esc(t('cad_active'))}</button>
            <button class="tab-btn ${cad.vehicleBoloStatus === 'closed' ? 'active' : ''}" data-bolo-status="closed">${esc(t('cad_closed'))}</button>
          </div>
          <button class="btn btn-primary btn-sm" id="vehicleBoloNewBtn" style="margin-top:8px;">${esc(t('cad_new_vehicle_bolo'))}</button>
        </div>
        <div class="cad-results-list" id="cadResultsList"></div>
      </div>
      <div class="cad-detail-col" id="cadDetailCol"><div class="cad-detail-empty">${esc(t('cad_select_result'))}</div></div>
    `;
    content.querySelectorAll('[data-bolo-status]').forEach((btn) => {
      btn.addEventListener('click', () => { cad.vehicleBoloStatus = btn.dataset.boloStatus; renderCadVehicleBolos(content); loadVehicleBolos(); });
    });
    document.getElementById('vehicleBoloNewBtn').addEventListener('click', openVehicleBoloModal);
    loadVehicleBolos();
  }

  function loadVehicleBolos() { post('cadSearchVehicleBolos', { status: cad.vehicleBoloStatus }); }

  function openVehicleBoloModal() {
    const priorities = cad.context.vehicleBoloPriorities || [
      { key: 'routine', label: 'Routine', color: 'gray' },
      { key: 'priority', label: 'Priority', color: 'amber' },
      { key: 'armed', label: 'Armed & Dangerous', color: 'red-bright' }
    ];
    let selectedPriority = priorities[0] ? priorities[0].key : 'routine';

    const modal = openModal(`
      <h2>${esc(t('cad_new_vehicle_bolo'))}</h2>
      <div class="arrest-menu-grid">
        <div class="arrest-menu-col">
          <div class="profile-section-head"><h3>${esc(t('cad_vehicle_description'))}</h3></div>
          <div class="field"><label>${esc(t('cad_plate'))}</label><input id="modPlate" maxlength="16"></div>
          <div class="field"><label>${esc(t('cad_brand'))}</label><input id="modBrand" maxlength="32"></div>
          <div class="field"><label>${esc(t('cad_model'))}</label><input id="modModel" maxlength="64"></div>
          <div class="field-row">
            <div class="field"><label>${esc(t('cad_type'))}</label><input id="modType" maxlength="64"></div>
            <div class="field"><label>${esc(t('cad_color'))}</label><input id="modColor" maxlength="32"></div>
          </div>
        </div>
        <div class="arrest-menu-col">
          <div class="profile-section-head"><h3>${esc(t('cad_bolo_details'))}</h3></div>
          <div class="field"><label>${esc(t('cad_reason'))}</label><textarea id="modReason" rows="2" maxlength="255"></textarea></div>
          <div class="field">
            <label>${esc(t('cad_priority'))}</label>
            <div class="chip-row" id="priorityChips">
              ${priorities.map((p, i) => `<button type="button" class="chip-btn chip-${esc(p.color)} ${i === 0 ? 'active' : ''}" data-priority="${esc(p.key)}">${esc(p.label)}</button>`).join('')}
            </div>
          </div>
          ${flagChipsMarkup('boloFlagChips')}
        </div>
      </div>
      <div class="field-row creator-signature-row">
        <div class="field"><label>${esc(t('cad_officer_signature'))}</label><input id="modSignature" maxlength="64" placeholder="${esc(t('cad_signature_placeholder'))}"></div>
      </div>
      <div class="field"><label>${esc(t('cad_notes'))}</label><textarea id="modNotes" rows="2"></textarea></div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit" disabled>${esc(t('confirm'))}</button></div>
    `, 'modal-panel-wide');

    const submitBtn = modal.querySelector('#modSubmit');
    const signatureInput = modal.querySelector('#modSignature');
    const reasonInput = modal.querySelector('#modReason');
    const descInputs = ['#modPlate', '#modBrand', '#modModel', '#modType', '#modColor'].map((s) => modal.querySelector(s));
    const boloFlags = wireFlagChips(modal, 'boloFlagChips');

    function checkValid() {
      const hasDescriptor = descInputs.some((i) => i.value.trim());
      submitBtn.disabled = !hasDescriptor || !reasonInput.value.trim() || !signatureInput.value.trim();
    }

    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelectorAll('#priorityChips .chip-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        selectedPriority = btn.dataset.priority;
        modal.querySelectorAll('#priorityChips .chip-btn').forEach((b) => b.classList.toggle('active', b === btn));
      });
    });
    descInputs.forEach((i) => i.addEventListener('input', checkValid));
    reasonInput.addEventListener('input', checkValid);
    signatureInput.addEventListener('input', checkValid);

    modal.querySelector('#modSubmit').addEventListener('click', () => {
      const hasDescriptor = descInputs.some((i) => i.value.trim());
      if (!hasDescriptor || !reasonInput.value.trim() || !signatureInput.value.trim()) return;
      post('cadCreateVehicleBolo', {
        plate: modal.querySelector('#modPlate').value,
        brand: modal.querySelector('#modBrand').value,
        model: modal.querySelector('#modModel').value,
        type: modal.querySelector('#modType').value,
        color: modal.querySelector('#modColor').value,
        reason: reasonInput.value,
        priority: selectedPriority,
        signature: signatureInput.value,
        notes: modal.querySelector('#modNotes').value,
        isArmed: boloFlags.armed,
        isViolent: boloFlags.violent,
        isMentallyIll: boloFlags.mentallyIll
      });
      modal.remove();
      setTimeout(loadVehicleBolos, 300);
    });

    checkValid();
  }

  function boloPriorityMeta(key) {
    const list = (cad.context && cad.context.vehicleBoloPriorities) || [
      { key: 'routine', label: 'Routine', color: 'gray' },
      { key: 'priority', label: 'Priority', color: 'amber' },
      { key: 'armed', label: 'Armed & Dangerous', color: 'red-bright' }
    ];
    return list.find((p) => p.key === key) || { key: key, label: key || 'Routine', color: 'gray' };
  }

  function renderVehicleBoloResults(results) {
    const list = document.getElementById('cadResultsList');
    if (!list) return;
    list.innerHTML = '';
    if (results.length === 0) { list.appendChild(el(`<div class="list-empty">${esc(t('cad_no_results'))}</div>`)); return; }
    results.forEach((b) => {
      const priority = boloPriorityMeta(b.priority);
      const flags = flagPills(b.is_armed, b.is_violent, b.is_mentally_ill);
      const row = el(`
        <div class="list-row">
          <div>
            <div style="font-weight:700;">${esc(b.plate || t('cad_no_plate'))} ${priority.key !== 'routine' ? `<span class="pill pill-${priority.color === 'red-bright' ? 'red' : priority.color}">${esc(priority.label)}</span>` : ''} ${flags}</div>
            <div class="char-meta">${esc([b.brand, b.model].filter(Boolean).join(' '))}${b.vehicle_type ? ' • ' + esc(b.vehicle_type) : ''}${b.color ? ' • ' + esc(b.color) : ''}</div>
          </div>
        </div>
      `);
      row.addEventListener('click', () => renderVehicleBoloDetail(b));
      list.appendChild(row);
    });
  }

  function renderVehicleBoloDetail(b) {
    const detail = document.getElementById('cadDetailCol');
    if (!detail) return;
    const priority = boloPriorityMeta(b.priority);
    detail.innerHTML = `
      <div class="profile-header">
        <div>
          <div class="name-huge">${esc(b.plate || t('cad_no_plate'))} ${flagPills(b.is_armed, b.is_violent, b.is_mentally_ill)}</div>
          <div class="char-meta">${esc([b.brand, b.model].filter(Boolean).join(' '))}${b.color ? ' • ' + esc(b.color) : ''}</div>
        </div>
        <div style="display:flex; gap:8px;">
          ${b.status === 'active' ? `<button class="btn btn-danger btn-sm" id="closeBoloBtn">${esc(t('cad_close_bolo'))}</button>` : `<span class="pill pill-green">${esc(t('cad_closed'))}</span>`}
          ${cad.context && cad.context.isAdmin ? `<button class="btn btn-danger btn-sm" id="adminDeleteBoloBtn">${esc(t('cad_remove'))}</button>` : ''}
        </div>
      </div>
      <div class="profile-meta-grid">
        <div class="meta-cell"><label>${esc(t('cad_type'))}</label>${esc(b.vehicle_type || '—')}</div>
        <div class="meta-cell"><label>${esc(t('cad_color'))}</label>${esc(b.color || '—')}</div>
        <div class="meta-cell"><label>${esc(t('cad_priority'))}</label><span class="pill pill-${priority.color === 'red-bright' ? 'red' : priority.color}">${esc(priority.label)}</span></div>
        <div class="meta-cell"><label>${esc(t('cad_issued_by'))}</label>${esc(b.issued_by)}</div>
      </div>
      <div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_reason'))}</h3></div><div class="record-row">${esc(b.reason)}</div></div>
      ${b.notes ? `<div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_notes'))}</h3></div><div class="record-row">${esc(b.notes)}</div></div>` : ''}
      ${b.signature ? `<div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_officer_signature'))}</h3></div><div class="record-row">${esc(b.signature)}</div></div>` : ''}
    `;
    const btn = document.getElementById('closeBoloBtn');
    if (btn) btn.addEventListener('click', () => { post('cadCloseVehicleBolo', { boloId: b.id }); loadVehicleBolos(); });
    const delBtn = document.getElementById('adminDeleteBoloBtn');
    if (delBtn) delBtn.addEventListener('click', () => {
      openConfirmModal(t('cad_admin_delete_record_confirm'), () => {
        post('cadAdminDeleteRecord', { type: 'vehicleBolo', id: b.id });
        detail.innerHTML = `<div class="cad-detail-empty">${esc(t('cad_select_result'))}</div>`;
        loadVehicleBolos();
      });
    });
  }

  function renderCadIncidents(content) {
    content.innerHTML = `
      <div class="cad-results-col">
        <div class="cad-search-bar">
          <div class="field"><input id="qIncident" placeholder="${esc(t('cad_incident_search'))}"></div>
          <div style="display:flex; gap:8px;">
            <button class="btn btn-primary btn-sm" id="incidentSearchBtn">${esc(t('search_officers'))}</button>
            <button class="btn btn-sm" id="incidentNewBtn">${esc(t('cad_new_incident'))}</button>
          </div>
        </div>
        <div class="cad-results-list" id="cadResultsList"></div>
      </div>
      <div class="cad-detail-col" id="cadDetailCol"><div class="cad-detail-empty">${esc(t('cad_select_result'))}</div></div>
    `;
    document.getElementById('incidentSearchBtn').addEventListener('click', () => {
      post('cadSearchIncidents', { query: document.getElementById('qIncident').value });
    });
    document.getElementById('incidentNewBtn').addEventListener('click', openIncidentModal);
    post('cadSearchIncidents', { query: '' });
  }

  function openIncidentModal() {
    const modal = openModal(`
      <h2>${esc(t('cad_new_incident'))}</h2>
      <div class="field"><label>${esc(t('cad_incident_title'))}</label><input id="modTitle" maxlength="128"></div>
      <div class="field"><label>${esc(t('cad_narrative'))}</label><textarea id="modNarrative" rows="10"></textarea></div>
      <div class="field"><label>${esc(t('cad_evidence'))}</label><textarea id="modEvidence" rows="5"></textarea></div>
      <div class="field"><label>${esc(t('cad_signing_officer'))}</label><input id="modSigningOfficer" maxlength="64" placeholder="${esc(t('cad_signature_placeholder'))}"></div>
      <div class="creator-actions"><button class="btn btn-ghost" id="modCancel">${esc(t('cancel'))}</button><button class="btn btn-primary" id="modSubmit">${esc(t('confirm'))}</button></div>
    `);
    modal.querySelector('#modCancel').addEventListener('click', () => modal.remove());
    modal.querySelector('#modSubmit').addEventListener('click', () => {
      post('cadCreateIncident', {
        title: modal.querySelector('#modTitle').value,
        narrative: modal.querySelector('#modNarrative').value,
        evidence: modal.querySelector('#modEvidence').value,
        signingOfficer: modal.querySelector('#modSigningOfficer').value
      });
      modal.remove();
      setTimeout(() => post('cadSearchIncidents', { query: '' }), 300);
    });
  }

  function renderIncidentResults(results) {
    const list = document.getElementById('cadResultsList');
    if (!list) return;
    list.innerHTML = '';
    if (results.length === 0) { list.appendChild(el(`<div class="list-empty">${esc(t('cad_no_results'))}</div>`)); return; }
    results.forEach((inc) => {
      const row = el(`
        <div class="list-row">
          <div>
            <div style="font-weight:700;">${esc(inc.title)}</div>
            <div class="char-meta">${esc(inc.case_number)} • ${esc(inc.status)}</div>
          </div>
        </div>
      `);
      row.addEventListener('click', () => renderIncidentDetail(inc));
      list.appendChild(row);
    });
  }

  function renderIncidentDetail(inc) {
    const detail = document.getElementById('cadDetailCol');
    if (!detail) return;
    detail.innerHTML = `
      <div class="profile-header">
        <div><div class="name-huge">${esc(inc.title)}</div><div class="char-meta">${esc(inc.case_number)}</div></div>
        <div style="display:flex; gap:8px;">
          <button class="btn btn-sm" id="toggleStatusBtn">${inc.status === 'open' ? esc(t('cad_close_case')) : esc(t('cad_reopen_case'))}</button>
          ${cad.context && cad.context.isAdmin ? `<button class="btn btn-danger btn-sm" id="adminDeleteIncidentBtn">${esc(t('cad_remove'))}</button>` : ''}
        </div>
      </div>
      <div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_narrative'))}</h3></div><textarea id="incNarrative" rows="10">${esc(inc.narrative || '')}</textarea></div>
      <div class="profile-section"><div class="profile-section-head"><h3>${esc(t('cad_evidence'))}</h3></div><textarea id="incEvidence" rows="5">${esc(inc.evidence || '')}</textarea></div>
      <div class="field"><label>${esc(t('cad_signing_officer'))}</label><input id="incSigningOfficer" maxlength="64" placeholder="${esc(t('cad_signature_placeholder'))}" value="${esc(inc.signing_officer || '')}"></div>
      <button class="btn btn-primary btn-sm" id="saveIncidentBtn">${esc(t('confirm'))}</button>
    `;
    document.getElementById('toggleStatusBtn').addEventListener('click', () => {
      inc.status = inc.status === 'open' ? 'closed' : 'open';
      post('cadUpdateIncident', { incidentId: inc.id, status: inc.status });
      renderIncidentDetail(inc);
    });
    document.getElementById('saveIncidentBtn').addEventListener('click', () => {
      post('cadUpdateIncident', {
        incidentId: inc.id, status: inc.status,
        narrative: document.getElementById('incNarrative').value,
        evidence: document.getElementById('incEvidence').value,
        signingOfficer: document.getElementById('incSigningOfficer').value
      });
    });
    const delBtn = document.getElementById('adminDeleteIncidentBtn');
    if (delBtn) delBtn.addEventListener('click', () => {
      openConfirmModal(t('cad_admin_delete_record_confirm'), () => {
        post('cadAdminDeleteRecord', { type: 'incident', id: inc.id });
        detail.innerHTML = `<div class="cad-detail-empty">${esc(t('cad_select_result'))}</div>`;
        setTimeout(() => post('cadSearchIncidents', { query: '' }), 300);
      });
    });
  }

  function renderCadDispatch(content) {
    content.innerHTML = `<div class="cad-detail-col" style="width:100%;" id="dispatchList"></div>`;
    post('requestDispatchState', {});
    renderDispatchList(cad.dispatchCalls);
  }

  function renderDispatchList(calls) {
    cad.dispatchCalls = calls || [];
    const wrap = document.getElementById('dispatchList');
    if (!wrap) return;
    if (cad.dispatchCalls.length === 0) {
      wrap.innerHTML = `<div class="cad-detail-empty">${esc(t('no_active_calls'))}</div>`;
      return;
    }
    wrap.innerHTML = '';
    const focusCallId = cad.focusCallId;
    let focusRow = null;
    const myServerId = cad.context && cad.context.serverId != null ? String(cad.context.serverId) : null;
    cad.dispatchCalls.forEach((c) => {
      const amResponder = !!(myServerId && Array.isArray(c.responders) && c.responders.some((r) => String(r.src) === myServerId));
      const row = el(`
        <div class="call-card${c.alertId === focusCallId ? ' call-card--focused' : ''}" ${c.coords ? 'data-selectable' : ''} style="margin-bottom:10px;" title="${c.coords ? esc(t('cad_set_waypoint')) : ''}">
          <div class="call-top">
            <strong>${esc(c.reason)}</strong>
            <span class="pill ${c.status === 'active' ? 'pill-amber' : 'pill-red'}">${esc(c.status || 'pending')}</span>
          </div>
          <div>${esc(c.street)}</div>
          <div class="char-meta">${esc(c.caller)} • ${esc(c.receivedAt)}${c.acceptedBy ? ' • ' + esc(c.acceptedBy) : ''}</div>
          <div style="display:flex; gap:8px; margin-top:6px;">
            ${c.status !== 'active' ? `<button class="btn btn-sm" data-accept="${esc(c.alertId)}">${esc(t('cad_accept'))}</button>` : ''}
            ${amResponder ? `<button class="btn btn-sm" data-leave="${esc(c.alertId)}">${esc(t('cad_leave_call'))}</button>` : ''}
            <button class="btn btn-sm btn-danger" data-complete="${esc(c.alertId)}">${esc(t('cad_complete'))}</button>
          </div>
        </div>
      `);
      const acceptBtn = row.querySelector('[data-accept]');
      if (acceptBtn) acceptBtn.addEventListener('click', (e) => { e.stopPropagation(); post('cadAcceptCall', { alertId: c.alertId }); });
      const leaveBtn = row.querySelector('[data-leave]');
      if (leaveBtn) leaveBtn.addEventListener('click', (e) => { e.stopPropagation(); post('cadLeaveCall', { alertId: c.alertId }); });
      row.querySelector('[data-complete]').addEventListener('click', (e) => { e.stopPropagation(); post('cadCompleteCall', { alertId: c.alertId }); });
      if (c.coords) row.addEventListener('click', () => post('cadSetWaypoint', { coords: c.coords }));
      if (c.alertId === focusCallId) focusRow = row;
      wrap.appendChild(row);
    });
    if (focusRow) {
      focusRow.scrollIntoView({ block: 'center' });
      cad.focusCallId = null;
    }
  }

  function renderCadPanic(content) {
    content.innerHTML = `<div class="cad-detail-col" style="width:100%;" id="panicList"></div>`;
    post('requestPanicState', {});
    renderPanicList(cad.panicAlerts);
  }

  function renderPanicList(alerts) {
    cad.panicAlerts = alerts || [];
    const wrap = document.getElementById('panicList');
    if (!wrap) return;
    if (cad.panicAlerts.length === 0) {
      wrap.innerHTML = `<div class="cad-detail-empty">${esc(t('no_active_panics'))}</div>`;
      return;
    }
    wrap.innerHTML = '';
    cad.panicAlerts.forEach((a) => {
      const row = el(`
        <div class="call-card" ${a.coords ? 'data-selectable' : ''} style="margin-bottom:10px;" title="${a.coords ? esc(t('cad_set_waypoint')) : ''}">
          <div class="call-top">
            <strong>${esc(a.name)} [${esc(a.callsign)}]</strong>
            <span class="pill pill-red">${esc(a.departmentLabel || a.department || '')}</span>
          </div>
          <div>${esc(a.street)}</div>
          <div class="char-meta">${esc(a.rank || '')}</div>
          ${cad.isPanicSupervisor ? `<div style="display:flex; gap:8px; margin-top:6px;">
            <button class="btn btn-sm btn-danger" data-clear="${esc(a.alertId)}">${esc(t('cad_clear'))}</button>
          </div>` : ''}
        </div>
      `);
      const clearBtn = row.querySelector('[data-clear]');
      if (clearBtn) clearBtn.addEventListener('click', (e) => { e.stopPropagation(); post('cadClearPanic', { alertId: a.alertId }); });
      if (a.coords) row.addEventListener('click', () => post('cadSetWaypoint', { coords: a.coords }));
      wrap.appendChild(row);
    });
  }

  function renderCadTenCodes(content) {
    const codes = (cad.context && cad.context.tenCodes) || [];
    content.innerHTML = `
      <div class="cad-detail-col" style="width:100%;">
        <div class="profile-header">
          <div>
            <div class="name-huge">${esc(t('cad_nav_tencodes'))}</div>
            <div class="char-meta" id="tenCodeCount"></div>
          </div>
        </div>
        <div class="field" style="max-width:320px; margin-bottom:14px;"><input id="tenCodeSearch" placeholder="${esc(t('cad_tencode_search'))}"></div>
        <div class="codes-grid" id="tenCodeGrid"></div>
      </div>
    `;

    function draw(filter) {
      const f = (filter || '').toLowerCase();
      const filtered = codes.filter((c) => !f || c.code.toLowerCase().includes(f) || c.label.toLowerCase().includes(f));
      document.getElementById('tenCodeCount').textContent = filtered.length + ' / ' + codes.length;
      const grid = document.getElementById('tenCodeGrid');
      grid.innerHTML = filtered.length ? filtered.map((c) => `
        <div class="code-chip"><span class="code-num">${esc(c.code)}</span><span class="code-label">${esc(c.label)}</span></div>
      `).join('') : `<div class="list-empty">${esc(t('cad_no_results'))}</div>`;
    }

    draw('');
    document.getElementById('tenCodeSearch').addEventListener('input', (e) => draw(e.target.value));
  }

  function renderCadPenalCodes(content) {
    const codes = (cad.context && cad.context.penalCodes) || [];
    content.innerHTML = `
      <div class="cad-detail-col" style="width:100%;">
        <div class="profile-header">
          <div>
            <div class="name-huge">${esc(t('cad_nav_penalcodes'))}</div>
            <div class="char-meta" id="penalCodeCount"></div>
          </div>
        </div>
        <div class="field" style="max-width:320px; margin-bottom:14px;"><input id="penalCodeSearch" placeholder="${esc(t('cad_penalcode_search'))}"></div>
        <div id="penalCodeList"></div>
      </div>
    `;

    function draw(filter) {
      const f = (filter || '').toLowerCase();
      const filtered = codes.filter((c) => !f || c.code.toLowerCase().includes(f) || c.title.toLowerCase().includes(f));
      document.getElementById('penalCodeCount').textContent = filtered.length + ' / ' + codes.length;
      const list = document.getElementById('penalCodeList');
      list.innerHTML = filtered.length ? filtered.map((c) => `
        <div class="record-row penal-row">
          <div class="record-top">
            <span>${esc(c.code)}</span>
            <span class="pill ${c.type === 'Felony' ? 'pill-red' : 'pill-amber'}">${esc(c.type)}</span>
          </div>
          <div style="font-weight:700; margin-bottom:4px;">${esc(c.title)}</div>
          <div class="char-meta">${esc(c.bondType)} • $${Number(c.bondAmount).toLocaleString()} • ${esc(c.jailTime)}</div>
        </div>
      `).join('') : `<div class="list-empty">${esc(t('cad_no_results'))}</div>`;
    }

    draw('');
    document.getElementById('penalCodeSearch').addEventListener('input', (e) => draw(e.target.value));
  }

  function screenVehicleRegistration() {
    initCustomCursor(false);
    setBgMusicPhase(false);
    renderRoot(`
      <div class="screen creator-screen vehicle-reg-screen">
        <div class="panel creator-panel" style="width:420px;">
          <div>
            <span class="eyebrow">${esc(t('veh_reg_subtitle'))}</span>
            <h1>${esc(t('veh_reg_title'))}</h1>
          </div>
          <p class="hint">${esc(t('veh_reg_help'))}</p>
          <button class="btn btn-block btn-ghost" id="vehMyVehiclesBtn" style="margin-bottom:4px;">${esc(t('veh_my_vehicles_btn'))}</button>
          <div class="field"><label>${esc(t('veh_reg_brand'))}</label><input id="vehRegBrand" maxlength="32"></div>
          <div class="field"><label>${esc(t('veh_reg_model'))}</label><input id="vehRegModel" maxlength="64"></div>
          <div class="field"><label>${esc(t('veh_reg_type'))}</label><input id="vehRegType" maxlength="64"></div>
          <div class="field"><label>${esc(t('veh_reg_year'))}</label><input id="vehRegYear" type="number" min="1900" max="2100"></div>
          <div class="field"><label>${esc(t('veh_reg_color'))}</label><input id="vehRegColor" maxlength="32"></div>
          <div class="field"><label>${esc(t('veh_reg_plate'))}</label><input id="vehRegPlate" maxlength="16"></div>
          <div class="field"><label>${esc(t('veh_reg_plate_state'))}</label><input id="vehRegPlateState" maxlength="8"></div>
          <div id="vehRegErr" class="hint" style="color:var(--red-bright);"></div>
          <div class="creator-actions">
            <button class="btn btn-ghost" id="vehRegCancelBtn">${esc(t('cancel'))}</button>
            <button class="btn btn-primary" id="vehRegSubmitBtn">${esc(t('veh_reg_submit'))}</button>
          </div>
        </div>
      </div>
    `);

    document.getElementById('vehRegCancelBtn').addEventListener('click', () => post('closeVehicleReg', {}));
    document.getElementById('vehMyVehiclesBtn').addEventListener('click', () => post('requestMyVehicles', {}));
    document.getElementById('vehRegSubmitBtn').addEventListener('click', () => {
      document.getElementById('vehRegErr').textContent = '';
      post('submitVehicleRegistration', {
        brand: document.getElementById('vehRegBrand').value,
        model: document.getElementById('vehRegModel').value,
        type: document.getElementById('vehRegType').value,
        year: document.getElementById('vehRegYear').value || null,
        color: document.getElementById('vehRegColor').value,
        plate: document.getElementById('vehRegPlate').value,
        plateState: document.getElementById('vehRegPlateState').value
      });
    });
  }

  function screenMyVehicles(vehicles) {
    initCustomCursor(false);
    setBgMusicPhase(false);
    renderRoot(`
      <div class="screen creator-screen vehicle-reg-screen">
        <div class="panel creator-panel" style="width:420px;">
          <div>
            <span class="eyebrow">${esc(t('veh_reg_subtitle'))}</span>
            <h1>${esc(t('veh_my_vehicles_title'))}</h1>
          </div>
          <div class="scroll-y" id="myVehiclesList" style="max-height:360px; overflow-y:auto; display:flex; flex-direction:column; gap:8px;"></div>
          <div class="creator-actions">
            <button class="btn btn-ghost" id="myVehBackBtn">${esc(t('back'))}</button>
            <button class="btn btn-primary" id="myVehCloseBtn">${esc(t('close'))}</button>
          </div>
        </div>
      </div>
    `);
    renderMyVehiclesList(vehicles);
    document.getElementById('myVehBackBtn').addEventListener('click', () => screenVehicleRegistration());
    document.getElementById('myVehCloseBtn').addEventListener('click', () => post('closeVehicleReg', {}));
  }

  function renderMyVehiclesList(vehicles) {
    const wrap = document.getElementById('myVehiclesList');
    if (!wrap) return;
    wrap.innerHTML = '';
    if (!vehicles || vehicles.length === 0) {
      wrap.appendChild(el(`<div class="list-empty">${esc(t('veh_my_vehicles_none'))}</div>`));
      return;
    }
    vehicles.forEach((v) => {
      wrap.appendChild(el(`
        <div class="list-row" style="cursor:default;">
          <div>
            <div style="font-weight:700;">${esc(v.plate)}${v.plate_state ? ` <span class="char-meta">(${esc(v.plate_state)})</span>` : ''}${v.stolen ? ' <span class="pill pill-red">STOLEN</span>' : ''}</div>
            <div class="char-meta">${esc([v.vehicle_year, v.brand, v.model].filter(Boolean).join(' '))}${v.vehicle_type ? ' • ' + esc(v.vehicle_type) : ''}</div>
            <div class="char-meta">${esc(v.color || '—')} • ${regPill(v.registration)} • ${v.insured ? esc(t('cad_insured')) : esc(t('cad_not_insured'))}</div>
            ${v.expiration_date ? `<div class="char-meta">${esc(t('cad_expiration_date'))}: ${fmtDate(v.expiration_date)}</div>` : ''}
          </div>
        </div>
      `));
    });
  }

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.locale) LOCALE = data.locale;
    if (data.notificationConfig) NOTIF_CFG = Object.assign(NOTIF_CFG, data.notificationConfig);

    switch (data.action) {
      case 'bootLoading': screenBootLoading(); break;

      case 'openCharacterCreator': screenCharacterCreator(data.context); break;
      case 'characterCreatorError': onCreatorError(data.message); break;
      case 'openCharacterSelector': screenCharacterSelector(data.payload); break;
      case 'characterLoaded': /* spawn selector takes over next */ break;

      case 'spawnLoading': screenSpawnLoading(); break;
      case 'openSpawnSelector': screenSpawnSelector(data); break;

      case 'openVehicleRegistration': screenVehicleRegistration(); break;
      case 'myVehicles': screenMyVehicles(data.vehicles); break;

      case 'openCad': {
        cad.context = null;
        const openToken = ++cadOpenToken;
        screenCadLoading(() => {
          if (openToken !== cadOpenToken) return; // CAD was closed again before the loading delay finished
          screenCad(data.context);
        });
        break;
      }
      case 'cadContext':
        cad.context = Object.assign({}, cad.context, data.context);
        renderCadHeader();
        if (document.getElementById('cadSidebar')) renderCadSidebar();
        break;
      case 'cadRoster': renderRosterList(data.list); break;
      case 'cadReferenceData':
        cad.context = Object.assign({}, cad.context, data.payload);
        if (cad.nav === 'tencodes') renderCadTenCodes(document.getElementById('cadContent'));
        else if (cad.nav === 'penalcodes') renderCadPenalCodes(document.getElementById('cadContent'));
        else if (cad.nav === 'admin') refreshCadAdminIfOpen();
        break;
      case 'cadSearchResults':
        cad.results = data.payload.results;
        if (data.payload.type === 'citizen') renderCitizenResults(data.payload.results);
        if (data.payload.type === 'vehicle') renderVehicleResults(data.payload.results);
        if (data.payload.type === 'warrant') { renderWarrantResults(data.payload.results); renderHomeWarrantsWidget(data.payload.results); }
        if (data.payload.type === 'vehicleBolo') { renderVehicleBoloResults(data.payload.results); renderHomeVehicleBolosWidget(data.payload.results); }
        if (data.payload.type === 'incident') renderIncidentResults(data.payload.results);
        break;
      case 'cadCitizenProfile': renderCitizenProfile(data.profile); break;
      case 'cadVehicleUpdated':
        if (data.vehicle) {
          cad.results = (cad.results || []).map((r) => r.id === data.vehicle.id ? data.vehicle : r);
          if (document.getElementById('cadResultsList') && cad.results.some((r) => r.id === data.vehicle.id)) {
            renderVehicleResults(cad.results);
          }
          renderVehicleDetail(data.vehicle);
        }
        break;
      case 'cadVehicleHistory':
        if (data.payload && vehicleHistoryModalState && vehicleHistoryModalState.vehicleId === data.payload.vehicleId) {
          renderVehicleHistoryList(vehicleHistoryModalState.modal, data.payload.history);
        }
        break;
      case 'cadDispatchState': renderDispatchList(data.calls); renderHomeCallsWidget(); break;
      case 'cadFocusCall':
        cad.nav = 'dispatch';
        cad.focusCallId = data.alertId || null;
        cad.profile = null;
        renderCadSidebar();
        renderCadNav();
        break;
      case 'cadCallUpdated':
        cad.dispatchCalls = cad.dispatchCalls.map((c) => c.alertId === data.call.alertId ? data.call : c);
        if (!cad.dispatchCalls.find((c) => c.alertId === data.call.alertId)) cad.dispatchCalls.push(data.call);
        renderDispatchList(cad.dispatchCalls);
        renderHomeCallsWidget();
        break;
      case 'cadCallCleared':
        cad.dispatchCalls = cad.dispatchCalls.filter((c) => c.alertId !== data.alertId);
        renderDispatchList(cad.dispatchCalls);
        renderHomeCallsWidget();
        break;

      case 'cadPanicState':
        cad.isPanicSupervisor = data.isSupervisor === true;
        renderPanicList(data.alerts);
        break;
      case 'cadPanicUpdated':
        if (!cad.panicAlerts.find((a) => a.alertId === data.alert.alertId)) cad.panicAlerts.push(data.alert);
        renderPanicList(cad.panicAlerts);
        break;
      case 'cadPanicCleared':
        cad.panicAlerts = cad.panicAlerts.filter((a) => a.alertId !== data.alertId);
        renderPanicList(cad.panicAlerts);
        break;

      case 'close': clearInterval(cadRosterTimer); stopCadClock(); cadOpenToken++; hideApp(); break;
      default: break;
    }
  });

  document.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape') return;
    if (document.querySelector('.modal-backdrop')) { document.querySelector('.modal-backdrop').remove(); return; }
    if (!app.classList.contains('hidden') && document.querySelector('.cad-screen')) { post('closeCad', {}); return; }
    if (!app.classList.contains('hidden') && document.querySelector('.vehicle-reg-screen')) { post('closeVehicleReg', {}); return; }
    if (document.getElementById('selector-screen') && spawnState.allowClose) {
      post('closeSpawnSelector', {});
    }
  });

  post('ready', {});
})();
