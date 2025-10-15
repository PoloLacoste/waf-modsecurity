# modsecurity
FROM alpine:3.20 AS modsecurity-builder

ARG LUA_VERSION
ARG MODSECURITY_VERSION

WORKDIR /build

RUN apk add --no-cache \
    autoconf \
    automake \
    ca-certificates \
    coreutils \
    curl \
    curl-dev \
    g++ \
    gcc \
    git \
    libc-dev \
    libfuzzy2-dev \
    libmaxminddb-dev \
    libstdc++ \
    libtool \
    libxml2-dev \
    linux-headers \
    lmdb-dev \
    lua${LUA_VERSION}-dev \
    make \
    openssl \
    openssl-dev \
    patch \
    pkgconfig \
    pcre-dev \
    pcre2-dev \
    yajl-dev \
    zlib-dev

RUN git clone https://github.com/owasp-modsecurity/ModSecurity --branch "v${MODSECURITY_VERSION}" --depth 1 --recursive; \
    cd ModSecurity; \
    ARCH=$(gcc -print-multiarch); \
    sed -ie "s/i386-linux-gnu/${ARCH}/g" build/ssdeep.m4; \
    sed -ie "s/i386-linux-gnu/${ARCH}/g" build/pcre2.m4; \
    ./build.sh; \
    ./configure --with-yajl --with-ssdeep --with-lmdb --with-pcre2 --with-maxmind --enable-silent-rules; \
    make install; \
    cp -r /usr/local/modsecurity/lib/ /usr/local/modsecurity/lib-dev/; \
    strip /usr/local/modsecurity/lib/lib*.so*
RUN mkdir /etc/modsecurity.d; \
    curl -sSL https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping \
        -o /etc/modsecurity.d/unicode.mapping

# coreruleset
FROM alpine:3.20 AS coreruleset

ARG CRS_VERSION
ARG CRS_DOCKER_VERSION

WORKDIR /build

RUN apk add --no-cache \
    ca-certificates \
    curl \
    gnupg
RUN mkdir /opt/owasp-crs; \
    curl -sSL https://github.com/coreruleset/coreruleset/releases/download/v${CRS_VERSION}/coreruleset-${CRS_VERSION}-minimal.tar.gz \
        -o v${CRS_VERSION}-minimal.tar.gz; \
    curl -sSL https://github.com/coreruleset/coreruleset/releases/download/v${CRS_VERSION}/coreruleset-${CRS_VERSION}-minimal.tar.gz.asc \
        -o coreruleset-${CRS_VERSION}-minimal.tar.gz.asc; \
    gpg --fetch-key https://coreruleset.org/security.asc; \
    gpg --verify coreruleset-${CRS_VERSION}-minimal.tar.gz.asc v${CRS_VERSION}-minimal.tar.gz; \
    tar -zxf v${CRS_VERSION}-minimal.tar.gz --strip-components=1 -C /opt/owasp-crs; \
    rm -f v${CRS_VERSION}-minimal.tar.gz coreruleset-${CRS_VERSION}-minimal.tar.gz.asc; \
    mv -v /opt/owasp-crs/crs-setup.conf.example /opt/owasp-crs/crs-setup.conf; \
    find /opt/owasp-crs/rules -type f -name "*.conf" | xargs sed -ie "s|@pmFromFile |@pmFromFile /opt/owasp-crs/rules/|g"
RUN curl -sSL https://github.com/coreruleset/modsecurity-crs-docker/archive/refs/tags/release/${CRS_DOCKER_VERSION}.tar.gz \
        -o modsecurity-crs-docker-${CRS_DOCKER_VERSION}.tar.gz; \
    tar -zxf modsecurity-crs-docker-${CRS_DOCKER_VERSION}.tar.gz; \
    rm -f modsecurity-crs-docker-${CRS_DOCKER_VERSION}.tar.gz; \
    mkdir -p /etc/modsecurity.d; \
    cp -a modsecurity-crs-docker-release-${CRS_DOCKER_VERSION}/src/etc/modsecurity.d/. /etc/modsecurity.d/; \
    mkdir -p /opt/modsecurity; \
    cp -a modsecurity-crs-docker-release-${CRS_DOCKER_VERSION}/src/opt/modsecurity/. /opt/modsecurity/; \
    rm -rf modsecurity-crs-docker-release-${CRS_DOCKER_VERSION}

