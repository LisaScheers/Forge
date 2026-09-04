{...}: {
  flake.modules.nixos.services_matrix = {
    lib,
    config,
    ...
  }: {
    imports = [
      ./_synapse.nix
      ./_coturn.nix
      ./_livekit.nix
    ];
    # configuration options for this module
    options.matrix = with lib; {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable this module";
      };

      rootDomain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The root domain for the matrix server";
      };

      subDomain = mkOption {
        type = types.str;
        default = "matrix";
        description = "The subdomain for the matrix server";
      };

      turnRealm = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The realm for the turn server";
      };

      registrationSecretFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Runtime path containing the Synapse registration shared secret";
      };
      turnSecretFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Runtime path containing the shared Synapse and Coturn secret";
      };
    };

    config.assertions = lib.mkIf config.matrix.enable [
      {
        assertion = config.matrix.rootDomain != null;
        message = "matrix.rootDomain must be set when Matrix is enabled";
      }
      {
        assertion = config.matrix.turnRealm != null;
        message = "matrix.turnRealm must be set when Matrix is enabled";
      }
      {
        assertion = config.matrix.registrationSecretFile != null;
        message = "matrix.registrationSecretFile must be set when Matrix is enabled";
      }
      {
        assertion = config.matrix.turnSecretFile != null;
        message = "matrix.turnSecretFile must be set when Matrix is enabled";
      }
    ];
  };
}
