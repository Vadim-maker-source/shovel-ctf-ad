# Shovel quick setup for Kali

Install Docker Engine and the Docker Compose plugin manually first. Then extract this kit and run:

```bash
chmod +x ./*.sh
./install.sh
```

By default the installer downloads Shovel into `~/shovel`, copies the starter rules, and generates `compose.live.yaml` for all currently UP interfaces except loopback and common Docker/bridge interfaces. It prepares the project without starting containers.

To choose interfaces explicitly:

```bash
./install.sh --interfaces eth0,wlan0,tun0
```

To also start after setup:

```bash
./install.sh --interfaces eth0,wlan0,tun0 --start
```

The installer creates these helpers in the Shovel directory:

- `start.sh` — start Shovel live capture from images already loaded in Docker.
- `stop.sh` — stop services while preserving their data.
- `status.sh` — show container state.
- `logs.sh` — follow Suricata, webapp and database logs.
- `reload-rules.sh` — signal Suricata to reload edited rules.

After setup, open <http://localhost:8000>. The default interface detector captures every host interface marked UP except common local/container bridges. Review `compose.live.yaml`; specify interfaces manually if the host has virtual links or overlapping capture points. The starter rules are heuristics, can produce false positives, and cannot read HTTPS contents or identify failed SSH passwords.

### Restricted network / GitHub-only access

The launcher does not build images or contact package registries. Before the event, pull the three Shovel images from GitHub Container Registry and the PostgreSQL image, then export them into Docker archives. Transfer those archives through this GitHub repository (split archives into files smaller than 100 MB, or attach them to a GitHub Release), and run `docker load` before `./start.sh`. The base Shovel compose file still names PostgreSQL as `docker.io/library/postgres:18`, so that image must be present locally under that name. `start.sh` reports a missing image without trying to build it.
