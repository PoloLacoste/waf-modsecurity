#!/bin/sh

CRS_DOCKER_VERSION=$1

apt update && apt install -y ca-certificates curl

curl -sSL https://github.com/coreruleset/modsecurity-crs-docker/archive/refs/tags/release/${CRS_DOCKER_VERSION}.tar.gz \
    -o modsecurity-crs-docker-${CRS_DOCKER_VERSION}.tar.gz
tar -zxf modsecurity-crs-docker-${CRS_DOCKER_VERSION}.tar.gz
rm -f modsecurity-crs-docker-${CRS_DOCKER_VERSION}.tar.gz
mkdir -p /etc/modsecurity.d
cp -a modsecurity-crs-docker-release-${CRS_DOCKER_VERSION}/src/etc/modsecurity.d/. /etc/modsecurity.d/
mkdir -p /opt/modsecurity
cp -a modsecurity-crs-docker-release-${CRS_DOCKER_VERSION}/src/opt/modsecurity/. /opt/modsecurity/
rm -rf modsecurity-crs-docker-release-${CRS_DOCKER_VERSION}