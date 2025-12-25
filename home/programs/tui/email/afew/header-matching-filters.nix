[
  {
    header = "X-GitHub-Reason";
    pattern = "review_requested";
    tags = [
      "+github"
      "+review-requested"
      "+urgent"
    ];
  }
  {
    header = "X-GitHub-Reason";
    pattern = "mention";
    tags = [
      "+github"
      "+mentioned"
    ];
  }
  {
    header = "Message-ID";
    pattern = "calendar-.*@google\.com";
    tags = [
      "+calendar"
      "+spabreaks"
      "-new"
    ];
  }
]
