// Frag95 — Windows 9x desktop layout.
// A single bottom "taskbar": classic Start menu (kicker), task list with
// labels, system tray, and a clock. The desktop is solid teal.

var panel = new Panel
panel.location = "bottom"
panel.height = Math.round(gridUnit * 1.6)
// Win9x taskbar is anchored to the edge, not a floating bar.
panel.floating = false

// Start menu — org.kde.plasma.kicker is the classic cascading Application Menu
// (as opposed to the modern full-screen Kickoff). Give it the Win95 "Start"
// button image, and curate its favorites to installed apps (the Plasma default
// favorites pin Discover etc., which aren't installed and error when clicked).
var kicker = panel.addWidget("org.kde.plasma.kicker")
kicker.currentConfigGroup = ["General"]
kicker.writeConfig("useCustomButtonImage", true)
kicker.writeConfig("customButtonImage", "/usr/share/frag95/start-button.png")
kicker.writeConfig("favoritesPortedToKAstats", false)
kicker.writeConfig("favorites", [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:steam.desktop",
    "applications:octopi.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
].join(","))

// "Show desktop" button next to Start, 9x-style.
panel.addWidget("org.kde.plasma.showdesktop")

// Task list with text labels (the Win9x taskbar look), takes the slack space.
panel.addWidget("org.kde.plasma.taskmanager")

// Push the tray + clock to the right.
panel.addWidget("org.kde.plasma.marginsseparator")

// System tray and a digital clock in the notification area.
panel.addWidget("org.kde.plasma.systemtray")
panel.addWidget("org.kde.plasma.digitalclock")

// Solid teal desktop (#008080) on every screen/desktop — the 9x signature.
var allDesktops = desktops()
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i]
    d.wallpaperPlugin = "org.kde.color"
    d.currentConfigGroup = ["Wallpaper", "org.kde.color", "General"]
    d.writeConfig("Color", "0,128,128")
}
