#!/bin/sh

CRS_VERSION=$1

apt update && apt install -y ca-certificates curl gnupg

mkdir -p /opt/owasp-crs
curl -sSL https://github.com/coreruleset/coreruleset/releases/download/v${CRS_VERSION}/coreruleset-${CRS_VERSION}-minimal.tar.gz \
    -o v${CRS_VERSION}-minimal.tar.gz
curl -sSL https://github.com/coreruleset/coreruleset/releases/download/v${CRS_VERSION}/coreruleset-${CRS_VERSION}-minimal.tar.gz.asc \
    -o coreruleset-${CRS_VERSION}-minimal.tar.gz.asc
gpg --fetch-key https://coreruleset.org/security.asc
gpg --verify coreruleset-${CRS_VERSION}-minimal.tar.gz.asc v${CRS_VERSION}-minimal.tar.gz
tar -zxf v${CRS_VERSION}-minimal.tar.gz --strip-components=1 -C /opt/owasp-crs
rm -f v${CRS_VERSION}-minimal.tar.gz coreruleset-${CRS_VERSION}-minimal.tar.gz.asc
mv -v /opt/owasp-crs/crs-setup.conf.example /opt/owasp-crs/crs-setup.conf