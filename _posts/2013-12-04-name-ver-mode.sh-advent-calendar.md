---
title: シェルの種類とバージョンの検出 - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013]
(http://www.adventar.org/calendars/212)、4日目の記事です。
毎日何時間も執筆に時間をとられて大変です。書くの遅いんです。
今日は軽めに、予定を変更してお届けします。

スクリプトがどのシェルインタープリターで動いているかを判定したいときってありませんか?
私はあります。ポータブルなシェルスクリプトを書きたい、
しかし、互換性の問題などでシェルの種類に依存するコードを書き分けないといけない場合です。

ざっくりとシェルの種類、バージョン、
動作モードを判定するスクリプトを作ってみました: {%
assign quote_file = "2013/12/04/sh-detect-name-ver-mode.sh" %}
{% include quote-file.html %}

bash は `$BASH_VERSION`、zsh は `$ZSH_VERSION`
というシェル変数にバージョン文字列が入るため、これで種類の判定ができます。
ちなみに `$VAR` でなく `${VAR-}` としているのは、
`set -u` (未定義パラメーターの展開をエラーとする)
されている場合にも対応するためです。
bash はメジャー、マイナー、マイクロバージョン番号が `$BASH_VERINFO`
に配列で設定されています。zsh は `$ZSH_VERSION` から切り分ける必要があります。
また、動作モードは bash は `$BASH` の値、zsh は `emulate`
組込みコマンドの出力で判定できます。

ksh はシェル変数 `$RANDOM` に乱数値が設定されるのが特徴です。
ksh ではほかに `$SECONDS` にシェルが起動してからの経過時間(秒)が設定されます。
バージョン番号を表すシェル変数等はないため、組込みコマンド `builtin`
有無で ksh 88 か 93 かを判定しています(この判定方法が妥当かどうかは自信がない)。
ksh 93 は 93a, 93b, …のようにマイナーバージョンがあるのですが、
それぞれの仕様の違いを把握していないので、どうすればいいのやら。
Linux であれば `/proc/$$/exe --version` で一応は判定できますが…。

それ以外は sh と判定しています。

シェルごとのシェル変数の特徴は `env - bash -c set`
のように実行すると表示できるので、ぜひ確認してみてください。

* * *

zsh の場合、バージョンごとに処理を切り替えには `is-at-least`
シェル関数が便利です。たとえば、`.zshrc`
でバージョンに依存する機能を使い分けたい場合、次のように書けます。

``` sh
#!/bin/zsh

autoload -U is-at-least

if is-at-least 4.3.0; then
  setopt PROMPT_CR
else
  setopt PROMPT_SP
fi
```

* * *

ところで12月25日はクリスマスな上に、
OSS 界隈で地味に活躍されているふみやすさんの誕生日ですね。

っ http://www.amazon.co.jp/registry/wishlist/27M7TV8CEEF6G?sort=priority
