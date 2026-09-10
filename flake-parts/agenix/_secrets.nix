# Standalone agenix CLI entry point; recipient features are evaluated by the flake.
(builtins.getFlake ("path:" + toString ../..)).agenixRules
