pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The active theme, as data.
//
// SATURN_THEME_DIR points at a theme directory built by
// modules/home/theme/build.nix. The greeter is given a fixed store path (it
// runs before anything has been switched); the lock screen is given
// ~/.local/state/theme/current, so `theme set` re-themes it live — FileView is
// watching, and every colour below is a binding.
Singleton {
    id: root

    readonly property string themeDir: Quickshell.env("SATURN_THEME_DIR") || ""
    readonly property string wallpaper: themeDir ? themeDir + "/wallpaper.jpg" : ""
    readonly property string logo: themeDir ? themeDir + "/logo.svg" : ""

    // Defaults are the saturn palette, so a missing or unreadable theme file
    // degrades to something legible rather than to black-on-black.
    readonly property var _d: ({
            name: "saturn",
            polarity: "dark",
            colors: {
                base: "#05070a",
                surface: "#18162c",
                overlay: "#241f38",
                muted: "#565a7a",
                subtle: "#a9b4d6",
                text: "#ffffff",
                accent: "#7aa2f7",
                accentAlt: "#f28fad",
                red: "#f7768e",
                green: "#7bd88f",
                cyan: "#7dd3c0",
                magenta: "#a78bfa"
            },
            fonts: {
                mono: "monospace",
                sans: "sans-serif",
                size: 10
            },
            rounding: 14,
            panelOpacity: 0.62
        })

    property var data: root._d

    readonly property color base: data.colors.base
    readonly property color surface: data.colors.surface
    readonly property color overlay: data.colors.overlay
    readonly property color muted: data.colors.muted
    readonly property color subtle: data.colors.subtle
    readonly property color text: data.colors.text
    readonly property color accent: data.colors.accent
    readonly property color accentAlt: data.colors.accentAlt
    readonly property color error: data.colors.red

    readonly property string name: data.name || "saturn"
    readonly property string monoFont: data.fonts.mono
    readonly property string sansFont: data.fonts.sans
    readonly property int rounding: data.rounding
    readonly property real panelOpacity: data.panelOpacity

    // Alpha helper — the design specifies most of its surfaces as white or
    // accent at some low opacity rather than as opaque colours.
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    FileView {
        path: root.themeDir ? root.themeDir + "/login-theme.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                // Merge over the defaults so a theme that omits a key, or an
                // older generated file, still yields every colour.
                root.data = Object.assign({}, root._d, parsed, {
                    colors: Object.assign({}, root._d.colors, parsed.colors || {}),
                    fonts: Object.assign({}, root._d.fonts, parsed.fonts || {})
                });
            } catch (e) {
                console.warn("login theme: could not parse login-theme.json:", e);
                root.data = root._d;
            }
        }
        onLoadFailed: {
            console.warn("login theme: could not read", path, "- using defaults");
            root.data = root._d;
        }
    }
}
