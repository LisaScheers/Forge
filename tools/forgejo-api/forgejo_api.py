"""Reuse Git's credential helpers for the Forgejo API, including token refresh."""

import argparse
import subprocess
import sys
import urllib.error
import urllib.request

HOST = "git.bylisa.dev"
CREDENTIAL = f"protocol=https\nhost={HOST}\nusername=Lisa\n\n"
OAUTH_HELPER = "@oauthHelper@"
OAUTH_CLIENT_ID = "@oauthClientId@"
OAUTH_SCOPES = "@oauthScopes@"


class NoRedirects(urllib.request.HTTPRedirectHandler):
    # Never forward the authorization header to a redirect destination.
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("endpoint", help="API path, or 'login' to authorize once")
    parser.add_argument("-X", "--method", default="GET")
    parser.add_argument("-d", "--data", help="JSON body; use '-' to read stdin")
    args = parser.parse_args()
    login = args.endpoint == "login"
    endpoint = "user" if login else args.endpoint.lstrip("/")
    if not endpoint or endpoint.startswith("api/") or "://" in endpoint:
        parser.error("use an API path such as user or repos/Lisa/STSTP-Controller")
    if login and (args.data is not None or args.method != "GET"):
        parser.error("login does not accept a method or body")

    # Match the packaged grant even before Home Manager has been activated.
    git = [
        "git",
        "-c",
        f"credential.https://{HOST}.oauthClientId={OAUTH_CLIENT_ID}",
        "-c",
        f"credential.https://{HOST}.oauthScopes={OAUTH_SCOPES}",
    ]
    if login:
        # Bypass the old grant for this call only. Approve still uses normal storage.
        for key, value in {
            "helper": "",
            "oauthAuthURL": "/login/oauth/authorize",
            "oauthTokenURL": "/login/oauth/access_token",
        }.items():
            git += ["-c", f"credential.https://{HOST}.{key}={value}"]
        git += ["-c", f"credential.https://{HOST}.helper={OAUTH_HELPER}"]
    credential = subprocess.run(
        [*git, "credential", "fill"],
        input=CREDENTIAL,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout
    fields = dict(line.split("=", 1) for line in credential.splitlines() if "=" in line)
    if not fields.get("password"):
        raise RuntimeError("Git did not return a Forgejo credential")
    # OAuth refresh can rotate the refresh token. Persist it before an API or
    # network error can lose it and send the next call back to a browser.
    subprocess.run(
        ["git", "credential", "approve"],
        input=credential + "\n",
        text=True,
        check=True,
    )
    body = sys.stdin.read() if args.data == "-" else args.data
    request = urllib.request.Request(
        f"https://{HOST}/api/v1/{endpoint}",
        data=body.encode() if body is not None else None,
        method=args.method,
        headers={
            "Authorization": f"Bearer {fields['password']}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        response = urllib.request.build_opener(NoRedirects()).open(request, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        if login and response.status == 200:
            print("Forgejo authorization saved in Git's credential storage.")
        else:
            sys.stdout.buffer.write(response.read())
            if response.status == 403:
                print(
                    "\nForgejo denied this request. Check account permissions and OAuth scopes.",
                    file=sys.stderr,
                )
        return 0 if 200 <= response.status < 300 else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (
        subprocess.CalledProcessError,
        urllib.error.URLError,
        RuntimeError,
    ) as error:
        print(f"forgejo-api: {error}", file=sys.stderr)
        sys.exit(1)
