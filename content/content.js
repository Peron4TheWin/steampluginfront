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

    async function addGame(id, btn) {
        const r = await fetch(`http://127.0.0.1:3000/${id}`, {
            method: "POST"
        });

        if (r.ok) {
            showToast("Game added!");
            setButtonMode(btn, "remove");
            return;
        }

        if (r.status === 401) {
            const askKey = async (key) => {
                const keyRes = await fetch("http://127.0.0.1:3000/key", {
                    method: "POST",
                    body: key
                });

                if (keyRes.ok) {
                    const retry = await fetch(`http://127.0.0.1:3000/${id}`, {
                        method: "POST"
                    });

                    if (retry.ok) {
                        showToast("Game added!");
                        setButtonMode(btn, "remove");
                    } else {
                        showToast("Error: " + await retry.text(), true);
                    }
                } else {
                    showToast("Key inválida: " + await keyRes.text(), true);
                    showKeyModal(askKey);
                }
            };

            showKeyModal(askKey);
            return;
        }

        showToast("Error " + r.status + ": " + await r.text(), true);
    }

    async function removeGame(id, btn) {
        const r = await fetch(`http://127.0.0.1:3000/remove/${id}`, {
            method: "DELETE"
        });

        if (r.ok) {
            showToast("Game removed!");
            setButtonMode(btn, "add");
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
        } else {
            btn.querySelector("span").textContent = "Add game";
            btn.onclick = (e) => {
                e.preventDefault();
                addGame(appId, btn);
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

    async function injectButton() {
        const container = document.querySelector(".apphub_OtherSiteInfo");
        if (!container) return;
        if (container.querySelector(".hubcap-add-game")) return;

        const btn = document.createElement("a");
        btn.className = "btnv6_blue_hoverfade btn_medium hubcap-add-game";
        btn.href = "#";
        btn.innerHTML = "<span>Add game</span>";

        // Check si ya está instalado antes de mostrar el botón
        try {
            const check = await fetch(`http://127.0.0.1:3000/check/${appId}`);
            if (check.ok) {
                setButtonMode(btn, "remove");
            } else {
                // Si el check falla, default a add
                setButtonMode(btn, "add");
            }
        } catch {
            setButtonMode(btn, "add");
        }

        container.appendChild(btn);
    }

    injectButton();
})();
