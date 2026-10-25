{
  lib,
  stdenvNoCC,
  nerd-font-patcher,
  fontSource,
}:
stdenvNoCC.mkDerivation {
  pname = "asterion-comic-code-nerd-font";
  version = "240323";
  src = fontSource;
  nativeBuildInputs = [nerd-font-patcher];

  buildPhase = ''
    runHook preBuild
    patched_dir="$TMPDIR/patched"
    font_list="$TMPDIR/fonts.txt"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$patched_dir" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
    find . -type f -name '*.otf' -print | sort > "$font_list"
    test -s "$font_list"
    while IFS= read -r font; do
      nerd-font-patcher --complete --careful --outputdir "$patched_dir" \
        --no-progressbars --quiet "$font"
    done < "$font_list"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install_dir="$out/share/fonts/opentype"
    mkdir -p "$install_dir"
    find "$patched_dir" -maxdepth 1 -type f -name '*.otf' -exec install -m644 {} "$install_dir" ';'
    test -n "$(find "$install_dir" -maxdepth 1 -name '*.otf' -print -quit)"
    runHook postInstall
  '';

  meta = {
    description = "Lisa's Comic Code fonts with the complete Nerd Fonts glyph set";
    platforms = lib.platforms.linux;
  };
}
