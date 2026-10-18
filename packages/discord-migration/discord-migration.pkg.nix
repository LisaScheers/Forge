{
  lib,
  stdenvNoCC,
  python3,
  discordchatexporter-cli,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "discord-migration";
  version = "0.1.0";
  src = ../../tools/discord-migration;
  nativeBuildInputs = [makeWrapper];
  nativeCheckInputs = [python3];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -B -m unittest discover -s tests
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm644 discord_migration.py "$out/lib/discord-migration/discord_migration.py"
    makeWrapper ${python3}/bin/python3 "$out/bin/discord-migration" \
      --add-flags "$out/lib/discord-migration/discord_migration.py" \
      --prefix PATH : ${lib.makeBinPath [discordchatexporter-cli]}
    runHook postInstall
  '';
  meta = {
    description = "Inventory and independently archive a Discord guild using a bot account";
    mainProgram = "discord-migration";
    platforms = lib.platforms.unix;
  };
}
