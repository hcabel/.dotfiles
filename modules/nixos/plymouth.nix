{
  config,
  pkgs,
  themeLib,
  themeName,
  themeData,
  builtTheme,
  ...
}:

# The boot splash — the stretch between the bootloader handing off and the
# greeter appearing, which is the "booting" stage in the design doc: the
# monogram over the wallpaper with a thin accent-gradient progress bar.
#
# The splash is baked into the initrd, so unlike everything else here it can't
# follow the runtime theme symlink; it has to commit to one theme at build
# time. It reads the same option the session does rather than restating the
# name, so `hcabel.theme.default` stays the single source of truth and a
# rebuild after changing it re-themes the splash too.
#
# The screen before this one — the generation menu — is GRUB, in
# modules/nixos/bootloader.nix. The two share the same wallpaper, veil and
# left-hand column on purpose, so the boot reads as one screen gaining detail
# rather than three unrelated ones.

let
  # themeName, themeData and builtTheme all come from modules/nixos/theme.nix.
  p = themeData.palette;

  # Plymouth's script language takes colour channels as 0..1 floats.
  rgbFloat =
    colour:
    let
      c = themeLib.hexToRgb colour;
    in
    {
      r = toString (c.r / 255.0);
      g = toString (c.g / 255.0);
      b = toString (c.b / 255.0);
    };

  base = rgbFloat p.base;
  accent = rgbFloat p.accent;

  # Sizes in the script are fractions of the screen rather than the design's
  # 1920x1080 pixel values, so the splash holds up on both the laptop panel
  # and a 4K external.
  script = pkgs.writeText "${themeName}.script" ''
    # Generated from theme "${themeName}" — do not edit.
    # Source: modules/nixos/plymouth.nix

    screen_width = Window.GetWidth();
    screen_height = Window.GetHeight();

    # Anything the images don't cover falls back to the palette's deepest
    # background rather than plymouth's default blue.
    Window.SetBackgroundTopColor(${base.r}, ${base.g}, ${base.b});
    Window.SetBackgroundBottomColor(${base.r}, ${base.g}, ${base.b});

    # ── wallpaper, cover-scaled ──────────────────────────────────────────────
    bg_image = Image("background.png");
    bg_ratio = bg_image.GetWidth() / bg_image.GetHeight();
    screen_ratio = screen_width / screen_height;

    if (screen_ratio > bg_ratio) {
      bg_width = screen_width;
      bg_height = screen_width / bg_ratio;
    } else {
      bg_height = screen_height;
      bg_width = screen_height * bg_ratio;
    }

    bg = Sprite(bg_image.Scale(bg_width, bg_height));
    bg.SetX((screen_width - bg_width) / 2);
    bg.SetY((screen_height - bg_height) / 2);
    bg.SetZ(-100);

    veil = Sprite(Image("veil.png").Scale(screen_width, screen_height));
    veil.SetX(0);
    veil.SetY(0);
    veil.SetZ(-90);

    # The design's boot screen is left-aligned rather than centred — the same
    # editorial column the login screen uses, so the handover from splash to
    # greeter doesn't move anything. 130/1920 of the way in.
    column_x = screen_width * 0.068;

    # ── monogram ─────────────────────────────────────────────────────────────
    logo_width = screen_width * 0.045;
    logo_height = logo_width / 1.2;   # matches the SVG's 120x100 viewBox
    logo = Sprite(Image("logo.png").Scale(logo_width, logo_height));
    logo.SetX(column_x);
    logo.SetY(screen_height * 0.265);
    logo.SetZ(10);

    # ── progress bar ─────────────────────────────────────────────────────────
    bar_width = screen_width * 0.22;
    bar_height = screen_height / 360;
    if (bar_height < 2) {
      bar_height = 2;
    }
    bar_x = column_x;
    bar_y = screen_height * 0.40;

    bar_track = Sprite(Image("bar-track.png").Scale(bar_width, bar_height));
    bar_track.SetX(bar_x);
    bar_track.SetY(bar_y);
    bar_track.SetZ(10);

    bar_fill_image = Image("bar-fill.png");
    bar_fill = Sprite();
    bar_fill.SetX(bar_x);
    bar_fill.SetY(bar_y);
    bar_fill.SetZ(11);

    fun on_boot_progress(duration, progress) {
      fill_width = bar_width * progress;
      # Scaling to zero width would drop the sprite entirely.
      if (fill_width < 2) {
        fill_width = 2;
      }
      bar_fill.SetImage(bar_fill_image.Scale(fill_width, bar_height));
    }
    Plymouth.SetBootProgressFunction(on_boot_progress);

    # ── messages and prompts ─────────────────────────────────────────────────
    # This machine has no encrypted volumes, so the password path is only
    # reached if one is ever added. Kept working rather than left to render
    # nothing, which would be indistinguishable from a hang.
    font = "Sans ${toString themeData.style.fonts.size}";

    fun column_text(sprite, text, y_fraction) {
      text_image = Image.Text(text, ${accent.r}, ${accent.g}, ${accent.b}, 1, font);
      sprite.SetImage(text_image);
      sprite.SetX(column_x);
      sprite.SetY(screen_height * y_fraction);
    }

    message = Sprite();
    message.SetZ(20);

    fun on_message(text) {
      column_text(message, text, 0.45);
    }
    Plymouth.SetMessageFunction(on_message);

    prompt = Sprite();
    prompt.SetZ(20);
    bullets = Sprite();
    bullets.SetZ(20);

    fun on_password(prompt_text, bullet_count) {
      column_text(prompt, prompt_text, 0.45);

      dots = "";
      i = 0;
      while (i < bullet_count) {
        dots = dots + "*";
        i = i + 1;
      }
      column_text(bullets, dots, 0.49);
    }
    Plymouth.SetDisplayPasswordFunction(on_password);

    fun on_normal() {
      prompt.SetOpacity(0);
      bullets.SetOpacity(0);
    }
    Plymouth.SetDisplayNormalFunction(on_normal);

    fun on_quit() {
      bar_track.SetOpacity(0);
      bar_fill.SetOpacity(0);
      message.SetOpacity(0);
    }
    Plymouth.SetQuitFunction(on_quit);
  '';

  # ImageDir and ScriptFile have to be absolute paths, which aren't known until
  # the builder runs — hence the placeholder. The NixOS plymouth module then
  # rewrites any /nix/store/*/share/plymouth/themes prefix to wherever it
  # stages the theme inside the initrd, so naming $out here is correct.
  plymouthMeta = pkgs.writeText "${themeName}.plymouth" ''
    [Plymouth Theme]
    Name=${themeData.name}
    Description=${themeData.description}
    ModuleName=script

    [script]
    ImageDir=@dir@
    ScriptFile=@dir@/${themeName}.script
  '';

  plymouthTheme =
    pkgs.runCommand "plymouth-theme-${themeName}"
      {
        nativeBuildInputs = with pkgs; [
          imagemagick
          librsvg
        ];
      }
      ''
        dir="$out/share/plymouth/themes/${themeName}"
        mkdir -p "$dir"

        # The wallpaper is decompressed out of the initrd on every boot, and
        # the source is 4K — 1080p is plenty for a splash.
        magick ${builtTheme}/wallpaper.jpg \
          -resize 1920x1080^ -gravity center -extent 1920x1080 \
          PNG24:"$dir/background.png"

        # The veil. The design darkens the wallpaper from the left so the
        # left-aligned column reads against it while the rings stay visible on
        # the right. Built as a flat base-colour layer whose alpha is a
        # gradient: the mask is authored vertically and rotated, because
        # ImageMagick's `gradient:` only runs top-to-bottom. -90 puts the
        # opaque end on the left.
        magick -size 1080x1920 xc:'${p.base}' \
          \( -size 1080x1920 gradient:'gray(230)'-'gray(13)' \) \
          -alpha off -compose CopyOpacity -composite \
          -rotate -90 PNG32:"$dir/veil.png"

        # Rasterise the monogram generously; the script scales it down to suit
        # the panel, and scaling down looks far better than scaling up.
        rsvg-convert --width=480 --height=400 \
          --output "$dir/logo.png" ${builtTheme}/logo.svg

        # Progress bar: an unfilled track, and a fill carrying the accent ramp.
        # Both authored wide and scaled by the script.
        magick -size 1600x6 xc:'rgba(255,255,255,0.14)' PNG32:"$dir/bar-track.png"
        # -90 so the ramp runs accent → accentAlt left to right, the direction
        # every gradient in the design runs.
        magick -size 6x1600 gradient:'${p.accent}'-'${p.accentAlt}' \
          -rotate -90 PNG32:"$dir/bar-fill.png"

        cp ${script} "$dir/${themeName}.script"

        substitute ${plymouthMeta} "$dir/${themeName}.plymouth" \
          --replace-fail '@dir@' "$dir"
      '';

