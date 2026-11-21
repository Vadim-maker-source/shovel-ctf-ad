# Установка из GitHub

Клонируй с вложенными GitHub-репозиториями: `shovel` и `vanya_ctf_superfarm`
сохранены как Git submodules.

```bash
git clone --recurse-submodules https://github.com/Vadim-maker-source/shovel-ctf-ad.git
cd shovel-ctf-ad/payload-generator
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -e .
ctf-payload-generator --eve /var/log/suricata/eve.json
```

Для запуска без установки пакета можно использовать `./install.sh` и `./run.sh`.

## Shovel на Ubuntu

Docker Engine и Compose должны быть установлены заранее. В каталоге
`shovel-kali-kit2` есть подготовщик интерфейсов и правил; он создаёт
`~/shovel/start.sh`. Запуск Shovel из ограниченной сети не собирает образы:
их надо заранее загрузить в Docker, включая PostgreSQL. Затем:

```bash
cd ~/shovel
./start.sh
docker compose -f docker-compose.yml -f compose.live.yaml ps
```

Если `./start.sh` отвечает `No such file or directory`, значит запускали
исходный Shovel без подготовщика. После полного клона выполни
`./shovel-kali-kit2/install.sh --interfaces <интерфейс[,интерфейс]>`.

## SSH-туннель с Kali к панели Ubuntu

На Kali выполни (замени пользователя и IP Ubuntu):

```bash
ssh -N -L 8000:127.0.0.1:8000 USER@UBUNTU_IP
```

Пока команда работает, открой на Kali `http://127.0.0.1:8000`. Для SSH на
нестандартном порту добавь `-p SSH_PORT` перед `USER@UBUNTU_IP`. На Ubuntu
должен быть запущен SSH-сервер и доступен порт SSH от Kali. Shovel слушает
только localhost, поэтому панель не публикуется напрямую в игровую сеть.
