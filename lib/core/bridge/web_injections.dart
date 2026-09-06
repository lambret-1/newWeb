/// 注入 WebView 的静态脚本集合：
/// - 整页翻译（网页翻译：手动 / 自动触发，可恢复原文）
/// - 阅读器模式（正文提取）
/// - 离线页面采集（内联 CSS/图片后回传）
/// - 弹窗兜底（广告域名 window.open 拦截；主拦截走原生 WKContentRuleList）
class WebInjections {
  WebInjections._();

  /// 广告拦截脚本：隐藏常见广告容器 + MutationObserver 持续清理。
  static String adBlockScript() => r'''
(function() {
  if (window.__NEWWEB_ADBLOCK__) return;
  window.__NEWWEB_ADBLOCK__ = true;
  var selectors = [
    '.ad', '.ads', '.advert', '.advertisement', '.adsbygoogle',
    '.ad-banner', '.ad-container', '.ad-wrapper', '.banner-ad',
    '.google-ads', '#google_ads', '#ad', '#ad-container',
    'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
    'iframe[src*="adservice"]', 'iframe[src*="ads"]',
    '[class*="ad-banner"]', '[id*="ad-"]', '[class*="-ad-"]'
  ];
  function hide() {
    for (var i = 0; i < selectors.length; i++) {
      var els;
      try { els = document.querySelectorAll(selectors[i]); } catch (e) { continue; }
      for (var j = 0; j < els.length; j++) {
        var el = els[j];
        if (el.style) {
          el.style.display = 'none';
          el.style.visibility = 'hidden';
          el.style.height = '0px';
        }
      }
    }
  }
  hide();
  new MutationObserver(hide).observe(document.documentElement, {
    childList: true, subtree: true
  });
})();
''';

  /// 弹窗兜底脚本：拦截广告域名触发的 window.open（原生规则外的补充）。
  static String popupGuardScript() => r'''
(function() {
  if (window.__NEWWEB_POPUP_GUARD__) return;
  window.__NEWWEB_POPUP_GUARD__ = true;
  var adHosts = /(popads\.net|propellerads\.com|exoclick\.com|adsterra\.com|popunder\.network|adcash\.com|clic\.pw)$/i;
  var _open = window.open;
  window.open = function(url, name, features) {
    try {
      var u = new URL(url, location.href);
      if (adHosts.test(u.hostname)) return null;
    } catch (e) { /* 忽略解析失败 */ }
    return _open.apply(this, arguments);
  };
})();
''';

  /// 整页翻译脚本：提取可见文本节点，分批经 JS Bridge 翻译并替换，可恢复原文。
  /// Dart 侧逐批回传结果：window.__NEWWEB_PAGE_TRANSLATE_APPLY__(id, results)。
  static String pageTranslateScript() => r'''
(function() {
  if (window.__NEWWEB_PAGE_TRANSLATE__) return;
  var nodes = [], backups = [], state = 'idle', total = 0, done = 0;

  function collect(maxCount) {
    nodes = []; backups = [];
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
    var n;
    while ((n = walker.nextNode())) {
      var t = n.nodeValue.replace(/\s+/g, ' ').trim();
      if (t.length < 2 || t.length > 200) continue;
      var p = n.parentElement;
      if (!p) continue;
      var tag = p.tagName;
      if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' ||
          tag === 'TEXTAREA' || tag === 'CODE' || tag === 'IFRAME') continue;
      if (p.closest && p.closest('script,style,noscript,code,pre')) continue;
      if (!/[A-Za-z]/.test(t)) continue;
      backups.push({ node: n, text: t });
      nodes.push({ index: backups.length - 1, text: t });
      if (nodes.length >= maxCount) break;
    }
  }

  function translate(maxCount, batchSize, mode) {
    if (state === 'translating') return false;
    collect(maxCount || 300);
    if (nodes.length === 0) { state = 'done'; return false; }
    state = 'translating';
    total = nodes.length; done = 0;
    var pos = 0, batchId = 0;
    function nextBatch() {
      var slice = nodes.slice(pos, pos + batchSize);
      if (slice.length === 0) { state = 'done'; emitState(); return; }
      batchId++;
      var id = 'pb-' + batchId;
      try {
        window.NativeBridge.postMessage(JSON.stringify({
          id: id,
          action: 'translateBatch',
          payload: {
            texts: slice.map(function(s) { return s.text; }),
            indices: slice.map(function(s) { return s.index; }),
            mode: mode || 'auto'
          }
        }));
      } catch (e) { state = 'error'; emitState(); return; }
      pos += batchSize;
    }
    window.__NEWWEB_PAGE_TRANSLATE_APPLY__ = function(id, results) {
      (results || []).forEach(function(r) {
        var b = backups[r.index];
        if (b && r.text) { b.node.nodeValue = r.text; done++; }
      });
      emitState();
      nextBatch();
    };
    nextBatch();
    return true;
  }

  function restore() {
    backups.forEach(function(b) { b.node.nodeValue = b.text; });
    backups = []; nodes = []; state = 'idle'; total = 0; done = 0;
  }

  function emitState() {
    try {
      window.NativeBridge.postMessage(JSON.stringify({
        id: 'pt-state-' + Date.now(),
        action: 'translateState',
        payload: { state: state, total: total, done: done }
      }));
    } catch (e) { /* 忽略 */ }
  }

  window.__NEWWEB_PAGE_TRANSLATE__ = {
    translate: translate,
    restore: restore,
    getState: function() { return state; }
  };
})();
''';

