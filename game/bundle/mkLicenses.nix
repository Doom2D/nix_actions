let
  licenses = {
    stdenv,
    executables,
    assets,
    _7zz,
    rar,
    lib,
  }: let
    licenses = lib.flatten (executables.meta.licenses ++ assets.meta.licenses);
    transformName = licenseFile: pname: let
      basename = builtins.baseNameOf licenseFile;
      split = lib.splitString "." basename;
    in
      if (lib.length split) == 1
      then "${basename}.${pname}.txt"
      else "${lib.concatStringsSep "." (lib.lists.init split)}.${pname}.${lib.strings.toLower (lib.lists.last split)}";
    # use -f, because there can be multiple versions of libraries for different platforms
    perLicenseAttrs = licenseAttrs: lib.map (x: "cp -f ${x} ${transformName x licenseAttrs.pname}") licenseAttrs.license;
    final = lib.map perLicenseAttrs licenses;
    copyExecutablesLicenses = lib.concatStringsSep " ;\n" (lib.flatten final);

    copySoundfontLicenses = lib.optionalString assets.meta.withDistroSoundfont ''
      # Distro soundfont doesn't have a license...
      # Pass.
    '';
    copyGusLicenses = lib.optionalString assets.meta.withDistroGus ''
      rar x -tsp ${assets.meta.distroMidiBanks} "docs/legal/*" /build/build
    '';
    copyAssetsLicenses = lib.concatStringsSep "\n" [copyGusLicenses copySoundfontLicenses];
  in
    stdenv.mkDerivation (finalAttrs: {
      version = "0.667";
      pname = "d2df-licenses";

      buildInputs = [_7zz rar];

      dontStrip = true;
      dontPatchELF = true;
      dontFixup = true;
      dontUnpack = true;

      src = null;

      buildPhase = ''
        mkdir -p build
        cd build
        mkdir -p docs
        cd docs
        mkdir -p legal
        cd legal
        ${copyExecutablesLicenses}
        ${copyAssetsLicenses}
      '';

      installPhase = ''
        cd /build
        7zz a -y -mtm -ssp -tzip out.zip -w build/.
        mv out.zip $out
      '';
    });
in
  licenses
