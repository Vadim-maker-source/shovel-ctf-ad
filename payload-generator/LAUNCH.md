# Запуск Shovel на Ubuntu и генератора payload на Kali

Схема:

```text
Ubuntu: Shovel + Suricata
  ├─ localhost:8000          → SSH tunnel → Kali localhost:8000
  └─ Suricata eve.json       → SSH stream  → Kali generator
```

## 1. Ubuntu: запустить Shovel

```bash
cd ~/shovel
./start.sh
```

Проверить панель и журнал:

```bash
curl http://127.0.0.1:8000
sudo test -f /var/log/suricata/eve.json
```

Если EVE-файл находится в другом месте, посмотри mount контейнера:

```bash
sudo docker inspect shovel-suricata-1 \
  --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

## 2. Kali: прокинуть панель Shovel

В отдельном терминале Kali:

```bash
ssh -N -L 8000:127.0.0.1:8000 user@UBUNTU_IP
```

Открой на Kali: <http://127.0.0.1:8000>.

## 3. Kali: установить генератор

Из каталога `shovel/payload-generator`:

```bash
chmod +x install.sh
./install.sh
```

## 4. Kali: получать EVE-события по SSH

Во втором терминале Kali:

```bash
cd /path/to/shovel/payload-generator
ssh user@UBUNTU_IP \
  'sudo tail -F /var/log/suricata/eve.json' \
  | ./run.sh --eve -
```

Генератор читает только события `event_type=alert` и создаёт результаты здесь:

```text
payload-generator/artifacts/
```

Для каждого нового SID создаётся каталог с:

```text
event.json      # событие с замаскированными секретами
payloads.json   # варианты шаблонов
replay.py       # Python-черновик для локального клона
README.md       # краткая информация об алерте
```

## 5. Если EVE-файл доступен только внутри контейнера

На Ubuntu можно передавать его через `docker exec`:

```bash
ssh user@UBUNTU_IP \
  'sudo docker exec -i shovel-suricata-1 tail -F /var/log/suricata/eve.json' \
  | ./run.sh --eve -
```

Уточни имя контейнера командой:

```bash
sudo docker ps --format '{{.Names}}'
```

## Остановка

На Kali останови генератор через `Ctrl+C` и SSH-туннель через `Ctrl+C`.

На Ubuntu останови Shovel без удаления данных:

```bash
cd ~/shovel
./stop.sh
```

Генератор не отправляет созданные payload’ы автоматически. Он сохраняет артефакты на Kali для проверки и запуска только в разрешённом локальном стенде.
