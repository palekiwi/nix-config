{
  services.home-assistant.config = {
    light = [
      {
        platform = "group";
        name = "Kitchen Lights";
        entities = [
          "light.kitchen_ceiling"
          "light.kitchen"
        ];
      }
      {
        platform = "group";
        name = "Salon All";
        entities = [
          "light.salon1"
          "light.salon2"
        ];
      }
      {
        platform = "group";
        name = "All";
        entities = [
          "light.bathroom"
          "light.desk"
          "light.kitchen"
          "light.kitchen_ceiling"
          "light.salon1"
          "light.salon2"
          "light.workbench"
        ];
      }
      {
        platform = "group";
        name = "Arrival";
        entities = [
          "light.desk"
          "light.salon"
          "light.workbench"
        ];
      }
      {
        platform = "group";
        name = "Study";
        entities = [
          "light.desk"
          "light.workbench"
        ];
      }
    ];
  };
}
