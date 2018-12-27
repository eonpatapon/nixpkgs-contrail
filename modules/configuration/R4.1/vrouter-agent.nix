{ pkgs, contrailPkgs, cfg }:

pkgs.writeTextFile {
  name = "contrail-vrouter-agent.conf";
  text = ''
    [DEFAULT]
    log_level = ${cfg.logLevel}
    log_file = /var/log/contrail/vrouter-agent.log
    log_local = 0
    use_syslog = 1

    disable_flow_collection = 1

    collectors = 127.0.0.1:8086

    [CONTROL-NODE]
    servers = 192.168.1.1:5269

    [VIRTUAL-HOST-INTERFACE]
    name = vhost0
    ip = ${cfg.vhostIP}/24
    gateway = ${cfg.vhostGateway}
    physical_interface = ${cfg.vhostInterface}

    [FLOWS]
    max_vm_flows = 20

    [METADATA]
    metadata_proxy_secret = t96a4skwwl63ddk6

    [TASK]
    tbb_keepawake_timeout = 25

    [SERVICE-INSTANCE]
    netns_command = ${contrailPkgs.vrouterNetNs}/bin/opencontrail-vrouter-netns
  '';
}
