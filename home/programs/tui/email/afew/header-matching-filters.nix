[
  {
    header = "X-GitHub-Reason";
    pattern = "(?P<reason>.+)";
    tags = [
      "+gh"
      "+gh/{reason}"
    ];
  }

  {
    header = "Message-ID";
    pattern = "calendar-.*@google\.com";
    tags = [
      "+calendar"
      "-new"
    ];
  }
]
