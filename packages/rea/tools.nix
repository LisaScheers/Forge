{
  pkgs,
  lib,
  rea,
  browser,
  pwndbg,
}: let
  inherit (pkgs.stdenv.hostPlatform) isLinux isx86_64;
  ghidraSupported = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.ghidra;
  kuna = pkgs.callPackage ./kuna.nix {};
  wakaru = pkgs.callPackage ./wakaru.nix {};
  nativeaot = pkgs.callPackage ./nativeaot.nix {};
  # The separate Quark analysis integration is not used by REA's JADX bridge.
  jadx = pkgs.jadx.override {quark-engine = pkgs.emptyDirectory;};
  # REA decodes resources; it does not rebuild APKs with the x86-only aapt.
  apktool = pkgs.apktool.override (lib.optionalAttrs (isLinux && !isx86_64) {
    aapt = pkgs.emptyDirectory;
  });
  # Qt 6.12's UI compiler rejects template names; preserve the same widget type.
  cutter = pkgs.cutter.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./cutter-qt-templates.patch];
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/widgets/{Breakpoint,Search,ListDock,Globals,Flags,Strings}Widget.ui src/dialogs/XrefsDialog.ui \
          --replace-fail 'AddressableItemList&lt;&gt;' 'DefaultAddressableItemList'
      '';
  });

  # These integrations reject newer or older version banners.
  wabt = pkgs.wabt.overrideAttrs {
    version = "1.0.42";
    src = pkgs.fetchurl {
      url = "https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42.tar.xz";
      hash = "sha256:a76cda3c174a43097863a07fc0b0c202f770f53e21806ea2636f167d1ffb1e30";
    };
    cmakeFlags = ["-DBUILD_TESTS=OFF" "-DCMAKE_PROJECT_VERSION=1.0.42"];
  };
  jadxHeadless = pkgs.fetchurl {
    url = "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar";
    hash = "sha256:6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75";
  };
  sigrok = pkgs.sigrok-cli.overrideAttrs {
    version = "0.7.2";
    src = pkgs.fetchurl {
      url = "https://github.com/sigrokproject/sigrok-cli/archive/refs/tags/sigrok-cli-0.7.2.tar.gz";
      hash = "sha256-zzWUYjmU833XqpnRgE/UHyb++yAwvkUTdUhNdDXIOlg=";
    };
  };
  mitmproxy = pkgs.mitmproxy.overridePythonAttrs (old: {
    version = "12.2.3";
    src = pkgs.fetchurl {
      url = "https://github.com/mitmproxy/mitmproxy/archive/refs/tags/v12.2.3.tar.gz";
      hash = "sha256-OQc/QUzbmgv0OLh12g55uzBry30TMbWAdjiG9Qn3jBs=";
    };
    dependencies = old.dependencies ++ [pkgs.python3Packages.zstandard pkgs.python3Packages.msgpack];
    pythonRemoveDeps = [];
  });
  unicorn = pkgs.unicorn.overrideAttrs {
    version = "2.1.2";
    src = pkgs.fetchurl {
      url = "https://github.com/unicorn-engine/unicorn/archive/refs/tags/2.1.2.tar.gz";
      hash = "sha256-mGh6rJS9/u7Rf4CvmAs7qv158cO+OuwukTkF1ZiPfEo=";
    };
  };
  pwntoolsPython = (pkgs.python3.override {
    packageOverrides = final: prev: {
      pyelftools = prev.pyelftools.overridePythonAttrs {
        version = "0.33";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/source/p/pyelftools/pyelftools-0.33.tar.gz";
          hash = "sha256-Zg2C3L646D0XAr2X8iP3YWJdoGERwMyYjqxrirDBth8=";
        };
        # The PyPI source distribution does not contain the upstream fixture suite.
        doCheck = false;
      };
      unicorn = (prev.unicorn.override {inherit unicorn;}).overridePythonAttrs (old: {
        sourceRoot = "unicorn-2.1.2/bindings/python";
        build-system = old.build-system ++ [final.versioningit];
        postPatch =
          (old.postPatch or "")
          + ''
            substituteInPlace pyproject.toml --replace-fail '[tool.versioningit]' '[tool.versioningit]
            default-version = "2.1.2"'
          '';
      });
      pwntools =
        (prev.pwntools.override {
          inherit (final) pyelftools unicorn;
        }).overridePythonAttrs {
          # REA's admitted profile uses unchanged upstream Python sources.
          postPatch = "";
        };
    };
  }).withPackages (ps: [ps.pwntools]);

  toolPackages =
    [
      browser
      pkgs.jdk21
      jadx
      apktool
      pkgs.android-tools
      kuna
      pkgs.rizin
      cutter
      pkgs.lldb
      pkgs.binutils-unwrapped
      pkgs.ilspycmd
      pkgs.wireshark-cli
      pkgs.frida-tools
      wabt
    ]
    ++ lib.optional ghidraSupported pkgs.ghidra
    ++ lib.optionals isLinux [
      pkgs.procps
      pkgs.util-linux
      pkgs.gdb
      pkgs.binwalk
      pkgs.unblob
      pkgs.unrar
      mitmproxy
      sigrok
    ]
    ++ lib.optionals (isLinux && isx86_64) [pwntoolsPython pwndbg wakaru];

  environment =
    {
      JAVA_HOME = toString pkgs.jdk21.home;
      REA_ANALYSIS_PROVIDER =
        if ghidraSupported
        then "ghidra"
        else "kuna";
      REA_KUNA_COMMAND = lib.getExe kuna;
      REA_RIZIN_COMMAND = lib.getExe pkgs.rizin;
      REA_OBJDUMP_COMMAND = "${pkgs.binutils-unwrapped}/bin/objdump";
      REA_ILSPY_CMD_PATH = lib.getExe pkgs.ilspycmd;
      REA_JADX_MCP_JAR = toString jadxHeadless;
      REA_ADB_PATH = "${pkgs.android-tools}/bin/adb";
      REA_APKTOOL_COMMAND = "${apktool}/bin/apktool";
      REA_WABT_BIN_DIRECTORY = "${wabt}/bin";
      REA_BROWSER_EXECUTABLE = lib.getExe browser;
      REA_TSHARK_COMMAND = "${pkgs.wireshark-cli}/bin/tshark";
      REA_CAPINFOS_COMMAND = "${pkgs.wireshark-cli}/bin/capinfos";
    }
    // lib.optionalAttrs ghidraSupported {
      GHIDRA_INSTALL_DIR = "${pkgs.ghidra}/lib/ghidra";
      REA_GHIDRA_NATIVEAOT_JAR = "${nativeaot}/share/java/rea-ghidra-nativeaot.jar";
    }
    // lib.optionalAttrs isLinux {
      REA_GDB_COMMAND = "${pkgs.gdb}/bin/gdb";
      REA_BINWALK_COMMAND = lib.getExe pkgs.binwalk;
      REA_UNBLOB_COMMAND = lib.getExe pkgs.unblob;
      REA_MITMDUMP_COMMAND = "${mitmproxy}/bin/mitmdump";
      REA_SIGROK_COMMAND = lib.getExe sigrok;
      REA_FIRMWARE_PRLIMIT_COMMAND = "${pkgs.util-linux}/bin/prlimit";
      REA_TSHARK_PRLIMIT_COMMAND = "${pkgs.util-linux}/bin/prlimit";
      REA_SIGROK_PRLIMIT_COMMAND = "${pkgs.util-linux}/bin/prlimit";
      REA_JAVASCRIPT_PRLIMIT_COMMAND = "${pkgs.util-linux}/bin/prlimit";
      REA_EVM_PRLIMIT_COMMAND = "${pkgs.util-linux}/bin/prlimit";
    }
    // lib.optionalAttrs (isLinux && isx86_64) {
      REA_PWNTOOLS_PYTHON = "${pwntoolsPython}/bin/python3";
      REA_WAKARU_COMMAND = lib.getExe wakaru;
      REA_PWNDBG_GDB = "${pwndbg.meta.pwndbgVenv}/bin/gdb";
      REA_PWNDBG_GDBINIT = "${pwndbg.meta.pwndbgVenv}/share/pwndbg/gdbinit.py";
      REA_PWNDBG_VENV_PATH = toString pwndbg.meta.pwndbgVenv;
    };
