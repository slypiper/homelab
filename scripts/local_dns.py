#!/usr/bin/env python3

import argparse
import sys
import os
import subprocess
import ipaddress
from halo import Halo

RESET  = "\033[0m"
BOLD   = "\033[1m"
YELLOW = "\033[33m"
RED    = "\033[31m"
CYAN   = "\033[36m"
WHITE  = "\033[97m"

IS_TTY = sys.stdout.isatty()

def log_success(text: str):
    if IS_TTY: Halo().succeed(f"{BOLD}{text}{RESET}")
    else: print(f"✔ {BOLD}{text}{RESET}")

def log_fail(text: str):
    if IS_TTY: Halo().fail(f"{BOLD}{RED}{text}{RESET}")
    else: print(f"✘ {BOLD}{RED}{text}{RESET}")

def log_warn(text: str):
    if IS_TTY: Halo().warn(f"{BOLD}{YELLOW}{text}{RESET}")
    else: print(f"⚠ {BOLD}{YELLOW}{text}{RESET}")

def log_info(text: str):
    if IS_TTY: Halo().info(f"{BOLD}{CYAN}{text}{RESET}")
    else: print(f"ℹ {BOLD}{CYAN}{text}{RESET}")

def load_lines(path):
    with open(path, 'r') as f:
        return f.readlines()

def save_lines(path, lines):
    with open(path, 'w') as f:
        f.writelines(lines)

def find_dns_hosts_bounds(lines):
    in_dns = False
    in_hosts = False
    start_index = -1
    end_index = -1

    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('[dns]'):
            in_dns = True
        elif stripped.startswith('[') and in_dns:
            break
            
        if in_dns and stripped.startswith('hosts = ['):
            in_hosts = True
            start_index = i
            continue
        
        if in_hosts and stripped.startswith(']'):
            end_index = i
            break
            
    return start_index, end_index

def add_host(lines, ip, hostname, force=False):
    start_index, end_index = find_dns_hosts_bounds(lines)
    if start_index == -1 or end_index == -1:
        log_fail("CRITICAL: Could not find [dns] hosts array in config.")
        return False, lines

    conflicts = []
    
    # Check if exists
    for i in range(start_index + 1, end_index):
        line_clean = lines[i].strip().rstrip(',').strip('"').strip()
        if not line_clean:
            continue
            
        parts = line_clean.split(maxsplit=1)
        if len(parts) == 2:
            existing_ip, existing_host = parts[0], parts[1]
        else:
            existing_ip, existing_host = '', line_clean

        if existing_ip == ip and existing_host == hostname:
            log_warn(f"SKIP: Record for {ip} {hostname} already exists.")
            return "exists", lines
            
        if existing_ip == ip or existing_host == hostname:
            conflicts.append(line_clean)

    if conflicts and not force:
        try:
            print(f"Found {len(conflicts)} existing record(s) using this IP or Hostname:")
            for c in conflicts:
                print(f"  {c}")
            choice = input(f"\n{BOLD}Are you sure you want to add this new record anyway? [y/N] {RESET}").strip().lower()
            if choice not in ('y', 'yes'):
                log_fail("Cancelled by user.")
                return "cancel", lines
        except (EOFError, KeyboardInterrupt):
            print()
            log_fail("Cancelled.")
            return "cancel", lines

    # Add it right before the end bracket
    insert_index = end_index
    
    if insert_index > start_index + 1:
        prev = lines[insert_index - 1].rstrip('\n')
        if not prev.endswith(','):
            lines[insert_index - 1] = prev + ',\n'

    lines.insert(insert_index, f'    "{ip} {hostname}",\n')
    log_success(f"ADDED: {ip} {hostname}")
    return "added", lines

