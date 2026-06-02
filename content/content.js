
const appId = window.location.href.match(/\/app\/(\d+)/)?.[1];
const btn = document.createElement("a");
btn.className = "btnv6_blue_hoverfade btn_medium";
btn.href = "#";
btn.innerHTML = "<span>Add game</span>";
btn.onclick = (e) => {
    e.preventDefault();
    fetch("http://localhost:3000/" + appId, { method: "POST" }).then(r => {
        if (r.ok) {
            window.alert("Game added!");
        } else {
            window.alert("Error adding game!");
        }
    });
};
document.querySelector(".apphub_OtherSiteInfo").appendChild(btn);