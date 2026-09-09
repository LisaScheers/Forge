{...}: {
  forge.modules.nixos.nook = {
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-users = ["root" "lisa" "nix-remote-builder"];
    };
  };
}
