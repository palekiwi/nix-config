{
  host = "10.77.0.1";
  guestPort = 18830;
  hostPort = 18831;
  topics = {
    speechRequest = "vm/speech/request";
    inbox = "host/agent/+/inbox";
    agentInbox = name: "host/agent/${name}/inbox";
  };
}
