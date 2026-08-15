pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The facts the design's date line quotes: NixOS version and the generation
// number. Both are readable without privileges, and both are read once —
// neither can change while a login or lock screen is on screen.
Singleton {
    id: root

    property string nixosVersion: ""
    property int generation: 0

    // "26.05.20260812.9f78f44" is more than the design's line wants; it shows
    // "nixos 25.05", so take the release prefix only.
    readonly property string nixosRelease: {
        const parts = nixosVersion.split(".");
        return parts.length >= 2 ? parts[0] + "." + parts[1] : nixosVersion;
    }

    FileView {
        path: "/run/current-system/nixos-version"
        onLoaded: root.nixosVersion = text().trim()
        onLoadFailed: root.nixosVersion = ""
    }

    // The generation number only exists as the name of a symlink, so it needs a
    // readlink rather than a file read.
    Process {
        running: true
        command: ["readlink", "/nix/var/nix/profiles/system"]
        stdout: StdioCollector {
            onStreamFinished: {
                // e.g. "system-24-link"
                const m = /system-(\d+)-link/.exec(text.trim());
                if (m)
                    root.generation = parseInt(m[1], 10);
            }
        }
    }
}
