---
title: "Raspberry Pi 2 + Debian"
layout: default
tags: [linux, debian, rpi, arm]
---
リンク
----------------------------------------------------------------------

  * RaspberryPi2 - Debian Wiki
    * https://wiki.debian.org/RaspberryPi2
  * Debian Jessie on Raspberry Pi 2
    * http://sjoerd.luon.net/posts/2015/02/debian-jessie-on-rpi2/
  * 第362回　Raspberry Pi 2でXubuntu 14.04を動かす：Ubuntu Weekly Recipe｜gihyo.jp … 技術評論社
    * http://gihyo.jp/admin/serial/01/ubuntu-recipe/0362

インストール
----------------------------------------------------------------------

### 用意するもの

  * Raspberry Pi 2 一式
    * 本体
    * USB 電源 (1A 以上) とケーブル
    * ネットワークケーブル
    * microSD カード (4GB 以上)
  * Raspberry Pi 2 用の Debian (jessie / armhf) のイメージ
    * https://images.collabora.co.uk/rpi2/
  * インストール/初期設定用 Linux 環境
    * OS
      * Debian GNU/Linux
    * microSD カードのデバイス名
      * `/dev/mmcblk0`
    * microSD カードのファイルシステムをマウントするディレクトリ
      * `/mnt`
    * `bmaptool`(1)
      * bmap-tools パッケージ
      * `dd`(1) でも構わないが `bmaptool` のほうが効率的

### Raspberry Pi 2 の Debian 環境の設定パラメーター

デフォルトはホスト名 jessie-rpi、ネットワーク設定は DHCP
クライアントになっているが、この手順では次のように設定することにする。

  * ホスト名
    * rpi.example.jp
  * IPアドレス/マスク長
    * 192.168.0.8/24
  * デフォルトルーター
    * 192.168.0.1
  * DNSキャッシュサーバー
    * 192.168.0.1
    * 8.8.8.8

### microSD カードへの Debian イメージのインストール

`wget`(1) や `curl`(1) などで Debian イメージとブロックマップをダウンロードする。

```console
$ wget -q https://images.collabora.co.uk/rpi2/jessie-rpi2-20150202.img.gz
$ wget -q https://images.collabora.co.uk/rpi2/jessie-rpi2-20150202.img.bmap
``` 

microSD カードを SD カードリーダーに挿入する。
必要であれば microSD → SD 変換アダプターを利用する。
近ごろのノート PC の内蔵 SD カードリーダーであれば、
デバイスは `/dev/mmcblk0` になる。
`lsblk`(8) などで確認しよう。

```console
$ sudo lsblk -o +fstype
NAME                     MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT FSTYPE
(…省略…)
mmcblk0                  179:0    0  29.7G  0 disk
```

圧縮されているイメージを展開し、bmaptool で microSD カードに書き込む。

```console
$ gzip -d https://images.collabora.co.uk/rpi2/jessie-rpi2-20150202.img.gz
$ sudo bmaptool copy --bmap jessie-rpi2-20150202.img.bmap jessie-rpi2-20150202.img /dev/mmcblk0
``` 

書き込みが完了すると、microSD カードには 2つのパーティションが作成される。
`/dev/mmcblk0p1` がブート用の VFAT ファイルシステム、
`/dev/mmcblk0p2` が Debian の ext4 ルートファイルシステム。

```console
$ sudo lsblk -o +fstype |sed -n '1p;/mmcblk0/p'
NAME                     MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT FSTYPE
mmcblk0                  179:0    0  29.7G  0 disk
├─mmcblk0p1              179:1    0   121M  0 part            vfat
└─mmcblk0p2              179:2    0   2.8G  0 part            ext4
```

### microSD カード上の Debian ルートファイルシステムのサイズ拡張

Debian イメージは 3GB 分の領域しか使用していないので、
このままだと microSD カードの残り容量が無駄になってしまう。
別途パーティションを切ってファイルシステムを作成し、
ディレクトリの一部を移行するのでもよいが、ルートファイルシステムを拡張するのがお手軽。

まずは `fdisk`(8) か `sfdisk`(8) などを利用してパーティションサイズを拡張する。 
`sfdisk` による手順は次のようになる。
(***デバイス名を間違えると関係ないファイルシステムを壊すので注意***)

