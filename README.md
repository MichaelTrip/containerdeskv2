# Debian XRDP desktop container

A multi-architecture Debian 13 desktop image with XRDP and XFCE. It supports
both `linux/amd64` and `linux/arm64` (including a Raspberry Pi 4 running a
64-bit OS).

Desktop applications include Firefox ESR, Chromium, Thunderbird, LibreOffice,
Visual Studio Code, Freelens, Headlamp, Pluma, and Tilix. The image also
contains kubectl, Helm, k9s, kubecm, kubectx, Vim, Zsh, Java, common network
diagnostics, and shell-completion support. The XRDP user belongs to `sudo` and
can elevate using the same password used to log in.

## Start with Docker Compose

Create the environment file and replace the example password:

```sh
cp .env.example .env
docker compose up --build -d
```

Connect an RDP client to port `3389` on the Docker host and log in with
`XRDP_USERNAME` and `XRDP_PASSWORD`.

Compose refuses to start if either required variable is absent. The container
entrypoint independently performs the same check, so direct `docker run`
invocations are also protected:

```sh
docker build -t xrdp-desktop:debian13 .
docker run -d \
  --name xrdp-desktop \
  -p 3389:3389 \
  --shm-size=1g \
  -e XRDP_USERNAME=desktop \
  -e XRDP_PASSWORD='replace-me' \
  -v xrdp-home:/home \
  xrdp-desktop:debian13
```

The `/home` volume preserves the user's browser profiles, documents, mail,
and desktop settings when the container is replaced. Keep the same username,
UID, and GID when reusing an existing volume. `XRDP_UID` and `XRDP_GID` both
default to `1000`.

Passwords may contain shell-special characters, but not a colon or newline.
Avoid exposing TCP port 3389 directly to the public internet; use a firewall,
VPN, or SSH tunnel.

## Multi-platform image

The Dockerfile uses packages available on both target architectures. Build and
push a manifest containing AMD64 and ARM64 variants with Buildx:

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t registry.example.com/xrdp-desktop:debian13 \
  --push .
```

A normal `docker compose build` automatically builds for the host architecture.
The Raspberry Pi must use a 64-bit OS to run the `linux/arm64` variant.
