#!/bin/sh

apt update && apt install -y libmodsecurity-dev curl

mkdir -p /etc/modsecurity.d
curl -sSL https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping \
        -o /etc/modsecurity.d/unicode.mapping