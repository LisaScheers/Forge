{pkgs}: let
  echarts = pkgs.fetchurl {
    url = "https://registry.npmjs.org/echarts/-/echarts-6.1.0.tgz";
    hash = "sha512-q0yaFPggC9FUdsWH4blavRWFmxdrIodbkoKNAjJudAI6CA9gNPxHtV2RcZNEepZVlk4yvBYkOkbk6HIVpIyHZA==";
  };
  three = pkgs.fetchurl {
    url = "https://registry.npmjs.org/three/-/three-0.186.1.tgz";
    hash = "sha512-blFeqb49wRCSGUGj7gtpfnSGHy2lwDk94RhUmS1c/hTby70kvChbWpkJ4Pm1390LqzzvTmzgXKHPEafJwCb8jA==";
  };
  threeDmol = pkgs.fetchurl {
    url = "https://registry.npmjs.org/3dmol/-/3dmol-2.5.5.tgz";
    hash = "sha512-kqNHouGqq3YfW58174tdERvm0XYTmP0tavQKOqIw1ouc2OJ7epkXEFrtEkVXV0clBZT2Ze2xHRC/qxX0u0qCdw==";
  };
in
  pkgs.runCommand "visualize-skill" {nativeBuildInputs = [pkgs.esbuild];} ''
    cp -R ${./.} "$out"
    chmod -R u+w "$out"
    mkdir -p "$out/assets/vendor"
    tar -xOf ${echarts} package/dist/echarts.min.js > "$out/assets/vendor/echarts.min.js"
    tar -xOf ${echarts} package/LICENSE > "$out/assets/vendor/LICENSE"
    tar -xOf ${echarts} package/NOTICE > "$out/assets/vendor/NOTICE"
    tar -xOf ${threeDmol} package/build/3Dmol-min.js > "$out/assets/vendor/3Dmol-min.js"
    tar -xOf ${threeDmol} package/LICENSE > "$out/assets/vendor/3Dmol-LICENSE"
    tar -xOf ${threeDmol} package/build/3Dmol-min.js.LICENSE.txt > "$out/assets/vendor/3Dmol-NOTICES"
    mkdir three
    tar -xf ${three} -C three --strip-components=1
    cat > three-entry.js <<'JS'
    export * from './three/build/three.module.js';
    export { OrbitControls } from './three/examples/jsm/controls/OrbitControls.js';
    JS
    esbuild three-entry.js --bundle --format=iife --global-name=THREE \
      --alias:three="$PWD/three/build/three.module.js" --minify --legal-comments=inline \
      --outfile="$out/assets/vendor/three.min.js"
    cp three/LICENSE "$out/assets/vendor/three-LICENSE"
  ''
