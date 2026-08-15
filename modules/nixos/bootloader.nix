{
  pkgs,
  themeLib,
  themeName,
  themeData,
  builtTheme,
  ...
}:

# The bootloader, and the graphical generation menu it draws.
#
# This is GRUB rather than systemd-boot for one reason: systemd-boot has no
# theming of any kind — no background, no colours, no fonts — and GRUB's
# gfxmenu is the only bootloader menu that renders real graphical widgets, so
# it's the only one that can draw the design's generation cards.
#
# What GRUB does *not* do, stated plainly so nobody goes looking:
#
#  * Menu rows are a single line. The design's second metadata line and its
#    "DEFAULT" chip have no equivalent — gfxmenu draws one string per entry.
#  * Older generations live behind an "All configurations" submenu rather than
#    sitting flat in the list, because that's how NixOS emits them.
#
# The upside beyond looks: gfxpayloadEfi = "keep" hands GRUB's framebuffer
# straight through to the kernel, so the mode is set once here and held all the
# way to the greeter instead of being renegotiated (and blanked) twice.

let
  # themeName, themeData and builtTheme all come from modules/nixos/theme.nix.
  p = themeData.palette;
  m = themeData.style.bootMenu;

  # GRUB has no alpha compositing between the desktop image and the menu, and
  # `rgba(...)` in ImageMagick draw commands needs the channels split out.
  rgba =
    colour: alpha:
    let
      c = themeLib.hexToRgb colour;
    in
    "rgba(${toString c.r},${toString c.g},${toString c.b},${toString alpha})";

  # The pixmaps are authored at exactly the theme's card height so the vertical
  # slices map 1:1 and nothing is resampled; only the horizontal middle
  # stretches. All of these numbers are shared with the theme.txt generator,
  # which has to agree on them exactly — see themeLib.grubGeometry.
  g = themeLib.grubGeometry m;
  inherit (g)
    cardWidth
    corner
    progressSlot
    progressPad
    progressBand
    ;

  # How far the accent bar stops short of the row's top and bottom. It spans
  # the corner slices as well as the stretching middle one, which is fine
  # because the card is authored at exactly itemHeight — the fixed corner
  # slices render 1:1 and only the middle is resampled.
  barInset = 6;

  grubTheme =
    pkgs.runCommand "grub-theme-${themeName}"
      {
        nativeBuildInputs = with pkgs; [
          imagemagick
          librsvg
          grub2
        ];
      }
      ''
        # $out *is* the theme directory, with theme.txt at its root. Not the
        # share/grub/themes/<name> layout the packaged themes use: install-grub.pl
        # rcopy's whatever boot.loader.grub.theme points at straight to
        # /boot/theme and then reads /boot/theme/theme.txt, so a nested layout
        # leaves nothing where GRUB looks — and GRUB's response to a theme it
        # can't load is to silently fall back to the plain text menu. It also
        # walks this directory for *.pf2 to emit loadfont lines for, which only
        # finds them at the root.
        dir="$out"
        mkdir -p "$dir"

        cp ${builtTheme}/grub-theme.txt "$dir/theme.txt"

        # ── background ────────────────────────────────────────────────────────
        # The design's left-to-right veil is baked into the image: gfxmenu can
        # only draw one desktop-image, so there is no second layer to put it on.
        # Same mask trick as the splash — authored vertically, rotated -90 so
        # the opaque end lands on the left.
        magick ${builtTheme}/wallpaper.jpg \
          -resize 1920x1080^ -gravity center -extent 1920x1080 \
          \( -size 1080x1920 xc:'${p.base}' \
             \( -size 1080x1920 gradient:'gray(230)'-'gray(13)' \) \
             -alpha off -compose CopyOpacity -composite -rotate -90 \) \
          -compose over -composite \
          PNG24:"$dir/background.png"

        # The slice of that background lying under gfxterm's window. Handed to
        # GRUB as the terminal's background bitmap, which it blits at the
        # window's origin — so cropping to the window's exact rect is what makes
        # the window invisible. See splashImage below.
        magick "$dir/background.png" \
          -crop ${toString g.terminal.width}x${toString g.terminal.height}+${toString g.terminal.x}+${toString g.terminal.y} \
          +repage PNG24:"$dir/terminal-background.png"

        rsvg-convert --width=86 --height=72 \
          --output "$dir/logo.png" ${builtTheme}/logo.svg

        # ── row pixmaps ───────────────────────────────────────────────────────
        W=${toString cardWidth}
        H=${toString m.itemHeight}
        R=${toString m.cornerRadius}

        # The rounded silhouette, reused as an alpha mask for both cards.
        magick -size "''${W}x''${H}" xc:black \
          -fill white -draw "roundrectangle 0,0 $((W-1)),$((H-1)) $R,$R" \
          -alpha off PNG24:mask.png

        # Multiplies a translucent layer's own alpha by the rounded mask, so a
        # gradient keeps its fade instead of being flattened. CopyOpacity alone
        # would replace the alpha channel and throw the gradient away.
        round_off() {
          magick "$1" -alpha extract PNG24:layer-alpha.png
          magick layer-alpha.png mask.png -compose Multiply -composite PNG24:combined-alpha.png
          magick "$1" combined-alpha.png -alpha off -compose CopyOpacity -composite PNG32:"$2"
        }

        # Unselected: a flat, barely-there card.
        magick -size "''${W}x''${H}" xc:'${rgba p.base 0.38}' PNG32:item-fill.png
        round_off item-fill.png item-rounded.png
        magick item-rounded.png \
          -fill none -stroke '${rgba p.text 0.06}' -strokewidth 1 \
          -draw "roundrectangle 0.5,0.5 $((W-1)).5,$((H-1)).5 $R,$R" \
          PNG32:item.png

        # Selected: the design's row fades out to the right. A *horizontal*
        # gradient survives 9-slicing — the centre slice only ever stretches
        # along the same axis, which rescales the fade rather than destroying
        # it. (A vertical gradient in the centre slice would not survive.)
        magick -size "''${H}x''${W}" \
          gradient:'${rgba p.accent 0.24}'-'${rgba p.accentAlt 0.0}' \
          -rotate -90 PNG32:select-fill.png
        round_off select-fill.png select-rounded.png
        magick select-rounded.png \
          -fill none -stroke '${rgba p.accent 0.40}' -strokewidth 1 \
          -draw "roundrectangle 0.5,0.5 $((W-1)).5,$((H-1)).5 $R,$R" \
          \( -size ${toString m.markWidth}x$((H - 2 * ${toString barInset})) \
             gradient:'${p.accent}'-'${p.accentAlt}' \) \
          -geometry +1+${toString barInset} -compose over -composite \
          PNG32:select.png

        # Cut each card into the nine slices gfxmenu expects. Corners keep
        # their size, edges stretch along one axis, the centre fills.
        slice() {
          local src="$1" prefix="$2"
          local w h c
          w=${toString cardWidth}
          h=${toString m.itemHeight}
          c=${toString corner}

          magick "$src" -crop "''${c}x''${c}+0+0"                +repage PNG32:"$dir/''${prefix}_nw.png"
          magick "$src" -crop "$((w-2*c))x''${c}+''${c}+0"       +repage PNG32:"$dir/''${prefix}_n.png"
          magick "$src" -crop "''${c}x''${c}+$((w-c))+0"         +repage PNG32:"$dir/''${prefix}_ne.png"
          magick "$src" -crop "''${c}x$((h-2*c))+0+''${c}"       +repage PNG32:"$dir/''${prefix}_w.png"
          magick "$src" -crop "$((w-2*c))x$((h-2*c))+''${c}+''${c}" +repage PNG32:"$dir/''${prefix}_c.png"
          magick "$src" -crop "''${c}x$((h-2*c))+$((w-c))+''${c}" +repage PNG32:"$dir/''${prefix}_e.png"
          magick "$src" -crop "''${c}x''${c}+0+$((h-c))"         +repage PNG32:"$dir/''${prefix}_sw.png"
          magick "$src" -crop "$((w-2*c))x''${c}+''${c}+$((h-c))" +repage PNG32:"$dir/''${prefix}_s.png"
          magick "$src" -crop "''${c}x''${c}+$((w-c))+$((h-c))"  +repage PNG32:"$dir/''${prefix}_se.png"
        }

        slice item.png item
        slice select.png select

        # ── countdown rule ────────────────────────────────────────────────────
        # The progress bar component cannot be shorter than ${toString progressSlot}px, so the
        # design's ${toString progressBand}px rule is drawn inside that slot with the space above
        # and below left transparent. The slot's north and south slices are the
        # transparent caps; only the middle row carries colour, and only that
        # row's centre slice stretches — so a gradient across the fill keeps its
        # ramp as the bar grows.
        RULE_W=256
        magick -size "''${RULE_W}x${toString progressBand}" \
          xc:'${rgba p.text 0.10}' PNG32:track.png
        magick -size "${toString progressBand}x''${RULE_W}" \
          gradient:'${p.accent}'-'${p.accentAlt}' \
          -rotate -90 PNG32:fill.png

        progress_slices() {
          local prefix="$1" src="$2"

          magick -size "1x${toString progressPad}" xc:none PNG32:cap.png
          for s in nw n ne sw s se; do
            cp cap.png "$dir/''${prefix}_''${s}.png"
          done

          magick "$src" -crop "1x${toString progressBand}+0+0" \
            +repage PNG32:"$dir/''${prefix}_w.png"
          magick "$src" -crop "$((RULE_W-2))x${toString progressBand}+1+0" \
            +repage PNG32:"$dir/''${prefix}_c.png"
          magick "$src" -crop "1x${toString progressBand}+$((RULE_W-1))+0" \
            +repage PNG32:"$dir/''${prefix}_e.png"
        }

        progress_slices progress_track track.png
        progress_slices progress_fill fill.png

        # ── fonts ─────────────────────────────────────────────────────────────
        # GRUB only speaks .pf2, and install-grub.pl loadfont's every .pf2 it
        # finds in the theme directory — so shipping them here is all that's
        # needed. theme.txt refers to them by internal name ("<family> Regular
        # <size>"), never by filename, which is why -n matters.
        for size in 11 12 16; do
          grub-mkfont -n '${themeData.style.fonts.sans}' -s "$size" \
            -o "$dir/sans-$size.pf2" \
            ${pkgs.inter}/share/fonts/truetype/InterVariable.ttf
        done
        grub-mkfont -n '${themeData.style.fonts.mono}' -s 14 \
          -o "$dir/mono-14.pf2" \
          ${pkgs.nerd-fonts.caskaydia-mono}/share/fonts/truetype/NerdFonts/CaskaydiaMono/CaskaydiaMonoNerdFont-Regular.ttf

        # Assert every font name theme.txt references actually exists in one of
        # the generated .pf2 files. A mismatch is invisible at build time and
        # silently falls back to GRUB's built-in face at runtime — which is
        # exactly the unstyled text this module exists to replace.
        for want in \
          '${themeData.style.fonts.sans} Regular 11' \
          '${themeData.style.fonts.sans} Regular 12' \
          '${themeData.style.fonts.sans} Regular 16' \
          '${themeData.style.fonts.mono} Regular 14'
        do
          if ! grep -qFl "$want" "$dir"/*.pf2 2>/dev/null; then
            echo "grub theme: no .pf2 provides the font \"$want\"" >&2
            echo "names actually generated:" >&2
            for f in "$dir"/*.pf2; do
              printf '  %s: ' "$(basename "$f")" >&2
              head -c 200 "$f" | tr -c '[:print:]' '\n' | grep -m1 . >&2 || echo '?' >&2
            done
            exit 1
          fi
        done
      '';

in
{
  # Boot order is not managed here, and cannot be. install-grub.pl only runs
  # grub-install when its state file changes (`requireNewInstall`), not on every
  # generation — so the "NixOS-boot" NVRAM entry is created once and BootOrder is
  # never revisited. This board's firmware then re-sorts BootOrder on its own,
  # which on the switch away from systemd-boot left NixOS-boot last and the
  # machine booting a stale systemd-boot entry.
  #
  # The fix is BIOS-side (MSI: Del for setup, F11 for a one-shot menu), because
  # the firmware owns that list and will not demote a choice made in its own UI.
  # efibootmgr is here to read the entries back and confirm what happened.
  environment.systemPackages = [ pkgs.efibootmgr ];

  boot.loader = {
    systemd-boot.enable = false;

    efi.canTouchEfiVariables = true;
    timeout = 3;

    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";

      # Keep the menu readable — one entry per generation adds up fast once
      # you're rebuilding several times a day.
      configurationLimit = 10;

      theme = grubTheme;

      # install-grub.pl gates the whole gfxterm/gfxmode block on `font` being
      # set, so this has to stay non-null even though theme.txt names its own
      # fonts. It becomes GRUB's fallback face.
      font = "${pkgs.inter}/share/fonts/truetype/InterVariable.ttf";
      fontSize = 16;

      # theme.txt lays the menu out in whole percentages of 1920x1080 and the
      # row pixmaps are cut at fixed pixel sizes, so the mode is pinned rather
      # than left at "auto" — otherwise a 4K mode would shrink the cards and
      # shift the column.
      gfxmodeEfi = "1920x1080,auto";
      gfxpayloadEfi = "keep";

      # Not a duplicate of the theme's own background, and not decoration.
      #
      # gfxmenu only owns the screen while the menu is up. The moment an entry
      # is chosen, gfxterm takes over and clears its window — 70% of the screen,
      # centred, and it cannot be made smaller than 80x24 of the terminal font
      # (get_min_terminal in gfxmenu/view.c clamps it and re-centres). So the
      # themed menu gets a large black rectangle punched through it for as long
      # as the kernel and initrd take to load.
      #
      # splashImage is `background_image`, which gives gfxterm a background
      # bitmap for that window. install-grub.pl emits it after the gfxterm setup
      # and before the theme, and pairs it with color_normal=white/black — and
      # gfxterm treats a black background as transparent, so the wallpaper shows
      # through and any message GRUB does print stays readable on top of it.
      #
      # It has to be the crop rather than the whole background: gfxterm blits
      # the bitmap at its *window's* origin, not the screen's, so a full-screen
      # image lands 288x162 out of place and reads as a bright misaligned panel.
      # And "normal" rather than "stretch": stretch rescales to whatever the
      # window is when the command runs, which at that point is still fullscreen.
      splashImage = "${grubTheme}/terminal-background.png";
      splashMode = "normal";
      backgroundColor = p.base;

      # The design's last row. `fwsetup` reboots straight into UEFI setup.
      extraEntries = ''
        menuentry "UEFI firmware settings" --class settings {
          fwsetup
        }
      '';
    };
  };
}
