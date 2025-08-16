{ ... }:

{
  virtualisation.vmVariant = {
    virtualisation = {
      sharedDirectories = {
        documents = {
          source = "$HOME/claude/shared/documents";
          target = "/mnt/documents";
        };

        nextcloud = {
          source = "$HOME/claude/Nextcloud";
          target = "/mnt/Nextcloud";
        };

        labs = {
          source = "$HOME/code/palekiwi-labs";
          target = "/mnt/palekiwi-labs";
        };

        spabreaks = {
          source = "$HOME/claude/shared/code/ygt/spabreaks";
          target = "/mnt/code/ygt/spabreaks";
        };
      };

      fileSystems = {
        "/mnt/palekiwi-labs" = { options = [ "rw" ]; };
        "/mnt/Nextcloud" = { options = [ "rw" ]; };
        "/mnt/code/ygt/spabreaks" = { options = [ "rw" ]; };
      };
    };
  };
}