def remove_host(lines, target, force=False):
    start_index, end_index = find_dns_hosts_bounds(lines)
    if start_index == -1 or end_index == -1:
        log_fail("CRITICAL: Could not find [dns] hosts array in config.")
        return False, lines
        
    removed = False
    remove_indices = []
    
    for i in range(start_index + 1, end_index):
        if target in lines[i]:
            remove_indices.append(i)
            removed = True

    if not removed:
        log_warn(f"No matches found for '{target}'.")
        return "not_found", lines

    if not force:
        try:
            print(f"Found {len(remove_indices)} record(s) matching '{target}':")
            for i in remove_indices:
                print(f"  {lines[i].strip().rstrip(',')}")
            choice = input(f"\n{BOLD}Would you like to remove the above references? [Y/n] {RESET}").strip().lower()
            if choice not in ('', 'y', 'yes'):
                log_fail("Cancelled by user.")
                return "cancel", lines
        except (EOFError, KeyboardInterrupt):
            print()
            log_fail("Cancelled.")
            return "cancel", lines

    # Remove the lines (reversed so indices don't shift during deletion)
    for line_index in reversed(remove_indices):
        del lines[line_index]
        
    # Fix potential trailing commas on the new last element
    new_end_index = end_index - len(remove_indices)
    last_item_index = new_end_index - 1
    
    if last_item_index > start_index:
        line = lines[last_item_index]
        if line.endswith(',\n'):
            lines[last_item_index] = line[:-2] + '\n'

    log_success(f"Successfully removed {len(remove_indices)} record(s) matching '{target}'.")
    return "removed", lines

def list_hosts(lines):
    start_index, end_index = find_dns_hosts_bounds(lines)
    if start_index == -1 or end_index == -1:
        log_fail("CRITICAL: Could not find [dns] hosts array in config.")
        return

    records = []
    for i in range(start_index + 1, end_index):
        line = lines[i].strip().rstrip(',').strip('"').strip()
        if line:
            parts = line.split(maxsplit=1)
            if len(parts) == 2:
                records.append({'ip': parts[0], 'hostname': parts[1]})
            else:
                records.append({'ip': '', 'hostname': line})

    if not records:
        log_warn("No local DNS records found in Pi-hole config.")
        return
        
    # Sort mathematically by IPv4 (e.g., 10 before 200, instead of 200 before 30)
    def ip_key(r):
        parts = r['ip'].split('.')
        if len(parts) == 4 and all(p.isdigit() for p in parts):
            return tuple(int(p) for p in parts)
        return (255, 255, 255, 255) # push invalid/empty IPs to the bottom

    records.sort(key=ip_key)
        
    log_info(f"Local DNS Records ({len(records)}):")
    for r in records:
        print(f"  {CYAN}{r['ip']:<16}{RESET} {BOLD}{r['hostname']}{RESET}")
    print()

