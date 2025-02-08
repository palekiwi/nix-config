{ ... }:
let
  sshKey = ./ssh.pub;
in
{
  users.users.pl = {
    openssh.authorizedKeys.keys = [
      sshKey
    ];
  };
}
