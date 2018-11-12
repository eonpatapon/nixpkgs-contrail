{ pkgs
# I didn't find a better way to run test by using the test framework
# of the bootstrapped nixpkgs. In fact, this is to avoid the user to
# set a specific NIX_PATH env var.
, pkgs_path ? <nixpkgs>
, contrailPkgs
, isContrail32
, isContrailMaster
# If not set, contrail32 or contrailMaster test scripts are used.
, testScript ? null
}:

with import (pkgs_path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };
with pkgs.lib;

let
  machine = {pkgs, config, ...}: {
    imports = [ ../modules/all-in-one.nix ];

    config = {
      _module.args = { inherit contrailPkgs isContrail32 isContrailMaster; };
      virtualisation = { memorySize = 4096; cores = 2; };

      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      services.openssh.extraConfig = "PermitEmptyPasswords yes";
      users.extraUsers.root.password = "";

      environment.systemPackages = [
        # Used by the test suite
        pkgs.jq contrailPkgs.configUtils
        contrailPkgs.tools.contrailApiCliWithExtra
      ];

      contrail.allInOne = {
        enable = true;
        vhostInterface = "eth1";
      };
    };
  };

  contrailTestScript = ''
    $machine->waitForUnit("cassandra.service");
    $machine->waitForUnit("rabbitmq.service");
    $machine->waitForUnit("zookeeper.service");
    $machine->waitForUnit("redis.service");

    $machine->waitForUnit("contrail-discovery.service");
    $machine->waitForUnit("contrail-api.service");

    $machine->waitForUnit("contrail-svc-monitor.service");
    $machine->waitUntilSucceeds("curl localhost:8088/");

    $machine->waitUntilSucceeds("curl localhost:5998/services.json | jq '.services[].ep_type' | grep -q IfmapServer");
    $machine->waitUntilSucceeds("curl localhost:5998/services.json | jq '.services[].ep_type' | grep -q ApiServer");

    $machine->waitForUnit("contrail-collector.service");
    $machine->waitUntilSucceeds("curl localhost:5998/services.json | jq '.services[].ep_type' | grep -q Collector");
    $machine->waitUntilSucceeds("curl localhost:5998/services.json | jq '.services | map(select(.ep_type == \"Collector\")) | .[].status' | grep -q up");

    $machine->waitForUnit("contrail-control.service");
    $machine->waitUntilSucceeds("curl localhost:5998/services.json | jq '.services[].ep_type' | grep -q xmpp-server");
    $machine->waitUntilSucceeds("curl localhost:5998/services.json | jq '.services | map(select(.ep_type == \"xmpp-server\")) | .[].status' | grep -q up");

    $machine->succeed("lsmod | grep -q vrouter");
    $machine->waitForUnit("contrail-vrouter-agent.service");

    $machine->waitUntilSucceeds("curl http://localhost:8083/Snh_ShowBgpNeighborSummaryReq | grep machine | grep -q Established");

    $machine->succeed("contrail-api-cli --ns contrail_api_cli.provision add-vn --project-fqname default-domain:default-project --subnet 20.1.1.0/24 vn1");
    $machine->succeed("netns-daemon-start -n default-domain:default-project:vn1 vm1");
    $machine->succeed("netns-daemon-start -n default-domain:default-project:vn1 vm2");

    $machine->succeed("ip netns exec ns-vm1 ip a | grep -q 20.1.1.252");
    $machine->succeed("ip netns exec ns-vm1 ping -c1 20.1.1.251");

    $machine->waitForUnit("contrail-analytics-api.service");
    $machine->waitUntilSucceeds("curl http://localhost:8081/analytics/uves/vrouters | jq '. | length' | grep -q 1");
  '';

in
  makeTest {
    name = "all-in-one";
    nodes = { inherit machine; };
    testScript = if testScript != null then testScript else contrailTestScript;
  }
