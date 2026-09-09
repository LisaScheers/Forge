{...}: {
  forge.modules.homeManager.lisa = {pkgs, ...}: {
    programs.zed-editor.extensions = [
      "nix"
      "toml"
      "catppuccin"
      "catppuccin-icons"
      "oxc"
      "nu"
    ];
  };
}
