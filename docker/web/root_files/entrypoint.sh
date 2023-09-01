#!/bin/sh

# ensure environment variables are set
if [ -z "$DB_HOSTNAME" ]; then
    echo "DB_HOSTNAME is not set"
    exit 1
fi
if [ -z "$DB_PORT" ]; then
    echo "DB_PORT is not set"
    exit 1
fi
if [ -z "$DB_DATABASE" ]; then
    echo "DB_DATABASE is not set"
    exit 1
fi
if [ -z "$DB_USERNAME" ]; then
    echo "DB_USERNAME is not set"
    exit 1
fi
if [ -z "$DB_PASSWORD" ]; then
    echo "DB_PASSWORD is not set"
    exit 1
fi
if [ -z "$CART_ENC_KEY" ]; then
    echo "CART_ENC_KEY is not set"
    exit 1
fi
if [ -z "$ADMIN_EMAIL" ]; then
    echo "ADMIN_EMAIL is not set"
    exit 1
fi
if [ -z "$ADMIN_PASS" ]; then
    echo "ADMIN_PASS is not set"
    exit 1
fi

cd /opt/adversary

# generate user.json (for potential build usage)
python create_user_json.py

# build database
# (if FULL_BUILD_MODE=preserve: only rebuild if no AttackVersion table or no versions in the table)
python -m app.utils.db.actions.full_build --config DefaultConfig

# clear user.json
rm app/utils/jsons/source/user.json

# HTTP:
if [ -z "$WEB_HTTPS_ON" ]; then

    echo "Running in HTTP mode"
    uwsgi --master --socket 0.0.0.0:5000 --protocol=http --module adversary:app

# HTTPS:
else

    echo "Running in HTTPS mode"

    # Cert Found:
    if [ -f app/utils/certs/adversary.crt ] && [ -f app/utils/certs/adversary.key ]; then

        echo "SSL Cert Found"

    # Cert Missing:
    else

        echo "SSL Cert Missing - Generating new one"

        # clear (1 could still exist, and .csr to be sure)
        rm -f app/utils/certs/adversary.crt app/utils/certs/adversary.key app/utils/certs/adversary.csr

        # generate
        openssl req \
            -x509 \
            -newkey rsa:4096 \
            -keyout app/utils/certs/adversary.key \
            -out app/utils/certs/adversary.crt \
            -nodes \
            -sha256 \
            -days 365 \
            -subj "/C=US/ST=Virginia/L=McLean/O=Company Name/OU=Org/CN=www.example.com"
    fi

    uwsgi --master --https 0.0.0.0:5000,app/utils/certs/adversary.crt,app/utils/certs/adversary.key --module adversary:app
fi
