# Standalone agenix CLI entry point: the flake's agenixRules, defined in recipients.nix.
(builtins.getFlake ("path:" + toString ../../..)).agenixRules
