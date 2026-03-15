#!/usr/bin/env python3
import sys
import os
import subprocess
import argparse
import urllib.request
from halo import Halo

BASE_DIR = "/data/docker/glance/config/yt"
RESTART_WEBHOOK = "https://wf.zappe.dev/webhook/d3e9e173-59ee-42d2-bbf4-3b4889e0c09c"

HOME_GROUP = {'favorites', 'family'}
NEWS_GROUP = {'news', 'politics', 'legal'}

RESET  = "\033[0m"
BOLD   = "\033[1m"
YELLOW = "\033[33m"
RED    = "\033[31m"
CYAN   = "\033[36m"
WHITE  = "\033[97m"

def log_success(text: str): Halo().succeed(f"{BOLD}{text}{RESET}")
def log_fail(text: str):    Halo().fail(f"{BOLD}{RED}{text}{RESET}")
def log_warn(text: str):    Halo().warn(f"{BOLD}{YELLOW}{text}{RESET}")
def log_info(text: str):    Halo().info(f"{BOLD}{CYAN}{text}{RESET}")

def get_available_categories() -> set[str]:
    """Scans the BASE_DIR for .yml files to determine available categories."""
    if not os.path.isdir(BASE_DIR):
        log_fail(f"CRITICAL: Directory {BASE_DIR} does not exist.")
        sys.exit(1)
    
    categories = set()
    for filename in os.listdir(BASE_DIR):
        if filename.endswith('.yml'):
            category_name, _ = os.path.splitext(filename)
            categories.add(category_name)
            
    return categories

