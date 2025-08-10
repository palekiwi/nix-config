{ ... }:

{
  virtualisation.vmVariant = {
    virtualisation = {
      sharedDirectories = {
        documents = {
          source = "$HOME/claude/shared/documents";
          target = "/mnt/documents";
        };

        spabreaks = {
          source = "$HOME/claude/shared/code/ygt/spabreaks";
          target = "/mnt/code/ygt/spabreaks";
        };

        labs = {
          source = "$HOME/code/palekiwi-labs";
          target = "/mnt/palekiwi-labs";
        };
      };

      fileSystems = {
        "/mnt/palekiwi-labs" = { options = [ "rw" ]; };
        "/mnt/code/ygt/spabreaks" = { options = [ "rw" ]; };
      };
    };
  };
}
