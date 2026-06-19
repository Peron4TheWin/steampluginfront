(function() {
    if (document.getElementById('peron-tab')) return;

    function waitFor(sel, cb, max) {
        max = max || 20;
        var n = 0;
        function check() {
            var el = document.querySelector(sel);
            if (el) { cb(el); return; }
            if (++n < max) setTimeout(check, 100);
        }
        check();
    }

    waitFor('[role="tablist"]', function(tablist) {
        var appId = (location.href.match(/\/app\/(\d+)/) || [])[1]
                 || (location.search.match(/appid=(\d+)/i) || [])[1];
        if (!appId) {
            var m = document.body.innerHTML.match(/\/app\/(\d+)\/properties/);
            appId = m ? m[1] : null;
        }
        if (!appId) { console.log('[Peron] Could not find appId'); return; }

        var tpl = tablist.querySelector('._1-vlriAtKYDViAEunue4VO');
        if (!tpl) return;

        var peronTab = tpl.cloneNode(true);
        peronTab.id = 'peron-tab';
        peronTab.className = tpl.className.replace(/_2DpXjzK3WWsOtUWUrcuOG7/g, '');
        peronTab.setAttribute('aria-selected', 'false');
        var label = peronTab.querySelector('._2PPbMrzl8PKBwpkjYs9b0i');
        if (label) label.textContent = 'Peron';

        var panel = document.createElement('div');
        panel.id = 'peron-content';
        panel.className = 'DialogContent _DialogLayout CFTLX2wIKOK3hNV-fS7_V';
        panel.setAttribute('role', 'tabpanel');
        panel.style.display = 'none';

        panel.innerHTML =
            '<div class="DialogContent_InnerWidth">' +
                '<div role="heading" aria-level="2" class="DialogHeader">Peron</div>' +
                '<div class="DialogBody">' +
                    '<div class="DialogControlsSection">' +
                        '<div aria-level="3" role="heading" class="SettingsDialogSubHeader">Fixes</div>' +
                        '<div style="display:flex; gap:8px; align-items:center; margin-top:10px;">' +
                            '<select id="peron-fixes-dd" class="DialogInput DialogInputPlaceholder DialogTextInputBase Focusable" style="flex:1; height:36px; background:#316282; color:#c6d4df; border:1px solid #4c6b22; border-radius:2px; padding:0 8px;">' +
                                '<option value="">-- Select a fix --</option>' +
                                '<option value="fps_unlock">FPS Unlock</option>' +
                                '<option value="skip_intro">Skip Intro</option>' +
                                '<option value="fov_mod">FOV Mod</option>' +
                                '<option value="packet_priority">Network Priority</option>' +
                            '</select>' +
                            '<a id="peron-fixes-apply" class="btnv6_blue_hoverfade btn_medium" href="#"><span>Apply</span></a>' +
                        '</div>' +
                        '<div id="peron-fixes-status" style="color:#8f98a0; font-size:12px; margin-top:6px;"></div>' +
                    '</div>' +
                    '<div class="DialogControlsSection" style="margin-top:28px;">' +
                        '<div aria-level="3" role="heading" class="SettingsDialogSubHeader">Denuvo</div>' +
                        '<div style="display:flex; justify-content:center; margin-top:16px;">' +
                            '<div style="background:rgba(27,40,56,0.96); border:2px solid #4c6b22; border-radius:6px; padding:22px 28px; text-align:center; max-width:340px; width:100%;">' +
                                '<div style="color:#c6d4df; font-size:15px; font-weight:600; margin-bottom:6px;">Denuvo Ticket</div>' +
                                '<div style="color:#8f98a0; font-size:12px; margin-bottom:12px;">One-time code for ' + appId + '</div>' +
                                '<div style="position:relative; margin-bottom:10px;">' +
                                    '<input id="peron-denuvo-code" placeholder="Paste code or click Get..." style="width:100%;box-sizing:border-box;background:#316282;border:1px solid #4c6b22;color:#5ba32b;padding:10px 36px 10px 10px;border-radius:2px;font-size:20px;font-family:monospace;text-align:center;letter-spacing:4px;font-weight:700;" />' +
                                    '<a id="peron-denuvo-copy" href="#" title="Copy code" style="position:absolute;top:8px;right:8px;display:flex;align-items:center;justify-content:center;width:26px;height:26px;border-radius:3px;background:#1b2838;border:1px solid #4c6b22;color:#8f98a0;text-decoration:none;">' +
                                        '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>' +
                                    '</a>' +
                                '</div>' +
                                '<div style="display:flex; gap:8px; justify-content:center;">' +
                                    '<a id="peron-denuvo-get" class="btnv6_blue_hoverfade btn_medium" href="#"><span>Get Code</span></a>' +
                                    '<a id="peron-denuvo-apply" class="btnv6_white_transparent btn_medium" href="#"><span>Apply</span></a>' +
                                '</div>' +
                                '<div id="peron-denuvo-status" style="color:#8f98a0; font-size:12px; margin-top:10px; min-height:16px;"></div>' +
                            '</div>' +
                        '</div>' +
                    '</div>' +
                '</div>' +
            '</div>';

        tablist.appendChild(peronTab);
        var contentArea = document.querySelector('.DialogContentTransition');
        if (contentArea) contentArea.appendChild(panel);

        function allTabs()   { return tablist.querySelectorAll('._1-vlriAtKYDViAEunue4VO'); }
        function allPanels() { return document.querySelectorAll('.DialogContent._DialogLayout'); }

        function selectPeron() {
            allTabs().forEach(function(t) {
                t.classList.remove('_2DpXjzK3WWsOtUWUrcuOG7');
                t.setAttribute('aria-selected', 'false');
            });
            peronTab.classList.add('_2DpXjzK3WWsOtUWUrcuOG7');
            peronTab.setAttribute('aria-selected', 'true');
            allPanels().forEach(function(c) { c.style.display = 'none'; });
            panel.style.display = '';
        }

        peronTab.addEventListener('click', selectPeron);

        var obs = new MutationObserver(function(ml) {
            ml.forEach(function(m) {
                if (m.type === 'attributes' && m.attributeName === 'class') {
                    var sel = tablist.querySelector('._1-vlriAtKYDViAEunue4VO._2DpXjzK3WWsOtUWUrcuOG7');
                    if (sel && sel.id !== 'peron-tab' && panel.style.display !== 'none') {
                        panel.style.display = 'none';
                        allPanels().forEach(function(c) {
                            if (c.id !== 'peron-content') c.style.display = '';
        });

        // Denuvo Apply (redeem code)
        document.getElementById('peron-denuvo-apply').addEventListener('click', function(e) {
            e.preventDefault();
            var st = document.getElementById('peron-denuvo-status');
            var input = document.getElementById('peron-denuvo-code');
            var code = input.value.trim();
            if (!code) { st.textContent = 'No code to apply.'; st.style.color = '#e84040'; return; }
            st.textContent = 'Applying...';
            st.style.color = '#f8a524';
            fetch('http://127.0.0.1:3000/denuvo/' + appId, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ code: code })
            }).then(function(r) { return r.text(); })
              .then(function(t) {
                if (t === 'OK') { st.textContent = 'Applied.'; st.style.color = '#5ba32b'; }
                else { st.textContent = 'Error: ' + t; st.style.color = '#e84040'; }
            }).catch(function() {
                st.textContent = 'Connection error.'; st.style.color = '#e84040';
            });
        });
                    }
                }
            });
        });
        obs.observe(tablist, { attributes: true, subtree: true, attributeFilter: ['class'] });

        // Load fixes on inject
        fetch('http://127.0.0.1:3000/fixes/' + appId)
            .then(function(r) { return r.json().catch(function() { return []; }); })
            .then(function(fixes) {
                var dd = document.getElementById('peron-fixes-dd');
                dd.innerHTML = '';
                if (!fixes || fixes.length === 0) {
                    dd.innerHTML = '<option value="">None</option>';
                } else {
                    dd.innerHTML = '<option value="">-- Select a fix --</option>';
                    fixes.forEach(function(f) {
                        var opt = document.createElement('option');
                        opt.value = f.id || f;
                        opt.textContent = f.name || f;
                        dd.appendChild(opt);
                    });
                }
            })
            .catch(function() {
                document.getElementById('peron-fixes-dd').innerHTML = '<option value="">None</option>';
            });

        // Fixes Apply
        document.getElementById('peron-fixes-apply').addEventListener('click', function(e) {
            e.preventDefault();
            var dd = document.getElementById('peron-fixes-dd');
            var st = document.getElementById('peron-fixes-status');
            var val = dd.value;
            if (!val) { st.textContent = 'Please select a fix first.'; st.style.color = '#e84040'; return; }
            st.textContent = 'Applying ' + val + '...';
            st.style.color = '#f8a524';
            fetch('http://127.0.0.1:3000/fixes/' + appId + '/apply', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ fix: val })
            }).then(function(r) {
                if (r.ok) { st.textContent = val + ' applied successfully.'; st.style.color = '#5ba32b'; }
                else { st.textContent = 'Error applying fix.'; st.style.color = '#e84040'; }
            }).catch(function() {
                st.textContent = 'Connection error.'; st.style.color = '#e84040';
            });
        });

        // Denuvo Get Code
        document.getElementById('peron-denuvo-get').addEventListener('click', function(e) {
            e.preventDefault();
            var st = document.getElementById('peron-denuvo-status');
            var input = document.getElementById('peron-denuvo-code');
            var btn = document.getElementById('peron-denuvo-get');
            st.textContent = 'Generating code...';
            st.style.color = '#f8a524';
            btn.querySelector('span').textContent = '...';

            fetch('http://127.0.0.1:3000/denuvo/' + appId)
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    if (data.error) throw new Error(data.error);
                    input.value = data.code || '';
                    st.textContent = 'Code generated.';
                    st.style.color = '#5ba32b';
                    btn.querySelector('span').textContent = 'Get Code';
                })
                .catch(function(e) {
                    st.textContent = 'Error: ' + e.message;
                    st.style.color = '#e84040';
                    btn.querySelector('span').textContent = 'Get Code';
                });
        });

        // Denuvo Copy
        document.getElementById('peron-denuvo-copy').addEventListener('click', function(e) {
            e.preventDefault();
            var input = document.getElementById('peron-denuvo-code');
            var code = input.value.trim();
            if (!code) return;
            input.select();
            document.execCommand('copy');
            var st = document.getElementById('peron-denuvo-status');
            st.textContent = 'Copied to clipboard.';
            st.style.color = '#5ba32b';
        });

        console.log('[Peron] Tab injected for app ' + appId);
    });
})();
