{ config, lib, options, pkgs, ... }:

let

  inherit (lib)
    mergeEqualOption
    mkDefault
    mkIf
    mkOption
    types
  ;
  cfg = config.mobile.boot.stage-1.kernel;
  device_config = config.mobile.device;

  modulesClosure = pkgs.makeModulesClosure {
    kernel = cfg.package;
    allowMissing = true;
    rootModules = cfg.modules ++ cfg.additionalModules;
    firmware = cfg.firmwares;
  };
in
{
  # Note: These options are provided  *instead* of `boot.initrd.*`, as we are
  # not re-using the `initrd` options.
  options.mobile.boot.stage-1.kernel = {
    modular = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether the kernel is built with modules or not.
        This will enable modules closure generation and listing modules
        to bundle and load.
      '';
    };
    modules = mkOption {
      type = types.listOf types.str;
      default = [
      ];
      description = ''
        Module names to add to the closure.
        They will be modprobed.
      '';
    };
    additionalModules = mkOption {
      type = types.listOf types.str;
      default = [
      ];
      description = ''
        Module names to add to the closure.
        They will not be modprobed.
      '';
    };
    firmwares = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Firmwares to add to the closure.
      '';
    };
    # We cannot use `linuxPackagesFor` as older kernels cause eval-time assertions...
    # This is bad form, but is already in nixpkgs :(.
    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Kernel to be used by the system-type to boot into the Mobile NixOS
        stage-1.

        This is not using a kernelPackages attrset, but a kernel derivation directly.
      '';
    };
  };

  config.mobile.boot.stage-1 = (mkIf cfg.modular {
    firmware = [ modulesClosure ];
    contents = [
      { object = "${modulesClosure}/lib/modules"; symlink = "/lib/modules"; }
    ];
    kernel.modules = [
      # Basic always-needed kernel modules.
      "loop"

      # Filesystems
      "nls_cp437"
      "nls_iso8859-1"
      "fat"
      "vfat"

      "ext4"
      "crc32c"
    ];
  });

  config.boot.kernelPackages = mkDefault (
    if (config.mobile.rootfs.shared.enabled || cfg.package == null)
    then {
      # This must look legit enough so that NixOS thinks it's a kernel attrset.
      stdenv = pkgs.stdenv;
      kernel = pkgs.runCommandNoCC "dummy" { version = "99"; } "mkdir $out; touch $out/dummy";
    }
    else (pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor config.mobile.boot.stage-1.kernel.package))
  );

  # Disable kernel config checks as it's EXTREMELY nixpkgs-kernel centric.
  # We're duplicating that good work for the time being.
  config.system.requiredKernelConfig = lib.mkForce [];
}

