{
  home.lisa-vega = {
    config,
    lib,
    pkgs,
    ...
  }: let
    appPath = "Applications/Forge Text Previews.app";
    bundleId = "dev.bylisa.forge.text-previews";
    previewBundleId = "${bundleId}.toml";
    textType = identifier: description: extension: {
      UTTypeIdentifier = identifier;
      UTTypeDescription = description;
      UTTypeConformsTo = ["public.plain-text"];
      UTTypeTagSpecification."public.filename-extension" = [extension];
    };
    writePlist = name: attrs: pkgs.writeText name (lib.generators.toPlist {escape = true;} attrs);
    appInfo = writePlist "text-previews-info.plist" {
      CFBundleIdentifier = bundleId;
      CFBundleName = "Forge Text Previews";
      CFBundleExecutable = "TextPreviews";
      CFBundlePackageType = "APPL";
      CFBundleVersion = "1";
      LSUIElement = true;
      UTExportedTypeDeclarations = [
        (textType "dev.bylisa.forge.nix-expression" "Nix Expression" "nix")
      ];
      UTImportedTypeDeclarations = [(textType "public.toml" "TOML Document" "toml")];
    };
    previewInfo = writePlist "toml-preview-info.plist" {
      CFBundleIdentifier = previewBundleId;
      CFBundleName = "TOML Preview";
      CFBundleExecutable = "TOMLPreview";
      CFBundlePackageType = "XPC!";
      CFBundleVersion = "1";
      NSExtension = {
        NSExtensionPointIdentifier = "com.apple.quicklook.preview";
        NSExtensionPrincipalClass = "TOMLPreviewProvider";
        NSExtensionAttributes = {
          QLIsDataBasedPreview = true;
          QLSupportedContentTypes = ["public.toml"];
        };
      };
    };
    entitlements = writePlist "toml-preview-entitlements.plist" {
      "com.apple.security.app-sandbox" = true;
      "com.apple.security.files.user-selected.read-only" = true;
    };
  in {
    home.file.${appPath}.source = pkgs.stdenv.mkDerivation {
      name = "forge-text-previews.app";
      dontUnpack = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        preview="$out/Contents/PlugIns/TOMLPreview.appex"
        mkdir -p "$out/Contents/MacOS" "$preview/Contents/MacOS"
        cp ${appInfo} "$out/Contents/Info.plist"
        cp ${previewInfo} "$preview/Contents/Info.plist"
        printf 'int main(void) { return 0; }\n' | "$CC" -x c - -o "$out/Contents/MacOS/TextPreviews"
        "$CC" -x objective-c -fobjc-arc -fapplication-extension -Wl,-e,_NSExtensionMain \
          -framework Foundation -framework QuickLookUI -framework UniformTypeIdentifiers \
          ${./toml-preview.m} -o "$preview/Contents/MacOS/TOMLPreview"
        /usr/bin/codesign --force --sign - --entitlements ${entitlements} "$preview"
        /usr/bin/codesign --force --sign - "$out"
      '';
    };

    home.activation.registerTextPreviewTypes = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f ${lib.escapeShellArg "${config.home.homeDirectory}/${appPath}"} \
        || warnEcho "Failed to register Nix and TOML preview types"
      run /usr/bin/pluginkit -a ${lib.escapeShellArg "${config.home.homeDirectory}/${appPath}/Contents/PlugIns/TOMLPreview.appex"} \
        || warnEcho "Failed to register the TOML Quick Look extension"
    '';
  };
}
