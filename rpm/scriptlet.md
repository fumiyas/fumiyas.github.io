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

* `%triggerin`
* `%triggerun`
* `%triggerpostun`

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

 1. Run `%pre` in the new package with `$1 == 2`
 2. Install new files in the new package
 3. Run `%post` in the new package with `$1 == 2`
 4. Run `%trigger` in other packages (if any) for the new package
    (FIXME: What values in `$1` and `$2`?)
 5. Run `%trigger` in the new package (if any)
    (FIXME: Correct?)
    (FIXME: What values in `$1` and `$2`?)
 6. Run `%triggerun` in the new package (if any) for the old package
    (FIXME: What values in `$1` and `$2`?)
 7. Run `%triggerun` in other packages (if any) for old package
    (FIXME: What values in `$1` and `$2`?)
 8. Run `%preun` in the old package with `$1 == 1` (FIXME: `$1` value is correct?)
 9. Remove old files in the old package if they are NOT included in new package
10. Run `%postun` in the old package with `$1 == 1`
11. Run `%triggerpostun` in old packages (if any) for the old package
    (FIXME: Correct?)
    (FIXME: What values in `$1` and `$2`?)

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
## トリガー前後のパッケージ数 ($1, $2) を評価する必要はない。

## 旧版のとき既に同名設定ファイルが存在する場合、新版での同名設定ファイルが
## %config なら上書きはせず、*.rpmsave に保存される。その場合は旧版の
## 設定ファイルが維持されるので、対処は不要。
##
## *.rpmsave がない場合は新版の設定ファイルが新たにインストール
## されるので、無効化する必要がある。
if [[ ! -f %{_sysconfdir}/foo.conf.rpmnew ]]; then
  ## 新版の設定ファイルをデフォルトのまま *.rpmsave に保存
  cp -p %{_sysconfdir}/foo.conf{,.rpmnew} || exit $?
  ## 新版の設定ファイルを無効化 (この例ではすべてコメントアウトしている)
  sed \
    -e 's/^/#/' \
    <%{_sysconfdir}/foo.conf.rpmnew \
    >%{_sysconfdir}/foo.conf \
  || exit $? \
  ;
fi
```
