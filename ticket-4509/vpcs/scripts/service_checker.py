import socket
import requests
from requests.exceptions import RequestException

# Service details
SERVICES = [
    {"name": "twiz-brie", "namespace": "twiz-brie", "service": "twiz-brie-service", "ports": [80, 443]},
    {"name": "vertex-edge", "namespace": "vertex-edge", "service": "vertex-edge-service", "ports": [8585]},
    {"name": "twedds", "namespace": "twedds", "service": "twedds-service", "ports": [80, 443]},
]

# Placeholder API paths (to be updated with actual paths)
API_PATHS = ["/", "/health", "/status"]

def check_dns_resolution(service_name, namespace):
    """
    Check if the service DNS resolves.
    """
    dns_name = f"{service_name}.{namespace}.svc.cluster.local"
    try:
        ip = socket.gethostbyname(dns_name)
        print(f"[DNS] {dns_name} resolved to {ip}")
        return ip
    except socket.gaierror as e:
        print(f"[DNS] {dns_name} resolution failed: {e}")
        return None

def check_tcp_connectivity(ip, port):
    """
    Check if a TCP connection can be established.
    """
    try:
        with socket.create_connection((ip, port), timeout=3):
            print(f"[TCP] Connection to {ip}:{port} succeeded")
            return True
    except (socket.timeout, socket.error) as e:
        print(f"[TCP] Connection to {ip}:{port} failed: {e}")
        return False

def check_http_endpoint(ip, port, path):
    """
    Check if the HTTP endpoint responds.
    """
    url = f"http://{ip}:{port}{path}"
    try:
        response = requests.get(url, timeout=3)
        print(f"[HTTP] {url} returned status {response.status_code}")
        return response.status_code
    except RequestException as e:
        print(f"[HTTP] {url} failed: {e}")
        return None

def main():
    for service in SERVICES:
        print(f"\nChecking service: {service['name']}")
        ip = check_dns_resolution(service["service"], service["namespace"])
        if not ip:
            continue

        for port in service["ports"]:
            if not check_tcp_connectivity(ip, port):
                continue

            for path in API_PATHS:
                check_http_endpoint(ip, port, path)

if __name__ == "__main__":
    main()