def get_channel_details(handle_input: str) -> tuple[str, str]:
    """Uses yt-dlp to get the canonical ID and Handle."""
    if subprocess.call('command -v yt-dlp', shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) != 0:
        log_fail("DEPENDENCY: yt-dlp is not installed.")
        log_info(f"Please install it with: {CYAN}snap install yt-dlp{RESET}")
        sys.exit(1)

    if handle_input.startswith("UC") and len(handle_input) >= 20:
        url = f"https://www.youtube.com/channel/{handle_input}"
    else:
        clean_handle = handle_input.lstrip('@')
        url = f"https://www.youtube.com/@{clean_handle}"
    
    clean_handle = handle_input.lstrip('@')
    
    spinner = Halo(text=f"Fetching YouTube details for {BOLD}@{clean_handle}{RESET}...", color='magenta').start()
    
    cmd = [
        "yt-dlp",
        "--playlist-end", "1",
        "--print", "%(channel_id)s|%(uploader_id)s",
        url
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        output = result.stdout.strip()
        
        if not output or output.startswith("NA|"):
            spinner.fail(f"NOT FOUND: Could not find details for {handle_input}")
            sys.exit(1)
        
        spinner.stop()
        channel_id, handle_raw = output.split('|')
        canonical_handle = handle_raw if handle_raw.startswith('@') else f"@{handle_raw}"
        return channel_id, canonical_handle
    except subprocess.CalledProcessError as e:
        spinner.fail(f"YT-DLP ERROR: {e.stderr.splitlines()[-1] if e.stderr else 'Unknown error'}")
        sys.exit(1)
    except Exception as e:
        spinner.fail(f"ERROR: {str(e)}")
        sys.exit(1)

def normalize_category(cat: str, available_cats: set[str]) -> str:
    """Resolves a partial category name to its full version."""
    cat = cat.lower()
    if cat in available_cats:
        return cat

    matches = [c for c in available_cats if cat in c]
    if len(matches) == 1:
        return matches[0]
    elif len(matches) > 1:
        log_fail(f"AMBIGUOUS: '{cat}' matched multiple categories: {', '.join(matches)}")
        sys.exit(1)
    
    log_fail(f"INVALID: '{cat}' is not a known category.")
    sys.exit(1)

def check_file_for_channel(filepath: str, channel_id: str | None = None, canonical_handle: str | None = None) -> tuple[bool, str | None]:
    """Checks a specific file for a channel by ID or handle."""
    if not os.path.exists(filepath):
        return False, None

    with open(filepath, 'r') as f:
        for line in f:
            if '#' not in line: 
                continue
            
            parts = line.split('#')
            existing_id = parts[0].strip().lstrip('- ')
            existing_handle = parts[1].strip()

            if channel_id and existing_id == channel_id:
                return True, existing_handle
            
            if canonical_handle and existing_handle and existing_handle.lower() == canonical_handle.lower():
                return True, existing_handle

    return False, None

def validate_category_constraints(target_cats: set[str], handle: str, available_cats: set[str]) -> None:
    """Ensures that if adding to HOME_GROUP, it exists in NEWS or other content groups."""
    if not any(c in HOME_GROUP for c in target_cats):
        return

    # Valid if also adding to a content category in this same command
    if any(c not in HOME_GROUP for c in target_cats):
        return

    # Check disk for existing content entry
    matches = search_channels(handle, available_cats, quiet=True)
    if any(m['cat'] not in HOME_GROUP for m in matches):
        return

    log_fail(f"CONSTRAINT: You are adding {BOLD}{handle}{RESET} to a Favorites list, but it's not in any content category.")
    sys.exit(1)

def search_channels(query: str, available_cats: set[str], quiet: bool = False, category_limit: str | None = None) -> list[dict]:
    """Searches through category files for matches by handle or ID."""
    query = query.lower().lstrip('@')
    results = []
    
    cats_to_search = sorted(available_cats)
    if category_limit:
        cats_to_search = [category_limit]
        
    for cat in cats_to_search:
        filepath = os.path.join(BASE_DIR, f"{cat}.yml")
        if not os.path.exists(filepath):
            continue
            
        with open(filepath, 'r') as f:
            for line in f:
                if '#' not in line: continue
                
                parts = line.split('#')
                cid = parts[0].strip().lstrip('- ')
                handle = parts[1].strip()
                
                if query == cid.lower() or query in handle.lstrip('@').lower():
                    results.append({'cat': cat, 'handle': handle, 'cid': cid, 'line': line})
    
    if not quiet:
        if not results:
            log_fail(f"No matches found for '{query}'.")
        else:
            log_info(f"Search Results for '{query}':")
            for r in results:
                print(f"  {CYAN}{r['cat']}:{RESET} {BOLD}{r['handle']}{RESET} {r['cid']}")
            print()
            
    return results

def remove_channels(query: str, available_cats: set[str], force: bool = False, category_limit: str | None = None) -> bool:
    """Handles logic for removing entries from YAML files."""
    matches = search_channels(query, available_cats, category_limit=category_limit)
    if not matches:
        return False

    if not force:
        try:
            choice = input(f"{BOLD}Would you like to remove the above references? [Y/n] {RESET}").strip().lower()
            if choice not in ('', 'y', 'yes'):
                log_fail("Cancelled by user.")
                return False
        except (EOFError, KeyboardInterrupt):
            print()
            log_fail("Cancelled.")
            return False

    # Group by category to avoid redundant file IO
    from collections import defaultdict
    by_cat = defaultdict(list)
    for m in matches:
        by_cat[m['cat']].append(m['line'])

    for cat, lines_to_remove in by_cat.items():
        filepath = os.path.join(BASE_DIR, f"{cat}.yml")
        with open(filepath, 'r') as f:
            all_lines = f.readlines()
        
        new_lines = [line for line in all_lines if line not in lines_to_remove]
        
        with open(filepath, 'w') as f:
            f.writelines(new_lines)
        
        log_success(f"Successfully removed {len(lines_to_remove)} match(es) from {cat}")

    return True

def trigger_restart() -> None:
    """Triggers the Glance restart webhook."""
    spinner = Halo(text=f"Restarting Glance...", color='cyan').start()
    try:
        with urllib.request.urlopen(RESTART_WEBHOOK) as response:
            if response.status == 200:
                spinner.succeed(f"{BOLD}RESTART: Webhook triggered successfully.{RESET}")
            else:
                spinner.warn(f"{BOLD}{YELLOW}RESTART: Webhook status: {response.status}{RESET}")
    except Exception as e:
        spinner.fail(f"{BOLD}{RED}RESTART: Failed to trigger: {str(e)}{RESET}")

def prompt_restart(restart: bool, force: bool) -> None:
    """Prompts the user to restart Glance if changes were made."""
    if restart or force:
        trigger_restart()
        return

    try:
        choice = input(f"\n{BOLD}Changes require a restart of glance, would you like to restart now? [Y/n] {RESET}").strip().lower()
        if choice in ('', 'y', 'yes'):
            trigger_restart()
        else:
            log_warn("No restart, changes won't take effect until restart is completed.")
    except (EOFError, KeyboardInterrupt):
        print()
        return

def add_handle(handle_input: str, categories_raw: list[str]) -> bool:
    """Orchestrates adding a YouTube channel (by handle or ID) to specific categories."""
    available_cats = get_available_categories()
    modified = False

    # Normalize name for local scan
    if handle_input.startswith("UC"):
        handle_for_check = handle_input
    else:
        handle_for_check = handle_input if handle_input.startswith('@') else f"@{handle_input}"

    target_cats = set([normalize_category(c, available_cats) for c in categories_raw])
    validate_category_constraints(target_cats, handle_for_check, available_cats)

    cats_to_process = []
    log_info(f"LOCAL SCAN: Checking files for {handle_for_check}")
    
    for cat in target_cats:
        filepath = os.path.join(BASE_DIR, f"{cat}.yml")
        found, _ = check_file_for_channel(filepath, handle_input if handle_input.startswith('UC') else None, handle_for_check)
        if found:
            log_warn(f"SKIP: Already in {cat}.yml")
        else:
            cats_to_process.append(cat)
            
    if cats_to_process:
        channel_id, canonical_handle = get_channel_details(handle_input)
        formatted_line = f"- {channel_id} # {canonical_handle}\n"

        log_info(f"Applying updates for {BOLD}{canonical_handle}{RESET} ({channel_id}):")
        
        for cat in cats_to_process:
            filepath = os.path.join(BASE_DIR, f"{cat}.yml")
            if check_file_for_channel(filepath, channel_id, canonical_handle)[0]:
                log_warn(f"SKIP: Already in {cat}.yml (verified via ID)")
                continue

            newline_needed = False
            if os.path.exists(filepath) and os.path.getsize(filepath) > 0:
                with open(filepath, 'rb+') as f:
                    f.seek(-1, os.SEEK_END)
                    if f.read(1) != b'\n':
                        newline_needed = True

            with open(filepath, 'a') as f:
                if newline_needed: f.write("\n")
                f.write(formatted_line)
            log_success(f"ADDED: Recorded in {cat}.yml")
            modified = True
    else:
        log_success("COMPLETE: Channel already exists in all target categories.")

    return modified

def main():
    parser = argparse.ArgumentParser(description="Add YouTube channels to Glance YAML config.")
    
    parser.add_argument("-l", "--list", nargs="?", const=True, help="List categories, or if a category is specified, list channels in that category")   
    parser.add_argument("-r", "--restart", action="store_true", help="Trigger restart of the glance service via webhook")
    parser.add_argument("--add", metavar="QUERY", help="Add channel by ID or Handle, QUERY: 'handle/ID category [category] ...'")
    parser.add_argument("--remove", metavar="QUERY", help="Remove channel(s) by search term, QUERY: 'search-term [category]'")
    parser.add_argument("-f", "--find", metavar="QUERY", help="Search for a channel by ID or Handle (case-insensitive), QUERY: 'search-term'")
    parser.add_argument("--get_id", metavar="HANDLE", help="Fetch the canonical YouTube ID for a handle")
    parser.add_argument("--force", action="store_true", help="Force default selection at any prompt")
    parser.add_argument("handle", nargs="?", help="YouTube handle (e.g. @modustrial)")
    parser.add_argument("categories", nargs="*", help="Categories to add to (e.g. favorites makers)")
    
    args = parser.parse_args()

    available_cats = get_available_categories()

    if args.add:
        categories_raw = []
        if args.handle: categories_raw.append(args.handle)
        categories_raw.extend(args.categories)

        if not categories_raw:
            log_fail("Please specify at least one category to add to.")
            sys.exit(1)

        changed = add_handle(args.add, categories_raw)

        if changed: 
            prompt_restart(args.restart, args.force)

        sys.exit(0)

    if args.remove:
        category_limit = None
        if args.handle:
            category_limit = normalize_category(args.handle, available_cats)
        
        changed = remove_channels(args.remove, available_cats, force=args.force, category_limit=category_limit)
        
        if changed: 
            prompt_restart(args.restart, args.force)

        sys.exit(0)

    if args.list:
        if isinstance(args.list, str):
            # Collect all requested categories
            requested_cats_raw = [args.list]
            if args.handle: 
                requested_cats_raw.append(args.handle)
            requested_cats_raw.extend(args.categories)

            # Resolve all categories first to catch errors early
            resolved_cats = [normalize_category(c, available_cats) for c in requested_cats_raw]

            for cat in resolved_cats:
                results = search_channels("", available_cats, quiet=True, category_limit=cat)
                
                if not results:
                    log_warn(f"No channels found in category '{cat}'.")
                    continue
                
                # Sort by handle (case-insensitive)
                results.sort(key=lambda x: x['handle'].lstrip('@').lower())
                
                log_info(f"Channels in '{cat}':")
                for r in results:
                    print(f"  {CYAN}{r['cat']}:{RESET} {BOLD}{r['handle']}{RESET} {r['cid']}")
                print()
            sys.exit(0)
        else:
            # List available categories (existing behavior)
            log_info("Available YT Categories:")
            for group, items in [("Favorites", HOME_GROUP), ("Regional/News", NEWS_GROUP)]:
                matching = [c for c in sorted(items) if c in available_cats]
                if matching: print(f"  {CYAN}{group:<15}{RESET} {', '.join(matching)}")
            
            others = sorted([c for c in available_cats if c not in (HOME_GROUP | NEWS_GROUP)])
            if others: print(f"  {CYAN}{'Other Content':<15}{RESET} {', '.join(others)}")
            print()
            sys.exit(0)

    if args.find:
        search_channels(args.find, available_cats)
        sys.exit(0)

    if args.get_id:
        cid, _ = get_channel_details(args.get_id)
        log_success(f"Found ID for {args.get_id}: {cid}")
        sys.exit(0)

    if args.restart:
        trigger_restart()
        sys.exit(0)

    if args.handle or args.categories:
        log_fail("Please specify --add or --remove")
        sys.exit(1)

    parser.print_help()

if __name__ == "__main__":
    main()