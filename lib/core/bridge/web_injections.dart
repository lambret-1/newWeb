/// 注入 WebView 的静态脚本集合：
/// - 广告拦截（隐藏常见广告元素）
/// - 选中文本翻译（浮动按钮 → JS Bridge）
/// - 离线页面采集（内联 CSS/图片后回传）
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

  /// 选中文本翻译脚本：监听 selectionchange，弹出「翻译」浮动按钮；
  /// 结果由 App 通过 __NEWWEB_TRANSLATE_RESULT__(id, ok, text) 回传。
  static String selectionTranslateScript() => r'''
(function() {
  if (window.__NEWWEB_TRANSLATE__) return;
  window.__NEWWEB_TRANSLATE__ = true;
  var btn = null, card = null;

  function removeEl(el) { if (el && el.parentNode) el.parentNode.removeChild(el); }

  function showCard(text) {
    removeEl(card);
    card = document.createElement('div');
    card.textContent = text;
    card.style.cssText = [
      'position:fixed', 'z-index:2147483647', 'background:#FFFFFF', 'color:#111111',
      'font-size:14px', 'padding:10px 12px', 'border-radius:10px',
      'box-shadow:0 4px 16px rgba(0,0,0,0.18)', 'max-width:280px',
      'border:1px solid #E5E7EB', 'line-height:1.6',
      'font-family:-apple-system,sans-serif', 'right:12px', 'top:64px'
    ].join(';') + ';';
    document.body.appendChild(card);
  }

  function createBtn(rect) {
    removeEl(btn);
    btn = document.createElement('div');
    btn.textContent = '翻译';
    btn.style.cssText = [
      'position:fixed', 'z-index:2147483646', 'background:#3B82F6',
      'color:#FFFFFF', 'font-size:13px', 'padding:4px 14px',
      'border-radius:12px', 'box-shadow:0 2px 8px rgba(0,0,0,0.2)',
      'cursor:pointer', 'font-family:-apple-system,sans-serif'
    ].join(';') + ';';
    var x = rect.left + rect.width / 2;
    btn.style.left = Math.max(8, Math.min(x - 30, window.innerWidth - 68)) + 'px';
    btn.style.top = Math.max(rect.top - 36, 8) + 'px';
    btn.addEventListener('click', function() {
      var sel = window.getSelection();
      var text = sel ? sel.toString().trim() : '';
      if (!text) return;
      removeEl(btn);
      showCard('翻译中…');
      try {
        window.NativeBridge.postMessage(JSON.stringify({
          id: 'translate-' + Date.now(),
          action: 'translate',
          payload: { text: text }
        }));
      } catch (e) {
        showCard('翻译不可用');
      }
    });
    document.body.appendChild(btn);
  }

  document.addEventListener('selectionchange', function() {
    var sel = window.getSelection();
    var text = sel ? sel.toString().trim() : '';
    if (text.length >= 2 && text.length <= 500) {
      try {
        var range = sel.getRangeAt(0);
        var rect = range.getBoundingClientRect();
        if (rect.width > 0 && rect.height > 0) createBtn(rect);
      } catch (e) { removeEl(btn); }
    } else {
      removeEl(btn);
    }
  });
  document.addEventListener('scroll', function() {
    removeEl(btn); removeEl(card);
  }, true);

  window.__NEWWEB_TRANSLATE_RESULT__ = function(id, ok, text) {
    removeEl(btn);
    showCard(ok ? text : ('翻译失败：' + text));
  };
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
