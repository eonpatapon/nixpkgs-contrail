self: super:

with builtins;

let

  inherit (super) callPackage callPackages;
  inherit (super.lib) filterAttrs;

  minimalDump = super.stdenv.mkDerivation {
    name = "minimal-cassandra-dump";
    src = ./test/minimal-cassandra-dump.tgz;
    setSourceRoot = "sourceRoot=`pwd`";
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };

  stdenv_gcc5 = super.overrideCC self.stdenv self.gcc5;
  stdenv_gcc49 = super.overrideCC self.stdenv self.gcc49;
  stdenv_gcc6 = super.overrideCC self.stdenv self.gcc6;

  contrail = super.lib.makeScope super.newScope (lself: let

    callPackage = lself.callPackage;

  in {

    contrailSources = null;
    contrailVersion = null;

    isContrail32 = lself.contrailVersion == "3.2";
    isContrail41 = lself.contrailVersion == "4.1";

    contrailBuildInputs = with self; [
      scons gcc5 pkgconfig autoconf automake libtool flex_2_5_35 bison
      # Global build deps
      libkrb5 openssl libxml2 perl curl
      lself.log4cplus
      (tbb.override{stdenv = stdenv_gcc5;})
      (boost155.override{
        buildPackages.stdenv.cc = gcc5;
        stdenv = stdenv_gcc5;
        enablePython = true;
      })
      # api-server
      pythonPackages.lxml pythonPackages.pip
      # To get xxd binary required by sandesh
      vim
      # vrouter-agent
      libipfix
      # analytics
      protobuf2_5 lself.cassandraCppDriver
      rdkafka # should be > 0.9
      python zookeeper_mt pythonPackages.sphinx
    ];

    modules = ./modules;
    path = ./.;

    # build
    contrailThirdPartyCache = callPackage ./pkgs/third-party-cache.nix { };
    contrailThirdParty = callPackage ./pkgs/third-party.nix { };
    contrailController = callPackage ./pkgs/controller.nix { };
    contrailWorkspace = callPackage ./pkgs/workspace.nix { stdenv = stdenv_gcc5; };
    contrailPythonBuild = callPackage ./pkgs/python-build.nix { stdenv = stdenv_gcc5; };

    lib = {
      # we switch to gcc 4.9 because gcc 5 is not supported before kernel 3.18
      buildVrouter = callPackage ./pkgs/vrouter.nix { stdenv = stdenv_gcc49; };
      # used for exposing to hydra
      sanitizeOutputs = contrailAttrs:
        let
          exclude = [
            "contrailSources"
            "contrailVersion"
            "contrailBuildInputs"
            "contrailThirdParty"
            "contrailThirdPartyCache"
            "contrailController"
            "contrailWorkspace"
            "contrailPythonBuild"
            "isContrail32"
            "isContrail41"
            "pythonPackages"
            "lib"
            "modules"
            "path"
            # added by makeScope
            "overrideScope'"
            "overrideScope"
            "callPackage"
            "newScope"
            "packages"
            # added by callPackage
            "override"
            "overrideDerivation"
          ];
          pythonPackages = [
            "contrail_neutron_plugin"
            "contrail_vrouter_api"
            "vnc_api"
            "cfgm_common"
            "vnc_openstack"
            "sandesh_common"
            "pysandesh"
            "discovery_client"
          ];
        in
          (filterAttrs (k: _: ! elem k exclude) contrailAttrs) // {
            pythonPackages = filterAttrs (k: _: elem k pythonPackages) contrailAttrs.pythonPackages;
          };
    };

    # deps
    cassandraCppDriver = callPackage ./pkgs/cassandra-cpp-driver.nix { stdenv = stdenv_gcc6; };
    libgrok = callPackage ./pkgs/libgrok.nix { };
    log4cplus = callPackage ./pkgs/log4cplus.nix { stdenv = stdenv_gcc5; };

    # vrouter
    vrouterAgent = callPackage ./pkgs/vrouter-agent.nix { stdenv = stdenv_gcc5; };
    vrouterUtils = callPackage ./pkgs/vrouter-utils.nix { };
    vrouterPortControl = callPackage ./pkgs/vrouter-port-control.nix { };
    vrouterNetNs = callPackage ./pkgs/vrouter-netns.nix { };
    vrouterModuleNixos_4_9 = lself.lib.buildVrouter self.linuxPackages_4_9.kernel.dev;

    # config
    apiServer = callPackage ./pkgs/api-server.nix { };
    svcMonitor = callPackage ./pkgs/svc-monitor.nix { };
    schemaTransformer = callPackage ./pkgs/schema-transformer.nix { };
    configUtils = callPackage ./pkgs/config-utils.nix { };

    # control
    control = callPackage ./pkgs/control.nix { stdenv = stdenv_gcc5; };

    # analytics
    analyticsApi = callPackage ./pkgs/analytics-api.nix { };
    collector = callPackage ./pkgs/collector.nix { stdenv = stdenv_gcc5; };
    queryEngine = callPackage ./pkgs/query-engine.nix { stdenv = stdenv_gcc5; };

    pythonPackages = callPackage ./pkgs/pythonPackages { };

    test = {
      allInOne = callPackage ./test/all-in-one.nix { contrailPkgs = lself; };
      tcpFlows = callPackage ./test/tcp-flows.nix { contrailPkgs = lself; };
      loadDatabase = callPackage ./test/load-database.nix {
        contrailPkgs = lself;
        cassandraDumpPath = minimalDump;
        extraTestScript = ''
          $machine->waitUntilSucceeds("contrail-api-cli ls -l virtual-network | grep -q vn1");
        '';
      };
      gremlinDump = callPackage ./test/gremlin-dump.nix { contrailPkgs = lself; cassandraDumpPath = minimalDump; };
    };

  });

in {

  contrail32 = contrail.overrideScope' (self: super: {
    contrailVersion = "3.2";
    contrailSources = callPackage ./sources-R3.2.nix { };
    contrailThirdPartyCache = super.contrailThirdPartyCache.overrideAttrs(oldAttrs:
      { outputHash = "1x0kgr2skq17lh5anwimlfjy1yzc8vhz5cmyraxg4hqig1g599sf"; });
    discovery = self.callPackage ./pkgs/discovery.nix { };
    tools.databaseLoader = callPackage ./tools/contrail-database-loader.nix { contrailPkgs = self; };
  });

  contrail41 = contrail.overrideScope' (lself: lsuper: {
    contrailVersion = "4.1";
    contrailSources = callPackage ./sources-R4.1.nix { };
    contrailBuildInputs = with self; lsuper.contrailBuildInputs ++ [
      cmake rabbitmq-c gperftools
    ];
    # contrailThirdPartyCache = super.contrailThirdPartyCache.overrideAttrs(oldAttrs:
    #   { outputHash = "1rvj0dkaw4jbgmr5rkdw02s1krw1307220iwmf2j0p0485p7d3h2"; });
  });

}
