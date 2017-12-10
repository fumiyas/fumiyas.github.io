---
title: 'ホームディレクトリをログインパスワードで暗号化 - Linux / Debian/Ubuntu Advent Calendar 2017'
tags: [linux, sh, shell]
layout: default
---

[Linux Advent Calendar 2017](https://qiita.com/advent-calendar/2017/linux)、
[Debian/Ubuntu Advent Calendar 2017](https://qiita.com/advent-calendar/2017/debian-ubuntu)
兼用の 10日目の記事です。

[某弊社](https://www.osstech.co.jp/company/recruit)
では「社外に持ち出すノート PC のファイルシステムは暗号化してね」って言われているのですが、
システムまるごと暗号化するのは面倒そう(やったことがないので想像)だったので、
Linux-CryptHome というものを作ってホームディレクトリだけ暗号化しています。
今回はこれを紹介したいと思います。

  * Linux-CryptHome - Mount/Unmount an encrypted user's home directory at login/logout 
      * <https://github.com/fumiyas/linux-crypthome>

要件
----------------------------------------------------------------------

Linux と以下のパッケージが必要です。ディストリビューションは新し目の
Debian / Ubuntu なら大丈夫だと思います。恐らく RHEL / CentOS も大丈夫です。

  * systemd
  * keyutils
  * cryptsetup
  * lvm2

Linux-CryptHome 用の暗号化ホームディレクトリの作成
----------------------------------------------------------------------
 
下記の手順で LVM 上に LUKS 暗号化ボリュームを作成し、
さらにその上にユーザーのホームディレクトリとして利用するファイルシステムを作成します。

  1. LVM で `crypthome.<ユーザー名>` という名前の論理ボリュームを作成する。
  2. 作成した論理ボリュームを LUKS ボリュームとして初期化する。
     **パスフレーズにはユーザーのログインパスワードを設定すること**。
  3. LUKS ボリュームをオープンする。
     先に設定したパスフレーズ(パスワード)の入力が必要です。
  4. LUKS ボリュームにファイルシステムを作成する。
  5. LUKS ボリュームをクローズする。

TODO: 管理者が保守するためのパスフレーズを `cryptsetup luksAddKey 〜` で追加する手順を追加。

ユーザー名 `alice`、論理ボリュームを作成する LVM
ボリュームグループ名 `VolGroup`、ボリュームサイズ 10 GB、
ファイルシステム XFS を利用する場合の実行例を示します。

```console
# lvcreate -n crypthome.alice -L 10g VolGroup
  Logical volume "crypthome.alice" created.
# cryptsetup luksFormat /dev/VolGroup/crypthome.alice

WARNING!
========
This will overwrite data on /dev/VolGroup/crypthome.alice irrevocably.

Are you sure? (Type uppercase yes): YES
Enter passphrase: <ユーザー alice のログインパスワード>
Verify passphrase: <ユーザー alice のログインパスワード>
# cryptsetup luksDump /dev/VolGroup/crypthome.alice
LUKS header information for /dev/VolGroup/crypthome.alice

Version:        1
Cipher name:    aes
Cipher mode:    xts-plain64
Hash spec:      sha256
...省略...
# cryptsetup open /dev/VolGroup/crypthome.alice decrypthome.alice
Enter passphrase for /dev/VolGroup/crypthome.alice: <ユーザー alice のログインパスワード>
# mkfs -t xfs /dev/mapper/decrypthome.alice
...省略...
# mkdir -p -m 0755 ~alice
# mount /dev/mapper/decrypthome.alice ~alice
# cp -a /etc/skel/. ~alice/
# chown -hR alice: ~alice
# chmod 0750 ~alice
# umount ~alice
# cryptsetup close decrypthome.alice
```

Linux-CryptHome のインストール
----------------------------------------------------------------------

[Linux-CryptHome](https://github.com/fumiyas/linux-crypthome)
のソースツリーを `git clone 〜` などでダウンロードし、
付属のシェルスクリプトと systemd unit ファイルをインストールします。

```console
$ git clone https://github.com/fumiyas/linux-crypthome.git
...省略...
$ cd linux-crypthome
$ sudo install -m 0755 crypthome-{pam,mount,umount} /usr/local/sbin/
$ sudo install -m 0644 crypthome@.service /lib/systemd/system/
$ sudo systemctl daemon-reload
```

PAM の設定
----------------------------------------------------------------------

### Debian / Ubuntu の場合

`/etc/pam.d/common-auth` ファイル内の
`# end of pam-auth-update config` 行の後に `pam_exec.so` の行を追加します。

```
...省略...
# and here are more per-package modules (the "Additional" block)
# end of pam-auth-update config
auth	optional			pam_exec.so expose_authtok /usr/local/sbin/crypthome-pam
```

#### RHEL / CentOS の場合

`/etc/pam.d/postlogi` ファイルに `pam_exec.so` の行を追加します。
追加する場所はどこでも構いません。

```
...省略...
auth        optional      pam_exec.so expose_authtok /usr/local/sbin/crypthome-pam
...省略...
```

SSH デーモンの設定
----------------------------------------------------------------------

Linux-CryptHome で暗号化ホームディレクトリをマウント/アンマウントするユーザーは、
ログイン時に PAM によるパスワード認証を受ける必要があります。
このため、SSH でのログインを公開鍵認証でのみ許可している場合は、
追加でパスワード認証も要求するように設定変更が必要です。

SSH デーモンの設定ファイル `sshd_config`(5) の設定例を示します。
(直接関係するディレクティブだけを抜粋)

```
AuthorizedKeysFile .ssh/authorized_keys /srv/home/%u/etc/ssh/authorized_keys

PubkeyAuthentication yes
PasswordAuthentication no
UsePAM yes

Match User alice
  PasswordAuthentication yes
  AuthenticationMethods publickey,password

Match Group crypthome-users
  PasswordAuthentication yes
  AuthenticationMethods publickey,password
```

簡単に解説しましょう。

  * `AuthorizedKeysFile .ssh/authorized_keys /srv/home/%u/etc/ssh/authorized_keys`
      * 認証許可する SSH 公開鍵リストファイルの場所に
        `/srv/home/<ユーザー名>/etc/ssh/authorized_keys` を追加します。
      * 認証時は Linux-CryptHome 対象ユーザーのホームディレクトリ内は参照できないため、
        ホームディレクトリ外に配置する必要があります。
      * Linux-CryptHome 対象ユーザーの `<ユーザーホームディレクトリ>/.ssh/authorized_keys`
        は `/srv/home/<ユーザー名>/etc/ssh/authorized_keys`
        へのシンボリックリンクにしておくとよいでしょう。
      * `AuthorizedKeysCommand` の利用も検討しましょう。
  * `UsePAM yes`
      * PAM の利用を有効化します。
      * パスワード認証時に PAM の認証モジュールが利用され、
        ログイン/ログアウト時に PAM セッションの開始/終了が実行されるようになります。
  * `AuthenticationMethods publickey,password`
      * ユーザーをパスワードと公開鍵で認証します。(多要素認証)
      * 各認証は記述した順番で試行されます。
      * この例では公開鍵認証が先に試行され、次に
        PAM によるパスワード認証が試行されます。
  * `Match User alice`
  * `Match Group crypthome-users`
      * 続くディレクティブを特定のユーザーやグループ、IPアドレスやポート番号
        に該当する場合にだけ適用します。
      * この例では Linux-CryptHome 対象のユーザーとグループにだけ
        公開鍵認証とパスワード認証の多要素認証を適用しています。

制限など
----------------------------------------------------------------------

`su - alice` には対応できません。代わりに次のような設定を `sshd_config`(5)
に追加して `ssh alice@localhost` で代用しましょう。

```
Match Address 127.0.0.1 Group crypthome-users
  PasswordAuthentication yes
  AuthenticationMethods password
Match Address ::1 Group crypthome-users
  PasswordAuthentication yes
  AuthenticationMethods password
```

TODO リスト:

  * ログインパスワード変更時に暗号化ボリュームのパスフレーズも同時に変更。
  * 暗号化ボリュームが存在しなかった場合に自動作成するオプションの実装。
  * 暗号化ボリューム/ファイルシステムをリサイズするにはどう操作する?
  * デバッグしやすいようにログを出力するオプションの実装。
  * ログイン中にスクリーンロック/アンロックしたときに暗号化ボリュームも
    ロック/アンロック。

* * *

{% include wishlist-dec.html %}
