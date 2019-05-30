---
title: "mlterm 情報"
tags: [vt,mlterm,emoji]
layout: default
---

mlterm で絵文字を表示する
======================================================================

Twitter Emoji (Twemoji) の PNG 画像ファイルを使います。

```console
$ mkdir -p ~/git/twitter
$ cd ~/git/twitter
$ git clone --depth 1 git@github.com:twitter/twemoji.git
$ ln -s ln -s ~/git/twitter/twemoji/2/72x72 ~/.mlterm/emoji
```

いくつか制限がある。

  * 合成絵文字には対応していない。
  * U+270B RAISED HAND などは表示できない。
      * `270b.png` は存在するが `mlterm` はそれをオープンしようとしないので、
        `mlterm` の仕様(制限)?
