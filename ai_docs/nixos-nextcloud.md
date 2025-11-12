# Nextcloud on NixOS

Nextcloud is a self-hosted web groupware and cloud software, offering collaboration on files, managing calendar events, contacts and tasks.

## Installation

A minimal example to get a Nextcloud running on localhost should look like this, replacing `PWD` with a 10+ char password that meets [Nextcloud's default password policy](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_password_policy.html).

```nix
# /etc/nixos/configuration.nix
environment.etc."nextcloud-admin-pass".text = "PWD";
services.nextcloud = {
  enable = true;
  package = pkgs.nextcloud31;
  hostName = "localhost";
  config.adminpassFile = "/etc/nextcloud-admin-pass";
  config.dbtype = "sqlite";
};
```

After that you will be able to login into your Nextcloud instance at http://localhost with user `root` and password `PWD` as configured above.

## Configuration

Be sure to read the [Nextcloud module's documentation](https://nixos.org/manual/nixos/stable/index.html#module-services-nextcloud-basic-usage) in the [NixOS Manual](https://nixos.org/manual/nixos/stable/index.html).

### Apps

[Some apps](https://github.com/NixOS/nixpkgs/blob/c931a329076796d3644a6bc5b7cc41afc7b3381e/pkgs/servers/nextcloud/packages/nextcloud-apps.json) which are already packaged on NixOS can be installed directly with the following example configuration:

```nix
# /etc/nixos/configuration.nix
services.nextcloud = {
  enable = true;
  # [...]
  package = pkgs.nextcloud28;
  # Instead of using pkgs.nextcloud28Packages.apps,
  # we'll reference the package version specified above
  extraApps = {
    inherit (config.services.nextcloud.package.packages.apps) news contacts calendar tasks;
  };
  extraAppsEnable = true;
};
```

The apps mail, news and contacts will be installed and enabled in your instance automatically. Note that the Nextcloud version specified in `package` and `extraApps` need to match one of the stable Nextcloud versions available in the NixOS repository.

To manually fetch and install packages, you need to add them via the helper script `fetchNextcloudApp` by specifing the release tarball as url, the correct checksum and the license. Additional apps can be found via [Nextcloud app store](https://apps.nextcloud.com), while the [nc4nix](https://github.com/helsinki-systems/nc4nix) provides an easy reference for the required variables. Note that the declarative specification of apps via this approach requires manual updating of package version (url) and checksum for a new release.

```nix
# /etc/nixos/configuration.nix
services.nextcloud = {
  enable = true;
  # [...]
  extraApps = {
    inherit (config.services.nextcloud.package.packages.apps) news contacts calendar tasks;
    memories = pkgs.fetchNextcloudApp {
        sha256 = "sha256-Xr1SRSmXo2r8yOGuoMyoXhD0oPVm/0/ISHlmNZpJYsg=";
        url = "https://github.com/pulsejet/memories/releases/download/v6.2.2/memories.tar.gz";
        license = "agpl3";
    };

  };
  extraAppsEnable = true;
};
```

It is even possible to fetch and build an app from source, in this example the development app [hmr_enabler](https://github.com/nextcloud/hmr_enabler).

```nix
# /etc/nixos/configuration.nix
services.nextcloud = {
  enable = true;
  # [...]
  extraApps = {
    hmr_enabler = pkgs.php.buildComposerProject (finalAttrs: {
      pname = "hmr_enabler";
      version = "1.0.0";
      src = pkgs.fetchFromGitHub {
        owner = "nextcloud";
        repo = "hmr_enabler";
        rev = "b8d3ad290bfa6fe407280587181a5167d71a2617";
        hash = "sha256-yXFby5zlDiPdrw6HchmBoUdu9Zjfgp/bSu0G/isRpKg=";
      };
      composerNoDev = false;
      vendorHash = "sha256-PCWWu/SqTUGnZXUnXyL8c72p8L14ZUqIxoa5i49XPH4=";
      postInstall = ''
        cp -r $out/share/php/hmr_enabler/* $out/
        rm -r $out/share
      '';
    });
  };
  extraAppsEnable = true;
};
```

Alternatively apps can be manually installed via the app store integrated in your Nextcloud instance by navigating in the profile menu to the site "Apps".

### SSL

If you would like to setup Nextcloud with Let's Encrypt TLS certificates (or certs from any other certificate authority) make sure to set `services.nextcloud.https = true;` and to enable it in the nginx-vHost.

```nix
# /etc/nixos/configuration.nix
services.nextcloud = {
  enable = true;
  # [...]
  hostName = "example.org";
  https = true;
};

services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
  forceSSL = true;
  enableACME = true;
};

security.acme = {
  acceptTerms = true;
  certs = {
    ${config.services.nextcloud.hostName}.email = "your-letsencrypt-email@example.com";
  };
};
```

### Caching

Redis can be enabled as a performant caching backend using following configuration. This will bring faster page loads to your Nextcloud instance.

```nix
# /etc/nixos/configuration.nix
services.nextcloud = {
  enable = true;
  configureRedis = true;
  # [...]
};
```

Note that APCu will still be used for local caching, as recommended by Nextcloud upstream.

### Object store

In this example we'll configure a local S3-compatible object store using Minio and connect it to Nextcloud:

```nix
# /etc/nixos/configuration.nix
{ ... } let

  accessKey = "nextcloud";
  secretKey = "test12345";

  rootCredentialsFile = pkgs.writeText "minio-credentials-full" ''
    MINIO_ROOT_USER=nextcloud
    MINIO_ROOT_PASSWORD=test12345
  '';

in {
  services.nextcloud = {
    # [...]
    config.objectstore.s3 = {
      enable = true;
      bucket = "nextcloud";
      autocreate = true;
      key = accessKey;
      secretFile = "${pkgs.writeText "secret" "test12345"}";
      hostname = "localhost";
      useSsl = false;
      port = 9000;
      usePathStyle = true;
      region = "us-east-1";
    };
  };

  services.minio = {
    enable = true;
    listenAddress = "127.0.0.1:9000";
    consoleAddress = "127.0.0.1:9001";
    inherit rootCredentialsFile;
  };

  environment.systemPackages = [ pkgs.minio-client ];

};
```

We'll need to run two commands to create the bucket `nextcloud` by using the access key `nextcloud` and the secret key `test12345`.

```bash
mc config host add minio http://localhost:9000 ${accessKey} ${secretKey} --api s3v4
mc mb minio/nextcloud
```

### Mail delivery

Besides various mail delivery options and settings, mail clients like Msmtp can be used to configure mail delivery for Nextcloud. This can be useful for sending registration mails or system notifications etc. To configure Nextcloud to use a local mail delivery daemon, we configure `mail_smtpmode` to `sendmail` and a further sending mode.

```nix
services.nextcloud = {
  # [...]
  settings = {
    mail_smtpmode = "sendmail";
    mail_sendmailmode = "pipe";
  };
};
```

Test mails can be send via administration interface in the menu section "Basic settings".

### Max upload file size

To increase the maximum upload file size, for example to 1 GB, add following option:

```nix
# /etc/nixos/configuration.nix
services.nextcloud.maxUploadSize = "1G";
```

### Secrets management

Do not supply passwords, hashes or keys via `settings` option, since they will be copied into the world-readable Nix store. Instead reference a JSON file containing secrets using the `secretFile` option.

```nix
services.nextcloud = {
  # [...]
  secretFile = "/etc/nextcloud-secrets.json";
};

environment.etc."nextcloud-secrets.json".text = ''
  {
    "passwordsalt": "12345678910",
    "secret": "12345678910",
    "instanceid": "10987654321",
    "redis": {
      "password": "secret"
    }
  }
'';
```

Consider using a secret management tool instead of referencing an unencrypted local secrets file.

### Fail2Ban

To block IPs of unsuccessful logins you will need to use `systemd` backend of Fail2Ban, example config:

```nix
# /etc/nixos/configuration.nix
services.fail2ban = {
  enable = true;
  # The jail file defines how to handle the failed authentication attempts found by the Nextcloud filter
  # Ref: https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html#setup-a-filter-and-a-jail-for-nextcloud
  jails = {
    nextcloud.settings = {
      # START modification to work with syslog instead of logile
      backend = "systemd";
      journalmatch = "SYSLOG_IDENTIFIER=Nextcloud";
      # END modification to work with syslog instead of logile
      enabled = true;
      port = 443;
      protocol = "tcp";
      filter = "nextcloud";
      maxretry = 3;
      bantime = 86400;
      findtime = 43200;
    };
  };
};

environment.etc = {
  # Adapted failregex for syslogs
  "fail2ban/filter.d/nextcloud.local".text = pkgs.lib.mkDefault (pkgs.lib.mkAfter ''
    [Definition]
    failregex = ^.*"remoteAddr":"<HOST>".*"message":"Login failed:
                ^.*"remoteAddr":"<HOST>".*"message":"Two-factor challenge failed:
                ^.*"remoteAddr":"<HOST>".*"message":"Trusted domain error.
  '');
};
```

## Maintenance

### Upgrade

As you can see on [the package search](https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nextcloud), there is no default nextcloud package. Instead you have to set the current version in [`services.nextcloud.package`](https://search.nixos.org/options?channel=unstable&show=services.nextcloud.package&from=0&size=50&sort=relevance&type=packages&query=nextcloud). As soon a major version of Nextcloud gets unsupported, it will be removed from nixpkgs as well.

Upgrading then consists of these steps:

1. Increment the version of `services.nextcloud.package` in your config by 1 (leaving out a major version is not supported)
2. `nixos-rebuild switch`

In theory, your nextcloud has now been upgraded by one version. NixOS attempts `nextcloud-occ upgrade`, if this succeeds without problems you don't need to do anything. Check `journalctl` to make sure nothing horrible happened. Go to the `/settings/admin/overview` page in your nextcloud to see whether it recommends further processing, such as database reindexing or conversion.

### Database

You can access the mysql database, for backup/restore, etc. like this:

```bash
sudo runuser -u nextcloud -- mysql -u nextcloud <options>
```

No password is required.

## Clients

### Nextcloudcmd

`nextcloudcmd` is a terminal client performing only a single sync run and then exits. The following example command will synchronize the local folder `/home/myuser/music` with the remote folder `/music` of the Nextcloud server `https://nextcloud.example.org`.

```bash
# nix shell nixpkgs#nextcloud-client -h --user example --password test123 --path /music /home/myuser/music https://nextcloud.example.org
```

The argument `-h` will enable syncing hidden files. For demonstration purpose username and password are supplied as an argument. This is a security risk and shouldn't be used in production.

Using Home Manager we can create a systemd-timer which automatically runs the sync command every hour for the user `myuser`.

```nix
# /etc/nixos/configuration.nix
home-manager.users.myuser = {

  home.file.".netrc".text = ''default
    login example
    password test123
  '';

  systemd.user = {
    services.nextcloud-autosync = {
      Unit = {
        Description = "Auto sync Nextcloud";
        After = "network-online.target";
      };
      Service = {
        Type = "simple";
        ExecStart= "${pkgs.nextcloud-client}/bin/nextcloudcmd -h -n --path /music /home/myuser/music https://nextcloud.example.org";
        TimeoutStopSec = "180";
        KillMode = "process";
        KillSignal = "SIGINT";
      };
      Install.WantedBy = ["multi-user.target"];
    };
    timers.nextcloud-autosync = {
      Unit.Description = "Automatic sync files with Nextcloud when booted up after 5 minutes then rerun every 60 minutes";
      Timer.OnBootSec = "5min";
      Timer.OnUnitActiveSec = "60min";
      Install.WantedBy = ["multi-user.target" "timers.target"];
    };
    startServices = true;
  };

};
```

The login credentials will be written to a file called `.netrc` used `nextcloudcmd` for authentication to the Nextcloud server.

### Nextcloud Desktop

"nextcloud-client" is a nextcloud themed desktop client.
It requires a keyring to store its login token. Without an active keyring, the user will be asked for to login on every application startup.

## Tips and tricks

### Change default listening port

In case port 80 is already used by a different application or you're using a different web server than Nginx, which is used by the Nextcloud module, you can change the listening port with the following option:

```nix
# /etc/nixos/configuration.nix
services.nginx.virtualHosts."localhost".listen = [ { addr = "127.0.0.1"; port = 8080; } ];
```

### Enable HEIC image preview

HEIC image preview needs to be explicitly enabled. This is done by adjusting the `enabledPreviewProviders` option. Beside the default list of supported formats, add an additional line `"OC\\Preview\\HEIC"` for HEIC image support. See also [this list of preview providers](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/config_sample_php_parameters.html#enabledpreviewproviders) for additional file types.

```nix
# /etc/nixos/configuration.nix
services.nextcloud = {
  settings.enabledPreviewProviders = [
    "OC\\Preview\\BMP"
    "OC\\Preview\\GIF"
    "OC\\Preview\\JPEG"
    "OC\\Preview\\Krita"
    "OC\\Preview\\MarkDown"
    "OC\\Preview\\MP3"
    "OC\\Preview\\OpenDocument"
    "OC\\Preview\\PNG"
    "OC\\Preview\\TXT"
    "OC\\Preview\\XBitmap"
    "OC\\Preview\\HEIC"
  ];
};
```

### Run nextcloud in a sub-directory

Say, you don't want to run nextcloud at `your.site/` but in a sub-directory `your.site/nextcloud/`. To do so, we are going to add more configurations to nextcloud and to nginx to [make](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) it a reverse-proxy.

First, define some overwritings. Nextcloud uses them to write out all URLs as if it runs in a sub-directory (which it is not.)

```nix
# /etc/nixos/configuration.nix
services.nextcloud = {
  settings = let
    prot = "http"; # or https
    host = "127.0.0.1";
    dir = "/nextcloud";
  in {
    overwriteprotocol = prot;
    overwritehost = host;
    overwritewebroot = dir;
    overwrite.cli.url = "${prot}://${host}${dir}/";
    htaccess.RewriteBase = dir;
  };
};
```

Make sure your nginx doesn't host nextcloud on your exposed port:

```nix
# /etc/nixos/configuration.nix
services.nginx.virtualHosts."${config.services.nextcloud.hostName}".listen = [ {
  addr = "127.0.0.1";
  port = 8080; # NOT an exposed port
} ];
```

Redirect some well-known URLs which have to be found at your.site/.well-known towards your new nextcloud URL:

```nix
# /etc/nixos/configuration.nix
services.nginx.virtualHosts."localhost" = {
  "^~ /.well-known" = {
            priority = 9000;
            extraConfig = ''
              absolute_redirect off;
              location ~ ^/\\.well-known/(?:carddav|caldav)$ {
                return 301 /nextcloud/remote.php/dav;
              }
              location ~ ^/\\.well-known/host-meta(?:\\.json)?$ {
                return 301 /nextcloud/public.php?service=host-meta-json;
              }
              location ~ ^/\\.well-known/(?!acme-challenge|pki-validation) {
                return 301 /nextcloud/index.php$request_uri;
              }
              try_files $uri $uri/ =404;
            '';
          };
};
```

Finally, forward `your.site/nextcloud/` (exposed port 80 or 443) to your unexposed nextcloud port 8080 (defined earlier):

```nix
# /etc/nixos/configuration.nix
services.nginx.virtualHosts."localhost" = {
  "/nextcloud/" = {
        priority = 9999;
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-NginX-Proxy true;
          proxy_set_header X-Forwarded-Proto http;
          proxy_pass http://127.0.0.1:8080/; # tailing / is important!
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
          proxy_redirect off;
        '';
      };
}
```

Note: If you have SSL (https) enabled, make sure nginx forwards to the correct port and nextcloud overwrites for the correct protocol.

### Use Caddy as webserver

Using a third-party module extension, the webserver Caddy can be used as an alternative by adding following options:

```nix
# /etc/nixos/configuration.nix
imports = [
  "${fetchTarball {
    url = "https://github.com/onny/nixos-nextcloud-testumgebung/archive/fa6f062830b4bc3cedb9694c1dbf01d5fdf775ac.tar.gz";
    sha256 = "0gzd0276b8da3ykapgqks2zhsqdv4jjvbv97dsxg0hgrhb74z0fs";}}/nextcloud-extras.nix"
];

services.nextcloud = {
  webserver = "caddy";
};
```

### Add users declaratively

Using a third-party module extension, additional users can be automatically configured using the `ensureUsers` option:

```nix
# /etc/nixos/configuration.nix
imports = [
  "${fetchTarball {
    url = "https://github.com/onny/nixos-nextcloud-testumgebung/archive/fa6f062830b4bc3cedb9694c1dbf01d5fdf775ac.tar.gz";
    sha256 = "0gzd0276b8da3ykapgqks2zhsqdv4jjvbv97dsxg0hgrhb74z0fs";}}/nextcloud-extras.nix"
];

environment.etc."nextcloud-user-pass".text = "PWD";

services.nextcloud = {
  ensureUsers = {
    user1 = {
      email = "user1@localhost";
      passwordFile = "/etc/nextcloud-user-pass";
    };
    user2 = {
      email = "user2@localhost";
      passwordFile = "/etc/nextcloud-user-pass";
    };
  };
};
```

## Troubleshooting

### Reading php logs

The [default Nextcloud setting](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/logging_configuration.html) is to log to syslog. To read php logs simply run:

```bash
# journalctl -t Nextcloud
```
