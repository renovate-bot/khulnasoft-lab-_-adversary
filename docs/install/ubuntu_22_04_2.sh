#!/bin/bash

# This is NOT idempotent
# This is intended for a fresh OS install
# This has no error handling

# temp dir for git clone & python building
cd
mkdir adversary_temp
cd adversary_temp

# ensure updated listing
sudo apt update

# adversary service account
sudo adduser --no-create-home --system --shell /bin/false adversary
sudo usermod -L adversary
sudo groupadd adversary
sudo usermod -aG adversary adversary

# install postgres
sudo apt install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl status postgresql

# clone repo
sudo apt install -y git
sudo mkdir /opt/adversary
git clone https://github.com/cisagov/adversary.git
sudo cp -a ./adversary/. /opt/adversary/1.0.0
sudo chown -R adversary:adversary /opt/adversary

# build python 3.8.10
sudo apt install -y build-essential gdb lcov pkg-config \
    libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
    libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
    lzma lzma-dev tk-dev uuid-dev zlib1g-dev
wget https://www.python.org/ftp/python/3.8.10/Python-3.8.10.tar.xz
tar -xf Python-3.8.10.tar.xz
cd Python-3.8.10
./configure --prefix=/opt/adversary/python3.8.10 --exec_prefix=/opt/adversary/python3.8.10 --enable-optimizations
sudo mkdir /opt/adversary/python3.8.10
sudo make altinstall
sudo chown -R adversary:adversary /opt/adversary/python3.8.10
cd ..

# setup venv
sudo -u adversary -g adversary /opt/adversary/python3.8.10/bin/python3.8 -m \
    venv /opt/adversary/1.0.0/venv/
sudo -u adversary -g adversary /opt/adversary/1.0.0/venv/bin/python -m \
    pip --no-cache-dir install -r /opt/adversary/1.0.0/requirements-pre.txt
sudo -u adversary -g adversary /opt/adversary/1.0.0/venv/bin/python -m \
    pip --no-cache-dir install -r /opt/adversary/1.0.0/requirements.txt

# create user.json (for build), create/run/rm init.sql (for DB init)
sudo -u adversary -g adversary cp /opt/adversary/1.0.0/.env.manual /opt/adversary/1.0.0/.env
sudo -u adversary -g adversary chmod 660 /opt/adversary/1.0.0/.env
sudo -u adversary -g adversary /opt/adversary/1.0.0/venv/bin/python /opt/adversary/1.0.0/initial_setup.py
sudo -i -u postgres psql -a -f /opt/adversary/1.0.0/init.sql
sudo -u adversary -g adversary rm /opt/adversary/1.0.0/init.sql

# build database
cd /opt/adversary/1.0.0/
sudo -u adversary -g adversary /opt/adversary/1.0.0/venv/bin/python -m \
    app.utils.db.actions.full_build --config DefaultConfig
sudo -u adversary -g adversary rm /opt/adversary/1.0.0/app/utils/jsons/source/user.json

# generate self-signed ssl cert
sudo -u adversary -g adversary RANDFILE=/opt/adversary/1.0.0/app/utils/certs/.rnd openssl genrsa \
    -out /opt/adversary/1.0.0/app/utils/certs/adversary.key 2048
sudo -u adversary -g adversary RANDFILE=/opt/adversary/1.0.0/app/utils/certs/.rnd openssl req -new \
    -key /opt/adversary/1.0.0/app/utils/certs/adversary.key \
    -out /opt/adversary/1.0.0/app/utils/certs/adversary.csr
sudo -u adversary -g adversary RANDFILE=/opt/adversary/1.0.0/app/utils/certs/.rnd openssl x509 -req -days 365 \
    -in /opt/adversary/1.0.0/app/utils/certs/adversary.csr \
    -signkey /opt/adversary/1.0.0/app/utils/certs/adversary.key \
    -out /opt/adversary/1.0.0/app/utils/certs/adversary.crt

# copy service file and start
sudo cp /opt/adversary/1.0.0/adversary.service /etc/systemd/system/adversary.service
sudo chmod 644 /etc/systemd/system/adversary.service
sudo systemctl start adversary
sudo systemctl status adversary
sudo systemctl enable adversary
echo "Default Login: admin@admin.com admin"
