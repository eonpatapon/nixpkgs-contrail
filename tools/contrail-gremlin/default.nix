{ stdenv, pkgs, buildGoPackage, fetchgit }:

let

  src = fetchgit {
    url = "https://github.com/eonpatapon/contrail-gremlin.git";
    rev = "26a6c607c29ca768c77642681aba5bd93fa242a5";
    sha256 = "15206w8w7gng03cqpnaz9yqwc9q46i5xaciizgqgpxlc8n9n2x2r";
  };

  gremlinPython = with pkgs.pythonPackages; buildPythonPackage rec {
    pname = "gremlinpython";
    version = "3.3.1";
    name = "${pname}-${version}";

    src = fetchPypi {
      inherit pname version;
      sha256 = "119pziz0lysrqjfj6ffks3r6dlhr4blgspl9sx01lzdksgswbdl9";
    };

    doCheck = false;
    propagatedBuildInputs = [ six aenum futures tornado ];
  };

in {

  go = buildGoPackage rec {
    name = "contrail-gremlin-${version}";
    version = "2018-01-23";

    inherit src;

    goPackagePath = "github.com/eonpatapon/contrail-gremlin";
    goDeps = ./deps.nix;

    postInstall = ''
      mkdir -p $bin/conf
      cp -v go/src/github.com/eonpatapon/contrail-gremlin/conf/* $bin/conf
      sed -i "s!conf/\(.*\).properties!$bin/conf/\1.properties!" $bin/conf/*.yaml
    '';

  };

  python = with pkgs.pythonPackages; buildPythonPackage rec {
    pname = "gremlin-fsck";
    version = "0.1";
    name = "${pname}-${version}";

    inherit src;

    preBuild = ''
      cd gremlin-fsck
    '';

    doCheck = false;
    propagatedBuildInputs = [
      futures
      gremlinPython
    ];
  };

}
