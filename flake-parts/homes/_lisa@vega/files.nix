{
  # add all .pub files in the ssh/public-keys directory to the home.file attribute set
  home.file = builtins.listToAttrs (map (key: {
    name = ".ssh/${key}";
    value = {
      source = ./ssh/public-keys/${key};
    };
  }) (builtins.filter (key: builtins.match ".*\\.pub" key != null) (builtins.attrNames (builtins.readDir ./ssh/public-keys))));
}
