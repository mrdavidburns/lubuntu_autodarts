# Changelog

All notable changes to this project will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- `setup_boot_speed.sh`: zero GRUB timeout (hidden), kernel cmdline
  tuning (`vt.global_cursor_default=0 logo.nologo udev.log_level=3
  i915.fastboot=1 fbcon=nodefer`), zstd-compressed initramfs,
  `DefaultTimeoutStopSec=10s` system-wide, `TimeoutStopSec=3` on
  `autodarts-chrome.service`. Disables `NetworkManager-wait-online`,
  `motd-news`, and `apt-daily*` timers (kiosk doesn't need them).
  Wired into `essentials.sh` after the Plymouth step.

### Fixed
- CI smoke build no longer references nonexistent `logger` package
  (the binary ships in `bsdutils`); add `iproute2` so
  `autodarts-status` can read interfaces.
- Drop `ENTRYPOINT ["/bin/bash","-l"]` from `tests/Dockerfile.smoke`
  so `docker run … bash -c "…"` from CI doesn't try to exec the literal
  `bash` arg as a script (was producing
  `cannot execute binary file` exit 126).
- All scripts that derive the kiosk user now use the
  `${SUDO_USER:-${USER:-$(id -un)}}` pattern. Earlier
  `${SUDO_USER:-$USER}` tripped `set -u` in containers where neither
  `$SUDO_USER` nor `$USER` is set.
- `lib/common.sh` `ad_actual_user` falls back to `id -un` when both
  env vars are empty.
- `setup_backup.sh` / `setup_repo_autoupdate.sh` only call
  `systemctl daemon-reload` + `enable --now` when
  `/run/systemd/system` exists, so smoke containers without
  systemd-init don't fail.
- `bin/autodarts-status` resolves `USER_HOME` via `getent passwd`
  (replaces `eval echo ~user`), with `$HOME` fallback.

### Changed
- `shfmt -i 4 -ci -bn` is now the canonical formatter; all shell
  files reformatted accordingly. CI fails the lint job on diff.

## [2.0.0] - 2026-05-03
### Added
- One-line bootstrap (`install.sh`).
- Shared `lib/common.sh`, `lib/preflight.sh`, `lib/verify.sh`.
- Logging tee to `/var/log/autodarts-setup.log`.
- HDMI audio routing via `setup_audio_hdmi.sh` (handles `output:hdmi-stereo*`).
- SDDM autologin (`setup_autologin.sh`).
- Chrome managed policy with force-installed
  Tools for Autodarts (`setup_chrome_policy.sh`).
- systemd `--user` Chrome watchdog with `Restart=always`
  (`setup_chrome_watchdog.sh`); replaces autostart `.desktop`.
- Kiosk hardening: blanking/sleep masked, popups suppressed, panel locked,
  unclutter, fwupd, NTP, Bluetooth off, DnD, power button → poweroff,
  `NAutoVTs=1`, ufw, sudoers lockdown, brightness keys.
- Operator tools: `autodarts-status`, `sound-test`, `exit-kiosk` (Ctrl+Alt+Q),
  branded SSH MOTD.
- Desktop shortcuts (Restart/Reboot/Shutdown/SUIT/Sound Test/Status).
- Unattended security upgrades (auto-reboot 04:00).
- Weekly config backup + repo self-update — now systemd timers, not cron.
- Optional Tailscale enrollment (`AD_ENABLE_TAILSCALE=1 TS_AUTHKEY=...`).
- Prometheus textfile exporter via `autodarts-status`.
- CI: shellcheck, shfmt, ruff, JSON parse, bats unit tests, Docker smoke
  test, idempotency check.
- Release workflow + Dependabot for GH Actions.
- VERSION file + CHANGELOG.

### Changed
- Google Chrome installs via Google's signed apt repo (GPG-verified) instead
  of raw `.deb`.
- SUIT install pinned via `SUIT_REF` env (default `main`).
- All scripts: `eval echo ~user` → `getent passwd | cut -d: -f6`.
- `setup_grub_theme.sh` / `setup_plymouth_theme.sh` use absolute `REPO_DIR`.
- Plymouth `update-initramfs` skipped when theme + modules hash unchanged.
- `update_quick_launch.py` creates `[quicklaunch]` section if missing.
- `essentials.sh` re-execs under sudo, holds `/var/lock/autodarts-setup.lock`,
  `set -Eeuo pipefail`, `trap ERR`.

### Security
- Chrome `.deb` signature verified through apt repository.
- Sudoers lockdown limits the kiosk user's passwordless commands.
- Firewall denies all inbound except mDNS + Tailscale tunnel.
- Power button + lid handling pinned via `/etc/systemd/logind.conf.d/`.

## [1.x]
Prior history captured in git log.