in
{
  boot.plymouth = {
    enable = true;
    themePackages = [ plymouthTheme ];
    theme = themeName;
    # Only one font is staged into the initrd, and the script asks for "Sans";
    # make that resolve to the theme's own sans rather than DejaVu.
    font = "${pkgs.inter}/share/fonts/truetype/InterVariable.ttf";
  };

  # The last black screen, and the least obvious one.
  #
  # multi-user.target pulls in plymouth-quit.service, whose ExecStart is a bare
  # `plymouth quit` — it tears the splash down and leaves the framebuffer black.
  # That fires around the same time greetd starts, so the screen blanks in the
  # gap before the greeter's first frame. services.greetd.greeterManagesPlymouth
  # only stops greetd *waiting* for the teardown; it does not stop the teardown
  # from blanking the screen.
  #
  # --retain-splash leaves the last frame in the framebuffer instead. Since the
  # script's quit function fades out the progress bar first, what's retained is
  # the wallpaper, the veil and the monogram — which is exactly what the greeter
  # then paints over. asDropin because the unit comes from the plymouth package
  # via systemd.packages, not from a NixOS module; the empty first entry is how
  # systemd is told to discard the packaged ExecStart rather than append to it.
  systemd.services.plymouth-quit = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  };

  # Early KMS. Plymouth draws through DRM, so whichever driver owns the panel
  # has to be in the initrd — otherwise plymouth comes up on the EFI
  # framebuffer at the wrong resolution and the real modeset, when i915
  # finally loads, blanks the screen mid-splash.
  #
  # It is i915 and not nvidia here: per modules/nixos/nvidia.nix, eDP-1 and
  # HDMI-A-1 both hang off the Intel iGPU on this chassis, and the dGPU is
  # asleep in the default (offload) configuration.
  boot.initrd.kernelModules = [ "i915" ];
}
