# Debian XRDP desktop container

A multi-architecture Debian 13 desktop image with XRDP and a choice of XFCE (default) or MATE. It supports
both `linux/amd64` and `linux/arm64` (including a Raspberry Pi 4 running a
64-bit OS).

Desktop applications include Firefox ESR, Chromium, Thunderbird, LibreOffice,
Visual Studio Code, Freelens, Headlamp, Pluma, and Tilix. The image also
contains kubectl, Helm, k9s, kubecm, kubectx, kubens, lfk, KubeVirt virtctl
(`virtctl` and `kubectl virt`), OIDC login (`kubectl oidc-login`), Argo CD,
Argonaut, Sofka, Forgejo CLI (`fj`), Vim, Neovim, Midnight Commander, tmux,
jq, Debian yq, Zsh, Java, and common network diagnostics. The XRDP user belongs to `sudo` and
can elevate using the same password used to log in.

The management CLI versions are pinned through Dockerfile build arguments to
match the supplied k8s-mgmt-pod image. Bash completion is enabled for kubectl,
Helm, kubectx, kubens, Argo CD, Sofka, and Forgejo CLI, including the `k=kubectl`
alias. The system-wide setup works in interactive login shells and desktop
terminals, including existing home volumes, without modifying user dotfiles.
Forgejo's completion banner workaround is applied once during the image build.
Rebuild the image and open a new terminal to use these additions. This image
uses XRDP; it does not include the other image's WebSSH2/nginx/SSH-server stack.

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
docker build -t xrdp-desktop:debian13-xfce .
docker run -d \
  --name xrdp-desktop \
  -p 3389:3389 \
  --shm-size=1g \
  -e XRDP_USERNAME=desktop \
  -e XRDP_PASSWORD='replace-me' \
  -v xrdp-home:/home \
  xrdp-desktop:debian13-xfce
```

The `/home` volume preserves the user's browser profiles, documents, mail,
and desktop settings when the container is replaced. Keep the same username,
UID, and GID when reusing an existing volume. `XRDP_UID` and `XRDP_GID` both
default to `1000`.

Passwords may contain shell-special characters, but not a colon or newline.
Avoid exposing TCP port 3389 directly to the public internet; use a firewall,
VPN, or SSH tunnel.

## MATE variant

Use the same `.env` credentials as above, then start the standalone MATE Compose
configuration:

```sh
docker compose -f compose.mate.yaml up --build -d
```

This builds the shared Dockerfile with `DESKTOP=mate`, installs the MATE core
desktop, and starts `mate-session` on RDP login. Both variants include the same
applications and command-line tools. XFCE remains the default build.

MATE defaults to Adwaita Dark for applications, with ClearlooksRe window borders
and a dark color preference for applications that support it. These are defaults,
not locked settings. To apply the theme to an existing profile, run these commands
in a terminal inside your MATE desktop:

```sh
gsettings set org.mate.interface gtk-theme 'Adwaita-dark'
gsettings set org.mate.Marco.general theme 'ClearlooksRe'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

MATE uses its own Compose project (`xrdp-mate`) and home volume
(`xrdp-mate-home`). Keep the desktops on separate home volumes because each
home's `.xsession` selects its desktop. Existing session files are preserved.
To run both variants together, select a different host port for MATE:

```sh
XRDP_PORT=3390 docker compose -f compose.mate.yaml up --build -d
```

Use `docker compose -f compose.mate.yaml logs` and
`docker compose -f compose.mate.yaml down` to inspect or stop MATE. Stopping
without `--volumes` preserves its home data.

To build MATE directly:

```sh
docker build --build-arg DESKTOP=mate -t xrdp-desktop:debian13-mate .
```

Use this image with the `docker run` options above and a separate home volume.
CI builds both desktops for AMD64. Main and release builds publish
`debian13-xfce` and `debian13-mate`. All other tags also include the desktop
suffix, for example `latest-xfce`, `latest-mate`, `1.2.3-xfce`, and `1.2.3-mate`.
Development builds use separate `dev-...-xfce` and `dev-...-mate` tags.

## Multi-platform image

The Dockerfile uses packages available on both target architectures. Build and
push a manifest containing AMD64 and ARM64 variants with Buildx:

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t registry.example.com/xrdp-desktop:debian13-xfce \
  --push .
```

A normal `docker compose build` automatically builds for the host architecture.
The Raspberry Pi must use a 64-bit OS to run the `linux/arm64` variant.

For MATE, add `--build-arg DESKTOP=mate` and use a distinct image tag in the
Buildx command above. ARM64 builds are not currently covered by CI.

## Container configuration

Files copied into the image live under `config/`: application wrappers, desktop
launchers, the entrypoint, theme defaults, and the `skel/` and `skel-mate/` user
defaults. The Dockerfile and Compose files stay in the project root alongside
`.env`, so the build and startup commands above still apply.

Both desktops use `config/wallpaper.png` as the default wallpaper, installed at
`/usr/share/wallpapers/wallpaper.png` (directory mode `0755`, file mode `0644`). XFCE seeds this default for homes
without an existing desktop configuration; MATE uses it as a system default.
Existing user wallpaper settings take precedence. Replace the PNG and rebuild
the image to change the bundled wallpaper.
