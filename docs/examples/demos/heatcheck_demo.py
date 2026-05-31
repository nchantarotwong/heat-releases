"""Live demo fixture for heatcheck in VS Code."""
from flask import Flask, request
import sqlite3

app = Flask(__name__)
db = sqlite3.connect("app.db")


@app.route("/users")
def get_user():
    user_id = request.args["id"]
    cur = db.cursor()
    cur.execute(f"SELECT * FROM users WHERE id = {user_id}")
    return dict(cur.fetchone())
