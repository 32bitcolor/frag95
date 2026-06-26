// Frag95 system-wide Firefox defaults.
//
// Use the system titlebar so Firefox windows get the Win95 (kwin Aurorae)
// decoration instead of Firefox's own dark CSD titlebar. NOTE: Firefox's INNER
// chrome (tab bar, toolbar, buttons, New Tab page) is drawn by Firefox itself
// and cannot be themed by the OS/GTK/Qt — making that Win95 needs a Firefox
// add-on/theme (one click from about:addons), so we don't ship it here.
pref("browser.tabs.inTitlebar", 0);
