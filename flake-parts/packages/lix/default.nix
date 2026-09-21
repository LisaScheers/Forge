{lib, ...}: {
  forge.modules.darwin.base.nixpkgs.overlays = lib.mkAfter [
    (_: prev: {
      lix = prev.lix.overrideAttrs (old: {
        # Darwin has no /dev/full. Exercise the export write failure itself,
        # rather than depending on the shell's platform-specific open error.
        patches = (old.patches or []) ++ [./export-bad-fd.patch];
      });
    })
  ];
}