# chef
FROM rust:alpine3.20 AS chef

WORKDIR /build

RUN apk add --no-cache musl-dev
RUN cargo install cargo-chef

# Planner
FROM chef AS planner

COPY . .

RUN cargo chef prepare --recipe-path recipe.json

# Builder
FROM chef AS builder

ARG MODSECURITY_VERSION
ARG LUA_VERSION

ENV OPENSSL_NO_VENDOR=1

RUN apk add --no-cache \
    autoconf \
    automake \
    ca-certificates \
    coreutils \
    curl \
    curl-dev \
    g++ \
    gcc \
    git \
    libc-dev \
    libfuzzy2-dev \
    libmaxminddb-dev \
    libstdc++ \
    libtool \
    libxml2-dev \
    linux-headers \
    lmdb-dev \
    lua${LUA_VERSION}-dev \
    make \
    openssl \
    openssl-dev \
    patch \
    pkgconfig \
    pcre-dev \
    pcre2-dev \
    yajl-dev \
    zlib-dev

# Copy modsecurity
COPY --from=modsecurity-builder /usr/local/modsecurity/lib-dev/lib*.so* /usr/local/modsecurity/lib/
COPY --from=modsecurity-builder /build/ModSecurity/modsecurity.pc /usr/local/modsecurity/lib/pkgconfig/

ENV PKG_CONFIG_PATH=/usr/local/modsecurity/lib/pkgconfig
RUN ldconfig /usr/local/modsecurity/lib/

# Build & cache dependencies
COPY --from=planner /build/recipe.json recipe.json
#RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

# Build app
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl

# Release
FROM alpine:3.20

ARG LUA_VERSION
ARG LUA_MODULES
ARG MODSECURITY_VERSION
ARG CRS_DOCKER_VERSION

ENV RUST_LOG=info
ENV HOST=0.0.0.0
ENV PORT=8080

WORKDIR /app

COPY --from=modsecurity-builder /usr/local/modsecurity/lib/libmodsecurity.so.${MODSECURITY_VERSION} /usr/lib/
COPY --from=modsecurity-builder /etc/modsecurity.d/unicode.mapping /etc/modsecurity.d/unicode.mapping
RUN ln -s /usr/lib/libmodsecurity.so.${MODSECURITY_VERSION} /usr/lib/libmodsecurity.so.3.0; \
    ln -s /usr/lib/libmodsecurity.so.${MODSECURITY_VERSION} /usr/lib/libmodsecurity.so.3; \
    ln -s /usr/lib/libmodsecurity.so.${MODSECURITY_VERSION} /usr/lib/libmodsecurity.so

COPY --from=coreruleset /opt/owasp-crs /opt/owasp-crs
COPY --from=coreruleset /opt/modsecurity /docker-entrypoint.d
COPY --from=coreruleset /etc/modsecurity.d /etc/modsecurity.d

RUN apk add --no-cache \
        curl \
        curl-dev \
        libfuzzy2 \
        libmaxminddb-dev \
        libstdc++ \
        libxml2-dev \
        lmdb-dev \
        lua${LUA_VERSION} \
        ${LUA_MODULES} \
        moreutils \
        pcre \
        pcre2 \
        yajl \
        sed
RUN ln -sv /opt/owasp-crs /etc/modsecurity.d/
RUN mkdir -p /tmp/modsecurity/data; \
    mkdir -p /tmp/modsecurity/upload; \
    mkdir -p /tmp/modsecurity/tmp

COPY --from=builder /build/target/x86_64-unknown-linux-musl/release/waf-modsecurity /app/waf-modsecurity

EXPOSE 3000

ENTRYPOINT ["/app/waf-modsecurity"]