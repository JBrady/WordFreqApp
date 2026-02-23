import os


def _as_int(name: str, default: int) -> int:
    raw = defines.get(name, default)
    try:
        return int(raw)
    except Exception:
        return int(default)


application = "WordFreqApp.app"

app_name = os.path.basename(application)
volume_name = defines.get("volume_name", defines.get("volume", "WordFreqApp"))

window_x = 100
window_y = 100
window_w = _as_int("window_w", _as_int("DMG_WINDOW_W", 700))
window_h = _as_int("window_h", _as_int("DMG_WINDOW_H", 440))

app_x = _as_int("app_x", _as_int("DMG_APP_X", 250))
app_y = _as_int("app_y", _as_int("DMG_APP_Y", 250))
apps_x = _as_int("apps_x", _as_int("DMG_APPS_X", 450))
apps_y = _as_int("apps_y", _as_int("DMG_APPS_Y", 250))

icon_size = _as_int("icon_size", 128)
text_size = _as_int("text_size", 12)

format = "UDZO"
filesystem = "HFS+"

files = [application]
symlinks = {"Applications": "/Applications"}

window_rect = ((window_x, window_y), (window_w, window_h))

default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_sidebar = False
show_pathbar = False

icon_locations = {
    app_name: (app_x, app_y),
    "Applications": (apps_x, apps_y),
}

arrange_by = None
include_icon_view_settings = "auto"
include_list_view_settings = "auto"

existing_hide = globals().get("hide", [])
if isinstance(existing_hide, tuple):
    existing_hide = list(existing_hide)
elif not isinstance(existing_hide, list):
    existing_hide = [existing_hide] if existing_hide else []
hide = list(existing_hide)
for hidden_name in [".DS_Store"]:
    if hidden_name not in hide:
        hide.append(hidden_name)

grid_offset = (0, 0)
grid_spacing = 100
label_pos = "bottom"

icon_size = icon_size
text_size = text_size
