{ lib, ... }:
{
  services = {
    # nixos-hardware's System76 module enables system76-power. Do not run the
    # overlapping GNOME power-profiles daemon alongside it.
    power-profiles-daemon.enable = lib.mkForce false;
    system76-scheduler.enable = true;
  };
}
