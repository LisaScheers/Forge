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
  test "$(fdtget -t x "$out/t6030-j516s.dtb" /soc/pmp_report@3503c0000 apple,pmp)" \
    = "$(fdtget -t x "$out/t6030-j516s.dtb" /soc/pmp@350500000 phandle)"
  test "$(fdtget -t x "$out/t6030-j516s.dtb" /soc/dcp@28ec00000 apple,pmp-report)" \
    = "$(fdtget -t x "$out/t6030-j516s.dtb" /soc/pmp_report@3503c0000/report@7 phandle)"
  test "$(fdtget -t s "$out/t6030-j516s.dtb" /soc/pmp@350500000 status)" = disabled
  for region in uat-ttbs uat-pagetables uat-handoff uat-pagetables-l2; do
    test "$(fdtget -t s "$out/t6030-j516s.dtb" "/reserved-memory/$region" status)" = disabled
  done
''
