# dmgbuild settings for the SuperDock DMG window. Used by scripts/release.sh:
#   dmgbuild -s packaging/dmg/settings.py -D app=<path to SuperDock.app> -D background=<tiff> "SuperDock" out.dmg
# dmgbuild writes Finder's .DS_Store layout directly, so no Finder scripting (and no Automation prompt) is needed.
import os

app = defines["app"]  # noqa: F821  (injected by dmgbuild)
format = "UDZO"
compression_level = 9
size = None
files = [app]
symlinks = {"Applications": "/Applications"}
badge_icon = None
hide_extensions = [os.path.basename(app)]   # show "SuperDock", not "SuperDock.app"

icon_locations = {
    os.path.basename(app): (170, 215),   # keep in sync with make-background.swift
    "Applications": (490, 215),
}

background = defines["background"]  # noqa: F821
window_rect = ((200, 140), (660, 420))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
icon_size = 112
text_size = 13
arrange_by = None
include_icon_view_settings = True
