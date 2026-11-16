// Licensed under GPL-3.0. See LICENSE.
//
//  PasswordScript.swift
//  VegaWeb
//
//  FORK: the page side of the password manager. It runs in its own content world, so the page's
//  own scripts can neither read it nor call the native handler. Nothing is filled until the person
//  clicks a saved login in the menu this script draws; the click must be a real one (isTrusted).
//

import Foundation

enum PasswordScript {
    static let handlerName = "vegaPasswords"

    /// Starts with "// Vega" so the app keeps it when it rebuilds a view's scripts (see WKUserScript+VegaOwned).
    static let source = #"""
    // Vega Passwords (Vega)
    (function () {
      if (window.__vegaPasswords) return;
      window.__vegaPasswords = true;
      const handler = () => window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.vegaPasswords;
      const ask = (msg) => { const h = handler(); return h ? h.postMessage(msg) : Promise.resolve(null); };

      const visible = (el) => {
        if (!el || !el.isConnected) return false;
        const r = el.getBoundingClientRect();
        if (r.width < 4 || r.height < 4) return false;
        const s = getComputedStyle(el);
        return s.visibility !== 'hidden' && s.display !== 'none';
      };
      const passwordFields = (root) => Array.from((root || document).querySelectorAll('input[type=password]'))
        .filter((el) => visible(el) && !el.disabled && !el.readOnly);
      const isUserField = (el) => el && el.tagName === 'INPUT' && ['text', 'email', 'tel', ''].includes((el.getAttribute('type') || '').toLowerCase()) && visible(el) && !el.disabled && !el.readOnly;

      // The username field: the closest visible text-like input before the password field.
      const usernameFor = (pw) => {
        const scope = pw.form || document;
        const fields = Array.from(scope.querySelectorAll('input')).filter(isUserField);
        const before = fields.filter((el) => el.compareDocumentPosition(pw) & Node.DOCUMENT_POSITION_FOLLOWING);
        const byHint = before.concat(fields).find((el) => /user|email|login|name/i.test((el.autocomplete || '') + (el.name || '') + (el.id || '')));
        return byHint || before[before.length - 1] || null;
      };
      // The password field a focused field belongs to: itself, or the one after a username field.
      const passwordFor = (el) => {
        if (el.type === 'password') return el;
        const scope = el.form || document;
        const pws = passwordFields(scope);
        return pws.find((pw) => el.compareDocumentPosition(pw) & Node.DOCUMENT_POSITION_FOLLOWING) || null;
      };

      const setValue = (el, value) => {
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        setter.call(el, value);
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      };

      // ---- The menu of saved logins ---------------------------------------------------------
      let menu = null, cache = null;
      const closeMenu = () => { if (menu) { menu.host.remove(); menu = null; } };
      const logins = async () => { if (!cache) cache = Promise.resolve(ask({ op: 'list' })).then((r) => Array.isArray(r) ? r : []); return cache; };

      const openMenu = async (field) => {
        const pw = passwordFor(field);
        // A username-only first step (two-page sign-ins) still offers the saved username; the password comes on the next page.
        if (!pw && !/username|email/i.test((field.autocomplete || '') + (field.type || ''))) return;
        const list = await logins();
        if (!list.length || document.activeElement !== field) return;
        closeMenu();
        const host = document.createElement('div');
        host.style.cssText = 'all:initial;position:absolute;z-index:2147483647;';
        const root = host.attachShadow({ mode: 'closed' });
        const rect = field.getBoundingClientRect();
        host.style.left = (rect.left + scrollX) + 'px';
        host.style.top = (rect.bottom + scrollY + 4) + 'px';
        const style = document.createElement('style');
        style.textContent = ':host{color-scheme:light dark}' +
          '.m{font:13px/1.25 -apple-system,system-ui;min-width:' + Math.max(rect.width, 240) + 'px;max-width:340px;background:Canvas;color:CanvasText;' +
          'border:.5px solid rgba(128,128,128,.45);border-radius:12px;box-shadow:0 10px 30px rgba(0,0,0,.28);padding:5px}' +
          '.i{padding:6px 8px;border-radius:7px;cursor:default;display:flex;gap:9px;align-items:center}' +
          '.i.s{background:#0a84ff;color:#fff}.i.s .t{color:rgba(255,255,255,.8)}' +
          '.k{flex:none;width:26px;height:26px;border-radius:7px;background:#f7a72b;display:flex;align-items:center;justify-content:center}' +
          '.k svg{width:15px;height:15px;fill:#fff}.n{font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
          '.t{font-size:11px;opacity:.65;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.x{display:flex;flex-direction:column;min-width:0}' +
          '.r{height:1px;background:rgba(128,128,128,.3);margin:4px 6px}';
        const box = document.createElement('div');
        box.className = 'm';
        const keyIcon = '<svg viewBox="0 0 24 24"><path d="M14.5 2a6.5 6.5 0 0 0-6.1 8.7L2 17.1V22h4.9v-2.2h2.2v-2.2h2.2l1.4-1.4A6.5 6.5 0 1 0 14.5 2zm2 4.2a1.6 1.6 0 1 1 0 3.2 1.6 1.6 0 0 1 0-3.2z"/></svg>';
        const rows = [];
        const choose = async (login) => {
          if (!pw) { setValue(field, login.u); closeMenu(); return; }
          // The native side asks for Touch ID or the Mac's password before it hands the password over.
          const secret = await ask({ op: 'fill', u: login.u });
          if (!secret) return;
          const user = pw === field ? usernameFor(pw) : field;
          if (user) setValue(user, login.u);
          setValue(pw, secret);
          closeMenu();
        };
        const mark = (i) => rows.forEach((r, j) => r.classList.toggle('s', i === j));
        list.forEach((login, i) => {
          const row = document.createElement('div');
          row.className = 'i';
          const icon = document.createElement('div');
          icon.className = 'k';
          icon.innerHTML = keyIcon;
          const text = document.createElement('div');
          text.className = 'x';
          const name = document.createElement('div');
          name.className = 'n';
          name.textContent = login.u || location.hostname;
          const site = document.createElement('div');
          site.className = 't';
          site.textContent = location.hostname.replace(/^www\./, '');
          text.append(name, site);
          row.append(icon, text);
          row.addEventListener('mousedown', (e) => e.preventDefault());
          row.addEventListener('mouseenter', () => { mark(i); if (menu) menu.index = i; });
          row.addEventListener('click', (e) => { if (e.isTrusted) choose(login); });
          rows.push(row);
          box.appendChild(row);
        });
        const rule = document.createElement('div');
        rule.className = 'r';
        const manage = document.createElement('div');
        manage.className = 'i';
        manage.innerHTML = '<div class="x"><div class="n">Passwords…</div></div>';
        manage.addEventListener('mousedown', (e) => e.preventDefault());
        manage.addEventListener('click', (e) => { if (e.isTrusted) { ask({ op: 'manage' }); closeMenu(); } });
        box.append(rule, manage);
        root.append(style, box);
        document.documentElement.appendChild(host);
        menu = { host, field, index: -1, rows, list, choose, mark };
      };

      document.addEventListener('focusin', (e) => {
        const el = e.target;
        if (el && el.tagName === 'INPUT' && (el.type === 'password' || isUserField(el))) openMenu(el);
      }, true);
      document.addEventListener('mousedown', (e) => { if (menu && e.target !== menu.field && !e.composedPath().includes(menu.host)) closeMenu(); }, true);
      document.addEventListener('keydown', (e) => {
        if (!menu) return;
        if (e.key === 'Escape') return closeMenu();
        const n = menu.rows.length;
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
          e.preventDefault();
          menu.index = (menu.index + (e.key === 'ArrowDown' ? 1 : -1) + n) % n;
          menu.mark(menu.index);
        } else if (e.key === 'Enter' && menu.index >= 0 && e.isTrusted) {
          e.preventDefault();
          menu.choose(menu.list[menu.index]);
        }
      }, true);

      // ---- Noticing a login ---------------------------------------------------------------------
      let candidate = null, timer = null;
      const sendCandidate = () => { if (candidate) { ask({ op: 'submit', u: candidate.u, p: candidate.p }); candidate = null; } };
      const capture = (scope) => {
        const pws = passwordFields(scope).filter((el) => el.value);
        if (!pws.length) return;
        // A sign-up form repeats the password; the login one has a single field.
        const pw = pws.find((el) => /current-password|new-password/.test(el.autocomplete || '')) || pws[0];
        const user = usernameFor(pw);
        candidate = { u: user ? user.value : '', p: pw.value, el: pw };
        clearTimeout(timer);
        // If the form is still there a moment later the login most likely failed: nothing to save.
        timer = setTimeout(() => { if (candidate && (!visible(candidate.el) || !candidate.el.value)) sendCandidate(); else candidate = null; }, 1800);
      };
      document.addEventListener('submit', (e) => capture(e.target), true);
      document.addEventListener('click', (e) => {
        const b = e.target.closest && e.target.closest('button, input[type=submit], [role=button]');
        if (b && e.isTrusted) capture(b.form || b.closest('form') || document);
      }, true);
      document.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.isTrusted && e.target.tagName === 'INPUT') capture(e.target.form || document); }, true);
      // Leaving the page after a submit is the usual sign of success.
      addEventListener('pagehide', sendCandidate);
    })();
    """#
}
