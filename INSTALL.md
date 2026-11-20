# Установка из GitHub

```bash
git clone https://github.com/Vadim-maker-source/shovel-ctf-ad.git
cd shovel-ctf-ad/payload-generator
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -e .
ctf-payload-generator --eve /var/log/suricata/eve.json
```

Для запуска без установки пакета можно использовать `./install.sh` и `./run.sh`.
