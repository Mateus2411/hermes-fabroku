#!/usr/bin/env python3
"""Hermes Fabroku - Web Chat Interface"""

import subprocess
import json
import os
import re
import time
import html
import uuid
from flask import Flask, request, jsonify, render_template, session

app = Flask(__name__)
app.secret_key = os.urandom(32)

HERMES_HOME = os.environ.get("HERMES_HOME", "/root/.hermes")
SESSION_DIR = os.path.join(HERMES_HOME, "web_sessions")
os.makedirs(SESSION_DIR, exist_ok=True)

ANSI_RE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')


def strip_ansi(text):
    return ANSI_RE.sub('', text)


def get_web_session_id(flask_session_id):
    """Get the hermes session ID stored for this flask session"""
    fpath = os.path.join(SESSION_DIR, flask_session_id)
    if os.path.exists(fpath):
        with open(fpath) as f:
            return f.read().strip()
    return None


def save_web_session_id(flask_session_id, hermes_sid):
    with open(os.path.join(SESSION_DIR, flask_session_id), "w") as f:
        f.write(hermes_sid)


def get_latest_session():
    """Get the most recent hermes session ID"""
    result = subprocess.run(
        ["hermes", "sessions", "list", "--limit", "5"],
        capture_output=True, text=True, timeout=10,
        env={**os.environ, "HERMES_HOME": HERMES_HOME}
    )
    for line in result.stdout.strip().split("\n"):
        parts = line.strip().split()
        if parts and len(parts[0]) > 15 and "_" in parts[0]:
            return parts[0]
    return None


def run_hermes(message, resume_sid=None):
    """Execute hermes with the given message and return (response, session_id)"""
    cmd = ["hermes", "-Q"]

    if resume_sid:
        cmd.extend(["--resume", resume_sid])
    else:
        # Force start new session with named label
        cmd.extend(["-c", "fabroku-web"])

    cmd.extend(["-q", message])

    env = {**os.environ, "HERMES_HOME": HERMES_HOME, "TERM": "xterm-256color"}

    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=180, env=env
    )

    stdout = strip_ansi(result.stdout or "")
    stderr = strip_ansi(result.stderr or "")

    # Try to extract the actual response (skip informational lines)
    lines = stdout.split("\n")
    response_lines = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if any(skip in line.lower() for skip in [
            "loading", "banner", "hermes", "session", "starting",
            "tool", "using model", "/help"
        ]):
            # Only skip if it looks like system output
            if len(line) < 120 and not line.startswith(("```", "Olá", "Você", "Oi")):
                continue
        response_lines.append(line)

    response_text = "\n".join(response_lines) if response_lines else stdout.strip()

    # Get the session ID of this conversation
    time.sleep(0.3)
    new_sid = get_latest_session()

    return response_text, new_sid


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    return jsonify({"status": "ok", "ts": time.time()})


@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.get_json(force=True)
    message = data.get("message", "").strip()
    if not message:
        return jsonify({"error": "Mensagem vazia"}), 400

    # Create or get flask session
    sid = session.get("sid")
    if not sid:
        sid = str(uuid.uuid4())
        session["sid"] = sid

    # Get existing hermes session for this web session
    hermes_sid = get_web_session_id(sid)
    is_new = hermes_sid is None

    try:
        response_text, new_hermes_sid = run_hermes(message, resume_sid=hermes_sid)

        if new_hermes_sid and new_hermes_sid != hermes_sid:
            save_web_session_id(sid, new_hermes_sid)

        return jsonify({
            "response": response_text,
            "session_id": new_hermes_sid or hermes_sid,
            "new": is_new
        })

    except subprocess.TimeoutExpired:
        return jsonify({"error": "Tempo limite excedido. Tente novamente."}), 504
    except Exception as e:
        return jsonify({"error": f"Erro: {str(e)}"}), 500


@app.route("/api/reset", methods=["POST"])
def reset():
    sid = session.get("sid")
    if sid:
        fpath = os.path.join(SESSION_DIR, sid)
        if os.path.exists(fpath):
            os.remove(fpath)
    session.clear()
    return jsonify({"status": "ok"})


if __name__ != "__main__":
    # Gunicorn mode
    pass
