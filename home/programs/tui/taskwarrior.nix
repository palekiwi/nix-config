{ pkgs, ...}:

let
  taskwarrior-pkg = pkgs.taskwarrior3;
  # Wrap taskwarrior-tui to ensure it always finds taskwarrior3's task binary,
  # even when devshells bring in their own go-task that overrides PATH
  taskwarrior-tui-wrapped = pkgs.symlinkJoin {
    name = "taskwarrior-tui-wrapped";
    paths = [ pkgs.taskwarrior-tui ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/taskwarrior-tui \
        --prefix PATH : ${taskwarrior-pkg}/bin
    '';
  };
in
{
  programs = {
    taskwarrior = {
      enable = true;
      package = taskwarrior-pkg;
      config = {
        context.spabreaks.read = "project:SB";

        sync.encryption_secret = "phahrei9YeiZ9eim";

        sync.server.client_id = "eea36aea-6c5d-4027-a897-aa859cad04db";
        sync.server.url = "http://haze:10222";

        uda.pr.type = "string";
        uda.pr.label = "PR";

        uda.jira.type = "string";
        uda.jira.label = "JIRA";

        uda.repo.type = "string";
        uda.repo.label = "Repo";

        uda.branch.type = "string";
        uda.branch.label = "Branch";

        # Customize list report to show UDAs
        report.list.columns = "id,start.active,project,priority,due,description.count,branch,pr,repo,jira";
        report.list.labels = "ID,A,Project,Pri,Due,Description,Branch,PR,Repo,JIRA";

        # Optional: Create a detailed report with full description
        report.detailed.description = "Detailed task list with full description";
        report.detailed.columns = "id,start.active,project,priority,due,description,branch,pr,repo,jira";
        report.detailed.labels = "ID,A,Project,Pri,Due,Description,Branch,PR,Repo,JIRA";
        report.detailed.filter = "status:pending";
        report.detailed.sort = "project+,priority-,due+";
      };
    };
  };

  home.packages = [ taskwarrior-tui-wrapped ];
}
