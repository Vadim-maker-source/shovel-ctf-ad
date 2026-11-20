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

- `start.sh` — build/pull missing images and start Shovel live capture.
- `stop.sh` — stop services while preserving their data.
- `status.sh` — show container state.
- `logs.sh` — follow Suricata, webapp and database logs.
- `reload-rules.sh` — signal Suricata to reload edited rules.

After setup, open <http://localhost:8000>. The default interface detector captures every host interface marked UP except common local/container bridges. Review `compose.live.yaml`; specify interfaces manually if the host has virtual links or overlapping capture points. The starter rules are heuristics, can produce false positives, and cannot read HTTPS contents or identify failed SSH passwords.
