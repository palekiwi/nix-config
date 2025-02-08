{ pkgs, ... }:
{
  users.groups.git = {};

  users.users.git = {
    description = "git";
    shell = pkgs.bashInteractive;
    group = "git";
    isSystemUser = true;
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../pl/ssh.pub)
    ];
  };
}
