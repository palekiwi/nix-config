{ lib }:

let
  tools = [
    "atlassian.com"
    "fullstory.com"
    "lastpass.com"
    "slack.com"
  ];
in
[
  {
    message = "Airbrake";
    query = "from:airbrake.io";
    tags = [
      "+airbrake"
      "-new"
    ];
  }

  {
    message = "Airbrake: Production alerts";
    query = "from:alerts.airbrake.io AND subject:Production";
    tags = [
      "+airbrake/production"
      "-new"
    ];
  }

  {
    message = "Tagging Staging Airbrake alerts";
    query = "from:alerts.airbrake.io AND subject:Staging";
    tags = [
      "+airbrake/staging"
      "-new"
    ];
  }

  {
    message = "Spabreaks";
    query = "to:team@spabreaks.com";
    tags = [
      "+spabreaks"
      "-new"
    ];
  }

  {
    message = "Developers";
    query = "to:developers@spabreaks.com OR from:developers@spabreaks";
    tags = [
      "+developers"
      "-new"
    ];
  }

  {
    message = "Bookings";
    query = "from:bookings@spabreaks.com";
    tags = [
      "+bookings"
      "-new"
    ];
  }

  {
    message = "Tools";
    query = "${lib.concatMapStringsSep " OR" (domain: " from:${domain}") tools}";
    tags = [
      "+tools"
      "-new"
    ];
  }

  {
    message = "Google";
    query = "from:google.com";
    tags = [
      "+google"
      "-new"
    ];
  }
]
