---
title: RPM SPEC scriptlet
tags: [rpm,package]
layout: default
---

scriptlet の種類
======================================================================

インストール/アンインストール scriptlet
----------------------------------------------------------------------

* `%pre`
* `%post`
* `%preun`
* `%postun`

### 引数

FIXME

トリガー scriptlet
----------------------------------------------------------------------

トリガー対象のパッケージにバージョン-リリースも指定できるが、
エポックは指定しても無視される。なんでだよ、クソが。

```
%trigger{un|in|postun} [[-n] <subpackage>] [-p <program>] -- <trigger>
```

* `%triggerin`
* `%triggerun`
* `%triggerpostun`

`%triggerin` は別名 `%trigger` でもよいらしい(要確認)。
`%triggerpostin` は存在しない。

### 引数

FIXME

* `$1`
    * Number of instances of the source (or triggered) package which will
      remain when the trigger has completed
* `$2`
    * Number of instances of the target package which will remain when
      the trigger has completed


scriptlet の実行順序
======================================================================

アップグレード
----------------------------------------------------------------------

 1. 全インストールパッケージの `%pretrans` を実行。

 2. 新パッケージの `%pre` を実行。`$1 == 2`
 3. 新パッケージのファイルをインストール。
 4. 新パッケージの `%post` を実行。`$1 == 2`
 5. 他パッケージの `%triggerin -- 新パッケージ名 [バージョン条件]` を実行。
    (旧パッケージの `%triggerin` も含む)
    (FIXME: What values in `$1` and `$2`?)
 6. 新パッケージの `%triggerin -- 新パッケージ名 [バージョン条件]` を実行。
    (FIXME: What values in `$1` and `$2`?)
 7. 旧パッケージの `%triggerun -- 旧パッケージ名 [バージョン条件]` を実行。
    (FIXME: What values in `$1` and `$2`?)
 8. 他パッケージの `%triggerun -- 旧パッケージ名 [バージョン条件]` を実行。
    (新パッケージの `%triggerun` も含む)
    (FIXME: What values in `$1` and `$2`?)
 9. 旧パッケージの `%preun` を実行。`$1 == 1`
 10. 旧パッケージのファイル (新パッケージに含まれていないファイル) をアンインストール。
11. 旧パッケージの `%postun` を実行。`$1 == 1`
12. 旧パッケージの `%triggerpostun -- 旧パッケージ名 [バージョン条件]` を実行。
    (FIXME: What values in `$1` and `$2`?)
13. 他パッケージの `%triggerpostun -- 旧パッケージ名 [バージョン条件]` を実行。
    (新パッケージの `%triggerpostun` も含む)
    (FIXME: What values in `$1` and `$2`?)

14. 新パッケージの `%posttrans` を実行。

`%triggerin%` と `%triggerun`
は、自パッケージ名をトリガー条件にしたときにバグがある。

* `%triggerin -- %{name} < %{version}-%{release}` is always triggered on upgrade · Issue #209 · rpm-software-management/rpm  
  <https://github.com/rpm-software-management/rpm/issues/209>

scriptlet の例
======================================================================

新版で追加した設定ファイルをアップグレード時は無効にする
----------------------------------------------------------------------

既存パッケージの RPM SPEC を更新し、新たに設定ファイルを追加したとする。
旧版からのアップグレード時は、勝手に追加設定が有効にならないようにしたいことがある。

旧版からのアップグレード時に追加設定ファイルを無効化したい場合の scriptlet の実装方法。

```sh
## 「旧版のアンインストール処理後」をトリガーとするため、%triggerpostun に
## 自パッケージ名と新版のバージョン-リリース未満を条件に指定する。
%triggerpostun -- %{name} < 1.0-2.new
## このトリガーは旧版からのアップデート時にだけ実行される。
## 新版のバージョン-リリース未満をトリガー条件にしているため、
## インスール/アンインストール前後のパッケージ数 ($1, $2) を
## 評価する必要はない。

## 旧版のとき既に同名設定ファイルが存在する場合、新版での同名設定ファイルが
## %config なら上書きはせず、*.rpmsave に保存される。その場合は旧版の
## 設定ファイルが維持されるので、対処は不要。
##
## *.rpmsave がない場合は新版の設定ファイルが新たにインストール
## されるので、無効化する必要がある。
if [[ ! -f %{_sysconfdir}/foo.conf.rpmnew ]]; then
  ## 新版の設定ファイルをデフォルトのまま *.rpmnew に保存する。
  ## RPM は、旧版でカスタマイズされている設定ファイル、かつ
  ## 新版で追加あるいは更新がされた設定ファイルは、
  ## 新版の設定ファイルで上書きせずに、*.rpmnew としてインストールする。
  ## 以下で無効化するので、RPM の動作に倣う。
  cp -p \
    %{_sysconfdir}/foo.conf \
    %{_sysconfdir}/foo.conf.rpmnew \
  || exit $?
  ## 新版の設定ファイルを無効化する。
  ## この例ではファイル内容をすべてコメントアウトしている。
  sed \
    -e 's/^/#/' \
    <%{_sysconfdir}/foo.conf.rpmnew \
    >%{_sysconfdir}/foo.conf \
  || exit $?
fi
```
