---
title: rsync 技術情報
layout: default
---

概要
----------------------------------------------------------------------

あとで書く。いつか書く。

`rsync`(1), `rsyncd.conf`(5), `ssh`(1), `authorized_keys`(5)

インストール
----------------------------------------------------------------------

Debian / Ubuntu の場合:

``` console
# apt-get install rsync openssh-client
```

RHEL の場合:

``` console
# yum install rsync openssh-clients
```

rsync over SSH によるプッシュ方式のバックアップ
----------------------------------------------------------------------

バックアップ対象のファイル群が存在するホストでスクリプトを実行し、
バックアップ先ホストへ転送する手順です。
(**「バックアップ」と称していますが、それ以外の用途にも利用できます**)

次の条件とします。

  * バックアップ対象のファイルがあるホストでバックアップスクリプトを実行する。
  * rsync over SSH を利用して安全にデータを送受信する。
  * rsync over SSH 専用の SSH 鍵ペアを用意する。
    (rsync 以外のシェルログイン等の操作は抑制する)
  * バックアップデータの世代管理は必要であれば別途実施すること。
  * バックアップ対象
    * ホスト名: `target-host`
    * 実行ユーザー: `root`
    * バックアップスクリプト: `/srv/sbin/backup-target-host`
    * SSH 鍵ペア: `/srv/etc/backup/id_rsa*`
    * バックアップ対象パス:
      * `/etc`
      * `/var/lib`
      * `/home`
  * バックアップ先
    * ホスト名: `backup-host`
    * 実行ユーザー: `backupuser`
    * バックアップディレクトリ: `/srv/var/backup/target-host`
    * rsync デーモン設定ファイル: `/srv/etc/backup/rsyncd.conf`

### バックアップ対象ホスト target-host での環境構築

バックアップ対象ホスト target-host で
SSH 鍵ペア `/srv/etc/backup/id_rsa*` を作成します。
SSH 接続を無人で行なえるようにするため、パスフレーズなしにします。

``` console
# mkdir -p /srv/etc/backup
# ssh-keygen -t rsa -N '' -f /srv/etc/backup/id_rsa
```

バックアップ対象ホスト target-host でバックアップスクリプト
`/srv/sbin/backup-target-host` を作成します。
**`ssh`(1) のオプションや
rsync の `--exclude` オプション (除外ファイル) は適宜調整してください**。

``` sh
#!/bin/bash

set -u
set -e

## ======================================================================

ssh_id="/srv/etc/backup/id_rsa"
ssh_opts="-o 'ServerAliveInterval 60'"

src_paths=(
  /etc
  /var/lib
  /home
)

dst="backup-user@backup-host::target-host"

## ======================================================================

rsync \
  --rsh "ssh -i '$ssh_id' $ssh_opts" \
  --archive \
  --relative \
  --omit-dir-times \
  --delete \
  --delete-excluded \
  --exclude '.sw?' \
  --exclude '.*.sw?' \
  --exclude '.libs' \
  --exclude '*~' \
  --exclude '*.tmp' \
  --exclude '*.bak' \
  --exclude '*.old' \
  --exclude '*.[oa]' \
  --exclude '*.l[oa]' \
  --exclude '*.pyc' \
  --exclude 'tmp/*' \
  --exclude '**/log/*' \
  --exclude '/var/lib/apt/lists/*' \
  --exclude '/var/lib/clamav/*' \
  --exclude '/var/lib/dpkg/info/*' \
  --exclude '/var/lib/mecab/dic/*' \
  --exclude '/var/lib/mlocate/mlocate.db' \
  --exclude '/var/lib/dkms/*' \
  --exclude '/var/lib/dropbox/*' \
  --exclude '/var/lib/groonga/db/*' \
  --exclude '/var/lib/gems/*' \
  "$@" \
  "${src_paths[@]}" \
  "$dst" \
  ;

```

### バックアップ先ホスト backup-host での環境構築

バックアップ先ホスト backup-host のバックアップ実行ユーザーの SSH 認可ファイル
`~backup-user/.ssh/authorized_keys` に
SSH 公開鍵を登録します。
公開鍵の前に各種オプションを記述することで
rsync 以外の実行や各種オプション機能を無効にして、
バックアップ以外の用途に利用されないようにします。
実行優先度を調整したい場合は `rsync ...` の前に`nice ` を、
IO 優先度を調整したい場合は `ionice -n7 `
などを追加してもいいでしょう。

```
command="rsync --server --daemon --config=/srv/etc/backup/rsyncd.conf .",no-agent-forwarding,no-port-forwarding,no-pty,no-x11-forwarding <target-host:/srv/etc/backup/id_rsa.pub の内容>
```

バックアップ先ホスト backup-host で rsync デーモンの設定ファイル
`/srv/etc/backup/rsyncd.conf` を用意します。

``` ini
[global]
## バックアップ先ホストで root 権限で実行しない場合
use chroot = no
## バックアップ先ホストで root 権限で実行しない場合、かつ
## バックアップ対象に複数のユーザー/グループ所有ファイルなどが含まれる場合
fake super = yes

## バックアップ先ホストで root 権限で実行する場合、かつ
## バックアップ対象ホストとユーザー/グループ構成・UID/GID 値が異なる場合
#numeric ids = yes

[target-host]
path = /srv/var/backup/target-host
read only = no
## バックアップ先を書き込み専用にする場合
#write only = yes
```

### 動作確認と自動化

動作確認のため、バックアップスクリプトを冗長モード (`--verbose`)
かつ実際の転送なし (`--dry-run`) で実行し、
想定通りのファイルが転送されることを確認します。

```
# /srv/sbin/backup-target-host --verbose --dry-run
…
```

問題なければ cron などで実行を自動化します。

`/etc/crontab` ファイルにより毎日午前 4時に実行するための記述例を示します。
この例では、実行優先度を調整するために `nice`(1) を、
IO 優先度を調整するために `ionice`(1) を、
rsync で圧縮転送を利用するために `--compress` オプションを指定しています。

```
00 04 * * * root nice ionice -n7 /srv/sbin/backup --compress
```

### リストアの例

``` console
# rsync \
  --rsh 'ssh -i /srv/etc/backup/id_rsa' \
  --archive \
  --relative \
  backup-user@backup-host::'target-host/etc target-host/var target-host/home' \
  /path/to/restore \
  ;
```

