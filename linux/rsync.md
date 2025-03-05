---
title: rsync 技術情報
tags: [rsync,ssh]
layout: default
---

概要
----------------------------------------------------------------------

あとで書く。いつか書く。

`rsync`(1), `rsyncd.conf`(5), `ssh`(1), `authorized_keys`(5)

インストール
----------------------------------------------------------------------

Debian / Ubuntu の場合:

```console
# apt-get install rsync openssh-client
```

RHEL の場合:

```console
# yum install rsync openssh-clients
```

よく利用するオプション
----------------------------------------------------------------------

* `--dry-run` (`-n`)
    * テストモード。実際の同期処理は実行しない。
* `--verbose` (`-v`)
    * 冗長モード。`--dry-run` と組み合せて同期前の確認に利用することが多い。
* `--stats`
    * 同期完了時に統計情報を表示する。
* `--compress` (`-z`)
    * 同期データを圧縮して転送する。
* `--archive` (`-a`)
    * 以下のオプションの列挙に相当する。
        (**注意**: `--acls`, `--xattrs`, `--hard-links` は含まれない)
        + `--recursive` (`-r`)
            * ディレクトリ階層を再帰的に同期する。
        + `--links` (`-l`)
            * シンボリックリンクを保持する。
        + `--perms` (`-p`)
            * パーミッションを保持する。
        + `--times` (`-t`)
            * タイムスタンプを保持する。
        + `--owner` (`-o`)
            * 所有ユーザーを保持する。(root で実行した場合のみ)
        + `--group` (`-g`)
            * 所有グループを保持する。
        + `--devices`
            * デバイスファイルを保持する。(root で実行した場合のみ)
        + `--specials`
            * 特殊ファイルを保持する。
* `--acls` (`-A`)
    * POSIX ACL ファイルを保持する。
* `--xattrs` (`-X`)
    * 拡張属性 (XATTR あるいは EA) を保持する。
* `--hard-links` (`-H`)
    * ハードリンクを保持する。
* `--relative` (`-R`)
    * 同期先に相対パスを含めて転送する。
    (同期元を複数指定した場合に便利)
* `--omit-dir-times`
    * ディレクトリのタイムスタンプを保持しない。
* `--delete`
    * 同期元に存在しないファイルを同期先から削除する。
* `--delete-excluded`
    * `--exclude` で除外したファイルを同期先から削除する。
* `--exclude <拡張 glob パターン>`
    * パターンに一致するファイルを同期から除外する。(`**` が `/` を含むすべての文字に一致する)

rsyncd over SSH によるプッシュ方式のバックアップ
----------------------------------------------------------------------

rsyncd over SSH (rsync server over SSH) 環境を構築し、
バックアップ対象のファイル群が存在するホストでスクリプトを実行し、
バックアップ先ホストへ転送する手順です。
(**「バックアップ」と称していますが、それ以外の用途にも利用できます**)

次の条件とします。

* バックアップ対象のファイルがあるホストでバックアップスクリプトを実行する。
* rsyncd over SSH を利用して安全にデータを送受信する。
* rsyncd over SSH 専用の SSH 鍵ペアを用意する。
  (**rsync 以外のシェルログイン等の操作は抑制する**)
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

```console
# mkdir -p /srv/etc/backup
# ssh-keygen -t rsa -N '' -f /srv/etc/backup/id_rsa
```

バックアップ対象ホスト target-host でバックアップスクリプト
`/srv/sbin/backup-target-host` を作成します。
**`ssh`(1) のオプションや
rsync の `--exclude` オプション (除外ファイル) は適宜調整してください**。

```sh
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

## 以下の rsync オプションの使用も検討すること:
##  * --acls
##    POSIX ACL を利用している場合
##  * --xattrs
##    拡張属性を利用している場合
##  * --hard-links
##    ハードリンクを利用している場合

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

バックアップ先ホスト backup-host
にバックアップ実行ユーザー `backup-user` を作成します。

```console
# useradd --system --create-home backup-user
```

バックアップ先ホスト backup-host のバックアップ実行ユーザーの SSH 認可ファイル
`~backup-user/.ssh/authorized_keys` に
SSH 公開鍵を登録します。
公開鍵の前に各種オプションを記述することで
rsync 以外の実行や各種オプション機能を無効にして、
バックアップ以外の用途に利用されないようにします。
実行優先度を調整したい場合は `rsync ...` の前に`nice ` を、
IO 優先度を調整したい場合は `ionice -n3`
などを追加してもいいでしょう。

```
restrict,command="rsync --server --daemon --config=/srv/etc/backup/rsyncd.conf ." <target-host:/srv/etc/backup/id_rsa.pub の内容>
```

設定ファイルとバックアップデータ保存先のディレクトリを作成します。

```console
# mkdir -m 0755 -p /srv/etc/backup
# mkdir -m 0755 -p /srv/var/backup/target-host
# chown backup-user: /srv/var/backup/target-host
```

バックアップ先ホスト backup-host で rsync デーモンの設定ファイル
`/srv/etc/backup/rsyncd.conf` を用意します。

```ini
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

```console
# /srv/sbin/backup-target-host --verbose --dry-run
…
```

問題なければ cron などで実行を自動化します。

`/etc/crontab` ファイルにより毎日午前 4時に実行するための記述例を示します。
この例では、実行優先度を調整するために `nice`(1) を、
IO 優先度を調整するために `ionice`(1) を、
rsync で圧縮転送を利用するために `--compress` オプションを指定しています。

```crontab
00 04 * * * root nice ionice -n7 /srv/sbin/backup --compress
```

### リストアの例

必要に応じて rsync に `--acls`, `--xattrs`, `--hard-links` オプションを指定すること。

```console
# rsync \
  --rsh 'ssh -i /srv/etc/backup/id_rsa' \
  --archive \
  --relative \
  backup-user@backup-host::'target-host/etc target-host/var target-host/home' \
  /path/to/restore \
  ;
```
