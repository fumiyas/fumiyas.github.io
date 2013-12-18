---
title: コマンドパイプラインの終了コード - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013]
(http://www.adventar.org/calendars/212)、18日目の記事です。
今日も書く暇がなかったので軽く済ませます。すみません。

今日は Twitter で [@koie さん](https://twitter.com/koie)
から[シェルネタ](https://twitter.com/koie/status/413209516046438400)を振られたので、
勝手に採用して、もう少し詳しく紹介したいと思います。

コマンドの終了コード
----------------------------------------------------------------------

実行したコマンドの終了コードはシェル変数 `$?` で取得できます。

``` console
$ true
$ echo $?
0
$ false
$ echo $?
1
$ grep
使用法: grep [OPTION]... PATTERN [FILE]...
Try 'grep --help' for more information.
$ echo $?
2
```

コマンドパイプラインの場合はどうでしょうか。
次の例のように、パイプラインの最後のコマンドの終了コードが採用されます。

``` console
$ true | true
$ echo $?
0
$ true | false
$ echo $?
1
$ false | true
$ echo $?
0
$ false | false
$ echo $?
1
$ sh -c 'exit 11' | sh -c 'exit 22' | sh -c 'exit 33'
$ echo $?
33
```

パイプラインの全コマンドの終了コード
----------------------------------------------------------------------

bash, zsh
依存となりますが、コマンドパイプラインのすべてのコマンドの終了コードを得るためのシェル変数が用意されています。

bash では配列型のシェル変数 `$PIPESTATUS` に各コマンドの終了コードが入ります。

``` console
$ sh -c 'exit 11' | sh -c 'exit 22' | sh -c 'exit 33'
$ echo "${PIPESTATUS[@]}"
11 22 33
```

zsh では配列型のシェル変数 `$pipestatus` に各コマンドの終了コードが入ります。

``` console
% sh -c 'exit 11' | sh -c 'exit 22' | sh -c 'exit 33'
% echo "${pipestatus[@]}"
11 22 33
```

ksh は…、そのようなシェル編集や手段は用意されていません。残念。
うまい方法を思い付かなかったのですが、
こんな風にすれば「いずれかのコマンドが失敗したら死ぬ」程度なら実現できます。
いまひとつですね、はい…。

``` sh
#!/bin/ksh

function pipe_run {
  "$@"
  typeset status="$?"
  [[ $status -ne 0 ]] && kill "$$"
  return 0
}

pipe_run cmd1 | pipe_run cmd2 | pipe_run cmd3
```

すべての終了コードの検査
----------------------------------------------------------------------

`$PIPESTATUS` (bash), `$pipestatus` (zsh)
は、パイプラインでない単発のコマンド実行でも更新されます。
これが厄介の元で、パイプラインの複数のコマンド終了コードを順次検査するには少し工夫が必要になります。

次の bash の例のように、コマンドパイプライン後の `echo "${PIPESTATUS[0]}"` の実行で
`$PIPESTATUS` の内容は `echo` コマンドの終了コード 0
だけが含まれる状態になってしまいます。

```
$ sh -c 'exit 11' | sh -c 'exit 22' | sh -c 'exit 33'
$ echo "${PIPESTATUS[0]}"
11
$ echo "${PIPESTATUS[1]}"

$ echo "${PIPESTATUS[2]}"

$
```

終了コード値の上書きを避けるため、
コマンドパイプライン直後に別の配列変数にコピーすれば問題ありません。

```
$ sh -c 'exit 11' | sh -c 'exit 22' | sh -c 'exit 33'
$ status=("${PIPESTATUS[@]}")
$ echo "${status[0]}"
11
$ echo "${status[1]}"
22
$ echo "${status[2]}"
33
```

パイプライン実行の度にコピーして検査するコードを書くのはあまり効率的ではありませんね。
そこでパイプライン後の全コマンドの終了コードを検査するシェル関数を考えてみました。

次の例のように検査処理をシェル関数で実装し、最初に 
`$PIPESTATUS` (bash), `$pipestatus` (zsh)
をコピーしてから順次検査するとよさそうです。

``` sh
#!/bin/bash
# or
#!/bin/zsh

pipestatus() {
  local _status="${PIPESTATUS[*]-}${pipestatus[*]-}"
  [[ ${_status//0 /} == 0 ]]
  return $?
}

foo-command |bar-command |xxx-command
if pipestatus; then
  echo OK
else
  echo NG
fi
```

この例中の `pipestatus()` 関数は、パイプラインの全コマンドの終了コードが 0
であれば 0 (真)を、そうでなければ 1 (偽) を返すようになっています。

* * *

{% include wishlist-dec.html %}

