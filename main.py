from modules.sysinfo import get_system_info

sysinfo = get_system_info()

def main():
    hostname = sysinfo.get("hostname")
    os = sysinfo.get("os")
    os_version = sysinfo.get("os_version")
    os_release = sysinfo.get("os_release")

    print("hello world")
    print(f"{hostname} {os} {os_version} {os_release}")

if __name__ == "__main__":
    main()