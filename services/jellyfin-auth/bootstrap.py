"""Create missing Authentik accounts once, without resetting existing passwords."""

import os


def bootstrap_users(user_model, environment):
    for username in ("jade", "esmee"):
        user, created = user_model.objects.get_or_create(
            username=username,
            defaults={"name": username.capitalize(), "type": "internal", "path": "users"},
        )
        if created:
            user.set_password(environment[f"JELLYFIN_{username.upper()}_INITIAL_PASSWORD"])
            user.save()


if __name__ == "__main__":
    from django.db import transaction
    from authentik.core.models import User

    with transaction.atomic():
        bootstrap_users(User, os.environ)
