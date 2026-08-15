//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

// The greetd greeter: LoginSurface driven by greetd's auth conversation.
//
// greetd relays a PAM conversation over a socket, so the flow is
// createSession → (authMessage … respond)* → readyToLaunch → launch. Every
// message greetd sends is shown on the surface rather than assumed to be
// "Password", which is why the surface takes a statusText.
ShellRoot {
    id: rootScope

    // One user ever logs into this machine and the design has no user picker,
    // so there isn't one here either.
    readonly property string username: Quickshell.env("SATURN_LOGIN_USER") || "hcabel"

    // Absolute path to the program greetd execs on success — see the launcher in
    // modules/nixos/login.nix, which is what makes a failed session launch show
    // up in the journal instead of vanishing with the VT. Empty when this file is
    // run by hand rather than by the greeter script, in which case the fallback
    // below applies.
    readonly property string sessionLauncher: Quickshell.env("SATURN_SESSION_LAUNCHER") || ""

    property string statusText: ""
    property bool failed: false
    property bool busy: false

    // Assigned by the primary screen's surface once it exists, so the auth
    // handlers below can read the typed answer and clear it. The surface is
    // created inside a Variants delegate and can't be reached by id from here.
    property Item form: null

    // What we last had typed, held because greetd asks for the password in a
    // callback rather than accepting it up front.
    property string pendingAnswer: ""

    // ── plymouth handoff ────────────────────────────────────────────────────
    // greetd was told not to wait for plymouth's teardown
    // (services.greetd.greeterManagesPlymouth), and plymouth-quit.service is
    // overridden to retain the splash, so the framebuffer keeps the splash
    // image whichever of the two fires first. This call is the second of those
    // two paths: harmless if plymouth is already gone, and it means the greeter
    // is not relying on a unit it doesn't own to get the flags right.
    property bool plymouthDismissed: false

    function dismissPlymouth() {
        if (rootScope.plymouthDismissed)
            return;
        rootScope.plymouthDismissed = true;
        plymouthQuit.running = true;
    }

    Process {
        id: plymouthQuit
        command: ["plymouth", "quit", "--retain-splash"]
    }

    // ── auth ────────────────────────────────────────────────────────────────
    function submit(answer) {
        if (rootScope.busy)
            return;
        rootScope.pendingAnswer = answer;
        rootScope.failed = false;
        rootScope.busy = true;

        if (Greetd.state === GreetdState.Inactive)
            Greetd.createSession(rootScope.username);
        else
            Greetd.respond(answer);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            rootScope.failed = error;
            rootScope.statusText = message ? message.trim() : "";

            if (!responseRequired) {
                // Informational only. Acknowledge and let the conversation move
                // on, otherwise greetd sits waiting forever.
                Greetd.respond("");
                return;
            }

            if (rootScope.form)
                rootScope.form.echoAnswer = echoResponse;

            // greetd is asking for exactly the secret already typed.
            Greetd.respond(rootScope.pendingAnswer);
        }

        function onAuthFailure(message) {
            rootScope.busy = false;
            rootScope.failed = true;
            rootScope.pendingAnswer = "";
            rootScope.statusText = message ? message.trim() : "authentication failed";
            if (rootScope.form) {
                rootScope.form.reset();
                rootScope.form.focusInput();
            }
            // greetd requires the failed session to be torn down before another
            // createSession is accepted.
            Greetd.cancelSession();
        }

        function onReadyToLaunch() {
            rootScope.statusText = "starting session…";
            rootScope.pendingAnswer = "";

            // The empty environment list is not an oversight: greetd builds the
            // session's environment from PAM itself, and anything passed here
            // would be the *greeter's* environment leaking into the user's
            // session. The launcher is a single absolute path for the same
            // reason — greetd resolves argv[0] with almost no PATH.
            Greetd.launch(rootScope.sessionLauncher ? [rootScope.sessionLauncher] : ["sh", "-lc", "uwsm start hyprland-uwsm.desktop"], [], true);
        }

        function onError(error) {
            rootScope.busy = false;
            rootScope.failed = true;
            rootScope.pendingAnswer = "";
            rootScope.statusText = error ? String(error) : "greetd error";
            if (rootScope.form)
                rootScope.form.reset();
        }
    }

    // ── surfaces ────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            readonly property bool isPrimary: modelData === Quickshell.screens[0]

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            // The palette's deepest background rather than black, so the one
            // frame before the wallpaper decodes matches what the splash and the
            // greeter's compositor are already showing.
            color: Theme.base

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            // Only the primary screen gets the form. The others carry the
            // wallpaper alone, so there's never a question of which of three
            // password fields has focus.
            LoginSurface {
                anchors.fill: parent

                username: win.isPrimary ? rootScope.username : ""
                statusText: win.isPrimary ? rootScope.statusText : ""
                failed: win.isPrimary && rootScope.failed
                busy: !win.isPrimary || rootScope.busy

                onSubmitted: answer => {
                    if (win.isPrimary)
                        rootScope.submit(answer);
                }

                Component.onCompleted: {
                    if (!win.isPrimary)
                        return;
                    rootScope.form = this;
                    focusInput();
                    // Deferred to the end of this event-loop pass so the scene
                    // is built before plymouth is told to go; the splash is
                    // retained either way, so this only has to be close.
                    Qt.callLater(rootScope.dismissPlymouth);
                }
            }
        }
    }
}
