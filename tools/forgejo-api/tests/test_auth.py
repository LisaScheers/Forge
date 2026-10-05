import contextlib
import io
import subprocess
import sys
import unittest
import urllib.error
from unittest.mock import patch

import forgejo_api


class AuthTests(unittest.TestCase):
    credential = (
        "protocol=https\nhost=git.bylisa.dev\nusername=Lisa\n"
        "password=access-token\npassword_expiry_utc=9999999999\n"
        "oauth_refresh_token=rotated-refresh-token\n"
    )

    def invoke(self, status, *args):
        response = io.BytesIO(b'{"login":"Lisa"}')
        response.status = status
        output = io.TextIOWrapper(io.BytesIO(), write_through=True)
        with (
            patch.object(sys, "argv", ["forgejo-api", *args]),
            patch.object(sys, "stdout", output),
            contextlib.redirect_stderr(io.StringIO()),
            patch.object(subprocess, "run") as run,
            patch.object(forgejo_api.urllib.request, "build_opener") as build_opener,
        ):
            run.return_value.stdout = self.credential
            if status >= 400:
                build_opener.return_value.open.side_effect = urllib.error.HTTPError(
                    "https://git.bylisa.dev/api/v1/user", status, "Error", {}, response
                )
            else:
                build_opener.return_value.open.return_value = response
            result = forgejo_api.main()
            output.seek(0)
            self.assertNotIn("access-token", output.read())
        return result, run.call_args_list, build_opener.return_value.open.call_args

    def test_success_stores_rotated_refresh_token_without_exposing_it_in_arguments(
        self,
    ):
        result, calls, request_call = self.invoke(200, "user")
        self.assertEqual(result, 0)
        self.assertEqual(calls[0].args[0][-2:], ["credential", "fill"])
        self.assertEqual(calls[1].args[0], ["git", "credential", "approve"])
        self.assertEqual(calls[1].kwargs["input"], self.credential + "\n")
        request = request_call.args[0]
        self.assertEqual(request.get_header("Authorization"), "Bearer access-token")
        self.assertNotIn("access-token", request.full_url)

    def test_scope_denial_preserves_refresh_token(self):
        result, calls, _ = self.invoke(403, "user")
        self.assertEqual(result, 1)
        self.assertEqual(calls[1].args[0], ["git", "credential", "approve"])
        self.assertIn(
            "oauth_refresh_token=rotated-refresh-token", calls[1].kwargs["input"]
        )
        self.assertEqual(len(calls), 2)  # No rejection or automatic browser login.

    def test_missing_repo_preserves_refresh_token(self):
        _, calls, _ = self.invoke(404, "repos/Lisa/new")
        self.assertEqual(calls[1].args[0], ["git", "credential", "approve"])

    def test_unauthorized_request_does_not_discard_credentials_or_reauthorize(self):
        result, calls, _ = self.invoke(401, "user")
        self.assertEqual(result, 1)
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[1].args[0], ["git", "credential", "approve"])

    def test_api_network_failure_keeps_rotated_refresh_token(self):
        with (
            patch.object(sys, "argv", ["forgejo-api", "user"]),
            patch.object(subprocess, "run") as run,
            patch.object(forgejo_api.urllib.request, "build_opener") as build_opener,
        ):
            run.return_value.stdout = self.credential
            build_opener.return_value.open.side_effect = urllib.error.URLError(
                "offline"
            )
            with self.assertRaises(urllib.error.URLError):
                forgejo_api.main()
            self.assertEqual(run.call_args.args[0], ["git", "credential", "approve"])
            self.assertIn(
                "oauth_refresh_token=rotated-refresh-token",
                run.call_args.kwargs["input"],
            )

    def test_expanded_login_bypasses_old_grant_then_uses_normal_storage(self):
        result, calls, _ = self.invoke(200, "login")
        self.assertEqual(result, 0)
        self.assertIn("credential.https://git.bylisa.dev.helper=", calls[0].args[0])
        self.assertIn(
            "credential.https://git.bylisa.dev.oauthScopes=" + forgejo_api.OAUTH_SCOPES,
            calls[0].args[0],
        )
        self.assertEqual(calls[1].args[0], ["git", "credential", "approve"])

    def test_redirect_does_not_forward_credentials(self):
        handler = forgejo_api.NoRedirects()
        self.assertIsNone(
            handler.redirect_request(None, None, 302, "", {}, "https://other.test")
        )


if __name__ == "__main__":
    unittest.main()
