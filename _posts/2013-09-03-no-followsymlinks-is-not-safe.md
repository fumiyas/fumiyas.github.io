---
title: "Apache HTTPD: `Options -FollowSymLinks` は不完全"
tags: [apache, security]
layout: default
---

## 背景

ロリポップの共有 Web サービス下のサイト改ざん事件で、
攻撃手法の一つとして
「他ユーザー所有のファイルへのシンボリックリンクを自分のコンテンツディレクトリ下に作り、Apache HTTPD 経由でアクセスする」手順が利用されたらしい。

参考:

  * ロリポップのサイト改ざん事件に学ぶシンボリックリンク攻撃の脅威と対策 | 徳丸浩の日記
    * http://blog.tokumaru.org/2013/09/symlink-attack.html
  * 当社サービス「ロリポップ！レンタルサーバー」ユーザーサイトへの第三者による大規模攻撃について
    * http://lolipop.jp/info/news/4149/#090122

徳丸さんのページで解説されているように、Web サーバーが Apache HTTPD であれば、
防ぐ方法として次の対策が挙げられる。

  * `Options -FollowSymLinks` を設定する。
    * Web コンテンツファイル、もしくはファイルまでのパスにシンボリックリンクが含まれている場合、アクセスを拒否する。
    * `.htaccess` ファイルで上書き設定されないように、
      `AllowOverride Options` や `AllowOverride Options=FollowSymLinks`
      設定を避ける必要もある。
  * `Options SymLinksIfOnwerMatch` を設定にする。
    * シンボリックリンクとリンク先ファイルの所有者が一致する場合のみシンボリックリンクを許す。

## 問題点

しかし、シンボリックリンク機能を持つ UNIX には
「ファイルがシンボリックリンクかどうかの判定」、
「ファイルまでのパスがシンボリックリンクかどうかの判定」、
「ファイルのオープン」を一度に処理する方法がないため、
この攻撃を完全には防くことはできない。

実際 Apache HTTPD は、シンボリックリンクを拒否するために次のように動作する。

  1. ファイルがシンボリックリンクかどうか検査する。
  2. ファイルの親ディレクトリがシンボリックリンクかどうか検査する。
  3. ルートディレクトリまで 2 を繰り返し。
  4. ファイルをオープンしてクライアントに返す。

各処理の間にはわずかながら別プロセスが動作する猶予があるため、
このタイミングでファイルまでのパスをシンボリックリンクに差し替えることで、
Apache HTTPD にシンボリックリンクを辿らせることができてしまう。

この問題は、Apache HTTPD の `Options` の `FollowSymLinks` と
`SymLinksIfOwnerMatch` の解説に簡単ながら触れられている。
http://httpd.apache.org/docs/2.4/ja/mod/core.html#options :

> このオプションを省略したからといってセキュリティの強化にはなりません。 
> なぜなら symlink の検査はレースコンディションを引き起こす可能性があり、
> そのため回避可能になるからです。

Twitter で [@a4lg](https://twitter.com/a4lg) さんに教えてもらったのだが、
この問題は「TOCTOU」(もしくは「TOCTTOU」、「Time Of Check to Time Of Use」)
と呼ばれる問題の一種とのこと。名前が付いているのは知らなかった…。

  * Bug #811428 “Apache does not honor -FollowSymlinks due to TOCTOU...” : Bugs : “apache2” package : Ubuntu
    * https://bugs.launchpad.net/ubuntu/+source/apache2/+bug/811428

同じく Twitter で [@tnozaki](https://twitter.com/tnozaki) さんに
TOCTTOU について具体的に解説していて参考になるページを紹介してもらった。

  * IPA 独立行政法人 情報処理推進機構：情報セキュリティ技術動向調査（2008 年下期）
    * http://www.ipa.go.jp/security/fy20/reports/tech1-tg/2_05.html

## 対策

というわけで、この攻撃の根本的な対策方法は「シンボリックリンクを作らせない」
しかない。具体的には次のような対策が挙げられる。

  * SSH, SFTP など、シンボリックリンクを作成可能なサービスの利用をユーザーに許可しない。
    * SFTP であれば、 シンボリックリンクを拒否するよう `sftp-server`
      を改造するとよいかもしれない。そのようなパッチがあるかどうかは未調査。
    * OpenSSH の `sftp-server` にはそのような機能はない。
    * `symlink`(2) を拒否するラッパーライブラリーとスクリプトを作ってみた。
      `symlink-filter` 下で `sftp-server` や `httpd` を動作させることで、
      シンボリックリンクの作成を抑制できるはず。
      * https://github.com/fumiyas/symlink-busters
  * VFAT など、シンボリックリンクが利用できないファイルシステムを利用する。
    ([@knok](https://twitter.com/knok) さん案)
  * etc.

もちろん、「ユーザーごとに別権限の Web サーバーを立ち上げる」や
「ユーザーごとに別権限でコンテンツをアクセスする Web サーバーにする」
といった方法で回避もできると思う。
後者の実装としては mod_process_security がよさげな印象。

  * 人間とウェブの未来 - mod_process_security – Apache上でスレッド単位で権限分離を行うファイルのアクセス制御アーキテクチャ
    * https://github.com/matsumoto-r/mod_process_security
    * http://blog.matsumoto-r.jp/?p=1972
    * http://blog.matsumoto-r.jp/?p=1989

## おまけ

さくらインターネットの社長の田中さんが「うちは対策済み」とツイートしているが、
上記の解説の通り、わずかながら穴があるはず。よって対策は不完全だと思う。
誰か検証してくれないかな。

  * https://twitter.com/kunihirotanaka/status/373423792451645441
  * http://tanaka.sakura.ad.jp/2013/09/symlink-attack.html

Linux 2.6.39 以降で実装されているという `open`(2) の
`O_PATH` オプションを利用すればシンボリックリンクを直接開くことが可能で、
これと `fstatat`(2) と `AT_SYMLINK_NOFOLLOW` フラグ、
`openat`(2) と `O_NOFOLLOW` フラグを組み合わせれば、
シンボリックリンクを避けたファイルのオープンが実装可能な様相。
Linux の特定バージョン依存とはいえ、有効な対策となりそう。

  * https://twitter.com/a4lg/status/374443046466617344

適当に書いた攻撃用のコードを晒しておく。あまり効率がよくなく、
CPU 負荷をかけるので注意。Linux であれば `inotify`(7) で監視するなどして、
Apache HTTPD が `stat`(2), `lstat`(2) しに来たタイミングでダミーを消して
シンボリックリンクを貼るのがいいと思う。

  * https://gist.github.com/fumiyas/445d2b8263a789cfcb52

