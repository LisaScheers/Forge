{lib, ...}: {
  # Backport JDK-8393212 until the pinned Nixpkgs JDKs include the fix.
  # https://github.com/openjdk/jdk/commit/5177a70b385c16f26ede191fdac7aaba0bed0f8b
  overlays.java4shell = _final: prev:
    lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
      javaPackages =
        prev.javaPackages
        // {
          compiler =
            prev.javaPackages.compiler
            // lib.genAttrs ["openjdk17" "openjdk21" "openjdk25"] (name: let
              original = prev.javaPackages.compiler.${name};
              major = lib.versions.major original.version;
              fixedVersion =
                {
                  "17" = "17.0.21.1";
                  "21" = "21.0.13.1";
                  "25" = "25.0.5.1";
                }.${
                  major
                };
              patch = jdk:
                if lib.versionAtLeast jdk.version fixedVersion
                then jdk
                else
                  jdk.overrideAttrs (old: {
                    patches =
                      (old.patches or [])
                      ++ [
                        (
                          if major == "17"
                          then ../../packages/java4shell/jdk17.patch
                          else ../../packages/java4shell/jdk.patch
                        )
                      ];
                  });
            in
              (patch original) // {headless = patch original.headless;});
        };
    };

  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {
      checks.java4shell = pkgs.runCommand "java4shell-regression" {} ''
        ${lib.concatMapStringsSep "\n" (jdk: ''
          mkdir ${lib.versions.major jdk.version}
          cd ${lib.versions.major jdk.version}
          cp ${../../packages/java4shell/Base64Regression.java} Base64Regression.java
          ${jdk}/bin/javac -d . Base64Regression.java
          ${jdk}/bin/java -Xbatch -XX:-TieredCompilation Base64Regression
          cd ..
        '') [pkgs.jdk17_headless pkgs.jdk21_headless pkgs.jdk25_headless]}
        touch "$out"
      '';
    };
}
