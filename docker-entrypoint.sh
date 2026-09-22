#!/usr/bin/env bash
set -Eeuo pipefail

readonly username="${XRDP_USERNAME:-}"
readonly password="${XRDP_PASSWORD:-}"
readonly user_uid="${XRDP_UID:-1000}"
readonly user_gid="${XRDP_GID:-1000}"

if [[ -z "$username" ]]; then
    echo "ERROR: XRDP_USERNAME must be set and non-empty." >&2
    exit 64
fi

if [[ -z "$password" ]]; then
    echo "ERROR: XRDP_PASSWORD must be set and non-empty." >&2
    exit 64
fi

if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo "ERROR: XRDP_USERNAME must be a valid lowercase Linux username (maximum 32 characters)." >&2
    exit 64
fi

if [[ "$password" == *$'\n'* || "$password" == *:* ]]; then
    echo "ERROR: XRDP_PASSWORD must not contain a colon or newline." >&2
    exit 64
fi

if [[ ! "$user_uid" =~ ^[1-9][0-9]*$ || ! "$user_gid" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: XRDP_UID and XRDP_GID must be positive integers." >&2
    exit 64
fi

if getent passwd "$username" >/dev/null; then
    echo "ERROR: User '$username' already exists in the image." >&2
    exit 65
fi

if getent passwd "$user_uid" >/dev/null; then
    echo "ERROR: XRDP_UID $user_uid is already in use." >&2
    exit 65
fi

if getent group "$user_gid" >/dev/null; then
    existing_group="$(getent group "$user_gid" | cut -d: -f1)"
else
    existing_group="$username"
    groupadd --gid "$user_gid" "$existing_group"
fi

useradd \
    --create-home \
    --home-dir "/home/$username" \
    --shell /bin/bash \
    --uid "$user_uid" \
    --gid "$existing_group" \
    --groups audio,video,sudo \
    "$username"

printf '%s:%s\n' "$username" "$password" | chpasswd

# Keep the persistent home usable when it was created by Docker as root.
chown "$username:$existing_group" "/home/$username"

# Seed desktop defaults when a persistent home predates the current image.
readonly xfce_config_dir="/home/$username/.config/xfce4/xfconf/xfce-perchannel-xml"
install -d -m 0755 -o "$username" -g "$existing_group" "$xfce_config_dir"
for config_file in xfce4-desktop.xml xsettings.xml; do
    if [[ ! -e "$xfce_config_dir/$config_file" ]]; then
        install -m 0644 -o "$username" -g "$existing_group" \
            "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/$config_file" \
            "$xfce_config_dir/$config_file"
    fi
done

install -d -m 0755 -o xrdp -g xrdp /run/xrdp /var/run/xrdp
rm -f /run/xrdp/xrdp.pid /run/xrdp/xrdp-sesman.pid \
      /var/run/xrdp/xrdp.pid /var/run/xrdp/xrdp-sesman.pid

if ! pgrep -x dbus-daemon >/dev/null; then
    mkdir -p /run/dbus
    dbus-uuidgen --ensure
    dbus-daemon --system --fork
fi

echo "Starting XRDP for user '$username' on port 3389."

/usr/sbin/xrdp-sesman --nodaemon &
sesman_pid=$!
/usr/sbin/xrdp --nodaemon &
xrdp_pid=$!

shutdown() {
    kill -TERM "$xrdp_pid" "$sesman_pid" 2>/dev/null || true
    wait "$xrdp_pid" "$sesman_pid" 2>/dev/null || true
}
trap shutdown TERM INT

set +e
wait -n "$xrdp_pid" "$sesman_pid"
status=$?
set -e

shutdown
exit "$status"
