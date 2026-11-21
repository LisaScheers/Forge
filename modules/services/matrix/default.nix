{
  nixos.matrix = {
    lib,
    config,
    ...
  }: {
    # configuration options for this module
    options.forge.matrix = with lib; {
      enable = mkOption {
        type = types.bool;
        default = true;
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

    config.assertions = lib.mkIf config.forge.matrix.enable [
      {
        assertion = config.forge.matrix.rootDomain != null;
        message = "forge.matrix.rootDomain must be set when Matrix is enabled";
      }
      {
        assertion = config.forge.matrix.turnRealm != null;
        message = "forge.matrix.turnRealm must be set when Matrix is enabled";
      }
      {
        assertion = config.forge.matrix.registrationSecretFile != null;
        message = "forge.matrix.registrationSecretFile must be set when Matrix is enabled";
      }
      {
        assertion = config.forge.matrix.turnSecretFile != null;
        message = "forge.matrix.turnSecretFile must be set when Matrix is enabled";
      }
    ];
  };
}
