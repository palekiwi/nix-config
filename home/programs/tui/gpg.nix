{ ... }:

{
  home.file.".gnupg/gpg-agent.conf".text = ''
    enable-ssh-support
    ttyname $GPG_TTY
    default-cache-ttl 60
    max-cache-ttl 120
    pinentry-program /usr/bin/pinentry-gnome3
  '';
}
