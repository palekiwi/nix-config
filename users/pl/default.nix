{ ... }:
{
  users.users.pl = {
    openssh.authorizedKeys.keys = [
      (builtins.readFile ./ssh.pub)
    ];
  };
}
