# LUKS-Encrypted USB Setup for Rocket Pool Data

This guide documents how to place the Rocket Pool data directory on a hardware-protected, LUKS-encrypted USB drive (with physical PIN entry) and ensure it auto-unlocks and mounts during boot. Follow the steps in order: prepare the encrypted drive, configure systemd units, verify the mount, then migrate the existing `~/.rocketpool/data` directory onto the secure volume.

## 1. Install Dependencies

```bash
sudo apt update
sudo apt install cryptsetup
```

## 2. Prepare and Format the USB Drive (new or replacement media only)

Skip this section if you are reusing an already-initialized LUKS drive; otherwise follow it once per new thumbdrive.

> **Warning:** These commands erase the target USB drive. Double-check the device path (e.g., `/dev/sdX`) with `lsblk` before running them.

1. Identify the device name:

	```bash
	lsblk -f
	```

2. Remove any existing signatures (optional but recommended):

	```bash
	sudo wipefs -a /dev/sdX
	sudo sgdisk --zap-all /dev/sdX
	```

3. Create a single GPT partition occupying the full drive:

	```bash
	sudo parted /dev/sdX --script mklabel gpt mkpart primary ext4 0% 100%
	```

4. Initialize the partition with LUKS (you will be prompted for a passphrase—use the same one tied to the PIN hardware token if required):

	```bash
	sudo cryptsetup luksFormat /dev/sdX1
	```

5. Open the LUKS container and create an ext4 filesystem:

	```bash
	sudo cryptsetup luksOpen /dev/sdX1 validator_keys_tmp
	sudo mkfs.ext4 /dev/mapper/validator_keys_tmp
	sudo cryptsetup luksClose validator_keys_tmp
	```

At this point the USB drive contains a clean LUKS container with an ext4 filesystem, ready for the automated unlock/mount configuration.

## 3. Collect LUKS Device Metadata

Replace `/dev/sdX1` with your USB partition device path.

```bash
sudo cryptsetup luksUUID /dev/sdX1
```

Copy the UUID from the output; you will use both the plain UUID and an escaped version (replace each hyphen `-` with `\x2d`) inside the systemd unit files.

## 4. Create a Secure Keyfile and Add It to LUKS

```bash
sudo dd if=/dev/urandom of=/root/luks-keyfile bs=512 count=1
sudo chmod 400 /root/luks-keyfile
sudo cryptsetup luksAddKey /dev/sdX1 /root/luks-keyfile
```

The final command prompts for the existing LUKS passphrase to authorize adding the keyfile.

## 5. Create the Mount Point

```bash
sudo mkdir -p /mnt/validator_keys
```

## 6. Create the Systemd Unlock Service

Create `/etc/systemd/system/validator-keys-unlock.service` with the following content, substituting your UUID values:

```ini
[Unit]
Description=Unlock Validator Keys USB
After=dev-disk-by\x2duuid-YOUR-ESCAPED-UUID.device
Requires=dev-disk-by\x2duuid-YOUR-ESCAPED-UUID.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/cryptsetup luksOpen UUID=YOUR-UUID validator_keys --key-file /root/luks-keyfile
ExecStop=/usr/sbin/cryptsetup luksClose validator_keys

[Install]
WantedBy=multi-user.target
```

- `After`/`Requires` ensure the service waits for the USB block device.
- `ExecStart` unlocks the device into `/dev/mapper/validator_keys` using the keyfile.

## 7. Create the Systemd Mount Unit

Create `/etc/systemd/system/mnt-validator_keys.mount` with:

```ini
[Unit]
Description=Mount Validator Keys
After=validator-keys-unlock.service
Requires=validator-keys-unlock.service

[Mount]
What=/dev/mapper/validator_keys
Where=/mnt/validator_keys
Type=ext4
Options=defaults

[Install]
WantedBy=multi-user.target
```

## 8. Enable and Test the Units

```bash
sudo systemctl daemon-reload
sudo systemctl enable validator-keys-unlock.service
sudo systemctl enable mnt-validator_keys.mount

sudo systemctl start validator-keys-unlock.service
sudo systemctl start mnt-validator_keys.mount
ls /mnt/validator_keys
```

If the directory listing succeeds, reboot to confirm automatic unlock/mount:

```bash
sudo reboot
```

After the system restarts, verify:

```bash
ls /mnt/validator_keys
sudo systemctl status validator-keys-unlock.service
sudo systemctl status mnt-validator_keys.mount
```

## 9. Migrate the Rocket Pool Data Directory

Once the encrypted volume is mounted, move the existing Rocket Pool data directory and replace it with a symbolic link.

```bash
rocketpool service stop
sleep 10
sudo mv ~/.rocketpool/data /mnt/validator_keys/data
ln -s /mnt/validator_keys/data ~/.rocketpool/data
ls -la ~/.rocketpool/data
sudo reboot
```

After logging back in:

```bash
ls /mnt/validator_keys/data
ls -la ~/.rocketpool/data
rocketpool service start
rocketpool service status
```

## 10. Operational Checklist

- Before starting Rocket Pool services, ensure the USB drive is inserted, unlocked via its physical PIN, and the systemd units have mounted `/mnt/validator_keys`.
- During failovers, confirm the symbolic link points to the mounted path and that the validator keystores are accessible. See the failover runbook for specific verification steps.

## 11. Troubleshooting Tips

- If the mount unit fails at boot, check `journalctl -u validator-keys-unlock.service -b` for cryptsetup errors (often incorrect UUID or missing keyfile permissions).
- Use `lsblk -f` to confirm the USB partition name if the device path changes.
- Keep an offline backup of the mnemonic/password; never store it on the USB drive.
