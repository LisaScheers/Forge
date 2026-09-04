{pkgs, ...}: {
  home.packages = with pkgs; [
    tree
    pnpm
    nodejs_24
  ];
}
