[
  {
    header = "X-GitHub-Reason";
    pattern = "(?P<reason>.*)";
    tags = [
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
