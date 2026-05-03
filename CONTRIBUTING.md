# Contributing

## Development setup

```bash
git clone https://github.com/mrdavidburns/lubuntu_autodarts.git
cd lubuntu_autodarts
# install lint/test tooling
sudo apt install -y shellcheck bats jq python3-pip
pip install --user ruff pre-commit
pre-commit install
```

## Running checks locally

```bash
shellcheck -S error essentials.sh install.sh setup_*.sh lib/*.sh \
    bin/autodarts-status bin/exit-kiosk bin/sound-test motd/00-autodarts
shfmt -d -i 4 -ci -bn essentials.sh install.sh setup_*.sh lib/*.sh
ruff check update_quick_launch.py
bats tests/
docker build -f tests/Dockerfile.smoke -t autodarts-smoke .
docker run --rm -v "$PWD:/repo" autodarts-smoke \
    bash -c "cd /repo && AD_AUTOCONFIRM=1 AD_SMOKE=1 ./tests/smoke-run.sh"
```

CI runs all of the above on push and PR.

## Coding conventions

- Bash: `set -euo pipefail` (or `set -Eeuo pipefail` if using `trap ERR`).
- Source `lib/common.sh` instead of redefining helpers.
- Use `ad_atomic_write` for any file in `/etc/`.
- Use `ad_apt` (not raw `apt`) so we wait for the dpkg lock and retry.
- Resolve user homes with `getent passwd | cut -d: -f6`, not `eval echo ~`.
- All new scripts must be idempotent — the self-update cron reruns
  `essentials.sh` weekly.
- Prefer systemd timers over `/etc/cron.d/`.

## Commit style

Conventional Commits — `feat:`, `fix:`, `chore:`, `docs:`, `ci:`, etc.
The release workflow turns these into a changelog when a tag is pushed.

## Releasing

1. Bump `VERSION`.
2. Update `CHANGELOG.md` `[Unreleased]` block.
3. `git tag -s vX.Y.Z` (signed) and push.
4. Release workflow creates the GitHub Release.

## Filing bugs

Open an issue using the bug-report template. Paste the output of
`autodarts-status` and the last 50 lines of `/var/log/autodarts-setup.log`.
