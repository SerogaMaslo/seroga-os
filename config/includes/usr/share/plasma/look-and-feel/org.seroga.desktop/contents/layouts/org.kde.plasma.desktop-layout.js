// Seroga OS darbvirsmas izkārtojums — Windows 11 stils:
// apakšējā josla, Start poga un lietotnes centrā, sistēmas tekne labajā pusē.

var panel = new Panel;
panel.location = "bottom";
panel.height = Math.round(gridUnit * 2.6);
panel.alignment = "center";
panel.floating = false;

panel.addWidget("org.kde.plasma.panelspacer");

var start = panel.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "/usr/share/seroga/seroga-start.svg");
start.writeConfig("favoritesDisplay", 0);
start.writeConfig("favorites", [
    "applications:seroga-faili.desktop",
    "applications:firefox.desktop",
    "applications:seroga-centrs.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
]);

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:seroga-faili.desktop",
    "applications:firefox.desktop",
    "applications:seroga-centrs.desktop"
]);
tasks.writeConfig("iconSpacing", 2);

panel.addWidget("org.kde.plasma.panelspacer");

panel.addWidget("org.kde.plasma.systemtray");

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "shortDate");

panel.addWidget("org.kde.plasma.showdesktop");

// Tapete
desktops().forEach(function (d) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/seroga-os.svg");
});
