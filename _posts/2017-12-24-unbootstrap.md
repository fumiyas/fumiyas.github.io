---
title: "Unbootstrap - 自分(Linux)の足(ファイルシステム)を自分(稼働したまま)で撃つ(破壊する)ためのシェルスクリプト - Linux / Shell Script Advent Calendar 2017"
tags: [linux, unix, sh, shell]
layout: default
---

[Linux Advent Calendar 2017](https://qiita.com/advent-calendar/2017/linux)、
[Shell Script Advent Calendar 2017](https://qiita.com/advent-calendar/2017/shellscript)
兼用の 24日目の記事です。メリークリスマス! イブ!!
明日が誕生日です。今年も無事におひとりさまですよ。おいしいケーキたべたい。

今回は Linux 環境を生きたままケア^H^H殺すためのシェルスクリプト、Unbootstrap
を紹介します。

 * Unbootstrap Shred files in a remote running OS (Shoot yourself in the foot) 
     * <https://github.com/fumiyas/unbootstrap>

Unbootstrap を使えば、リモートの Linux 環境に SSH 経由でログインした状態で
ファイルシステム等のデータ破壊とマシン電源オフを安全(?)・確実(?)に行なうことができます。
「生きたまま殺す」「自分の脚を自分で撃つ」とはその喩えです、念の為。
コンソールログインなどの物理アクセスや、別 OS 環境のブートも不要です。

開発の経緯
----------------------------------------------------------------------

私は [日本 Samba ユーザー会](http://www.samba.gr.jp/) (Samba-JP)
のスタッフとしてユーザー会の各種サービスを稼働させているホストを維持・
管理しているのですが、ある時あるホストマシンを引退させることになりました。
モノはリモートにある物理マシンです。OS は Debian だったかな? Ubuntu だったかな?

マシンの設置場所はユーザー会のスタッフ (当時。現在は故人)の前職場である
[(株)ファム](http://www.famm.co.jp/) の某ビル内にあり、ファムの方で電源断、
ストレージ (SATA HDD) のデータ破壊、マシンの破棄まで作業してくださるとのことでした。
その節はお世話になりました!

お言葉に甘えてそのまますべてお任せでもよかったのですが、
「リモートにあるコンソールにアクセスできないマシン上の Linux
環境のストレージを破壊する簡単な方法がないものか?」と思い立ち、
作ってみたのが Unbootstrap です。

稼働中のシステムのファイルシステム/スワップを破壊するとどうなる?
----------------------------------------------------------------------

今回、マシンを引退するにあたり実現したいことは以下でした。

  1. 一時的なデータの破壊
      * メモリなどが該当します。
      * マシンの電源オフで破壊できます。
  2. 一時的ではあるが残されるデータの破壊
      * スワップファイル/デバイスが該当します。
      * `dd`(1) や `shred`(1) などで破壊できます。
  3. 恒久的なデータの破壊
      * ファイルシステムなどが該当します。
      * `dd`(1) や `shred`(1) などで破壊できます。

メモリは電源オフで簡単に消せますが、スワップファイル/デバイスやファイルシステムはどうでしょうか? 
稼働中の Linux にログインして以下のコマンドラインを実行したとき、
どのようなことが起きるか想像してみてください。

```console
$ lsblk --noheadings --list --scsi --output name \
  |sed 's|!|/|g' \
  |while read dev; do echo sudo dd if=/dev/urandom of=/dev/$dev; done
```

これを実行すると
(上記例は `echo` を挟んでいるので実際は何も起きませんが、`echo` を外して実行すると)
ファイルシステムやスワップ(を含むブロックデバイス)をランダムデータで上書きして破壊します。

使用中のファイルシステム/スワップデータが壊れると何が起きるでしょうか?

  * ファイルシステム/スワップへのアクセス不正でカーネルが停止 (カーネルパニック)、あるいは暴走する?
      * 古い Linux は脆弱でパニックやハングアップする可能性が高そうですが、
        最近のバージョンなら堅牢で該当ファイルシステムを停止するだけで済みそう。
      * スワップファイル/デバイスのデータが破壊されたときは無理そう?

  * カーネルが壊れたファイルシステムを停止することで何かしらのプロセスが暴走する?
      * ファイルシステムフルになると暴走する実装を過去にいくつか見た記憶があるし、
        ファイルの読み書き失敗を契機に何か不具合が発動するかもしれません。

  * サービスの機能不全を検知してウォッチドッグがマシンを強制リブートする?
      * ソフトウェア実装やハードウェア実装があるようですが、使ったこともないのでわかりません。

  * そのほか?
      * 何かありますか? 

いずれにしても、システムを稼働したままファイルシステムなどを破壊すると、
途中で停止しまう恐れがあると考えられます。

Unboostrap は何をするのか
----------------------------------------------------------------------

こんなことができます。

  1. メモリ上に `tmpfs`(5) のファイルシステムを作り、その中に Unbootstrap
     環境を作る。データ破壊に必要な各種コマンドやデバイスファイルがコピーする。

  2. スワップファイル/デバイスをすべて無効化する。

  3. Unbootstrap 環境に `chroot`(2) してヘルパーシェルスクリプトを起動する。

  4. ヘルパーシェルスクリプトは以下の機能を提供する:
      * Unbootstrap 環境のプロセスを除くすべてのプロセスを停止する。 (`SIGSTOP` シグナル送信)
      * Unbootstrap 環境内でシェルを起動する。
      * マシンの電源を強制的にオフする。(`poweroff --force`)

現在のところ、ファイルシステムやスワップを自動的に検出・破壊する機能は
実装してありません。シェル内で `lsblk`(8), `dd`(1), `shred`(1)
などを利用して手動で破壊する必要があります。

なお、`init`(1) プロセスはカーネルがシグナルをブロックするので停止できませんが、
調べた限りでは通常のファイルシステム上のファイルはオープンしていないので、
止めなくても問題なさそうです。`ptrace`(2) で一度アタッチするとシグナルがブロック
されなくなるようなので、どうしても止めたい場合は事前に `strace`(1)
などでアタッチしてみてください。

Unboostrap の使い方
----------------------------------------------------------------------

リポジトリ内にデモ用に Vagrant による仮想マシン環境を用意してあるので、
ダウンロードしてみてください。

```console
$ git clone https://github.com/fumiyas/unbootstrap.git
Cloning into 'unbootstrap'...
$ cd unbootstrap
```

`vagrant` を直接起動してもいいですが、`Makefile` にルールを書いておいたので、
それを利用してもいいでしょう。

最初に仮想マシンを起動 (Vagrant Box イメージが手元になければダウンロードも)
して `unbootstrap` スクリプトをインストールします。

```console
$ make vagrant.up
vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Box 'bento/debian-9.2' could not be found. Attempting to find and install...
...省略...
==> default: Running provisioner: file...
==> default: Running provisioner: shell...
    default: Running: inline script
```

仮想マシン内のシステム (Debian) に SSH ログインして `root` になります。

```console
$ make vagrant.ssh
Linux debian-9 4.9.0-4-amd64 #1 SMP Debian 4.9.51-1 (2017-09-28) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
vagrant@debian-9:~$ sudo -i
root@debian-9:~# 
```

`unbootstrap` を起動すると Unbootstrap 環境が自動的に構築され、
メニューが表示されます。

```console
root@debian-9:~# unbootstrap
Creating Unbootstrap directory /tmp/unbootstrap.1220.tmp ...
Copying some files in /etc to /tmp/unbootstrap.1220.tmp/etc ...
Copying device files in /dev to /tmp/unbootstrap.1220.tmp/dev ...
Copying commands to /tmp/unbootstrap.1220.tmp/bin ...
Copying required libraries to /tmp/unbootstrap.1220.tmp/lib ...
Creating busybox commands in /tmp/unbootstrap.1220.tmp/bin ...
Entering Unbootstrap directory /tmp/unbootstrap.1220.tmp ...
Mounting /proc ...
Mounting /sys ...

Unbootstrap Menu:

  1 : Suspend all processes except Unbootstrap processes
  2 : Start /bin/sh in Unbootstrap environment
  3 : Force to poweroff
  4 : Force to reboot
  5 : Resume all suspended processes
  6 : Exit from Unbootstrap environment

Enter a number to do:
```

`1` で Unbootstrap 環境以外のプロセスを停止した後、
`2` でシェルを起動してファイルシステムなどを破壊して終了 (`exit`) して
メニューに戻り、最後に `3` で強制電源オフする、という流れになります。

謝辞
----------------------------------------------------------------------

現在の Samba-JP の各種サービスは、数名の有志と、
KDDI [Cloud Core VPS](http://www.cloudcore.jp/)、
[さくらインターネット(株)](https://www.sakura.ad.jp/) の
[さくらのVPS](http://vps.sakura.ad.jp/)、
[オープンソース・ソリューション・テクノロジ](https://www.osstech.co.jp)
の提供でをお送りしております。

この度、マシンの老朽化のため、ファムに設置して頂いているホストマシン
darwin.samba.gr.jp を退役させることになりました。長い間ありがとうございました。
ベアメタルの Intel Celeron (Coppermine) 566MHz、IDE HDE 20GB
の古いマシンでした。

* * *

{% include wishlist-dec.html %}
