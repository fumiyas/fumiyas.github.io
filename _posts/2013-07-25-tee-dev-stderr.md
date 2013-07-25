---
title: "`tee /dev/stderr` の罠"
tags: [shell]
layout: default
---
今日、ある意味で宇宙に近い某所で fml 4.0
を駆逐すべく準備をしていたところ、`tee` でちょっとハマった話。

[ちょお適当に書いた fml 4.0 → Mailman 2.1 移行スクリプト `fml2mm.ksh`](https://github.com/fumiyas/mailman-hack/blob/master/bin/fml2mm.ksh) に次のようなコードがあった。
Mailman に作成した移行先のメーリングリストの設定を調整するため、
簡単な Python スクリプトを生成して Mailman (Python で実装されている) の
`withlist` に喰わせるのだけど、喰わせる内容を確認したかったので 
`tee` で標準エラー出力にも出力させるハックがある。

``` sh
#!/bin/ksh
# ...省略...
{
  echo "m.real_name = '$ml_name'"
  # ...省略...
  echo 'm.Save()'
} \
|tee /dev/stderr \
|withlist --quiet --lock "$ml_name" || exit 1
```

移行にかかる作業時間を計測する必要があったので、
適当に次のようなスクリプトも作った。(`fml2mm-all.sh`)

``` sh
#!/bin/sh
set -x
for ml_dir in /srv/work/data/oldenv/spool/fml/*; do
  /usr/bin/time -p /srv/work/bin/fml2mm.ksh "$ml_dir"
done
```

今日は移行手順の各種検証をしていたのだけど、
移行元のデータ量が多くて時間切れになってしまった。
そこで次のようにバックグランドで流して帰ることにした。

``` console
# /usr/bin/time -p /srv/work/bin/fml2mm-all.sh </dev/null >/srv/work/log/fml2mm.log 2>&1 &
[1] 8122
# disown
# exit
```

実行が失敗してたら悲しいので、しばらくログファイルを観測していたのだが、
どうも様子が変。
`tail -f /srv/work/log/fml2mm.log` している分には一見問題ないように見えるのだけど、
ログファイルのサイズが単調増加しないで増えたり減ったりするし、
ページャーなどで見ると開く度に内容が違う。何かを契機に上書きされている感じ。
なんだこりゃ?

シェルスクリプトでファイルが上書き(切り詰め)される要因といえば、
非追記なリダイレクト。だけどリダイレクトは使ってないし、
そもそも問題のログファイルのパス名はスクリプト中では扱ってない。

ログファイルとスクリプトはスクリプトの標準出力とエラー出力でしか繋ってない。
それなのに切り詰めらえるってことは…あっ、そうか!
というわけで原因に気付いて、`fml2mm.ksh` 内の `tee` に `-a` オプション
(出力先を切り詰めないで追加する) を追加。

``` sh
#!/bin/ksh
# ...省略...
{
  echo "m.real_name = '$ml_name'"
  # ...省略...
  echo 'm.Save()'
} \
|tee -a /dev/stderr \
|withlist --quiet --lock "$ml_name" || exit 1
```

これで直った。
こうしないと `tee` が起動する度に `/dev/stderr`
が向いているログファイルが切り詰められてしまう。

というわけで、`tee` で一見ファイルでないものにデータ流す場合でも
条件によってはファイルになるので `-a` オプションを付けておいたほうがよさげ、
っていうお話でした。
