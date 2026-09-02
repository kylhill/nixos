{ config, lib, ... }:
let
  inherit (lib.hm.gvariant)
    mkArray
    mkDictionaryEntry
    mkDouble
    mkTuple
    mkVariant
    ;

  colors = config.lib.stylix.colors;
  solarizedDarkUuid = "043f5921-e1fb-4f08-91b1-6f9e936b85a7";
  rgb =
    name:
    mkTuple (
      map mkDouble [
        (lib.toInt colors."${name}-rgb-r" / 255.0)
        (lib.toInt colors."${name}-rgb-g" / 255.0)
        (lib.toInt colors."${name}-rgb-b" / 255.0)
      ]
    );
  dictionary =
    entries:
    mkArray "{sv}" (
      map (
        entry:
        mkDictionaryEntry [
          entry.name
          (mkVariant entry.value)
        ]
      ) entries
    );
  palette = dictionary [
    {
      name = "foreground";
      value = rgb "base04";
    }
    {
      name = "background";
      value = rgb "base00";
    }
    {
      name = "transparency";
      value = mkDouble (1.0 - config.stylix.opacity.terminal);
    }
    {
      name = "colours";
      value = mkArray "(ddd)" (
        map rgb [
          "base01"
          "base08"
          "base0B"
          "base0A"
          "base0D"
          "base0F"
          "base0C"
          "base06"
          "base00"
          "base09"
          "base02"
          "base03"
          "base04"
          "base0E"
          "base05"
          "base07"
        ]
      );
    }
  ];
in
{
  dconf.settings."org/gnome/Console" = {
    custom-font = "${config.stylix.fonts.monospace.name} ${toString config.stylix.fonts.sizes.terminal}";
    custom-liveries = dictionary [
      {
        name = solarizedDarkUuid;
        value = dictionary [
          {
            name = "uuid";
            value = solarizedDarkUuid;
          }
          {
            name = "name";
            value = "Solarized Dark";
          }
          {
            name = "night";
            value = palette;
          }
        ];
      }
    ];
    ignore-scrollback-limit = true;
    livery = solarizedDarkUuid;
    theme = "night";
    transparency = true;
    use-system-font = false;
  };
}
