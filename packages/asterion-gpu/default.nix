# Asterion's GPU stack, wired in one place. `kernel` is the kernel the host
# actually boots; the out-of-tree modules and device tree must match it.
{
  pkgs,
  kernel ? null,
}: let
  callPackage = path: pkgs.callPackage path;
in rec {
  gpuKernel = callPackage ../asterion-gpu-kernel/package.nix {};
  mesa = callPackage ../mesa-aurora/package.nix {};
  modules = callPackage ../asterion-gpu-modules/package.nix {inherit kernel;};
  dtb = callPackage ../asterion-gpu-dtb/package.nix {inherit kernel;};
  m1n1 = callPackage ../asterion-gpu-m1n1/package.nix {};
  smoke = callPackage ../asterion-gpu-smoke/package.nix {};
  vulkanSmoke = callPackage ../asterion-vulkan-smoke/package.nix {};
  session = callPackage ../asterion-gpu-session/package.nix {inherit mesa;};
}
