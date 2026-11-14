{
  name,
  port,
  tap,
  guestAddr,
  listenAddr,
}:
let
  new = "${name}-new";
  rule = "-p tcp --dport ${toString port}";
  drop = chain: ''
    while iptables -w -D INPUT ${rule} -j ${chain}; do :; done 2>/dev/null
    iptables -w -F ${chain} 2>/dev/null || true
    iptables -w -X ${chain} 2>/dev/null || true
  '';
in
{
  start = ''
    iptables -w -E ${new} ${name} 2>/dev/null || true
  ''
  + drop new
  + ''
    iptables -w -N ${new} 2>/dev/null || true
    iptables -w -F ${new}
    iptables -w -A ${new} -i ${tap} -s ${guestAddr} -d ${listenAddr} -j ACCEPT
    iptables -w -A ${new} -j DROP
    iptables -w -I INPUT 1 ${rule} -j ${new}
  ''
  + drop name
  + ''
    iptables -w -E ${new} ${name}
  '';
  stop = drop name + drop new;
}