def trigger_reload(docker_host: str) -> None:
    """Triggers the Pi-hole DNS reload natively without container restart."""
    msg = f"Reloading Pi-hole DNS on {docker_host}..."
    spinner = None
    if IS_TTY:
        spinner = Halo(text=msg, color='cyan').start()
    else:
        print(f"ℹ {BOLD}{msg}{RESET}")

    try:
        script = 'docker exec $(docker ps -q -f name=dns_pihole | head -n 1) pihole reloaddns'
        subprocess.run(
            ["ssh", "-q", docker_host, script], 
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        if spinner: spinner.succeed(f"{BOLD}RELOAD: Pi-hole effectively reloaded.{RESET}")
        else: print(f"✔ {BOLD}RELOAD: Pi-hole effectively reloaded.{RESET}")
    except subprocess.CalledProcessError:
        if spinner: spinner.fail(f"{BOLD}{RED}RELOAD: Failed to reload dns_pihole.{RESET}")
        else: print(f"✘ {BOLD}{RED}RELOAD: Failed to reload dns_pihole.{RESET}")

def verify_dns(hostname: str, expect_found: bool = True) -> None:
    spinner = None
    msg = f"Verifying DNS record for {hostname}..."
    if IS_TTY:
        print()
        spinner = Halo(text=msg, color='cyan').start()
    else:
        print(f"ℹ {BOLD}{msg}{RESET}")

    try:
        result = subprocess.run(
            ["dig", "@192.168.86.2", hostname],
            capture_output=True,
            text=True,
            check=False
        )
        
        lines = result.stdout.split('\n')
        in_answer = False
        answer_lines = []
        
        for line in lines:
            if line.startswith(';; ANSWER SECTION:'):
                in_answer = True
                answer_lines.append(line)
            elif in_answer and line.startswith(';;'):
                break
            elif in_answer and line.strip():
                answer_lines.append(line)
                
        if len(answer_lines) > 1:
            if expect_found:
                if spinner: spinner.succeed(f"{BOLD}DNS Record Found:{RESET}")
                else: print(f"✔ {BOLD}DNS Record Found:{RESET}")
                print("\n" + "\n".join(answer_lines) + "\n")
            else:
                if spinner: spinner.fail(f"{BOLD}DNS record still exists for {hostname}!{RESET}")
                else: print(f"✘ {BOLD}DNS record still exists for {hostname}!{RESET}")
                print("\n" + "\n".join(answer_lines) + "\n")
        else:
            if expect_found:
                if spinner: spinner.warn(f"{BOLD}No DNS record found for {hostname}{RESET}\n")
                else: print(f"⚠ {BOLD}No DNS record found for {hostname}{RESET}\n")
            else:
                if spinner: spinner.succeed(f"{BOLD}No DNS record found for {hostname} (Successfully removed){RESET}\n")
                else: print(f"✔ {BOLD}No DNS record found for {hostname} (Successfully removed){RESET}\n")
            
    except Exception as e:
        if spinner: spinner.fail(f"{BOLD}{RED}DNS verification failed: {str(e)}{RESET}\n")
        else: print(f"✘ {BOLD}{RED}DNS verification failed: {str(e)}{RESET}\n")

def main():
    parser = argparse.ArgumentParser(description="Manage Pi-hole local DNS records")
    parser.add_argument('--config', default='/data/docker/pihole/config/pihole.toml', help='Path to pihole.toml')
    parser.add_argument('--docker-host', default='once', help='Docker swarm node host to run the reload command on')
    parser.add_argument("--noreload", action="store_true", help="Do not trigger reload of the pihole DNS service")
    parser.add_argument("--force", action="store_true", help="Force default selection at any prompt")
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('-l', '--list', action='store_true', help='List all configured Pi-hole local DNS records')
    group.add_argument('--add', nargs=2, metavar=('IP', 'HOSTNAME'), help='Add a local DNS record')
    group.add_argument('--remove', nargs='+', metavar='TARGET', help='Remove a local DNS record by IP or Hostname')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.config):
        log_fail(f"DEPENDENCY: Config file not found at {args.config}")
        sys.exit(1)
        
    lines = load_lines(args.config)
    
    if args.list:
        list_hosts(lines)
        sys.exit(0)
        
    changed = False
    target_host = None
    
    if args.add:
        ip, hostname = args.add
        
        try:
            ipaddress.ip_address(ip)
        except ValueError:
            log_fail(f"INVALID RECORD: '{ip}' is not a properly formatted IP Address. Did you forget to provide it?")
            sys.exit(1)
            
        if hostname.startswith('-'):
            log_fail(f"INVALID RECORD: '{hostname}' looks like a flag. Did you forget to provide the IP Address?")
            sys.exit(1)
            
        status, lines = add_host(lines, ip, hostname, force=args.force)
        if status in ("added", "exists"):
            target_host = hostname
            expect_found = True
            changed = (status == "added")
        else:
            target_host = None
            changed = False
            
    elif args.remove:
        remove_term = " ".join(args.remove)
        status, lines = remove_host(lines, remove_term, force=args.force)
        
        if status == "removed":
            target_host = args.remove[-1]
            expect_found = False
            changed = True
        else:
            target_host = None
            changed = False
        
    if changed:
        save_lines(args.config, lines)
        if not args.noreload:
            trigger_reload(args.docker_host)
        
    if target_host:
        verify_dns(target_host, expect_found)

if __name__ == "__main__":
    main()
