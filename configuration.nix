{ config, lib, pkgs, inputs, ... }:

let
  # Dérivation pour ChalKak (outil de capture/screenshot)
  chalkak = pkgs.stdenv.mkDerivation rec {
    pname = "chalkak";
    version = "0.5.2";
    src = pkgs.fetchurl {
      url = "https://github.com/BitYoungjae/ChalKak/releases/download/v${version}/chalkak-x86_64-unknown-linux-gnu.tar.gz";
      sha256 = "sha256-pbW/RvGX3sdBa2/auZVErrf4EuMxMRIp4DOrlTtuMTQ=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [ gtk4 libadwaita wayland glib ];
    sourceRoot = ".";
    installPhase = ''install -m755 -D chalkak $out/bin/chalkak'';
  };
in
{
  imports = [ 
    ./hardware-configuration.nix 
  ];

  # --- MAINTENANCE & NIX SETTINGS ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nixpkgs.config.allowUnfree = true;

  # --- BOOT & NOYAU (ZEN & LOW-LATENCY) ---
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  boot.consoleLogLevel = 3;
  boot.kernelParams = [ 
    "quiet" 
    "systemd.show_status=auto" 
    "rd.udev.info_cleanup_force=0"
    "usbcore.autosuspend=-1" 
    "intel_pstate=active"     
  ];

  # --- RÉSEAU (IWD UNIQUEMENT - ULTRA LÉGER) ---
  networking.hostName = "djmorganorix";
  networking.networkmanager.enable = false; # On bannit NetworkManager
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.AddressRandomization = "once";
      Network.EnableIPv6 = true;
    };
  };

  # --- LOCALISATION & CONSOLE ---
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  console = {
    earlySetup = true;
    font = "ter-v32n";
    packages = with pkgs; [ terminus_font ];
    useXkbConfig = true;
  };

  # --- MATÉRIEL SPÉCIFIQUE DELL / INTEL ---
  zramSwap.enable = true;
  hardware.enableAllFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
    ];
  };

  # --- BLUETOOTH (BLUEZ VIA CLI) ---
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # Économise du CPU, à activer manuellement via bluetoothctl
    settings = {
      General = {
        Experimental = true; # Pour de meilleures perfs audio BT si besoin
      };
    };
  };

  services.thermald.enable = true; 
  services.libinput.enable = true; 
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.journald.extraConfig = "SystemMaxUse=50M\nRuntimeMaxUse=30M";

  # --- AUDIO & BASSE LATENCE (MIXXX & ICECAST) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;      
        "default.clock.min-quantum" = 64;
        "default.clock.max-quantum" = 512;
      };
    };
  };

  security.pam.loginLimits = [
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
  ];

  # --- INTERFACE & GREETD ---
  programs.hyprland.enable = true;
  programs.dconf.enable = true;
  programs.regreet.enable = true;
  
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.dbus}/bin/dbus-run-session ${pkgs.greetd.regreet}/bin/regreet";
        user = "greeter";
      };
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  # --- GESTIONNAIRE DE FICHIERS ---
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  
  environment.pathsToLink = [
    "/share/gsettings-schemas"
    "/share/thumbnailers"
  ];

  # --- STOCKAGE & MUSIQUE ---
  fileSystems."/mnt/music_save" = {
    device = "/dev/disk/by-label/MUSIC_SAVE";
    fsType = "btrfs";
    options = [ "compress=zstd" "nofail" "noatime" "user" ];
  };
  
  services.udev.packages = [ pkgs.mixxx ];

  # --- UTILISATEUR & PAQUETS ---
  programs.fish.enable = true;
  users.users.djmorganorix = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "video" "audio" ];
    initialPassword = "azerty";
    packages = with pkgs; [
      # Outils Système & Réseau CLI
      brightnessctl usbutils psmisc btrfs-progs alsa-utils
      git btop fastfetch jq python3 wl-clipboard
      unzip zip xarchiver
      
      # Réseau et BT (CLI uniquement)
      bluez       # Fournit bluetoothctl
      # iwd est déjà fourni par services.iwd
      
      # Audio & Monitoring
      mixxx
      pavucontrol
      helvum         
      pw-visage      
      
      # UI & Apps
      foot
      swaybg
      rofi
      playerctl
      grim
      slurp
      libnotify
      zathura
      imv
      adwaita-icon-theme
      
      # Browser
      inputs.zen-browser.packages.x86_64-linux.default
      
      # Custom
      eww
      chalkak
    ];
  };

  # --- ÉDITEUR & CLAVIER ---
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  # --- POLICES ---
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      font-awesome
    ];
    fontconfig.enable = true;
  };

  # --- VARIABLES D'ENVIRONNEMENT ---
  environment.variables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
  };

  # --- POWER MANAGEMENT ---
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "performance"; 

  documentation.enable = false;
  documentation.nixos.enable = false;

  system.stateVersion = "24.11"; 
}