```console
$ sudo sfdisk --dump /dev/mmcblk0 |sed '$s/.*,//' |sudo sfdisk /dev/mmcblk0
Checking that no-one is using this disk right now ... OK

Disk /dev/mmcblk0: 29.7 GiB, 31893487616 bytes, 62291968 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x50446648

Old situation:

Device         Boot  Start      End  Sectors  Size Id Type
/dev/mmcblk0p1        2048   249855   247808  121M  c W95 FAT32 (LBA)
/dev/mmcblk0p2      249856 6146047 5896192  2.8G 83 Linux
/dev/mmcblk0p2      249856 62291967 62042112 29.6G 83 Linux

>>> Script header accepted.
>>> Script header accepted.
>>> Script header accepted.
>>> Script header accepted.
>>> Created a new DOS disklabel with disk identifier 0x50446648.
Created a new partition 1 of type 'W95 FAT32 (LBA)' and of size 121 MiB.
/dev/mmcblk0p2: Created a new partition 2 of type 'Linux' and of size 29.6 GiB.
/dev/mmcblk0p3:
New situation:

Device         Boot  Start     End Sectors  Size Id Type
/dev/mmcblk0p1        2048  249855  247808  121M  c W95 FAT32 (LBA)
/dev/mmcblk0p2      249856 6146047 5896192  2.8G 83 Linux

The partition table has been altered.
Calling ioctl() to re-read partition table.
Re-reading the partition table failed.: デバイスもしくはリソースがビジー状態です
The kernel still uses the old table. The new table will be used at the next reboot or after you run partprobe(8) or kpartx(8).
Syncing disks.
```

`lsblk` などで拡張されたことを確認。

```console
$ sudo lsblk -o +fstype |sed -n '1p;/mmcblk0/p'
NAME                     MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT FSTYPE
mmcblk0                  179:0    0  29.7G  0 disk
├─mmcblk0p1              179:1    0   121M  0 part            vfat
└─mmcblk0p2              179:2    0  29.6G  0 part            ext4
```

ext4 ファイルシステムのサイズ拡張には `resize2fs`(8) を利用する。

```console
$ sudo resize2fs /dev/mmcblk0p2
resize2fs 1.42.12 (29-Aug-2014)
Resizing the filesystem on /dev/mmcblk0p2 to 7755264 (4k) blocks.
The filesystem on /dev/mmcblk0p2 is now 7755264 (4k) blocks long.
```

`parted`(8) か `gparted`(8) を利用してもよい。

### microSD カード上の Debian 環境の調整

microSD カードの Debian のルートファイルシステムを適当なディレクトリにマウントする。

```console
$ sudo mount /dev/mmcblk0p2 /mnt
```

ホスト名の設定を上書きする。

```console
$ echo rpi.exmaple.jp |sudo tee /mnt/etc/hostname
```

ネットワークの設定を上書きする。
デフォルトは DHCP クライアント設定になっているので、それでよければ放置して次へ。

```console
$ cat <<EOF |sudo tee /mnt/etc/systemd/network/eth0.network >/dev/null
[Match]
Name=eth0

[Network]
Address=192.168.0.8/24
Gateway=192.168.0.1
DNS=192.168.0.1
DNS=8.8.8.8
EOF
```

SSH サーバーのパスワード認証の無効化、既存ホスト鍵の破棄、
ホスト鍵の生成を行う。

```console
$ sudo sed -i 's/^#*\(PasswordAuthentication\).*/\1 no/' /mnt/etc/ssh/sshd_config
$ sudo rm /mnt/etc/ssh/ssh_host_*_key*
$ for t in rsa ecdsa ed25519; do
  sudo ssh-keygen -q -t $t -C rpi.example.jp -N '' -f /mnt/etc/ssh/ssh_host_${t}_key
done
```

現在作業中の一般ユーザーの情報をコピーする。

この段階では dash と bash しかインストールされていないため、
`/bin/zsh` などを利用している場合、下記例の最後のコマンドラインのようにログインシェルを変更すること。

```console
$ getent passwd `id -un` |sudo tee -a /mnt/etc/passwd >/dev/null
$ getent passwd `id -gn` |sudo tee -a /mnt/etc/group >/dev/null
$ sudo getent shadow `id -un` |sudo tee -a /mnt/etc/shadow >/dev/null
$ sudo sed -i '$s/[^:]*$/\/bin\/bash/' /mnt/etc/passwd
```

現在作業中の一般ユーザーの SSH 公開鍵をコピーして、
公開鍵認証で SSH ログイン可能にする。

```console
$ sudo mkdir -p -m 0755 /mnt$HOME/.ssh
$ sudo chown -hR `id -un`: /mnt$HOME
$ cp -p ~/.ssh/id_rsa.pub /mnt$HOME/.ssh/authorized_keys
```

Debian 環境のルートファイルシステムをアウンマウントする。

```console
$ sudo umount /mnt
```

### ブートとログイン

microSD カードを Raspberry Pi 2 に挿入、ネットワークケーブルを接続、
microUSB 電源を接続し、ブートさせる。

作業に利用したユーザー名で公開鍵認証で SSH ログインできるはず。

```console
$ ssh 192.168.0.8
The authenticity of host '192.168.0.8 (192.168.0.8)' can't be established.
ECDSA key fingerprint is XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.0.8' (ECDSA) to the list of known hosts.

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Wed May 13 16:34:06 2015 from sugar.example.jp
foobar@rpi:~$ 
```

root のパスワードはデフォルトで `debian` に設定されている。
必要であれば変更しよう。

```console
foobar@rpi:~$ su -
Password:
root@rpi:~# passwd
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully
root@rpi:~#
```

