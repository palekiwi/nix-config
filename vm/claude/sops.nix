{ ... }:

{
  sops.defaultSopsFile = ../../secrets/claude-vm.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/pl/.config/sops/age/claude-vm-key.txt";

  # sops.secrets."neo4j/user" = { owner = "claude"; };
  # sops.secrets."neo4j/password" = { owner = "claude"; };
  sops.secrets."neo4j/user" = {};
  sops.secrets."neo4j/password" = {};
}
