//@ pragma UseQApplication

import QtQuick
import Quickshell

// A plain window showing LoginSurface with nothing wired to it, so the design
// can be checked and iterated on a live desktop without going anywhere near
// greetd or a session lock. Not installed — run it from the repo:
//
//   SATURN_THEME_DIR=~/.local/state/theme/current \
//     quickshell -p modules/home/shell/login/preview.qml
ShellRoot {
    FloatingWindow {
        implicitWidth: 1920
        implicitHeight: 1080
        color: "black"

        LoginSurface {
            anchors.fill: parent
            username: "hugo"
            sessionName: "hyprland"
            statusText: ""
            onSubmitted: answer => {
                statusText = "submitted " + answer.length + " characters";
                reset();
            }
        }
    }
}
