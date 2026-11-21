{
  home.lisa-vega = {
    config,
    lib,
    pkgs,
    ...
  }: let
    appPath = "Applications/Forge Text Previews.app";
  in {
    home.file.${appPath}.source = pkgs.callPackage ../../../../packages/forge-text-previews/package.nix {};

    home.activation.registerTextPreviewTypes = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f ${lib.escapeShellArg "${config.home.homeDirectory}/${appPath}"} \
        || warnEcho "Failed to register Nix and TOML preview types"
      run /usr/bin/pluginkit -a ${lib.escapeShellArg "${config.home.homeDirectory}/${appPath}/Contents/PlugIns/TOMLPreview.appex"} \
        || warnEcho "Failed to register the TOML Quick Look extension"
    '';
  };
}
