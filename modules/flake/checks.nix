{
  config,
  inputs,
  lib,
  withSystem,
  ...
}: let
  root = config.flake-root;
  entryPoint = root + /modules/security/agenix/_secrets.nix;
  nixFiles =
    builtins.filter (path: lib.hasSuffix ".nix" (toString path))
    (lib.filesystem.listFilesRecursive (root + /modules));
  features =
    builtins.filter (
      path:
        path != entryPoint
    )
    nixFiles;
  allowed = [
    "_class"
    "_file"
    "_module"
    "imports"
    "options"
    "config"
    "disabledModules"
    "nixos"
    "darwin"
    "home"
    "overlays"
    "nginxErrorPage"
    "ci"
    "flake"
    "flake-file"
    "perSystem"
    "systems"
    "debug"
    "secrets"
  ];
  validFeature = path: let
    value = import path;
    module =
      if builtins.isFunction value
      then value {inherit config inputs lib withSystem;}
      else value;
    relative = lib.removePrefix (toString root) (toString path);
  in
    builtins.isAttrs module
    && !lib.hasInfix "/_" relative
    && builtins.all (name: builtins.elem name allowed) (builtins.attrNames module);
  invalid = builtins.filter (path: !validFeature path) features;
in {
  perSystem = {pkgs, ...}: {
    checks.dendritic = assert lib.assertMsg (invalid == [])
    "Non-top-level or hidden Nix features: ${lib.concatMapStringsSep ", " toString invalid}";
      pkgs.runCommand "dendritic-module-boundary" {} ''
        printf '%s\n' '${toString (builtins.length features)} top-level feature modules checked' > "$out"
      '';
  };
}
