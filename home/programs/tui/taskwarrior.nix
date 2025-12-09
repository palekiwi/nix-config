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

        uda.issue.type = "string";
        uda.issue.label = "Issue";

        uda.pr.type = "string";
        uda.pr.label = "PR";
      };
    };
  };

  home.packages = [ taskwarrior-tui-wrapped ];
}
