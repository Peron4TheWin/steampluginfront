(() => {
    const appId = window.location.href.match(/\/app\/(\d+)/)?.[1];
    if (!appId) return;

    function showKeyModal(onSubmit) {
        const overlay = document.createElement("div");
        overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.7);z-index:99999;display:flex;align-items:center;justify-content:center;";
        overlay.innerHTML = `
            <div style="background:#1b2838;border:1px solid #4c6b22;border-radius:4px;padding:24px;width:360px;font-family:Arial,sans-serif;">
                <div style="color:#c6d4df;font-size:16px;margin-bottom:8px;">API Key requerida</div>
                <div style="color:#8f98a0;font-size:13px;margin-bottom:16px;">Ingresá tu key de HubCap para continuar.</div>
                <input id="hc-key-input" type="text" placeholder="smm_..." style="width:100%;box-sizing:border-box;background:#316282;border:1px solid #4c6b22;color:#c6d4df;padding:8px;border-radius:2px;font-size:13px;margin-bottom:16px;"/>
                <div style="display:flex;gap:8px;justify-content:flex-end;">
                    <a id="hc-cancel" class="btnv6_white_transparent btn_medium" href="#"><span>Cancelar</span></a>
                    <a id="hc-submit" class="btnv6_blue_hoverfade btn_medium" href="#"><span>Guardar</span></a>
                </div>
            </div>
        `;

        document.body.appendChild(overlay);

        overlay.querySelector("#hc-cancel").onclick = (e) => {
            e.preventDefault();
            overlay.remove();
        };

        overlay.querySelector("#hc-submit").onclick = (e) => {
            e.preventDefault();
            const key = overlay.querySelector("#hc-key-input").value.trim();
            if (!key) return;
            overlay.remove();
            onSubmit(key);
        };

        overlay.querySelector("#hc-key-input").addEventListener("keydown", (e) => {
            if (e.key === "Enter") overlay.querySelector("#hc-submit").click();
        });

        setTimeout(() => overlay.querySelector("#hc-key-input").focus(), 50);
    }

    function showFixedModal(id, btn, keyless) {
        const overlay = document.createElement("div");
        overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.7);z-index:99999;display:flex;align-items:center;justify-content:center;";
        overlay.innerHTML = `
            <div style="background:#1b2838;border:1px solid #4c6b22;border-radius:4px;padding:24px;width:400px;font-family:Arial,sans-serif;">
                <div style="color:#c6d4df;font-size:16px;margin-bottom:8px;">Version crackeada disponible</div>
                <div style="color:#8f98a0;font-size:13px;margin-bottom:6px;">Este juego tiene una version fija con manifiestos crackeados.</div>
                <div style="color:#f8a524;font-size:12px;margin-bottom:16px;">Usar esta version garantiza compatibilidad con el crack.</div>
                <div style="display:flex;gap:8px;justify-content:flex-end;">
                    <a id="fc-no" class="btnv6_white_transparent btn_medium" href="#"><span>No, normal</span></a>
                    <a id="fc-yes" class="btnv6_blue_hoverfade btn_medium" href="#"><span>Usar crackeada</span></a>
                </div>
            </div>
        `;
        document.body.appendChild(overlay);

        overlay.querySelector("#fc-no").onclick = (e) => {
            e.preventDefault();
            overlay.remove();
            doAddGame(id, btn, keyless, false);
        };
        overlay.querySelector("#fc-yes").onclick = (e) => {
            e.preventDefault();
            overlay.remove();
            doAddGame(id, btn, keyless, true);
        };
    }

    async function doAddGame(id, btn, keyless, useFixed) {
        const url = useFixed
            ? `http://127.0.0.1:27060/fixed/${id}`
            : keyless
                ? `http://127.0.0.1:27060/keyless/${id}`
                : `http://127.0.0.1:27060/${id}`;

        const r = await fetch(url, { method: "POST" });

        if (r.ok) {
            showToast(useFixed ? "Fixed version added!" : keyless ? "Game added (keyless)!" : "Game added!");
            setButtonMode(btn, "remove");
            await refreshLimit();
            return;
        }

        if (r.status === 401 && !keyless && !useFixed) {
            const askKey = async (key) => {
                const keyRes = await fetch("http://127.0.0.1:27060/key", {
                    method: "POST",
                    body: key
                });
                if (keyRes.ok) {
                    const retry = await fetch(`http://127.0.0.1:27060/${id}`, { method: "POST" });
                    if (retry.ok) {
                        showToast("Game added!");
                        setButtonMode(btn, "remove");
                        await refreshLimit();
                    } else {
                        showToast("Error: " + await retry.text(), true);
                    }
                } else {
                    showToast("Key invalida: " + await keyRes.text(), true);
                    showKeyModal(askKey);
                }
            };
            showKeyModal(askKey);
            return;
        }

        showToast("Error " + r.status + ": " + await r.text(), true);
    }

    async function addGame(id, btn, keyless = false) {
        // Check fixed (cracked) version first
        try {
            const fixCheck = await fetch(`http://127.0.0.1:27060/hasfixed/${id}`);
            if (fixCheck.ok) {
                const data = await fixCheck.json();
                if (data.available) {
                    showFixedModal(id, btn, keyless);
                    return;
                }
            }
        } catch {}

        doAddGame(id, btn, keyless, false);
    }

    async function removeGame(id, btn) {
        const r = await fetch(`http://127.0.0.1:27060/remove/${id}`, {
            method: "POST"
        });

        if (r.ok) {
            showToast("Game removed!");
            setButtonMode(btn, "add");
            await refreshLimit();
            return;
        }

        showToast("Error " + r.status + ": " + await r.text(), true);
    }

    function setButtonMode(btn, mode) {
        if (mode === "remove") {
            btn.querySelector("span").textContent = "Remove game";
            btn.onclick = (e) => {
                e.preventDefault();
                removeGame(appId, btn);
            };
            btn.oncontextmenu = null;
        } else {
            btn.querySelector("span").textContent = "Add game";
            btn.onclick = (e) => {
                e.preventDefault();
                addGame(appId, btn, true);
            };
            btn.oncontextmenu = (e) => {
                e.preventDefault();
                addGame(appId, btn, false);
            };
        }
    }

    function showToast(msg, isError = false) {
        const t = document.createElement("div");
        t.style.cssText = `position:fixed;bottom:24px;right:24px;background:${isError ? "#922" : "#4c6b22"};color:#fff;padding:10px 18px;border-radius:4px;font-size:13px;z-index:99999;font-family:Arial,sans-serif;`;
        t.textContent = msg;
        document.body.appendChild(t);
        setTimeout(() => t.remove(), 3000);
    }

    async function refreshLimit() {
        const el = document.querySelector(".hubcap-limit-text");
        if (!el) return;
        try {
            const r = await fetch("http://127.0.0.1:27060/limit");
            const text = (await r.text()).trim();
            const [used, total] = text.split("/").map(Number);
            const pct = used / total;
            const color = pct >= 1 ? "#e84040" : pct >= 0.75 ? "#f8a524" : "#5ba32b";
            el.textContent = text;
            el.style.color = color;
        } catch {
            el.textContent = "N/A";
            el.style.color = "#8f98a0";
        }
    }

    async function injectButton() {
        const container = document.querySelector(".apphub_OtherSiteInfo");
        if (!container) return;
        if (container.querySelector(".hubcap-add-game")) return;

        const btn = document.createElement("a");
        btn.className = "btnv6_blue_hoverfade btn_medium hubcap-add-game";
        btn.href = "#";
        btn.innerHTML = "<span>Add game</span>";

        try {
            const check = await fetch(`http://127.0.0.1:27060/check/${appId}`);
            if (check.ok) {
                setButtonMode(btn, "remove");
            } else {
                setButtonMode(btn, "add");
            }
        } catch {
            setButtonMode(btn, "add");
        }

        container.appendChild(btn);

        const limitEl = document.createElement("div");
        limitEl.style.cssText = "display:inline-flex;align-items:center;gap:6px;margin-left:12px;font-family:Arial,sans-serif;font-size:13px;color:#c6d4df;vertical-align:middle;";
        limitEl.innerHTML = `<span style="color:#8f98a0;">Daily limit:</span> <span class="hubcap-limit-text" style="color:#8f98a0;">...</span>`;
        container.appendChild(limitEl);

        await refreshLimit();
    }

    injectButton();
})();
