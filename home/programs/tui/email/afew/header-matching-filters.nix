[
  {
    message = "Github: Review Requested";
    header = "X-GitHub-Reason";
    pattern = "review_requested";
    tags = [
      "+github"
      "+review-requested"
      "+urgent"
    ];
  }
  {
    message = "Github: Review Mention";
    header = "X-GitHub-Reason";
    pattern = "mention";
    tags = [
      "+github"
      "+mentioned"
    ];
  }
  {
    message = "Google Calendar";
    header = "Message-ID";
    pattern = "calendar-.*@google\.com";
    tags = [
      "+calendar"
      "+spabreaks"
      "-new"
    ];
  }
]
