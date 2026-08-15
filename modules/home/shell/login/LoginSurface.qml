pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower

// The login screen, as drawn in the design doc's "editorial" variant: an
// off-axis left column over the wallpaper, with the rings left visible on the
// right. This is the same column the boot splash uses, so the handover from
// splash to greeter doesn't move anything on screen.
//
// This component knows nothing about authentication. It renders state and
// reports keystrokes; greeter.qml drives it through greetd and lock.qml drives
// it through PAM. That's the whole reason it's a separate file — one design,
// two backends.
Item {
    id: root

    // ── driven by the wrapper ───────────────────────────────────────────────
    property string username: ""
    property string sessionName: "hyprland"
    property string keymap: "us"

    // Message under the input: whatever PAM or greetd last said, verbatim. The
    // wrappers pass it through unfiltered and this component decides what is
    // worth showing.
    property string statusText: ""
    property bool failed: false

    // PAM opens every conversation with "Password:", which says nothing a
    // password field doesn't already say. Errors and anything unusual (a
    // keyring prompt, an expiry warning) still come through.
    readonly property string displayStatus: failed || !/^\s*password:?\s*$/i.test(statusText) ? statusText : ""

    // While authenticating, input is frozen and the caret stops blinking.
    property bool busy: false

    // PAM occasionally asks something that should be typed in the clear.
    property bool echoAnswer: false

    readonly property string answer: input.text

    signal submitted(string answer)

    function reset() {
        input.clear();
    }
    function focusInput() {
        input.forceActiveFocus();
    }

    // ── geometry from the design, as fractions of 1920x1080 ─────────────────
    readonly property real columnX: width * 0.0677 // 130px
    readonly property real columnWidth: Math.min(width * 0.35, 620)

    // ── background ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.base
    }

    Image {
        anchors.fill: parent
        source: Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // The wallpaper is 4K; without this Qt decodes it at full size on every
        // screen, which is visible as a stall on the greeter.
        sourceSize.width: root.width
        sourceSize.height: root.height
    }

    // The veil. The design darkens hard on the left and releases by about two
    // thirds across, which is what keeps white text legible over a bright sky
    // without hiding the rings.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Theme.alpha(Theme.base, 0.90)
            }
            GradientStop {
                position: 0.38
                color: Theme.alpha(Theme.base, 0.60)
            }
            GradientStop {
                position: 0.68
                color: Theme.alpha(Theme.base, 0.05)
            }
            GradientStop {
                position: 1.0
                color: Theme.alpha(Theme.base, 0.05)
            }
        }
    }

    // ── the column ──────────────────────────────────────────────────────────
    Column {
        x: root.columnX
        width: root.columnWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // Monogram · rule · hostname
        Row {
            spacing: 14
            height: 48

            Image {
                source: Theme.logo
                width: 58
                height: 48
                sourceSize.width: 116
                sourceSize.height: 96
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 1
                height: 34
                color: Theme.alpha(Theme.text, 0.16)
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: Theme.name.toUpperCase()
                color: Theme.alpha(Theme.text, 0.55)
                font.family: Theme.monoFont
                font.pixelSize: 11
                font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            width: 1
            height: 56
        }

        // The clock. Light and tight, the design's dominant element.
        Text {
            id: clock
            text: Qt.formatDateTime(clockTick.now, "HH:mm")
            color: Theme.text
            font.family: Theme.monoFont
            font.pixelSize: 104
            font.weight: Font.Light
            font.letterSpacing: -4
            lineHeight: 1.0
        }

        Item {
            width: 1
            height: 12
        }

        Text {
            text: {
                const d = Qt.formatDateTime(clockTick.now, "dddd d MMMM").toLowerCase();
                let line = d;
                if (SystemInfo.nixosRelease)
                    line += " · nixos " + SystemInfo.nixosRelease;
                if (SystemInfo.generation > 0)
                    line += " · gen " + SystemInfo.generation;
                return line;
            }
            color: Theme.alpha(Theme.text, 0.55)
            font.family: Theme.monoFont
            font.pixelSize: 14
            font.letterSpacing: 2
        }

        Item {
            width: 1
            height: 64
        }

        // Username · answer field
        Row {
            width: parent.width
            spacing: 14

            Text {
                id: usernameLabel
                text: root.username
                color: Theme.alpha(Theme.text, 0.90)
                font.family: Theme.monoFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                // Derived from the siblings rather than from this item's own x,
                // which the Row is still assigning at binding time.
                width: parent.width - usernameLabel.width - parent.spacing
                height: 56
                radius: 16
                color: Theme.alpha(Theme.base, 0.55)
                border.width: 1
                border.color: root.failed ? Theme.alpha(Theme.error, 0.55) : Theme.alpha(Theme.text, 0.10)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on border.color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                // The real input, never drawn. The design shows dots, so the
                // text itself is invisible and the dots below mirror its length.
                TextInput {
                    id: input
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    enabled: !root.busy
                    echoMode: TextInput.NoEcho
                    activeFocusOnTab: true
                    onAccepted: root.submitted(text)
                    onTextChanged: root.failed = false
                }

                Row {
                    id: dots
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.right: hint.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        // Capped so a long passphrase can't overflow the pill.
                        model: Math.min(input.text.length, 24)
                        delegate: Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.alpha(Theme.text, 0.78)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Visible answer, for the rare PAM prompt that wants one.
                    Text {
                        visible: root.echoAnswer
                        text: input.text
                        color: Theme.alpha(Theme.text, 0.85)
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 2
                        height: 19
                        color: Theme.accentAlt
                        anchors.verticalCenter: parent.verticalCenter

                        // The blink lives on its own property so that stopping
                        // it while authenticating leaves the caret solid,
                        // rather than frozen at whatever the animation had last
                        // written to opacity.
                        property real blink: 1
                        opacity: root.busy ? 1 : blink

                        SequentialAnimation on blink {
                            running: !root.busy
                            loops: Animation.Infinite
                            // Steps, not a fade — the design's caret is a hard
                            // blink.
                            PropertyAnimation {
                                to: 1
                                duration: 0
                            }
                            PauseAnimation {
                                duration: 550
                            }
                            PropertyAnimation {
                                to: 0
                                duration: 0
                            }
                            PauseAnimation {
                                duration: 550
                            }
                        }
                    }
                }

                Text {
                    id: hint
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.busy ? "…" : "↵ unlock"
                    color: Theme.alpha(Theme.text, 0.35)
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
            }
        }

        Item {
            width: 1
            height: 26
        }

        // Session and layout chips
        Row {
            spacing: 10

            Rectangle {
                height: 30
                width: sessionLabel.width + 8 + 5 + 24
                radius: 10
                color: Theme.alpha(Theme.accent, 0.16)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.30)

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: sessionLabel
                        text: root.sessionName
                        color: Theme.alpha(Theme.accent, 1.0)
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Repeater {
                model: [`F1 session`, `F2 ${root.keymap}`]
                delegate: Rectangle {
                    required property string modelData
                    height: 30
                    width: chipText.width + 24
                    radius: 10
                    color: Theme.alpha(Theme.text, 0.05)

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Theme.alpha(Theme.text, 0.50)
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                    }
                }
            }
        }

        Item {
            width: 1
            height: 20
        }

        // PAM's prompt, or why the last attempt failed. Reserved height so the
        // column above doesn't jump when a message appears.
        Text {
            width: parent.width
            height: 16
            text: root.displayStatus
            color: root.failed ? Theme.error : Theme.alpha(Theme.text, 0.50)
            font.family: Theme.monoFont
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    // ── footer ──────────────────────────────────────────────────────────────
    // The design also shows a network state here. That's left out rather than
    // faked: reading it means NetworkManager over D-Bus, which is a lot of
    // plumbing for one decorative word on a screen shown for five seconds.
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 60
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        text: {
            const bat = UPower.displayDevice;
            const parts = [];
            if (bat && bat.isLaptopBattery)
                parts.push("bat " + Math.round(bat.percentage * 100) + "%");
            parts.push("ctrl+alt+F2 tty");
            return parts.join("  ·  ");
        }
        color: Theme.alpha(Theme.text, 0.45)
        font.family: Theme.monoFont
        font.pixelSize: 11
    }

    // One timer for every clock binding on screen.
    Timer {
        id: clockTick
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: now = new Date()
    }
}
