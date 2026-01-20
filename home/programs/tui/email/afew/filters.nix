{ lib }:

let
  tools = [
    "atlassian.com"
    "atlassian.net"
    "browserstack.com"
    "figma.com"
    "fullstory.com"
    "lastpass.com"
    "slack.com"
  ];

  important = [
    "accounts@spabreaks.com"
    "tamzin.silander@spabreaks.com"
  ];

  joinFromOr = addresses: lib.concatMapStringsSep " OR" (domain: " from:${domain}") addresses;
in
[
  {
    message = "Airbrake";
    query = "from:airbrake.io";
    tags = [
      "+airbrake"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Airbrake: Production Alerts";
    query = "from:alerts.airbrake.io AND subject:Production";
    tags = [
      "+airbrake/production"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Airbrake: Staging Alerts";
    query = "from:alerts.airbrake.io AND subject:Staging";
    tags = [
      "+airbrake/staging"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Bookings";
    query = "from:bookings@spabreaks.com";
    tags = [
      "+bookings"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Developers";
    query = "to:developers@spabreaks.com OR from:developers@spabreaks";
    tags = [
      "+developers"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Google";
    query = "from:google.com";
    tags = [
      "+google"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Important";
    query = "${joinFromOr important}";
    tags = [
      "+*important"
    ];
  }

  {
    message = "Spabreaks";
    query = "to:team@spabreaks.com";
    tags = [
      "+spabreaks"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Spabreaks: Vouchers";
    query = "from:vouchers@spabreaks.com";
    tags = [
      "+spabreaks/vouchers"
      "-new"
      "-inbox"
    ];
  }

  {
    message = "Tools";
    query = "${joinFromOr tools}";
    tags = [
      "+tools"
      "-new"
      "-inbox"
    ];
  }
]
