{
  # Preserve Nook's existing Firestorm dependency at this Nixpkgs lock.
  nixos.nook.nixpkgs.config.problems.handlers."gtk+".broken = "warn";
}
