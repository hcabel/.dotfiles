//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

// The lock screen: the same LoginSurface, driven by PAM instead of greetd.
//
// This is a real lock, not an overlay — WlSessionLock speaks
// ext-session-lock-v1, so the compositor keeps the session covered even if this
// process dies, and there is no window-stacking trick to defeat.
//
// The point of sharing LoginSurface with greeter.qml is that the login and lock
// screens can't drift apart: there is one design, and two backends for it.
ShellRoot {
    id: rootScope

    property string statusText: ""
    property bool failed: false
    property bool busy: false
    property Item form: null

    readonly property string username: Quickshell.env("USER") || "hcabel"

    function submit(answer) {
        if (rootScope.busy)
            return;
        rootScope.failed = false;
        rootScope.busy = true;

        if (!pam.active) {
            if (!pam.start()) {
                rootScope.busy = false;
                rootScope.failed = true;
                rootScope.statusText = "could not start pam";
                return;
            }
        }
        // PAM asks for the secret through onMessage; hold it until then.
        rootScope.pendingAnswer = answer;
    }

    property string pendingAnswer: ""

    PamContext {
        id: pam

        // Matches security.pam.services.saturn-lock in modules/nixos/login.nix.
        // Without a config of our own PAM would fall back to the tty `login`
        // stack, which authenticates but won't unlock the keyring on resume.
        config: "saturn-lock"
        configDirectory: "/etc/pam.d"
        user: rootScope.username

        onPamMessage: {
            rootScope.statusText = pam.message ? pam.message.trim() : "";
            rootScope.failed = pam.messageIsError;

            if (!pam.responseRequired)
                return;

            if (rootScope.form)
                rootScope.form.echoAnswer = pam.responseVisible;

            pam.respond(rootScope.pendingAnswer);
        }

        onCompleted: result => {
            rootScope.busy = false;
            rootScope.pendingAnswer = "";

            if (result === PamResult.Success) {
                lock.locked = false;
                return;
            }

            rootScope.failed = true;
            rootScope.statusText = result === PamResult.MaxTries ? "too many attempts" : "authentication failed";
            if (rootScope.form) {
                rootScope.form.reset();
                rootScope.form.focusInput();
            }
        }

        onError: err => {
            rootScope.busy = false;
            rootScope.failed = true;
            rootScope.pendingAnswer = "";
            rootScope.statusText = "pam error: " + PamError.toString(err);
            if (rootScope.form)
                rootScope.form.reset();
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        // The compositor tears the surfaces down once unlocked; there is nothing
        // left for this process to do, and leaving it running would hold a
        // second lock client ready to grab the next lock request.
        onLockedChanged: if (!locked)
            Qt.quit()

        WlSessionLockSurface {
            id: surface

            readonly property bool isPrimary: surface.screen === Quickshell.screens[0]

            // Matches the greeter: the palette's deepest background, not black,
            // so a dropped frame doesn't read as the screen going out.
            color: Theme.base

            LoginSurface {
                anchors.fill: parent

                username: surface.isPrimary ? rootScope.username : ""
                statusText: surface.isPrimary ? rootScope.statusText : ""
                failed: surface.isPrimary && rootScope.failed
                busy: !surface.isPrimary || rootScope.busy

                onSubmitted: answer => {
                    if (surface.isPrimary)
                        rootScope.submit(answer);
                }

                Component.onCompleted: {
                    if (!surface.isPrimary)
                        return;
                    rootScope.form = this;
                    focusInput();
                }
            }
        }
    }
}
