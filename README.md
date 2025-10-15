<h1 align="center">
Waf ModSecurity
</h1>

<p align="center">
    <a href="https://github.com/PoloLacoste/waf-modsecurity/issues/new/choose">Report Bug</a>
    ·
    <a href="https://github.com/PoloLacoste/waf-modsecurity/issues/new/choose">Request Feature</a>
</p>

## 🚧 Requirements

- [Rust](https://www.rust-lang.org/)
- [Docker](https://www.docker.com)

For windows : 
- [Docker Desktop](https://www.docker.com/products/docker-desktop)

## 🛠️ Installation Steps

Clone the repo
```sh
git clone https://github.com/PoloLacoste/waf-modsecurity.git
```

You can find the latest version of coreruleset [here](https://github.com/coreruleset/coreruleset/releases)
```sh
./scripts/install-coreruleset.sh <VERSION>
```

Install modsecurity
```sh
./scripts/install-modsecurity.sh
```

You can find the latest version of modsecurity-crs-docker [here](https://github.com/coreruleset/modsecurity-crs-docker/releases)
```sh
./scripts/install-modsecurity-crs.sh <VERSION>
```

Set environment variables, updating `modsecurity.conf`
```sh
./scripts/set-env.sh
```

## 🔧 Build Steps

### 💻 Legacy

The output will be available inside the folder `target/release`.

```sh
cargo build --release
```

### 🐳 For docker

Build the container

```sh
docker buildx bake
```