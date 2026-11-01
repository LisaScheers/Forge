{
  home.lisa-vega.programs.awscli = {
    enable = true;
    settings = {
      "profile lava-benchmark" = {
        sso_session = "lava-benchmark";
        sso_account_id = "173535830848";
        sso_role_name = "AdministratorAccess";
        region = "eu-central-1";
        output = "json";
      };
      "sso-session lava-benchmark" = {
        sso_start_url = "https://d-99674cfdb3.awsapps.com/start";
        sso_region = "eu-central-1";
        sso_registration_scopes = "sso:account:access";
      };
    };
  };
}
