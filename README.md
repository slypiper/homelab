## Homelab

An assortment of homelab centered scripts around running services and exploring technologies.



## scripts/docker_monitor.sh

This script creates a tmux session with `lazydocker` and `htop` on multiple hosts. It organizes the session into columns for each host, splits each column to add `htop`, and can optionally add a full-width **Admin Pane** at the bottom for quick terminal access. If the admin pane is enabled, it automatically runs `clear` to provide a clean workspace.

### Usage

![docker_monitor.sh example](img/docker-monitor-example.png)


```bash
/data/linux/scripts/docker_monitor.sh --session 'session_name' --hosts 'host1,host2,host3'
```

### Flags

- `--session`: Name of the tmux session (required)
- `--hosts`: Comma-separated list of hosts (required)
- `--htop`: Add htop to the session (default: `true`)
- `--htop_size`: Height percentage for the htop panes (default: `25%`)
- `--admin (-a)`: Add a full-width SSH row at the bottom for admin tasks (default: `false`)
- `--admin_size`: Height percentage for the admin row (default: `20%`)
- `--reset (-r)`: If already open, close and recreate session (default: `false`)
- `--kill (-k)`: Look for and kill any existing sessions with the same name (default: `false`)

### Aliases

- `lazydev`: Creates a tmux session with lazydocker and htop on uno, dos, and tres
- `lazyprod`: Creates a tmux session with lazydocker and htop on once, doce, and trece

## scripts/fix

A modular system check and fix utility designed for Homelab infrastructure. It scans and runs parallel checks across multiple system components (like checking CLI tools, Bashrc synchronization, and SSH key states) and provides an interactive dashboard to apply proposed fixes.

### Features

- **Parallel Execution**: Runs all system modules simultaneously in the background.
- **Live Dashboard**: Provides a real-time terminal UI showing active and completed checks.
- **Modular**: Automatically discovers and loads check modules from the `scripts/fix/modules/` directory.
- **Cross-Platform**: Built-in support for Ubuntu (apt/ESM) and Arch Linux (pacman/AUR).
- **Interactive Fixes**: Proposes terminal commands to fix detected issues and applies them upon confirmation.

### Usage

![fix.sh example](img/fix-example.png)

```bash
fix
```
### Flags

- `--apply (-a)`: Automatically apply all proposed fixes without confirmation.
- `--quiet (-q)`: Suppress all optional output and only show critical errors/dashboard.
- `--header / --noheader`: Show or hide the ASCII banner. (Default: Show)
- `--summary / --nosummary`: Display a final pass/fail summary report. (Default: Show)
- `--success / --nosuccess`: Toggle visibility of success messages. (Default: Show)
- `--warning / --nowarning`: Toggle visibility of warning messages. (Default: Show)
- `--debug (-d)`: Enable verbose output for troubleshooting. (Default: Hidden)
- `--security_updates`: Show Ubuntu ESM/Pro security updates in the report. (Default: Hidden)

## scripts/glance_watcher.sh

A highly optimized file watching utility that monitors the Glance configuration directory. When changes to `.yml` or `.yaml` files are detected, it forcefully reloads the Docker Swarm `dash_glance` service. 

### Features

- **Efficient Polling**: Uses batch-processed `fdfind` subshell evaluations to securely monitor NFS network mounts, comparing exact metadata timestamps without spamming CPU usage.
- **Tmux Integration**: Native remote host-jumping. Automatically creates and launches itself inside a detached `glance_watcher` tmux session on the target host.

### Usage

```bash
/data/linux/scripts/glance_watcher.sh
```

### Flags

- `--directory`: Directory to watch for modifications. (default: `/data/docker/glance/config`)
- `--service_name`: Name of the swarm service to force update. (default: `dash_glance`)
- `--host`: Host to execute the watcher on. Opens a tmux session remotely. (default: `once`)
- `--sleep_secs`: Seconds to sleep between loop iterations. (default: `2`)

## scripts/glance_youtube.py

