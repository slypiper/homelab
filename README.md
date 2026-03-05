## Homelab

An assortment of homelab centered scripts around running services and exploring technologies.

## tmux_lazydocker_htop.sh

This script will create a tmux session with lazydocker on multiple hosts and htop on each host. It will split the tmux session into columns for each host and then split each column in half to add htop. It will then resize the htop panes to a specified percentage of the tmux session height.

### Usage

```bash
./tmux_lazydocker_htop.sh --hosts 'host1,host2,host3'
```

### Flags

- `--session`: Name of the tmux session (default: `lazyminirack`)
- `--htop_size`: Height percentage for the htop panes (default: `25%`)
- `--hosts`: Comma-separated list of hosts (default: `once,doce,trece`)

### Aliases

- `lazydev`: Creates a tmux session with lazydocker on uno, dos, and tres
- `lazyprod`: Creates a tmux session with lazydocker on once, doce, and trece
- `lazysingle`: Creates a tmux session with lazydocker on a single host as defined in [lazysingle.sh](aliases/lazysingle.sh)


