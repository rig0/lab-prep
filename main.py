from modules.sysinfo import get_system_info
from modules.pushover import send_pushover_message

sysinfo = get_system_info()

def main():
    hostname = sysinfo.get("hostname")
    os = sysinfo.get("os")
    os_version = sysinfo.get("os_version")
    os_release = sysinfo.get("os_release")

    print("hello world")
    print(f"{hostname} {os} {os_version} {os_release}")

    send_pushover_message(
        f"Hello from: {hostname} - {os} ({os_version}) [{os_release}]",
        title="Lab Prep",
        priority=0
    )

if __name__ == "__main__":
    main()