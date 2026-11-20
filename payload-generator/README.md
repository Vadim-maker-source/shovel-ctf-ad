# CTF payload generator

Запускается на той же Ubuntu, где работают Shovel и Suricata. Читает локальный EVE JSON и создаёт артефакты для ручного анализа. Не отправляет запросы.

```bash
chmod +x install.sh
./install.sh
./run.sh --eve /var/log/suricata/eve.json
```

Результаты появляются в `artifacts/`. SSH-туннель и Docker для генератора не нужны.
