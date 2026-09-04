{...}: {
  _module.args.localKnownHosts = lib: let
    knownHostsLines =
      lib.filter
      (line: line != "" && !(lib.hasPrefix "#" line))
      (lib.splitString "\n" (builtins.readFile ./known_hosts));

    mkKnownHost = index: line: let
      fields = lib.splitString " " line;
    in {
      name = "known-host-${toString index}";
      value = {
        hostNames = lib.splitString "," (builtins.elemAt fields 0);
        publicKey = "${builtins.elemAt fields 1} ${builtins.elemAt fields 2}";
      };
    };
  in
    builtins.listToAttrs (lib.imap0 mkKnownHost knownHostsLines);
}
