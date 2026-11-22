{mautrix-discord}:
# Unencrypted rooms do not need the deprecated libolm dependency.
mautrix-discord.overrideAttrs {
  tags = ["nocrypto"];
  buildInputs = [];
  patches = [
    ./discord-relay-recovery.patch
    ./discord-relay-features.patch
    ./discord-history.patch
    ./discord-reaction-history.patch
    ./discord-history-content.patch
    ./discord-missing-thread-starter.patch
  ];
  doCheck = true;
}
