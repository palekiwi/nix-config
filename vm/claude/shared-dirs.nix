{ ... }:

{
  virtualisation.vmVariant = {
    virtualisation = {
      sharedDirectories = {
        documents = {
          source = "$HOME/claude/documents";
          target = "/home/claude/Documents";
        };

        nextcloud = {
          source = "$HOME/claude/Nextcloud";
          target = "/home/claude/Nextcloud";
        };

        labs = {
          source = "$HOME/code/palekiwi-labs";
          target = "/home/claude/code/palekiwi-labs";
        };

        spabreaks = {
          source = "$HOME/claude/code/ygt/spabreaks";
          target = "/home/claude/code/ygt/spabreaks";
        };
      };

      fileSystems = {
        "/home/claude/code/palekiwi-labs" = { options = [ "rw" ]; };
        "/home/claude/Nextcloud" = { options = [ "rw" ]; };
        "/home/claude/code/ygt/spabreaks" = { options = [ "rw" ]; };
      };
    };
  };
}
