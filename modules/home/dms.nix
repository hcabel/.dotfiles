{ config, lib, pkgs, ... }:

# DankMaterialShell configuration.
#
# DMS writes its own settings.json whenever you change something in its UI, so
# Nix seeds and patches that file rather than owning it — otherwise the
# settings panel would appear to work and silently revert on the next rebuild.
#
# Only the two keys documented for custom themes are asserted here
# (`currentThemeName` and `customThemeFile`); everything else is left to the
# UI. Terminal and editor theming is suppressed simply by never including the
# files DMS generates for them — per its docs, those templates only take
# effect if the target config includes them, and ours don't.

let
  dmsDir = "${config.xdg.configHome}/DankMaterialShell";

  seed = {
    currentThemeName = "custom";
    customThemeFile = "${dmsDir}/custom-theme.json";
  };
in
{
  home.activation.seedDmsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${dmsDir}/settings.json"
    run mkdir -p "${dmsDir}"

    if [ ! -f "$settings" ]; then
      run echo '${builtins.toJSON seed}' > "$settings"
    else
      # Merge our invariants over what DMS has written, preserving every other
      # preference set through the UI.
      tmp=$(${pkgs.coreutils}/bin/mktemp)
      if ${pkgs.jq}/bin/jq --argjson seed '${builtins.toJSON seed}' \
           '. * $seed' "$settings" > "$tmp" 2>/dev/null; then
        run mv "$tmp" "$settings"
      else
        run rm -f "$tmp"
      fi
    fi
  '';
}
