---
title: '共用ユーザーのシェル環境を SSH ユーザーごとに切り替え - Shell Script Advent Calendar 2017'
tags: [sh, shell, ssh]
layout: default
---

[Shell Script Advent Calendar 2017](https://qiita.com/advent-calendar/2017/shellscript)
の 6日目の記事です。

本日のお題は、共用ユーザーアカウントのシェル環境を SSH の接続元ユーザーごとに
カスタマイズできるようにする方法を紹介します。

きっかけはこちらのツイート <https://twitter.com/ttdoda/status/937929507528368129>:

> alias vi=vim すればいいんだろうけれど、共用アカウントだから.bashrcに書いたら他の人にも影響でるからなあ。

`authorized_keys`(5) で公開鍵ごとにシェルを切り替え
----------------------------------------------------------------------

共用ユーザーのログインシェルが `/bin/bash` だが俺は `/bin/zsh` を使いたい!
というような時の実現方法です。

SSH の `authorized_keys`(5) に登録する SSH 公開鍵には、`command="..."`
オプションで任意のコマンドラインを指定することができます。
このコマンドラインは SSH ログイン時にユーザーのログインシェルで実行されます。
ここに任意のシェルに切り替える細工を施します。

以下はシェルに `/bin/zsh` を使用する場合の `authorized_keys`(5) の例です。

```
command="[ -n \"${SSH_ORIGINAL_COMMAND+set}\" ] && set -- -c \"$SSH_ORIGINAL_COMMAND\" || set -- -l; exec /bin/zsh \"$@\"" <SSH公開鍵...>
```

単一行で記述してありダブルクォートのエスケープが含まれていて分かりにくいでしょうか。
これに相当するシェルスクリプトに展開して示すと以下のようになります。
これがログイン時に実行されます。

```sh
if [ -n "${SSH_ORIGINAL_COMMAND+set}" ]; then
  exec /bin/zsh -c "$SSH_ORIGINAL_COMMAND"
else
  exec /bin/zsh -l
fi
```

つまり、環境変数 `SSH_ORIGINAL_COMMAND` が設定されているときは `/bin/zsh`
でそれを実行し、そうでない場合は単にログインシェルとして `/bin/zsh`
を起動しているだけです。SSH クライアントでコマンドラインを指定して
ログインした場合はその内容が環境変数 `SSH_ORIGINAL_COMMAND`
が設定されるので、それを利用して切り分けています。簡単ですね!

`/bin/zsh` の部分は `/bin/fish` やお好きなシェルに切り替えてください。

`authorized_keys`(5) で公開鍵ごとに接続元ユーザー識別情報を設定
----------------------------------------------------------------------

SSH でログインした環境には接続元のユーザー情報として以下のような
環境変数が設定されます。接続元(クライアント)のユーザー名等は含まれません。

```console
$ env |grep '^SSH_'
SSH_CLIENT=<接続元IPアドレス> <接続元ポート番号> <サーバーポート番号>
SSH_CONNECTION=<接続元IPアドレス> <接続元クライアントポート番号> <サーバーIPアドレス> <サーバーポート番号>
SSH_TTY=<TTYデバイスファイル名>
```

接続元 IP アドレスでユーザーを識別できる状況であれば
`SSH_CLIENT` か `SSH_CONNECTION` の値を利用できますが、
ここでは公開鍵ごとにユーザー名を設定する方法を考えます。

SSH サーバーの `sshd_config`(5) の `AcceptEnv` オプションと
SSH クライアントの `ssh_config`(5) の `SendEnv`
オプションに環境変数名を追加設定して SSH 接続時にユーザー名を渡す、
という方法が考えられます。接続元でユーザー名を保持している環境変数としては
`USER` や `LOGNAME` などがありますが、これらはログイン先のシェルが
上書き設定してしまうため利用できません。よって別途 `SSH_USER`
といった名前の環境変数を使う必要がありますが、SSH クライアントで
それを設定する必要があります。

このように、接続元からユーザー名を環境変数渡しするのは少し面倒なので、
先ほどと同じように `authorized_keys`(5) で設定してしまいましょう。

先ほど紹介した `authorized_keys`(5) の例に環境変数 `SSH_USER`
を設定する記述を追加します。

```
command="export SSH_USER=alice; [ -n \"${SSH_ORIGINAL_COMMAND+set}\" ] && set -- -c \"$SSH_ORIGINAL_COMMAND\" || set -- -l; exec /bin/zsh \"$@\"" <SSH公開鍵...>
```

あとはシェルの環境設定ファイル `~/.profile`、`~/.bash_profile` (bash の場合) や
`~/.zprofile` (zsh の場合) などで `SSH_USER` の値を元にユーザーごとの設定を記述しましょう。

```sh
case "$SSH_USER" in
alice)
  alias vi=vim
  ;;
bob)
  alias vi=emacs
  ;;
esac
```

* * *

{% include wishlist-dec.html %}
