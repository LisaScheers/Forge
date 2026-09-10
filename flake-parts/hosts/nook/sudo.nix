{
  forge.modules.nixos.nook = {
    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };
}
