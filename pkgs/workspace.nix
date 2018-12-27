{ pkgs
, stdenv
, isContrail32
, isContrail41
, contrailVersion
, contrailBuildInputs
, contrailSources
, contrailThirdParty
, contrailController }:

with pkgs.lib;

stdenv.mkDerivation rec {
  name = "contrail-workspace";
  version = contrailVersion;
  USER = "contrail";
  phases = [ "unpackPhase" "patchPhase" "configurePhase" "installPhase" "fixupPhase" ];

  # We don't override the patchPhase to be nix-shell compliant
  preUnpack = ''mkdir workspace || exit; cd workspace'';

  srcs = with contrailSources;
    [ build contrailThirdParty generateds sandesh vrouter neutronPlugin contrailController ];

  sourceRoot = "./";

  postUnpack = with contrailSources; ''
    cp ${build.out}/SConstruct .

    mkdir tools
    mv ${build.name} tools/build
    mv ${generateds.name} tools/generateds
    mv ${sandesh.name} tools/sandesh

    [[ ${contrailController.name} != controller ]] && mv ${contrailController.name} controller
    [[ ${contrailThirdParty.name} != third_party ]] && mv ${contrailThirdParty.name} third_party
    find third_party -name configure -exec chmod 755 {} \;
    [[ ${vrouter.name} != vrouter ]] && mv ${vrouter.name} vrouter

    mkdir openstack
    mv ${neutronPlugin.name} openstack/neutron_plugin
  '';

  prePatch = ''
    # Should be moved in build drv
    sed -i 's|def UseSystemBoost(env):|def UseSystemBoost(env):\n    return True|' -i tools/build/rules.py

    sed -i 's|--proto_path=/usr/|--proto_path=${pkgs.protobuf2_5}/|' tools/build/rules.py

    # GenerateDS crashes woth python 2.7.14 while it works with python 2.7.13
    # See https://bugs.launchpad.net/opencontrail/+bug/1721039
    sed -i 's/        parser.parse(infile)/        parser.parse(StringIO.StringIO(infile.getvalue()))/' tools/generateds/generateDS.py
  '';

  installPhase = "mkdir $out; cp -r ./ $out";
}
