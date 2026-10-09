"""Configure LDAP before Jellyfin starts, preserving its account-link table."""

import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def configure(config_file, password):
    tree = ET.parse(config_file) if config_file.exists() else ET.ElementTree(ET.Element("PluginConfiguration"))
    root = tree.getroot()
    settings = {
        "LdapServer": "auth.bylisa.dev",
        "LdapPort": "636",
        "UseSsl": "true",
        "UseStartTls": "false",
        "SkipSslVerify": "false",
        "AllowPassChange": "false",
        "LdapBindUser": "cn=jellyfin-ldap,ou=users,dc=jellyfin,dc=bylisa,dc=dev",
        "LdapBindPassword": password,
        "LdapBaseDn": "dc=jellyfin,dc=bylisa,dc=dev",
        "LdapSearchFilter": "(&(objectClass=user)(memberOf=cn=jellyfin-users,ou=groups,dc=jellyfin,dc=bylisa,dc=dev))",
        "LdapAdminFilter": "_disabled_",
        "LdapSearchAttributes": "cn",
        "LdapUsernameAttribute": "cn",
        "LdapUidAttribute": "uid",
        "CreateUsersFromLdap": "false",
        "EnableLdapProfileImageSync": "false",
        "PasswordResetUrl": "https://auth.bylisa.dev/if/user/",
    }
    for key, value in settings.items():
        element = root.find(key)
        if element is None:
            element = ET.SubElement(root, key)
        element.text = value
    config_file.parent.mkdir(parents=True, exist_ok=True)
    temporary = config_file.with_suffix(".tmp")
    with temporary.open("wb") as output:
        os.chmod(temporary, 0o600)
        tree.write(output, encoding="utf-8", xml_declaration=True)
    temporary.replace(config_file)


if __name__ == "__main__":
    credential = Path(os.environ["CREDENTIALS_DIRECTORY"]) / "jellyfin-ldap-env"
    prefix = "JELLYFIN_LDAP_BIND_PASSWORD="
    password = next(line.removeprefix(prefix) for line in credential.read_text().splitlines() if line.startswith(prefix))
    if not password:
        raise ValueError("LDAP bind password is empty")
    configure(Path(sys.argv[1]), password)
