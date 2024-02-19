---
title: shell モジュールでのシェル芸の書き方 - Ansible / OSSTech Advent Calendar 2018"
tags: [ansible, sh, shell]
layout: default
---

[Ansible Advent Calendar 2018](https://qiita.com/advent-calendar/2018/ansible)、
兼 [OSSTech Advent Calendar 2018](https://qiita.com/advent-calendar/2018/osstech)、
5日目の記事です。
大幅に遅れてしまいました。すみません。

Ansible の
[`shell` モジュール](https://docs.ansible.com/ansible/latest/modules/shell_module.html)
を利用したタスクを書くときの蘊蓄を語りたいと思います。

<!-- FIXME
`shell` モジュールの課題
======================================================================

Ansible で何かしらのタスクを実行するとき、専用のモジュールがあればそれを
利用すべきですが、モジュールがない場合は `shell` モジュールを利用して
シェルスクリプトで実装するのが手軽です。

  * 羃等性
-->

`shell` モジュールを使用したタスクの例
======================================================================

以下は今回解説する `shell` モジュールを利用したタスク例です。
Mailman のサイトパスワードを設定する (ただしパスワード設定済みの場合は何もしない)
ものです。
(簡略化のため `mailman_site_password` に `'` が含まれるとバグる問題は無視してください)

{% raw %}
```yaml
- name: "Set site password"
  no_log: "{{not (site_ansible_sensitive_task_log |default(false))}}"
  shell:
    cmd: |
      set -xu
      [ -s {{mailman_sysconf_dir |quote}}/adm.pw ] && {
        echo 'RESULT:OK:Site password already set' >&2
        exit 0
      }
      /usr/sbin/mmsitepass {{mailman_site_password |quote}} || {
        rc=$?
        echo 'RESULT:NG:Setting site password failed' >&2
        exit $rc
      }
      echo 'RESULT:OK:Done' >&2
  become: true
  register: result
  changed_when: result.stderr_lines[-1] == 'RESULT:OK:Done'
```
{% endraw %}

<!--
FIXME: bash を指定する方法

```yaml
  args:
    executable: /bin/bash 
```
-->

以下にポイントごとに解説します。

{% raw %}`no_log: "{{not (site_ansible_sensitive_task_log |default(false))}}"`{% endraw %}
======================================================================

これは今回のネタとは関係ありませんが、ついでに紹介しておきます。

`ansible-playbook -v ...` などのようにしてプレイブックを実行すると
実行されるタスクの詳細なログが出力されますが、`no_log: true`
にすることでタスクごとにログを抑制することができます。パスワードなどの
機密情報を扱うタスク実行でログに機密情報を残したくない場合に利用すると便利です。
しかし、`no_log: true` と固定値にしてしまうとデバッグしたいときに不便です。

そこで `no_log` の値にこの例のような式を指定して、`group_vars/all/site.yml`
など適当な場所で次のような変数 `site_ansible_sensitive_task_log`
を定義しておきます。

{% raw %}
```yaml
site_ansible_sensitive_task_log: "{{inventory == 'staging'}}"
```
{% endraw %}

これで変数 `inventory` の値が `staging` の場合だけログが有効化され、
それ以外では無効化されます。(ここで参照している変数 `inventory` は Ansible
が標準で設定する類のものではないので、別途定義する必要があります。念の為)

ちなみに `no_log` に指定する式をわざわざ {% raw %}`{{not ...}}`{% endraw %} にしているのは、
変数名等に否定系あるいは無効化系の名前を用いるのが私の好みでないからです。
逆に式がわかりにくくなってしまうので、そこまで拘らなくてもいいような
気もしますが…悩ましい…。Ansible が `no_log` でなく `log` という名前で
このオプションを用意してくれていたらよかったのに。

`shell: <シェルスクリプト>` (`cmd: 〜` を使用しない) 記述の問題点
======================================================================

`shell` モジュールで実行するシェルスクリプトは YAML の文字列として
記述しますが、YAML での文字列の記法は「フロースタイル」と
「ブロックスタイル」があり、「ブロックスタイル」にはさらに改行コードの
扱いが異なる記法が 4 つもあります。その中でも通常の複数行のシェルスクリプトを
ほぼそのまま記述可能で、改行コードをそのまま維持するブロックスタイル
`shell: |` が書きやすいと思います。

ただし問題が 2 つあることに気付いたのでご注意ください。

  * Unexpected shell module behaviors (with and without cmd:) · Issue #32800 · ansiblensible
      * https://github.com/ansible/ansible/issues/32800

問題の一つは、何故かヒアドキュメントがうまく動作しませんでした。
簡単に調べた限りでは、Ansible が YAML に記述したスクリプトの改行を
改行+スペースに変換してからシェルに渡しているようです。
ヒアドキュメント以外でも動作が壊れる可能性がありますが、恐らく、
大抵のケースで問題とならないでしょう。

もう一つの問題は、以下のようなスクリプトを記述すると、タスク実行時に
エラーを起こします。Ansible はコマンド `/bin/sh` と引数 `-c` に続く
引数にシェルスクリプトを渡して実行しようとするのですが、余計なエスケープ処理を
実行しているのかもしれません。エスケープは不要なはずなので謎です。


```yaml
- hosts: localhost
  tasks:
    - shell: |
        echo '\'
        #echo '\\' これも駄目
        #echo "\\" これも駄目
```

```console
$ ansible-playbook playbook.yml
 [WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'

ERROR! failed at splitting arguments, either an unbalanced jinja2 block or quotes: echo '\'

The error appears to have been in '/home/fumiyas/git/fumiyas/ansible-playground/shell/playbook.yml': line 3, column 7, but may
be elsewhere in the file depending on the exact syntax problem.

The offending line appears to be:

  tasks:
    - shell: |
      ^ here
```

`set -x`
======================================================================

シェルは `set -x` すると以後にコマンドラインを実行する前に
標準エラー出力に出力するようになります。デバッグ時に便利なので、
このようにスクリプトの最初に実行しておくとよいでしょう。


`[ -s {{mailman_sysconf_dir |quote}}/adm.pw ] && { 〜 exit 0 }`
======================================================================

この後に実行する Mailman サイトパスワード設定コマンド `mmsitepass` は
何度実行しても問題はありません。しかし、Ansible の実行結果としては、
サイトパスワード未設定状態から設定状態になった場合だけ `changed`
として欲しいところです。

そこで、サイトパスワードが設定済みかどうかを検査し、設定済みであれば
その旨のメッセージをエラー出力に出力 (`echo 〜 1>&2`) して
正常終了 (`exit 0`) するようにしています。
メッセージはなくても構いませんが、コメント代わりにあったほうがよいと思います。

タスク実行結果が `changed` に判定されるかどうかは最後のコマンドライン
`echo 'RESULT:OK:Done' >&2` と `changed_when` 節も関係ありますが、
それは後ほど解説します。

`/usr/sbin/mmsitepass 〜 || { rc=$? 〜 exit $rc }`
======================================================================

コマンドの実行結果の失敗を Ansible タスク実行結果の失敗とするには、
`some-command-name || exit 1` のように 0 以外の終了コードで終了すれば
十分です。しかし、これではコマンド終了コードが不明になってしまうので、
`some-command-name || exit $?` としたほうがより多くの情報を残せます。

さらにデバッグに役立ちそうな追加の診断メッセージを出力したほうが
よいこともあります。そのような場合、この例のように一旦実行失敗した
コマンドの終了コードを保存 (`rc=$?`) し、メッセージを出力  (`echo 〜 1>&2`)
した後に保存しておいたコマンド終了コードで終了 (`exit $rc`) する必要があります。

`echo 'RESULT:OK:Done' >&2`
======================================================================

サイトパスワード設定コマンドの実行 (`/usr/sbin/mmsitepass`) が成功して
タスクの目的の変更が完了したら、最後にそれを示すメッセージ
`RESULT:OK:Done` を標準エラー出力に出力します。

これによりタスク実行結果が `changed` であることを示します。

`changed_when: result.stderr_lines[-1] == 'RESULT:OK:Done'`
======================================================================

`shell` モジュールのデフォルトではタスク実行結果は常に `changed`
となりますが、もちろん `changed_when` 節で実行結果により制御することができます。

標準エラー出力の最後の行が `RESULT:OK:Done` の場合に `changed`
となるように記述しています。

* * *

{% include wishlist-dec.html %}
