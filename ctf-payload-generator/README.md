# CTF payload generator

Читает Suricata EVE JSON и создаёт локальные артефакты для ручного анализа. Не отправляет запросы.

```bash
chmod +x install.sh
./install.sh
./run.sh --eve /var/log/suricata/eve.json
```

Через SSHFS: `sshfs user@ubuntu:/var/log/suricata ./remote-suricata` затем `./run.sh --eve ./remote-suricata/eve.json`.
