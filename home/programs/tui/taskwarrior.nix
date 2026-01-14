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
        context.spabreaks.read = "project:sb";

        sync.encryption_secret = "phahrei9YeiZ9eim";

        sync.server.client_id = "eea36aea-6c5d-4027-a897-aa859cad04db";
        sync.server.url = "http://haze:10222";

        uda.pr.type = "string";
        uda.pr.label = "PR";

        uda.jira_url.type = "string";
        uda.jira_url.label = "JIRA";

        uda.pr_url.type = "string";
        uda.pr_url.label = "PR URL";

        uda.repo.type = "string";
        uda.repo.label = "Repo";
      };
    };
  };

  home.packages = [ taskwarrior-tui-wrapped ];
}
