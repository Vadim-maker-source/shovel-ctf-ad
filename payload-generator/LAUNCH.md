# Запуск Shovel и генератора payload на Ubuntu

Схема:

```text
Ubuntu: Shovel + Suricata + payload-generator
  ├─ localhost:8000 — панель Shovel
  └─ localhost:8000/api/flow — источник alert’ов
```

## 1. Ubuntu: запустить Shovel

```bash
cd "$HOME/shovel"
./start.sh
```

Проверить панель и журнал:

```bash
curl http://127.0.0.1:8000
curl http://127.0.0.1:8000/api/flow
```

Если EVE-файл находится в другом месте, посмотри mount контейнера:

```bash
sudo docker inspect shovel-suricata-1 \
  --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

## 2. Ubuntu: установить генератор

Из каталога `$HOME/shovel/payload-generator`:

```bash
chmod +x install.sh
./install.sh
```

## 3. Ubuntu: запустить генератор через API Shovel

```bash
cd "$HOME/shovel/payload-generator"
mkdir -p "$HOME/shovel/generated"
./run.sh
```

Генератор читает HTTP-потоки с Suricata signatures через Shovel API и создаёт результаты здесь:

```text
$HOME/shovel/generated/
```

Для каждого нового SID создаётся каталог с:

```text
event.json      # сведения об alert и HTTP-транзакциях, секретные заголовки замаскированы
replay.py       # replay-заготовка Shovel; включает тело POST, если оно захвачено
README.md       # краткая информация об алерте
```

## 4. Альтернатива: EVE JSON

Если у вас отдельно настроен EVE JSON, передай путь через `--eve`. В этой конфигурации Shovel пишет события в базу, поэтому файла EVE по умолчанию нет.

```bash
./run.sh --eve /path/to/eve.json
```

Уточни имя контейнера командой:

```bash
sudo docker ps --format '{{.Names}}'
```

## Остановка

Останови генератор через `Ctrl+C`.

На Ubuntu останови Shovel без удаления данных:

```bash
cd "$HOME/shovel"
./stop.sh
```

Генератор не отправляет replay автоматически. Он сохраняет артефакты на Ubuntu для проверки. Shovel API возвращает не более 100 последних потоков за запрос, поэтому при высокой нагрузке возможен пропуск.
