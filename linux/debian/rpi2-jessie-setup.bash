#!/bin/bash
##
## Copyright (c) 2015 SATOH Fumiyasu @ OSS Technology Corp., Japan
##
## License: GNU General Public License version 3
##
## WARNING: NO WARRANTY
##

set -u
set -e

mnt='/mnt'
dev='/dev/mmcblk0p2'
hostname='rpi.example.jp'
username=$(id -un)
if='eth0'
address='192.168.0.8/24'
gateway='192.168.0.1'
dns_list=(192.168.0.1 8.8.8.8)

## ----------------------------------------------------------------------

groupname=$(id -gn "$username")
home=$(getent passwd "$username" |sed 's/:[^:]*$//;s/.*://')

## ======================================================================

sudo mount "$dev" "$mnt"

trap 'sudo umount "$mnt"' EXIT

## ======================================================================

echo "$hostname" |sudo tee "$mnt/etc/hostname" >/dev/null

(
cat <<EOF
[Match]
Name=$if

[Network]
Address=$address
Gateway=$gateway
EOF
for dns in "${dns_list[@]}"; do
  echo "DNS=$dns"
done
)|sudo tee "$mnt/etc/systemd/network/eth0.network" >/dev/null

## ======================================================================

sudo sed -i 's/^#*\(PasswordAuthentication\).*/\1 no/' "$mnt/etc/ssh/sshd_config"
for t in dsa rsa ecdsa ed25519; do
  k="$mnt/etc/ssh/ssh_host_${t}_key"
  sudo rm -f "$k" "$k.pub"
  sudo ssh-keygen -q -t $t -C "$hostname" -N '' -f "$k"
done

## ======================================================================

sudo sed -i "/^${username//./\\.}:/d" "$mnt/etc/passwd"
getent passwd "$username" \
|sed '$s/[^:]*$/\/bin\/bash/' \
|sudo tee -a "$mnt/etc/passwd" >/dev/null

sudo sed -i "/^${username//./\\.}:/d" "$mnt/etc/shadow"
sudo getent shadow "$username" |sudo tee -a "$mnt/etc/shadow" >/dev/null

sudo sed -i "/^${groupname//./\\.}:/d" "$mnt/etc/group"
getent group "$groupname" |sudo tee -a "$mnt/etc/group" >/dev/null

sudo mkdir -p -m 0755 "$mnt$home/.ssh"
sudo cp -p "$home/.ssh/id_rsa.pub" "$mnt$home/.ssh/authorized_keys"
sudo chown -hR "$username:" "$mnt$home"

## ======================================================================

exit 0

