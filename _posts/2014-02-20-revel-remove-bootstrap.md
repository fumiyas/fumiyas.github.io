---
title: "Revel: 初期 App から Twitter Bootstrap 依存をなくす"
tags: [revel, golang]
layout: default
---

Revel 始めました。Go 言語、いい感じ。

Revel の既定の CSS が Twitter Bootstrap でした。
CSS 素人なのだが、こいつは駄目だ。
サイズ指定のほとんどがピクセル (px)
単位なので特定の解像度の端末しか相手にできないし、
CSS の関連を把握せずに class 指定しない HTML
書いたりすると文字が画面外にはみ出したりと、
非常に使いにくい。

ということで、捨てます。

1. 以下のファイルを削除する。
    * public/css/bootstrap.css
    * public/img/glyphicons-halflings.png
    * public/img/glyphicons-halflings-white.png
2. app/views/header.html から
   `<link rel="stylesheet" type="text/css" href="/public/css/normalize.css">`
   を削除。
3. app/views/debug.html の
   `<a id="toggleSidebar" href="#" class="toggles"><i class="icon-chevron-left"></i></a>`
   を
   `<a id="toggleSidebar" href="#" class="toggles">X</a>`
   などのように書き換え。

最後の debug.html の書き換えをしないと、
デバッグ環境で有効になるサイドバーの表示切り替えボタンが表示されなくなります。

