{
  host = "10.77.0.1";
  guestPort = 18830;
  hostPort = 18831;
  topics = {
    speechRequest = "vm/speech/request";
    inbox = "host/agent/+/inbox";
    agentInbox = name: "host/agent/${name}/inbox";
  };
  credentials = {
    guestUsers = [
      "vm-speech"
      "vm-inbox"
    ];
    hostUsers = [
      "host-speech"
      "host-inbox"
    ];
    hashSecret = user: "agent-mqtt/${user}/hash";
    passwordSecret = user: "agent-mqtt/${user}/password";
    hostPasswordFile = user: "/run/secrets/agent-mqtt/${user}/password";
    guestDir = "/var/lib/agent-mqtt";
    guestPasswordFile = user: "/var/lib/agent-mqtt/${user}";
  };
}
