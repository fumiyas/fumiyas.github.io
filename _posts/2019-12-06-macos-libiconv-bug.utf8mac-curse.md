---
title: "macOS iconv(3) UTF-8-MAC エンコーディングの問題 - OSSTech Advent Calendar 2019"
tags: [unicode, utf-8-mac, iconv]
layout: default
---

Apple 社 UTF-8-MAC の呪い Advent Calendar 2019 …ではなく、
[OSSTech Advent Calendar 2019](https://qiita.com/advent-calendar/2019/osstech)
の 6 日目の記事です。

macOS iconv(3) は UTF-8-MAC
という名前の特殊なエンコーディングに対応していますが、
これに問題を見つけたので紹介します。
macOS 10.14.2 (Mojave) にて確認。

その前に…

UTF-8-MAC は NFD じゃねぇえええーーーーーーーっ!!!!
======================================================================

NFD いうな! 福神づけ喰らわすぞ。

NFD 正規化されるのは一部の文字だけです。

例:

| Original      | UTF-8-MAC に変換      | NFD に正規化  |
| ------------- | --------------------- | ------------- |
| 福 (U+FA1B)   | ← に同じ             | 福 (U+798F)   |
| 神 (U+FA19)   | ← に同じ             | 神 (U+795E)   |
| づ (U+3065)   | づ (U+3064 U+3099)    | ← に同じ     |
| け (U+3051)   | ← に同じ             | ← に同じ     |

UTF-8-MAC 関連の問題で NFC / NFD 正規化を使うなよ! 騙るなよ?!
お兄^Hじさんとの約束だぞ!!

ちなみに UTF-8-MAC → UTF-8 変換した結果は NFC ではないぞ。NFC いうな!

以下、本題。

長めの UTF-8-MAC テキストデータ → 他のエンコーディング変換が失敗する
======================================================================

再現例:

```console
$ while :; do echo あああ; done |iconv -f UTF-8-MAC -t UTF-8
...
あああ
あああ
iconv: (stdin):819:6: cannot convert
```

絵文字などのサロゲートペアな文字の変換が失敗、あるいは壊れる
======================================================================

再現例:

```console
$ echo 😀 |iconv -f UTF-8-MAC -t UTF-8
iconv: (stdin):1:0: cannot convert
$ echo 😀 |iconv -f UTF-8 -t UTF-8-MAC 
�
$ echo 😀 |iconv -f UTF-8 -t UTF-8-MAC |od -tcx1
0000000    �  **  **  \n
           ef  bf  bd  0a
0000004
```

修正版
======================================================================

趣味でオリジナルの GNU libiconv に macOS 版 GNU libiconv の UTF-8-MAC
を移植したものを作って公開しているのですが、そちらで修正してみました。

* GNU libiconv with UTF-8-MAC support (Port from Apple's GNU libiconv) 
    * <https://github.com/fumiyas/libiconv-utf8mac>

macOS でビルドできるかは試していません。駄目だったらパッチください。

自分は macOS で困ってないので Apple にバグ報告・パッチ投げする
モチベーションが湧きません。
誰か困っている人、暇な人、Apple の中の人、代わりにお願いします。

* * *

{% include wishlist-dec.html %}
