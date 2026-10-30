{
  lib,
  stdenvNoCC,
  fetchurl,
  jdk21,
  ghidra,
}: let
  reaSource = fetchurl {
    url = "https://github.com/morluto/rea/archive/160d821ac9a0310afcb8d1fc427862dd6508add5.tar.gz";
    hash = "sha256-Ve8+OQjHg6etdgY1QCTcqUdrmsBEQ51NjfEGwdZJjKM=";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "rea-ghidra-nativeaot";
    version = "6.8.0";
    src = fetchurl {
      url = "https://github.com/Washi1337/ghidra-nativeaot/archive/effeb734fc570c32650f88b159608979dc7b423e.tar.gz";
      hash = "sha256-feMh3yFn9lsyRhNXK+DosmH7AhZklmdBtXXxA7I/xWY=";
    };
    nativeBuildInputs = [jdk21];
    buildPhase = ''
      runHook preBuild
      mkdir bridge classes
      tar -xzf ${reaSource} -C bridge --strip-components=3 --wildcards '*/bridge/nativeaot/*.java'
      # Follow REA 6.8's pinned NativeAOT build lane and deterministic JAR date.
      java_classpath=$(find ${ghidra}/lib/ghidra/Ghidra -name '*.jar' -print | sort | paste -sd : -)
      mapfile -t java_sources < <(find src/main/java bridge -name '*.java' -print | sort)
      javac -J-Xmx512m -J-XX:ActiveProcessorCount=1 --release 21 -proc:none \
        -cp "$java_classpath" -d classes "''${java_sources[@]}"
      cp LICENSE.md classes/LICENSE-ghidra-nativeaot.md
      jar --create --file rea-ghidra-nativeaot.jar --date=2025-01-01T00:00:00Z -C classes .
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm644 rea-ghidra-nativeaot.jar "$out/share/java/rea-ghidra-nativeaot.jar"
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      jar --list --file "$out/share/java/rea-ghidra-nativeaot.jar" | grep 'NativeAotExtension.class$'
      runHook postInstallCheck
    '';
    meta = {
      description = "REA's pinned .NET NativeAOT extension for Ghidra";
      homepage = "https://github.com/morluto/rea/blob/rea-agents-6.8.0/docs/ghidra-nativeaot.md";
      license = lib.licenses.mit;
      inherit (ghidra.meta) platforms;
    };
  }
