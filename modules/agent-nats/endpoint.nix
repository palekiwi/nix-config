{
  host = "10.77.0.1";
  guest = "10.77.0.2";
  tap = "vm-agent";
  leafPort = 7422;
  clientPort = 4222;
  subjects = "agent.>";
  jsDomain = "pale";
  accounts = {
    agent = "AGENT";
    host = "HOST";
  };
  hostUser = "host";
  seed = {
    dir = "/var/lib/agent-nats";
    file = "/var/lib/agent-nats/leaf.env";
    var = "NATS_LEAF_SEED";
  };
}
