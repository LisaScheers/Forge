{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule rec {
  pname = "cli-proxy-api-plus-capture";
  version = "8.0.53-0";
  src = fetchFromGitHub {
    owner = "kaitranntt";
    repo = "CLIProxyAPIPlus";
    rev = "5eddd91445a959145ebbc05df7e26b9758dbebd6";
    hash = "sha256-wirkT0GlLBZfh9huFvDK4j2G+9DuNGIPCW32vCYrw+c=";
  };
  vendorHash = "sha256-SiMleE0Kamux8jm7pLTFzG3apOPjr0p+sYomcsNPb9Y=";
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
