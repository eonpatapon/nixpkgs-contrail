{ nixpkgs ? <nixpkgs> }:

let bootstrap_pkgs = import nixpkgs {};
in {
  pkgs = bootstrap_pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # Belong to the branch release-17.09-cloudwatt
    rev = "92d088e891edee8dba99b1cab6889445b6ad3bee";
    sha256 = "1kg1lbgwc222x4rvgwbmfglhi74wspxvysaw1w96016pf29h3nf4";};
  }
