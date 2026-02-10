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
    header = "From";
    query = "hailey-qa";
    tags = [
      "+qa"
      "-new"
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
