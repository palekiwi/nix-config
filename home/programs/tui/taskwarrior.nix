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

  # Function to generate report columns and labels from an array of tuples
  # Takes: [[ "id" "ID" ] [ "project" "Project" ] ...]
  # Returns: { columns = "id,project,..."; labels = "ID,Project,..."; }
  mkReportConfig = fields: {
    columns = pkgs.lib.concatMapStringsSep "," (f: builtins.elemAt f 0) fields;
    labels = pkgs.lib.concatMapStringsSep "," (f: builtins.elemAt f 1) fields;
  };

  listReportFields = [
    [ "id" "ID" ]
    [ "start.active" "A" ]
    [ "project" "Project" ]
    [ "pr" "PR" ]
    [ "description" "Description" ]
    [ "branch" "Branch" ]
    [ "repo" "Repo" ]
    [ "priority" "Pri" ]
    [ "due" "Due" ]
  ];

  detailedReportFields = [
    [ "id" "ID" ]
    [ "start.active" "A" ]
    [ "priority" "Pri" ]
    [ "project" "Project" ]
    [ "pr" "PR" ]
    [ "branch" "Branch" ]
    [ "description" "Description" ]
    [ "repo" "Repo" ]
    [ "due" "Due" ]
  ];

  listReport = mkReportConfig listReportFields;
  detailedReport = mkReportConfig detailedReportFields;
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
        report.list.columns = listReport.columns;
        report.list.labels = listReport.labels;

        # Optional: Create a detailed report with full description
        report.detailed.description = "Detailed task list with full description";
        report.detailed.columns = detailedReport.columns;
        report.detailed.labels = detailedReport.labels;
        report.detailed.filter = "status:pending";
        report.detailed.sort = "project+,priority-,due+";
      };
    };
  };

  home.packages = [ taskwarrior-tui-wrapped ];
}