A utility for managing YouTube channels within [Glance](https://github.com/glanceapp/glance) configuration files. It handles fetching channel details via `yt-dlp`, normalizing categories, and triggering Glance restarts via webhooks.

### Features

- **Channel Management**: Easily add or remove channels using YouTube handles (e.g., `@TheSwedishMaker`) or Channel IDs.
- **Auto-Discovery**: Automatically fetches canonical Channel IDs and handles using `yt-dlp`.
- **Category Resolution**: Supports partial category name matching (e.g., `fav` -> `favorites`) and enforces constraints (e.g., Favorites must coexist in a content category).
- **Restart Integration**: Detects changes and prompts to trigger a Glance restart webhook, or handles it automatically with flags.
- **Search & Inspection**: Search across all category YAML files or fetch YouTube IDs for specific handles.

### Usage

```bash
# Add a channel to specific categories
/data/linux/scripts/glance_youtube.py --add @JeffGeerling homelab makers

# Remove a channel (optionally from a specific category)
/data/linux/scripts/glance_youtube.py --remove @JeffGeerling homelab

# Search for a channel
/data/linux/scripts/glance_youtube.py --find tested

# List all available categories
/data/linux/scripts/glance_youtube.py -l

# List channels in specific categories (sorted)
/data/linux/scripts/glance_youtube.py -l makers family
```

### Flags

- `--add QUERY`: Add a channel by ID or handle. QUERY: 'handle/ID category [category] ...'
- `--remove QUERY`: Remove channel(s) by search term. QUERY: 'search-term [category]'
- `--find QUERY (-f)`: Search for a channel by ID or handle (case-insensitive).
- `--list (-l) [CAT ...]`: List categories. If category(s) specified, list channels in those categories.
- `--restart (-r)`: Trigger restart of the glance service via webhook after processing.
- `--force`: Force default selection at any prompt (e.g., skip confirmation for removal or restart).
- `--get_id HANDLE`: Fetch the canonical YouTube ID for a handle and exit.

### Glance integration

The files populated by this tool exist in `/data/docker/glance/config/yt` which is used in the docker configuration for `glance`. My glance pages use a similar structure to import the files: 

![glance config example](img/glance-example.png)

```bash
❯ grep -B1 -A5 "title: Makers" config/youtube.yml 
        - type: videos
          title: Makers
          collapse-after-rows: 1
          limit: 40
          style: grid-cards
          channels:
            $include: yt/makers.yml
```

While the `yt/makers.yml` looks similar to:

```bash
❯ head -2 config/yt/makers.yml 
- UC39z4_U8Kls0llAij3RRZAQ # @3x3CustomTamar 
- UCWizIdwZdmr43zfxlCktmNw # @AlecSteele 
```

## scripts/local_dns.py

Manages Pi-hole local DNS records by modifying the `pihole.toml` configuration. It supports adding, removing, and listing records, and automatically triggers a DNS reload on the Pi-hole container via Docker exec.

### Usage

```bash
# List all records
local_dns -l

# Add a new record
local_dns --add 192.168.86.10 test.home

# Remove a record by IP or hostname
local_dns --remove test.home
```

### Flags

- `-l, --list`: List all configured Pi-hole local DNS records.
- `--add IP HOSTNAME`: Add a local DNS record.
- `--remove TARGET [TARGET ...]`: Remove a local DNS record by IP or Hostname.
- `--config`: Path to `pihole.toml` (default: `/data/docker/pihole/config/pihole.toml`).
- `--docker-host`: Docker swarm node host to run the reload command on (default: `once`).
- `--noreload`: Do not trigger reload of the pihole DNS service.
- `--force`: Force default selection at any prompt.

### Aliases

- `local_dns`: Points to `/data/linux/scripts/local_dns.py`

## scripts/new_host.sh

Automates the onboarding of a new host into the homelab. This script handles updating the Ansible inventory (creating groups if necessary), configuring Pi-hole DNS, and executing the installation playbook. Technical output from DNS and Ansible operations is captured in timestamped log files in `/data/ansible/logs/`.

### Usage

```bash
/data/linux/scripts/new_host.sh --host dante --ip 10
```

### Flags

- `--host`: Host name of the new install.
- `--ip`: IP of the new install (1-254 suffix or full IP).
- `--subnet`: Default IP subnet for new hosts (default: `192.168.86`).
- `--group`: Optional Ansible group to place the host in.
- `--config`: Ansible Inventory File path.
- `--dns / --nodns`: Update Pi-hole Local DNS automatically (default: `true`).
- `--ansible_debug`: Show verbose ansible-playbook output (-vvvv).
- `--debug (-d)`: Enable real-time streaming of log files to the terminal.

### Aliases

- `new_host`: Points to `/data/linux/scripts/new_host.sh`