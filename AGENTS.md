# Repository guidance

## Project overview

This repository builds a Debian 13 slim desktop container with XFCE (default) or MATE and XRDP,
desktop applications, and Kubernetes command-line tools. There is no application
framework, dependency lockfile, or automated test suite. The main integration
check is building and running the image.

## File map

- `Dockerfile`: packages, pinned tool versions, architecture-specific downloads,
  desktop configuration, health check, and the `tini` entrypoint.
- `config/docker-entrypoint.sh`: validates environment variables, creates the desktop
  user, prepares persistent home defaults, and manages D-Bus and XRDP processes.
- `compose.mate.yaml`: standalone MATE configuration with a separate project and
  home volume; builds the shared Dockerfile with `DESKTOP=mate`.
- `config/mate-theme.gschema.override`: MATE-only theme defaults, compiled during the
  image build; user settings take precedence.
- `config/skel-mate/`: MATE session defaults. Keep these separate from XFCE defaults.
- `compose.yaml`: local build and runtime settings, port mapping, 1 GB shared
  memory, and the persistent `xrdp-home` volume mounted at `/home`.
- `.env.example`: sample runtime variables; `.env` is ignored by Git and Docker.
- `config/skel/`: initial user defaults copied to `/etc/skel`, including the XFCE session
  launcher and icon theme. The Dockerfile adds the desktop wallpaper configuration.
- `config/code-wrapper`, `config/headlamp-wrapper`, `config/chromium-container.conf`: container-specific
  application launch flags. `config/headlamp.desktop` provides the desktop menu entry.
- `.github/workflows/build.yml`: scheduled, push, pull-request, and manual image
  builds. Pull requests build without pushing; other configured events publish.

## Implementation conventions

- Keep changes focused and follow the existing shell, Dockerfile, and YAML style.
  Update `README.md` and `.env.example` when changing user-facing configuration.
- The entrypoint uses Bash with `set -Eeuo pipefail`; wrappers and `.xsession`
  use POSIX `sh`. Keep Bash syntax out of those POSIX scripts, quote variable
  expansions, and preserve argument forwarding with `"$@"` in wrappers.
- Do not run the entrypoint directly on the host: it changes users, groups,
  passwords, ownership, and system services. Exercise runtime behavior inside
  disposable containers.
- Preserve required username/password validation, positive UID/GID checks, and
  rejection of passwords containing colons or newlines. Never log passwords or
  commit `.env` or real credentials.
- `/home` is persistent. Preserve existing user settings when seeding defaults;
  the entrypoint currently installs missing XFCE configuration files only.
  Keep username/UID/GID stable when reusing a volume and avoid deleting home data
  as part of testing or cleanup.
- Preserve signal forwarding and cleanup: `tini -g` starts the entrypoint, which
  supervises both XRDP processes and shuts them down when either exits.
- Keep application wrappers and their desktop launchers consistent. Existing
  sandbox flags address container restrictions; changes need a GUI smoke test
  under the normal container settings.
- Keep tool versions in Dockerfile `ARG`s and retain existing checksum checks.
  When changing downloads, verify upstream asset names for both `amd64` and
  `arm64`; some projects use `x86_64` or `x64` instead of `amd64`.
- The Dockerfile targets AMD64 and ARM64, but CI currently builds only
  `linux/amd64`. Do not describe a passing CI run as ARM64 validation.
- When adding image inputs, check Dockerfile `COPY` instructions, executable
  permissions, `.dockerignore`, and the workflow's push path filters.

## Validation

Run checks appropriate to the change from the repository root. For shell edits:

```sh
bash -n config/docker-entrypoint.sh
for script in config/code-wrapper config/headlamp-wrapper config/skel/.xsession config/skel-mate/.xsession config/chromium-container.conf; do
    sh -n "$script" || exit 1
done
git diff --check
```

Validate Compose interpolation without creating a real credentials file:

```sh
XRDP_USERNAME=desktop XRDP_PASSWORD=validation-only docker compose config --quiet
XRDP_USERNAME=desktop XRDP_PASSWORD=validation-only docker compose -f compose.mate.yaml config --quiet
```

For image changes, build locally:

```sh
docker build -t xrdp-desktop:debian13-xfce .
docker build --build-arg DESKTOP=mate -t xrdp-desktop:debian13-mate .
```

For architecture-specific changes, use Buildx to build each target separately
with `--platform linux/amd64` or `--platform linux/arm64` and `--load`, using a
builder capable of that architecture. Builds download large packages and need
network access. Do not push an image just to validate it.

For runtime changes, use a disposable container and fresh test volume. Check
credential rejection, successful startup, container health, RDP login to the selected desktop,
and clean shutdown as applicable. For persistent-home changes, recreate the
container with the same volume and confirm that custom settings survive. For
application changes, launch the affected program from the desktop. The health
check only confirms that `xrdp` and `xrdp-sesman` processes exist; it does not
verify a working graphical login.

Documentation-only changes do not require an image build. Report checks actually
performed and identify unavailable Docker, architecture, or GUI validation.

CI uses a desktop matrix with separate cache scopes. All image tags use the
`-xfce` or `-mate` suffix; main and release builds also publish `debian13-xfce`
and `debian13-mate`. Shared changes need validation for
both desktops. Never overwrite an existing home session to switch desktops.
