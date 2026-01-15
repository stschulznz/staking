# ============================================================
# LUKS USB: convert /mnt/validator_keys to systemd .automount
# Works even if USB is missing/locked at boot.
#
# RUN ON NODE002 FIRST (standby). Then run on NODE001 in a window.
# ============================================================

# --------------------------
# NODE002 (standby) - SAFE
# --------------------------

# 0) Pre-check (see what is mounted)
findmnt /mnt/validator_keys -o TARGET,SOURCE,FSTYPE,OPTIONS || true
mount | egrep -i '/mnt/validator_keys|validator_keys' || true

# 1) Create a clean automount unit (NO Requires/After on unlock)
sudo tee /etc/systemd/system/mnt-validator_keys.automount >/dev/null <<'EOF'
[Unit]
Description=Automount Validator Keys

[Automount]
Where=/mnt/validator_keys

[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
EOF

# 2) Reload systemd and rewire enablement
sudo systemctl daemon-reload
sudo systemctl reset-failed mnt-validator_keys.automount mnt-validator_keys.mount validator-keys-unlock.service || true
sudo systemctl disable mnt-validator_keys.automount || true
sudo systemctl enable mnt-validator_keys.automount

# 3) Switch immediately (Option B): stop existing mount, unmount, start automount
sudo systemctl stop mnt-validator_keys.mount || true
sudo umount /mnt/validator_keys || true

sudo systemctl start mnt-validator_keys.automount
sudo systemctl status mnt-validator_keys.automount --no-pager

# 4) Ensure unlock is active (mapper exists)
sudo systemctl restart validator-keys-unlock.service
sudo cryptsetup status validator_keys || true

# 5) Trigger the mount via access and verify correct source
ls -la /mnt/validator_keys
findmnt /mnt/validator_keys -o TARGET,SOURCE,FSTYPE,OPTIONS
df -hT /mnt/validator_keys

# 6) Disable boot-time mount unit so it doesn't race/fail at boot
sudo systemctl disable mnt-validator_keys.mount || true

# 7) Reboot test (recommended)
# sudo reboot


# --------------------------
# NODE001 (ACTIVE) - DO IN A MAINTENANCE WINDOW
# --------------------------
# IMPORTANT: stop Rocket Pool first so nothing is using the USB mount.

# 0) Stop Rocket Pool stack
rocketpool service stop

# 1) Confirm nothing is using the mount (should be empty output)
sudo lsof +f -- /mnt/validator_keys || true

# 2) Create the same automount unit
sudo tee /etc/systemd/system/mnt-validator_keys.automount >/dev/null <<'EOF'
[Unit]
Description=Automount Validator Keys

[Automount]
Where=/mnt/validator_keys

[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
EOF

# 3) Reload + enable automount
sudo systemctl daemon-reload
sudo systemctl reset-failed mnt-validator_keys.automount mnt-validator_keys.mount validator-keys-unlock.service || true
sudo systemctl disable mnt-validator_keys.automount || true
sudo systemctl enable mnt-validator_keys.automount

# 4) Switch immediately (Option B): stop existing mount, unmount, start automount
sudo systemctl stop mnt-validator_keys.mount || true
sudo umount /mnt/validator_keys || true

sudo systemctl start mnt-validator_keys.automount
sudo systemctl status mnt-validator_keys.automount --no-pager

# 5) Ensure unlock is active, trigger mount, verify
sudo systemctl restart validator-keys-unlock.service
sudo cryptsetup status validator_keys || true

ls -la /mnt/validator_keys
findmnt /mnt/validator_keys -o TARGET,SOURCE,FSTYPE,OPTIONS
df -hT /mnt/validator_keys

# 6) Disable boot-time mount unit (prevents boot failure when USB is locked/missing)
sudo systemctl disable mnt-validator_keys.mount || true

# 7) Sanity check Rocket Pool data path BEFORE restarting
readlink -f ~/.rocketpool/data || true
ls -la ~/.rocketpool/data || true

# 8) Start Rocket Pool again
rocketpool service start

# 9) Optional reboot later to confirm boot behavior
# sudo reboot