  /// 阅读器模式脚本：启发式提取正文（标题 + HTML），同步返回 JSON 字符串。
  static String readerExtractScript() => r'''
(function() {
  if (window.__NEWWEB_READER__) return;
  function score(el) {
    var p = el.querySelectorAll('p').length;
    var text = el.innerText ? el.innerText.length : 0;
    return p * 10 + text / 500;
  }
  function extract() {
    var candidates = [];
    var selectors = [
      'article', '[role="main"]', '.article-content', '.post-content',
      '.entry-content', '.article', '.content', '#content', '.main-content',
      '.article-body', '.rich_media_content'
    ];
    selectors.forEach(function(sel) {
      var els = document.querySelectorAll(sel);
      for (var i = 0; i < els.length; i++) candidates.push(els[i]);
    });
    if (candidates.length === 0) {
      var divs = document.querySelectorAll('div');
      for (var i = 0; i < divs.length; i++) {
        var d = divs[i];
        if (!d.querySelectorAll || d.querySelectorAll('div').length > 5) continue;
        if (d.querySelectorAll('p').length >= 3) candidates.push(d);
      }
    }
    if (candidates.length === 0) return null;
    candidates.sort(function(a, b) { return score(b) - score(a); });
    var best = candidates[0];
    if (score(best) < 5) return null;
    var title = document.title || '';
    var h = best.querySelector('h1,h2');
    if (h && h.innerText && h.innerText.trim()) title = h.innerText.trim();
    var clone = best.cloneNode(true);
    var drop = clone.querySelectorAll(
      'script,style,noscript,iframe,ins,aside,nav,button,form,' +
      '.ad,.ads,.advert,.advertisement,.adsbygoogle,.banner-ad,.ad-banner,' +
      '.share,.comment,.related,.recommend,[class*=social]'
    );
    for (var j = 0; j < drop.length; j++) {
      var el = drop[j];
      if (el.parentNode) el.parentNode.removeChild(el);
    }
    var imgs = clone.querySelectorAll('img');
    for (var k = 0; k < imgs.length; k++) {
      var img = imgs[k];
      if (img.src && img.src.indexOf('data:') !== 0) {
        var src = img.getAttribute('data-src') || img.src;
        if (src && img.src !== src) img.setAttribute('src', src);
      }
    }
    return {
      title: title,
      html: clone.innerHTML,
      url: location.href,
      source: location.hostname
    };
  }
  window.__NEWWEB_READER__ = extract;
})();
''';

  /// 离线采集脚本：内联 CSS 与图片后，把归档 HTML 经 JS Bridge 回传。
  static String collectOfflineScript() => r'''
(function() {
  if (window.__NEWWEB_COLLECT__) return;
  window.__NEWWEB_COLLECT__ = function() {
    return new Promise(function(resolve) {
      var finished = false;
      var links = Array.prototype.slice.call(
        document.querySelectorAll('link[rel="stylesheet"]')
      );
      var imgs = Array.prototype.slice.call(
        document.querySelectorAll('img[src]')
      );
      var pending = links.length + imgs.length;
      if (pending === 0) { finalize(); return; }

      function check() {
        pending--;
        if (pending <= 0 && !finished) finalize();
      }
      function finalize() {
        if (finished) return;
        finished = true;
        var html = '<!DOCTYPE html>\n' + document.documentElement.outerHTML;
        try {
          window.NativeBridge.postMessage(JSON.stringify({
            id: 'offline-' + Date.now(),
            action: 'offlineCollected',
            payload: {
              html: html,
              title: document.title || location.hostname,
              url: location.href
            }
          }));
        } catch (e) { /* 回传失败由 Dart 侧超时处理 */ }
        resolve(html);
      }

      links.forEach(function(link) {
        var href = link.href;
        if (!href || href.indexOf('http') !== 0) { check(); return; }
        fetch(href).then(function(r) { return r.text(); }).then(function(css) {
          var style = document.createElement('style');
          style.setAttribute('data-inlined', '1');
          style.textContent = css;
          try { link.parentNode.replaceChild(style, link); } catch (e) {}
          check();
        }).catch(function() { check(); });
      });

      imgs.forEach(function(img) {
        var src = img.src;
        if (!src || src.indexOf('data:') === 0 || src.indexOf('http') !== 0) {
          check(); return;
        }
        fetch(src).then(function(r) { return r.blob(); }).then(function(blob) {
          var reader = new FileReader();
          reader.onload = function() {
            try { img.setAttribute('src', reader.result); } catch (e) {}
            check();
          };
          reader.onerror = function() { check(); };
          reader.readAsDataURL(blob);
        }).catch(function() { check(); });
      });

      setTimeout(function() { finalize(); }, 8000);
    });
  };
})();
''';
}
