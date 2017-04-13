---
title: ksh でパイプライン後に exec するとゾンビができる - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013](http://www.adventar.org/calendars/212)、11日目の記事です。
Twitter で読者が少ないようだと零したところ、
「ネタがマニアックすぎでは」と言われました。そうですか、そうですね。

今日のネタはさらにマニアックかつマイナーな ksh 限定の話題で、
さらに下を行きたいと思います!

ゾンビ出現!
----------------------------------------------------------------------

数年前、仕事で自社ソフトウェアパッケージを AIX 対応しました。
モノは何かというと [Samba](http://www.samba.org/) です。
それまでは Red Hat Enterprise Linux 版と Solaris 版を用意していたのですが、
新たに AIX 版を作ることになったのです。
IBM POWER EXPRESS 520 が 200台だか何台だか忘れましたが、
とにかくアホみたいに多い大型案件。それ全部に Samba を入れるとか、
何を考えているのでしょうか。よくわかりませんがありがとうございました!

作業は無事に完了し、パッケージの納品も済み、目出度し目出度し…
と思っていたところ、「サービスを起動すると `<defunct>` プロセスが発生する」
との連絡を受けました。いわゆる「ゾンビプロセス」が出たというのです。

以下の報告例によると、ゾンビプロセスの親プロセスは Samba の
`smbd` (PID 270496) です。これ以外にも Samba の `nmbd` や
Samba 以外のサービスでも同じ問題が発生していたため、
この時点で Samba に原因はないと判断できます。

``` console
# /opt/osstech/sbin/service osstech-smb status
/opt/osstech/etc/svscan/smbd (pid 270496) is running...
# ps -ef | grep 270496 | grep -v grep
 root 270496 258182  0 13:07:27  -  0:00 sv:/var/opt/osstech/lib/sv/smbd --daemon --foreground
 root 282806 270496  0 13:07:27  -  0:00 sv:/var/opt/osstech/lib/sv/smbd --daemon --foreground
 root 295074 270496  0              0:00 <defunct>
```

`/opt/osstech/sbin/service` コマンドは
RHEL の `service`(8) とインターフェイス互換にした独自のスクリプトで、
RHEL と同じような使い勝手でサービスの制御を行なえるようになっています。
また、各種サービス (デーモン) は 
[daemontools-encore](https://github.com/bruceg/daemontools-encore)
([daemontools](http://cr.yp.to/daemontools.html) の派生)
の `supervise`(8) で制御する構成になっています。

`supervise` から 実行する `smbd` の起動スクリプト `run`
 の内容は次のようになっていました。

``` sh
#!/bin/sh
exec 2>&1
exec envdir ./env sh -c '
  echo "PID: $$"
  env |sort |sed "s/^/Environment: /"
  set -- \
    ${NICE:+nice} ${NICE:+-n} ${NICE:+"$NICE"} \
    softlimit \
      ${DATALIMIT:+"-d$DATALIMIT"} \
      ${STACKLIMIT:+"-s$STACKLIMIT"} \
      ${OPENFILELIMIT:+"-o$OPENFILELIMIT"} \
      ${COREFILELIMIT:+"-c$COREFILELIMIT"} \
    argv0 \
    "$COMMAND" \
      "${ARGV0:-sv:`pwd`}" \
      --daemon \
      --foreground \
      ${CONFIGFILE:+"--configfile=$CONFIGFILE"} \
      ${PORT:+"--port=$PORT"} \
      ${LOGLEVEL:+"--debuglevel=$LOGLEVEL"} \
      ${LOGDIR:+"--log-basename=$LOGDIR"} \
    ;
  echo "Execute: $@"
  exec "$@"
'
```

daemontools を使ったことがない人にとってはちょっとトリッキーなスクリプトに見えるかもしれませんが、
要は次のように動作します。
ログ用に各種出力を行なっている以外は、ごく一般的な `run` スクリプト様式です。

1. 標準エラー出力を標準出力にリダイレクト。
   (`run` スクリプトの出力は標準出力を経由して daemontools
   のログ収集プロセスである `multilog` に送られる)
2. `env` ディレクトリ下にあるファイルから値を読み込み、
   ファイル名と同名の環境変数に値を設定する。(`envdir` コマンドの動作)
3. 環境変数を参照するために `/bin/sh` を介して以降を実行する。
4. プロセス ID と環境変数の状態をログ用に出力する。
5. `smbd` のコマンドラインを組み立てる。
6. `smbd` のコマンドラインをログ用に出力する。
7. `smbd` を起動する。

一見、何の問題もないように見えます。

このゾンビを残したのは誰だあっ!!
----------------------------------------------------------------------

どうやって原因究明したのかは失念しましたが、
おおよそ次のようにして絞り込んだと記憶しています。

* `supervise` を介さず直接 `run` を実行しても再現する。
* `run` を bash や zsh で実行すると再現しない。
* `/bin/sh` の実体は ksh である。
* zsh の ksh エミュレーションで実行しても再現しない。
* `truss -f ./run` でシステムコールを追ってみた:
    * スクリプト内で起動したプロセスがすべて終了する前に
      `sh` プロセスが `smbd` に切り替わって (`exec`) いる。
    * `smbd` に切り替わった後に生き残っていたプロセスが終了している。
    * `smbd` は生き残っていたプロセスの親プロセスなので看取る
      (`wait`(2)） かスルーする (`SIGCHLD` シグナルを無視する) 責任があるが、
      `smbd` は自身が生成していないプロセスの終了には関知しない。
    * ゾンビ化!!

ksh が `exec` 前に自身が生んだプロセスを看取っていないのが悪いと判断しました。

さらに条件を絞り込む
----------------------------------------------------------------------

ksh に原因があることがわかったので、
次にスクリプトの内容による再現条件の絞り込みをしました。
これも具体的どうやったか覚えていないのですが、
以下で再現することがわかりました。

``` console
$ /bin/ksh -c 'true | true; exec cat'
```

これではやや再現する確率が低いです。
後述の原因がわかると、こうするとさらに再現しやすいことがわかります。
(パイプライン前段の終了を遅らせる)

``` console
$ /bin/ksh -c 'sleep 1 | true; exec cat'
```

理由はよくわからないですが、こうするとさらに再現しやすいようです。
(パイプラインの最後を外部コマンドにする)

``` console
$ /bin/ksh -c 'sleep 1 | command true; exec cat'
```

AIX だけでなく、Solaris や
各種 Linux ディストリビューションの ksh でも再現できますので、
機会があれば試してみてください。(pdksh や mksh は除く。AT&T ksh のみ)

結局、再現条件はこれだけでした。

* ksh を使用する。
* コマンドパイプラインを実行する。
* `exec` する。

また、ゾンビになるのはコマンドパイプラインの最右辺以外、
つまりサブシェルであるプロセスだということも突き止めました。
([昨日の記事](/2013/12/10/lastpipe.sh-advent-calendar.html) もご覧ください)

結論としては、ksh は次のような動作をするようです。
(ソースコードまでは確認していません)

* パイプラインの実行は最右辺のメインシェルの処理が終わった時点で以降の処理の実行を始める。
  サブシェルの終了は待たない。
* スクリプト (ksh) 継続中にサブシェルが終了した場合、
  メインシェルが看取る。当然、この場合はゾンビとならない。
* `exec` する場合でもサブシェルの終了は待たない。

このため、スクリプト (ksh) が `exec` でほかのコマンドに切り替わった後にサブシェルが終了する可能性があります。
`exec` したコマンドプロセス (新しい親)
がサブシェル (子プロセス) の終了に関知しなければ、
サブシェルはゾンビとして残ってしまいます。

対策
----------------------------------------------------------------------

ksh が自動でサブシェルを待ってくれないのなら、待てと指示すればよいですね。

``` console
$ /bin/ksh -c 'sleep 1 | command true; wait; exec cat'
```

組込みコマンド `wait` ですべてのサブシェルが終了するのを待ち、
それから `exec` するようにすることで問題は発生しなくなりました。

ネタ募集
----------------------------------------------------------------------

今後のネタですが、相変らず 10日分くらい足らなそうな見込みです。

もしよろしければ、
*[シェルスクリプトの関する疑問・質問、スクリプトの添削依頼、やって欲しいネタをください!!]({{site.twitter.tweet}}{{ "@satoh_fumiyasu シェルネタ応募:" | UrlEncode }})*
記事に反映できるかどうかは内容や私の実力次第ですし、お礼は特にご用意できませんが、
よろしくお願いします。orz

* * *

{% include wishlist-dec.html %}
