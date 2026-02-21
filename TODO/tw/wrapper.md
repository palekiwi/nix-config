# Wrapper

---

## Description
I enter a directory with an `.envrc`. I want to have a command utility that wraps `taskwarrior` so that it becomes aware of the current project I am working now. So it should automatically detect project from environment vars, files, etc.

Right now, I manually add tasks with `task add project:sb:1234 "Task title"` where `sb` is the namespace that also corresponds to Jira project and `1234` is the issue number. I also would like to be able to track the issue URL and a PR url as either annotations or UDA.

JIRA issue number can usually be inferred from the branch name as we name branches with: `sb-1234-some-name` or `1234-some-name`
Other jira info could be provided in env vars, e.g.: `home/config/spabreaks/.envrc`
That should be enough to automatically construct data (such as URLs) for taskwarrior entries.

The PR number may be saved in `.git/GH_PR_NUMBER` (this is set by git hooks).

Since we have multiple repositories that share the same jira board and can also share the same issue number, I would like to additionally tag the tasks with the name of the reporitory.

The utility should allow me to both list and add tasks.
