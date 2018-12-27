{ pkgs, cfg }:

pkgs.writeTextFile {
  name = "contrail-control.conf";
  text = ''
    [DEFAULT]
    log_level = ${cfg.logLevel}
    log_local = 0
    log_file = /var/log/contrail/control.log
    use_syslog = 1

    collectors = 127.0.0.1:8086
  '';
}
