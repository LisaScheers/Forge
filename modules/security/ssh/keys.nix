{
  # Lisa's public keys under ~/.ssh, where SSH and the 1Password agent pick the
  # identity for each host block.
  home.ssh-public-keys = {
    home.file = builtins.listToAttrs (map (key: {
      name = ".ssh/${key}";
      value.source = ./public-keys/${key};
    }) (builtins.filter (key: builtins.match ".*\\.pub" key != null) (builtins.attrNames (builtins.readDir ./public-keys))));
  };
}
