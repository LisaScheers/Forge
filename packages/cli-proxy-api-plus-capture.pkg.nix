{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule rec {
  pname = "cli-proxy-api-plus-capture";
  version = "8.0.56-0";
  src = fetchFromGitHub {
    owner = "kaitranntt";
    repo = "CLIProxyAPIPlus";
    rev = "0341bcc440583738d7d0e673abefc63bbe99e131";
    hash = "sha256-j7F90QSAQ4sndd/Av2wuEGAtANOJ9uxu69sYdy6Biuo=";
  };
  vendorHash = "sha256-Z2+PAoD6Mbh5dYwfe7bPamG6vHG45vJnenIqYSHkQDY=";
  patches = [./cli-proxy-api-plus-capture.patch];
  subPackages = ["cmd/server"];
  tags = ["no_plugin"];
  ldflags = ["-X main.Version=${version}" "-X main.Commit=${src.rev}"];
  env.CGO_ENABLED = "0";
  checkPhase = ''
    runHook preCheck
    go test -tags no_plugin ./internal/logging
    go test -tags no_plugin ./sdk/cliproxy/auth -run 'Test.*Responses|Test.*OpenAIResponse|TestForge'
    go test -tags no_plugin ./sdk/api/handlers/openai -run 'Test.*Interrupt' -timeout 120s
    runHook postCheck
  '';
  postInstall = ''
    mv "$out/bin/server" "$out/bin/cli-proxy-api-plus"
  '';
  meta = {
    description = "CLIProxyAPIPlus with lossless streaming log backpressure";
    mainProgram = "cli-proxy-api-plus";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
