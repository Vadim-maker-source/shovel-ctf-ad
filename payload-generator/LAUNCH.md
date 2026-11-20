# Запуск Shovel и генератора payload на Ubuntu

Схема:

```text
Ubuntu: Shovel + Suricata + payload-generator
  ├─ localhost:8000 — панель Shovel
  └─ /var/log/suricata/eve.json — источник alert’ов
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

## 2. Ubuntu: установить генератор

Из каталога `~/shovel/payload-generator`:

```bash
chmod +x install.sh
./install.sh
```

## 3. Ubuntu: запустить генератор на локальном EVE-файле

```bash
cd ~/shovel/payload-generator
./run.sh --eve /var/log/suricata/eve.json
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

## 4. Если EVE-файл доступен только внутри контейнера

На Ubuntu передай поток в локальный генератор через `docker exec`:

```bash
sudo docker exec -i shovel-suricata-1 tail -F /var/log/suricata/eve.json \
  | ./run.sh --eve -
```

Уточни имя контейнера командой:

```bash
sudo docker ps --format '{{.Names}}'
```

## Остановка

Останови генератор через `Ctrl+C`.

На Ubuntu останови Shovel без удаления данных:

```bash
cd ~/shovel
./stop.sh
```

Генератор не отправляет созданные payload’ы автоматически. Он сохраняет артефакты на Ubuntu для проверки.
