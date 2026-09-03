{ lib, ... }:
let
  inherit (lib.hm.gvariant)
    mkArray
    mkDictionaryEntry
    mkDouble
    mkTuple
    mkVariant
    ;

  colors = {
    base00 = [ 0 43 54 ];
    base01 = [ 7 54 66 ];
    base02 = [ 88 110 117 ];
    base03 = [ 101 123 131 ];
    base04 = [ 131 148 150 ];
    base05 = [ 147 161 161 ];
    base06 = [ 238 232 213 ];
    base07 = [ 253 246 227 ];
    base08 = [ 220 50 47 ];
    base09 = [ 203 75 22 ];
    base0A = [ 181 137 0 ];
    base0B = [ 133 153 0 ];
    base0C = [ 42 161 152 ];
    base0D = [ 38 139 210 ];
    base0E = [ 108 113 196 ];
    base0F = [ 211 54 130 ];
  };
  solarizedDarkUuid = "043f5921-e1fb-4f08-91b1-6f9e936b85a7";
  rgb =
    name:
    mkTuple (
      map (value: mkDouble (value / 255.0)) colors.${name}
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
      value = mkDouble 0.0;
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
    transparency = false;
    use-system-font = true;
  };
}
