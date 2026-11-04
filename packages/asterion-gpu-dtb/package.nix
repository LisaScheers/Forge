{
  kernel,
  runCommand,
  dtc,
}:
runCommand "asterion-j516s-gpu-dtb" {
  nativeBuildInputs = [dtc];
} ''
  mkdir -p "$out"
  dtc -q -I dtb -O dts ${kernel}/dtbs/apple/t6030-j516s.dtb > target.dts
  substituteInPlace target.dts \
    --replace-fail 'uat-ttbs@10' 'uat-ttbs' \
    --replace-fail 'uat-pagetables@20' 'uat-pagetables' \
    --replace-fail 'uat-handoff@30' 'uat-handoff' \
    --replace-fail 'uat-pagetables-l2@40' 'uat-pagetables-l2'
  dtc -q -I dts -O dtb -o "$out/t6030-j516s.dtb" target.dts

  fdtget -t s "$out/t6030-j516s.dtb" / compatible | grep -qw apple,j516s
  # Upstream's display gate creates the PMP and supplier links at boot.
  # Static nodes would collide with its admitted overlay.
  if fdtget -l "$out/t6030-j516s.dtb" /soc | grep -Eq '^(pmp_report@3503c0000|pmp@350500000)$'; then
    echo 'Unexpected static PMP in the upstream overlay profile.' >&2
    exit 1
  fi
  for region in uat-ttbs uat-pagetables uat-handoff uat-pagetables-l2; do
    test "$(fdtget -t s "$out/t6030-j516s.dtb" "/reserved-memory/$region" status)" = disabled
  done
''
