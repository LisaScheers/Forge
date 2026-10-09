"""Link explicitly selected accounts through Jellyfin's API, after LDAP lookup succeeds."""

import json
from pathlib import Path
import sqlite3
import sys
import time
from urllib.error import URLError
from urllib.request import Request, urlopen
from uuid import UUID


LDAP_PROVIDER = "Jellyfin.Plugin.LDAP_Auth.LdapAuthenticationProviderPlugin"
LOCAL_PROVIDER = "Jellyfin.Server.Implementations.Users.DefaultAuthenticationProvider"
ACCOUNTS = {
    "lisa": "466f59ea-0289-49cc-a303-3f222ebec388",
    "rose": "35b31cb4-09f9-4d8a-8803-b8d8b6d8fe5d",
    "jade": "f35f8038-8cbe-4f2c-b31f-9dc14b927013",
    "esmee": "f8415972-20d5-4a12-9a55-221108b27637",
}


def link_accounts(request):
    users = request("GET", "/Users")
    # Validate every mapping before changing any policy. Never guess by display name.
    selected = []
    for username, user_id in ACCOUNTS.items():
        user = next((user for user in users if UUID(user["Id"]) == UUID(user_id)), None)
        if user is None or user["Name"] != username:
            raise ValueError(f"Jellyfin account identity changed: {username}")
        if user["Policy"]["AuthenticationProviderId"] not in (LOCAL_PROVIDER, LDAP_PROVIDER):
            raise ValueError(f"Unexpected authentication provider: {username}")
        result = request("POST", "/Ldap/LdapUserSearch", {
            "LdapSearchAttributes": "cn", "TestSearchUsername": username,
        })
        expected_dn = f"cn={username},ou=users,dc=jellyfin,dc=bylisa,dc=dev"
        if (result.get("LocatedDn") or "").lower() != expected_dn:
            raise ValueError(f"Authentik LDAP identity did not match: {username}")
        selected.append(user)

    for user in selected:
        policy = user["Policy"]
        if policy["AuthenticationProviderId"] == LDAP_PROVIDER:
            continue
        policy = {**policy, "AuthenticationProviderId": LDAP_PROVIDER}
        request("POST", f"/Users/{user['Id']}/Policy", policy)
        updated = request("GET", f"/Users/{user['Id']}")
        if updated["Policy"]["AuthenticationProviderId"] != LDAP_PROVIDER:
            raise ValueError(f"Link verification failed: {user['Name']}")
        print(f"Linked existing Jellyfin account: {user['Name']}")


def main(database):
    # Existing integration API keys already have administrator authority. Read one
    # locally without copying it into the Nix store, arguments, or logs.
    with sqlite3.connect(f"{Path(database).as_uri()}?mode=ro", uri=True) as connection:
        row = connection.execute("SELECT AccessToken FROM ApiKeys ORDER BY Id LIMIT 1").fetchone()
    if row is None:
        raise ValueError("An administrator API key is required to link Jellyfin accounts")

    def request(method, endpoint, data=None):
        body = None if data is None else json.dumps(data).encode()
        headers = {"X-Emby-Token": row[0], "Content-Type": "application/json"}
        with urlopen(Request("http://127.0.0.1:8096" + endpoint, body, headers, method=method), timeout=15) as response:
            content = response.read()
            return json.loads(content) if content else None

    for attempt in range(30):
        try:
            request("GET", "/System/Info")
            break
        except URLError:
            if attempt == 29:
                raise
            time.sleep(2)
    link_accounts(request)


if __name__ == "__main__":
    main(sys.argv[1])
