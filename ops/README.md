# dockerhost01 runner cleanup

The runner stores Actions cache data in `/home/runner/.cache/actcache` and
BuildKit data in Docker's storage. These are not Docker volumes. The timer runs
daily at 02:00 local time. It waits for active jobs to finish, rotates the
Actions cache only when it exceeds 6 GiB, prunes the default Buildx cache down
to 4 GB, and removes dangling images older than seven days. Tagged images and
active containers are left alone.

Install on `dockerhost01` with root privileges:

```sh
sudo install -m 0755 ops/forgejo-runner-cleanup.sh /usr/local/sbin/forgejo-runner-cleanup
sudo install -m 0644 ops/forgejo-runner-cleanup.service /etc/systemd/system/
sudo install -m 0644 ops/forgejo-runner-cleanup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now forgejo-runner-cleanup.timer
```

Run it once after all jobs have finished and inspect the result:

```sh
sudo systemctl start forgejo-runner-cleanup.service
systemctl status forgejo-runner-cleanup.service
systemctl list-timers forgejo-runner-cleanup.timer
```

The host runner currently allows three concurrent jobs. Set `runner.capacity`
to `1` in `/home/runner/runner-config.yml` and restart `forgejo-runner.service`
when jobs have finished if the 58 GB root disk cannot support concurrent builds
from other repositories.
