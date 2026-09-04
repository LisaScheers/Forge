{
  inputs,
  pkgs,
  ...
}: let
  comicCodeNerdFont = pkgs.stdenvNoCC.mkDerivation {
    pname = "comic-code-nerd-font";
    version = "240323";

    src = inputs.comic-code-fonts;

    nativeBuildInputs = [
      pkgs.nerd-font-patcher
    ];

    buildPhase = ''
      runHook preBuild

      patched_dir="$TMPDIR/patched"
      home_dir="$TMPDIR/home"
      font_list="$TMPDIR/fonts.txt"

      mkdir -p "$patched_dir" "$home_dir"

      find . -type f -name '*.otf' -print | sort > "$font_list"

      if [ ! -s "$font_list" ]; then
        echo "Comic Code archive did not contain any OTF fonts" >&2
        exit 1
      fi

      while IFS= read -r font; do
        HOME="$home_dir" nerd-font-patcher \
          --complete \
          --careful \
          --outputdir "$patched_dir" \
          --no-progressbars \
          --quiet \
          "$font"
      done < "$font_list"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install_dir="$out/share/fonts/opentype"
      mkdir -p "$install_dir"
      find "$patched_dir" -maxdepth 1 -type f -name '*.otf' -exec install -m 0644 {} "$install_dir" ';'

      if ! find "$install_dir" -maxdepth 1 -type f -name '*.otf' | grep -q .; then
        echo "nerd-font-patcher did not produce any OTF fonts" >&2
        exit 1
      fi

      runHook postInstall
    '';

    meta = {
      description = "Comic Code patched with the complete Nerd Fonts glyph set";
      platforms = pkgs.lib.platforms.darwin;
    };
  };
in {
  fonts.packages = [
    comicCodeNerdFont
  ];
}
