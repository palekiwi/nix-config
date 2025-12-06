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
        context.spabreaks.read = "project:SB- or +sb";
        context.spabreaks.write = "project:SB- or +sb";
      };
    };
  };

  home.packages = [ taskwarrior-tui-wrapped ];
}
