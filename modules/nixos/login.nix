{
  config,
  lib,
  pkgs,
  builtTheme,
  ...
}:

# The login and lock screens.
#
# Both are the same QML component (modules/home/shell/login), one driven by
# greetd and one by PAM through ext-session-lock-v1. DMS's greeter is not used:
# its layout is fixed — centred avatar, name, input — and only its colours are
# configurable, so it could never be the design's off-axis editorial screen.
#
# Because the greeter reads the theme straight out of /nix/store there is none
# of the copying dms-greeter needs: no /var/lib staging, no configHome, no
# group membership or ACLs on the user's home directory.

let
  user = "hcabel";

  # builtTheme comes from modules/nixos/theme.nix.

  # The QML, as a store path. Copied rather than referenced from the working
  # tree so the greeter keeps working while the repo is being edited — a syntax
  # error mid-edit must not be able to break logging in.
  #
  # preview.qml is left out: it's the harness for looking at LoginSurface on a
  # running desktop and has no business on the login screen.
  loginShell = pkgs.runCommand "saturn-login-shell" { } ''
    mkdir -p "$out"
    for f in ${../home/shell/login}/*.qml; do
      case "$(basename "$f")" in
        preview.qml) continue ;;
      esac
      cp "$f" "$out/"
    done
  '';

  quickshell = config.programs.dms-shell.quickshell.package;

  # greetd runs one command, and quickshell needs a compositor to be a client
  # of, so that command is a throwaway Hyprland whose only job is to host the
  # greeter and exit with it. Same shape as the wrapper dms-greeter ships.
  greeterCompositorConfig = pkgs.writeText "saturn-greeter-hyprland.conf" ''
    # Nothing but the greeter runs in here.
    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
      force_default_wallpaper = 0
      background_color = rgb(05070a)
    }

    animations {
      enabled = false
    }

    # Quitting the compositor when the greeter exits is what lets greetd move on
    # to the session.
    exec-once = sh -c "${lib.getExe' quickshell "quickshell"} -p ${loginShell}/greeter.qml; hyprctl dispatch exit"
  '';

  greeterScript = pkgs.writeShellApplication {
    name = "saturn-greeter";
    runtimeInputs = [
      config.programs.hyprland.package
      quickshell
      # The greeter dismisses the splash itself. This has to be the same build
      # as the running daemon — the module's default is an override of
      # pkgs.plymouth against the initrd's systemd, so pkgs.plymouth is a
      # different derivation.
      config.boot.plymouth.package
    ];
    text = ''
      export XDG_SESSION_TYPE=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_QPA_PLATFORM=wayland

      # The greeter runs as the `greeter` user, which has no home worth writing
      # to; point Qt and quickshell at a scratch dir so neither warns nor tries
      # to persist anything.
      runtime="''${XDG_RUNTIME_DIR:-/tmp}/saturn-greeter"
      mkdir -p "$runtime"
      export XDG_CACHE_HOME="$runtime/cache"
      export XDG_STATE_HOME="$runtime/state"
      export XDG_DATA_HOME="$runtime/data"

      # Read-only, world-readable, and fixed at build time: the greeter runs
      # before any theme has been switched at runtime, so it cannot follow the
      # `current` symlink the way the lock screen does.
      export SATURN_THEME_DIR=${builtTheme}
      export SATURN_LOGIN_USER=${user}

      # An absolute path, and a single argv element. The session command used to
      # be passed as a string for the greeter to hand to `sh -lc`, which meant
      # the QML had to know how to spell a shell invocation and greetd had to
      # resolve `sh` out of an environment that has no PATH worth speaking of.
      # The launcher owns both of those now.
      export SATURN_SESSION_LAUNCHER=${lib.getExe sessionLauncher}

      # start-hyprland rather than Hyprland: launched directly, Hyprland draws a
      # red "started without start-hyprland" warning across the top of the
      # greeter. Same invocation DMS's own greeter script uses.
      #
      # Its watchdog only relaunches Hyprland when it exits *un*cleanly, so the
      # `hyprctl dispatch exit` above still ends the greeter and lets greetd move
      # on to the session rather than looping back to the login screen.
      exec start-hyprland -- --config ${greeterCompositorConfig}
    '';
  };

  # uwsm is how programs.hyprland is set up here (withUWSM), so the session has
  # to be started through it or it gets no systemd targets — which is what DMS's
  # user service binds to.
  sessionCommand = "uwsm start hyprland-uwsm.desktop";

  # What greetd actually execs when authentication succeeds.
  #
  # greetd points the session's stdin/stdout/stderr at the VT, not at its own
  # journal stream. So when the session command fails, its error is written to
  # tty1 and then wiped the instant the greeter restarts — the login bounces
  # back with the failure recorded precisely nowhere. That is what made this
  # undebuggable, so the launcher exists to close it.
  #
  # systemd-cat is the right tool because it *execs* its argument rather than
  # forking: the process greetd waits on is still the shell, so uwsm keeps the
  # session-leader PID it binds the session lifetime to
  # (wayland-session-bindpid@$PID) and still receives the signals its own
  # handler installs. Only the two file descriptors change.
  #
  # The login shell is kept deliberately: uwsm needs a full system PATH (it
  # shells out to systemctl, systemd-cat and sh by name), and sourcing
  # /etc/profile is what supplies it. greetd's own environment has almost
  # nothing in it.
  sessionLauncher = pkgs.writeShellApplication {
    name = "saturn-session";
    text = ''
      exec ${lib.getExe' config.systemd.package "systemd-cat"} \
        --identifier=saturn-session --stderr-priority=warning -- \
        ${lib.getExe pkgs.bash} -lc ${lib.escapeShellArg "exec ${sessionCommand}"}
    '';
  };

in
{
  services.greetd = {
    enable = true;

    # Do not order greetd after plymouth-quit-wait. Left at the default, greetd
    # waits for plymouth to fully tear down — the screen goes black, and only
    # then does the compositor start and the greeter paint. greeter.qml instead
    # runs `plymouth quit --retain-splash` once it has painted its first frame,
    # so the splash image stays in the framebuffer right up to the handover.
    greeterManagesPlymouth = true;

    settings.default_session.command = lib.getExe greeterScript;
  };

  # greetd's own `greeter` user is created with no supplementary groups, unlike
  # the dedicated user dms-greeter made for itself. logind does hand a session
  # on tty1 the DRM and input ACLs it needs, but the compositor is the one thing
  # here that fails closed — a greeter that can't open the GPU is an unbootable
  # desktop — so this matches what dms-greeter was doing rather than relying on
  # the ACLs alone.
  users.users.greeter.extraGroups = [
    "video"
    "input"
  ];
  services.libinput.enable = lib.mkDefault true;

  # The lock screen's PAM stack. Referenced by name from lock.qml; without it
  # PamContext falls back to /etc/pam.d/login, which is built for a tty and
  # won't unlock the keyring on resume.
  security.pam.services.saturn-lock.enableGnomeKeyring = true;

  # `saturn-lock` is the command hypridle and the power menu call. It lives here
  # rather than in home-manager so the greeter and the lock resolve the exact
  # same QML store path.
  #
  # saturn-session is the greeter's session launcher, exposed so the exact
  # command greetd runs can be run by hand from a spare VT — which is the only
  # way to watch a session start without a login screen in the way.
  environment.systemPackages = [
    sessionLauncher
    (pkgs.writeShellApplication {
      name = "saturn-lock";
      runtimeInputs = [ quickshell ];
      text = ''
        # Already locked — a second lock client would just fail to bind.
        if pgrep -f 'quickshell.*lock\.qml' >/dev/null 2>&1; then
          exit 0
        fi
        # Unlike the greeter, this follows the live theme symlink, so `theme set`
        # re-themes the lock screen with no rebuild.
        export SATURN_THEME_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/theme/current"
        exec quickshell -p ${loginShell}/lock.qml
      '';
    })
  ];
}
