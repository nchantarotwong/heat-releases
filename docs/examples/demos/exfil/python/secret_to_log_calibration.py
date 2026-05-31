import logging
import os


def audit_startup() -> None:
    secret_value = os.environ["DEPLOY_SECRET"]
    logging.info("deployment secret: %s", secret_value)


if __name__ == "__main__":
    audit_startup()

