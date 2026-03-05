## Homelab

An assortment of homelab centered scripts around running services and exploring technologies.

## tmux_lazydocker_htop.sh

This script will create a tmux session with lazydocker on multiple hosts and htop on each host. It will split the tmux session into columns for each host and then split each column in half to add htop. It will then resize the htop panes to a specified percentage of the tmux session height.

### Usage

```bash
./tmux_lazydocker_htop.sh --hosts 'host1,host2,host3'
```

### Flags

- `--session`: Name of the tmux session (required)
- `--hosts`: Comma-separated list of hosts (required)
- `--htop`: Add htop to the session (default: `true`)
- `--htop_size`: Height percentage for the htop panes (default: `25%`)
- `--admin`: Add a full-width SSH row at the bottom for admin tasks (default: `false`)
- `--admin_size`: Height percentage for the admin row (default: `20%`)
- `--reset`: If already open, close and recreate session (default: `false`)
- `--kill`: Look for and kill any existing sessions with the same name (default: `false`)

### Aliases

- `lazydev`: Creates a tmux session with lazydocker and htop on uno, dos, and tres
- `lazyprod`: Creates a tmux session with lazydocker and htop on once, doce, and trece
- `lazysingle`: Creates a tmux session with lazydocker and htop on a single host; Aliasas defined in [lazysingle.sh](aliases/lazysingle.sh)