in
  pkgs.buildEnv {
    name = "rea-${rea.version}-with-tools";
    paths = [rea] ++ toolPackages;
    pathsToLink = ["/bin" "/lib/node_modules/rea-agents" "/share/applications" "/share/icons"];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for command_name in rea rea-agents; do
        rm "$out/bin/$command_name"
        makeWrapper ${rea}/bin/rea "$out/bin/$command_name" \
          --prefix PATH : ${lib.makeBinPath toolPackages} \
          ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "--set-default ${name} ${lib.escapeShellArg value}") environment)}
      done
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: value: "test -e ${lib.escapeShellArg value}") (removeAttrs environment ["REA_ANALYSIS_PROVIDER"]))}
      test "$(${wabt}/bin/wasm-validate --version)" = 1.0.42
      ${lib.optionalString isLinux ''
        ${sigrok}/bin/sigrok-cli --version | grep '^sigrok-cli 0.7.2$'
        ${mitmproxy}/bin/mitmdump --version | grep '12.2.3'
      ''}
      ${lib.optionalString (isLinux && isx86_64) ''
        ${pwntoolsPython}/bin/python3 -I -c 'import importlib.metadata as m; assert {p: m.version(p) for p in ["pwntools", "pyelftools", "unicorn"]} == {"pwntools": "4.15.0", "pyelftools": "0.33", "unicorn": "2.1.2"}'
      ''}
      ${pkgs.nodejs_26}/bin/node ${./test-mcp.mjs} "$out/bin/rea"
    '';
    passthru = {
      inherit environment toolPackages;
      unwrapped = rea;
    };
    meta = rea.meta;
  }
