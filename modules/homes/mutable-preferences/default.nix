{config, ...}: {
  home.lisa-vega.imports = [config.home.mutable-preferences];

  home.mutable-preferences = {
    config,
    lib,
    pkgs,
    ...
  }: let
    preferences = config.forge.mutablePreferences;
    json = pkgs.formats.json {};
    stringValue = value:
      if builtins.isString value
      then value
      else builtins.toJSON value;
    element = tag: attributes: content:
      "<${tag}"
      + lib.concatStrings (lib.mapAttrsToList (name: value: " ${name}=\"${lib.escapeXML (stringValue value)}\"") attributes)
      + ">${content}</${tag}>";
    llsd = value:
      if builtins.isAttrs value
      then element "map" {} (lib.concatStrings (lib.mapAttrsToList (name: child: element "key" {} (lib.escapeXML name) + llsd child) value))
      else if builtins.isList value
      then element "array" {} (lib.concatMapStrings llsd value)
      else if builtins.isBool value
      then
        element "boolean" {} (
          if value
          then "1"
          else "0"
        )
      else if builtins.isInt value
      then element "integer" {} (stringValue value)
      else if builtins.isFloat value
      then element "real" {} (stringValue value)
      else if value == null
      then element "undef" {} ""
      else element "string" {} (lib.escapeXML value);
    freecadTypes = {
      bool = "FCBool";
      int = "FCInt";
      uint = "FCUInt";
      float = "FCFloat";
      text = "FCText";
    };
    freecad = groups:
      lib.concatStrings (lib.mapAttrsToList (name: value:
        if value ? type && value ? value
        then
          element freecadTypes.${value.type}
          ({Name = name;}
            // lib.optionalAttrs (value.type != "text") {
              Value =
                if value.type == "bool"
                then
                  (
                    if value.value
                    then "1"
                    else "0"
                  )
                else stringValue value.value;
            })
          (
            if value.type == "text"
            then lib.escapeXML value.value
            else ""
          )
        else element "FCParamGroup" {Name = name;} (freecad value))
      groups);
    serialize = format: settings:
      if format == "llsd"
      then element "llsd" {} (llsd settings)
      else if format == "freecad"
      then element "FCParameters" {} (freecad settings)
      else if format == "xml"
      then element settings.root {} (lib.concatMapStrings (attributes: element "entries" attributes "") settings.entries)
      else builtins.toJSON settings;
    manifest = pkgs.writeText "mutable-preferences.json" (builtins.toJSON (
      lib.mapAttrsToList (target: entry: {
        inherit target;
        inherit (entry) format;
        source = pkgs.writeText "preferences-${builtins.hashString "sha256" target}" (serialize entry.format entry.settings);
      })
      preferences
    ));
    python = pkgs.python3.withPackages (ps: [ps.pyyaml]);
  in {
    options.forge.mutablePreferences = lib.mkOption {
      default = {};
      description = "Fallback preferences not covered by native Home Manager program options, keyed by home-relative target.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          settings = lib.mkOption {
            type = json.type;
            description = "Declarative preferences owned by the app's feature module.";
          };
          format = lib.mkOption {
            type = lib.types.enum ["json" "yaml" "lines" "llsd" "freecad" "xml"];
            default = "json";
            description = "The target's preference format and merge strategy.";
          };
        };
      });
    };

    config = lib.mkIf (preferences != {}) {
      home.activation.syncMutablePreferences = lib.hm.dag.entryAfter ["linkGeneration"] ''
        run ${python}/bin/python3 ${./sync-preferences.py} \
          ${lib.escapeShellArg config.home.homeDirectory} ${manifest}
      '';
    };
  };

  perSystem = {pkgs, ...}: {
    checks.mutable-preferences =
      pkgs.runCommand "mutable-preferences" {
        nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml]))];
      } ''
        cp ${./sync-preferences.py} sync-preferences.py
        cp ${./test_sync_preferences.py} test_sync_preferences.py
        python3 -B test_sync_preferences.py
        touch "$out"
      '';
  };
}
