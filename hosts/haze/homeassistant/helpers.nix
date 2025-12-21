{
  services.home-assistant.config = {
    input_number = {
      brightness_lock = {
        name = "Brightness Lock";
        initial = false;
      };
    };

    input_number = {
      base_brightness = {
        name = "Base Brightness";
        initial = 100;
        min = 1;
        max = 100;
        step = 1;
        unit_of_measurement = "%";
        icon = "mdi:brightness-7";
      };

      base_kelvin = {
        name = "Base Kelvin";
        initial = 4000;
        min = 2202;
        max = 4000;
        step = 1;
        icon = "mdi:temperature-kelvin";
      };
    };
  };
}
