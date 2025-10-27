#!/usr/bin/env python3
import os
import requests
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

PUSHOVER_API_URL = "https://api.pushover.net/1/messages.json"
PUSHOVER_USER = os.getenv("PUSHOVER_USR")
PUSHOVER_TOKEN = os.getenv("PUSHOVER_APP")

if not PUSHOVER_USER or not PUSHOVER_TOKEN:
    print("[Error] Missing PUSHOVER_USR or PUSHOVER_APP in .env")
    exit(1)

def send_pushover_message(message, **kwargs):
    """
    Send a message via Pushover with optional parameters.
    Full API docs: https://pushover.net/api
    """
    payload = {
        "token": PUSHOVER_TOKEN,
        "user": PUSHOVER_USER,
        "message": message,
        # Optional parameters
        "device": kwargs.get("device"),           # Target device name(s)
        "title": kwargs.get("title"),             # Custom title
        "url": kwargs.get("url"),                 # Supplemental URL
        "url_title": kwargs.get("url_title"),     # Title for the URL
        "priority": kwargs.get("priority", 0),    # -2 to 2
        "timestamp": kwargs.get("timestamp"),     # UNIX timestamp
        "sound": kwargs.get("sound"),             # Notification sound
        "html": kwargs.get("html", 0),            # 1 = allow HTML
        "retry": kwargs.get("retry"),             # Required for priority=2
        "expire": kwargs.get("expire"),           # Required for priority=2
        "callback": kwargs.get("callback"),       # Callback URL for emergency messages
    }

    # Remove None values
    payload = {k: v for k, v in payload.items() if v is not None}

    try:
        response = requests.post(PUSHOVER_API_URL, data=payload, timeout=10)
        response.raise_for_status()
        data = response.json()

        if data.get("status") == 1:
            print("[Pushover] Message sent successfully!")
        else:
            print("[Pushover] API returned non-success status:", data)

        #print("Response:", data)

    except requests.exceptions.RequestException as e:
        print("[Error] Failed to send Pushover message:", e)

if __name__ == "__main__":
    send_pushover_message(
        "Hello from Python!",
        title="Test Notification",
        url="https://example.com",
        url_title="Visit Example",
        priority=0,
        sound="magic",
        html=1
    )
