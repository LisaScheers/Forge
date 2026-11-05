{lib, ...}: let
  withoutLTO = package:
    (package.override {enableLTO = false;}).overrideAttrs (old: {
      # Mozilla falls back to Rust-only full LTO in release builds when
      # cross-language LTO is off. Both modes exhaust the ARM builder's memory.
      postPatch =
        old.postPatch
        + ''
          substituteInPlace build/moz.configure/rust.configure \
            --replace-fail 'set_config("RUST_LTO_ELIGIBLE", True, when=rust_lto_eligible)' \
              'set_config("RUST_LTO_ELIGIBLE", False)'
        '';
    });
in {
  overlays.asterion-mozilla = _final: prev:
    lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
      firefox-unwrapped = withoutLTO prev.firefox-unwrapped;
      thunderbird-unwrapped = withoutLTO prev.thunderbird-unwrapped;
    };
}
