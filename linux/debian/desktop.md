---
title: "Linux デスクトップ"
layout: default
tags: [linux, desktop, kde]
---

デバイスへのアクセス権限
----------------------------------------------------------------------

参考: <https://wiki.ubuntu.com/Security/Privileges>

```
$ sudo usermod -aG cdrom,audio,video,plugdev,netdev,dip,bluetooth $(id -un)
```

systemd
----------------------------------------------------------------------

### ノート PC を閉じたときのサスペンドを無効化

`/etc/systemd/logind.conf`:

```ini
[Login]
HandleLidSwitch=ignore
```

```console
$ sudo systemctl restart logind
```

Bluetooth
----------------------------------------------------------------------

FIXME

* /dev/rfkill

オーディオ
----------------------------------------------------------------------

```console
$ sudo apt install pipewire pipewire-pulse libspa-0.2-bluetooth wireplumber gstreamer1.0-pipewire
$ sudo touch /etc/pipewire/media-session.d/with-pulseaudio
$ systemctl --user --now enable wireplumber.service
```

キーボードと入力
======================================================================

キーボードマッピングの変更
----------------------------------------------------------------------

initramfs に `setkeycodes`(1) を実行するフックスクリプトを組込む。
`initramfs-tools`(7) などを参照。

`/etc/initramfs-tools/scripts/init-top/setkeycodes.sh`:

```sh
#!/bin/sh

PREREQS="keymap"

prereqs() { echo "$PREREQS"; }

case "$1" in
    prereqs)
    prereqs
    exit 0
    ;;
esac

set -x

## `showkey -s` on a conole to get scancodes
## `showkey -k` on a conole to get keycodes

## CapsLock scancode -> Ctrl (left) keycode
setkeycodes 0x3a 29
## Hiragana/Katanaka scancode -> Ctrl (right) keycode
setkeycodes 0x70 97

## Hankaku/Zenkaku scancode -> Esc keycode
setkeycodes 0x29 1
```

* `PREREQS="..."` は `/usr/share/initramfs-tools/scripts/init-top/*`
  のフックスクリプトのうち、先に実行してほしいものの名前を記述する。
* フックスクリプトのファイルのモードに実行権限が必要。
* initramfs に `setkeycodes` コマンドを組込むには:
    * busybox パッケージが必要。
    * `/etc/initramfs-tools/initramfs.conf` に `BUSYBOX=auto` か `BUSYBOX=y` 設定も必要。
* initramfs の更新を忘れないように。

```console
$ sudo chmod +x /etc/initramfs-tools/scripts/init-top/setkeycodes.sh
$ sudo apt install busybox
$ sudo update-initramfs -u
...
```

SKK
----------------------------------------------------------------------

```console
$ sudo apt install fcitx5-skk
$ mkdir ~/.config/libskk/rules
$ cp -rp /usr/share/libskk/rules/default ~/.config/libskk/rules/fumiyas
```

GUI
======================================================================

ディスプレイの解像度の追加
----------------------------------------------------------------------

縦横比 16:10 の 4K ディスプレイ (3840x2400) で解像度を 3200x2000
に設定したい、といったときに `xrandr`(1) 調べでに該当する解像度 (モード) がない場合がある。
(例: ThinkPad X1 Extreme Gen 4 の内臓ディスプレイ)

```console
$ xrandr
...省略...
eDP-1 connected primary 3840x2400+0+0 (normal left inverted right x axis y axis) 344mm x 2
15mm
   3840x2400     60.00*+
   3840x2160     59.97
   3200x1800     59.96    59.94
   2880x1620     59.96    59.97
   2560x1600     59.99    59.97
...省略...
```

`cvt`(1) でモードラインを計算する。
CRT は滅んだろうから `--reduced` オプション付きでよいのかな?

```console
# cvt --reduced 3200 2000
# 3200x2000 59.97 Hz (CVT 6.40MA-R) hsync: 123.36 kHz; pclk: 414.50 MHz
Modeline "3200x2000R"  414.50  3200 3248 3280 3360  2000 2003 2009 2057 +hsync -vsync
```

`xrandr` でモードラインとその名前を登録する。
`cvt` 出力の `Modeline ` 以降の部分を用いる。
`3200x2000R` 部分は任意の名前を指定しても構わない。

```console
# xrandr --newmode "3200x2000R" 548.75 3200 3456 3808 4416 2000 2003 2009 2072 -hsync +vsync
```

`xrandr` で出力先ディスプレイに登録したモードラインを追加する。

```console
# xrandr --addmode eDP-1 3200x2000R
```

`xrandr` で出力先ディスプレイの解像度を切り替える。

```console
# xrandr --output eDP-1 --mode 3200x2000
```

X サーバーの DRI の有効化
----------------------------------------------------------------------

```console
$ sudo apt install libgl1-mesa-dri
```

DRI 有効の確認:

```console
$ xdpyinfo |sed -n '/^number of extensions:/,/^[^ ]/p' |grep ' DRI'
```

GTK
----------------------------------------------------------------------

FIXME: どっち?

```console
$ echo gtk-key-theme-name=Emacs >>~/.config/gtk-3.0/settings.ini
$ gsettings set org.gnome.desktop.interface gtk-key-theme Emacs
```

KDE 6 (KWin, Plasma)
----------------------------------------------------------------------

FIXME: GUI でなく CLI で変更を適用する方法

KDE システム設定:

* `[入出力デバイス]` グループ
  - `[マウスとタッチパッド]`
  - `[スクリーンエッジ]`:
    * `[マウスカーソルを画面の端に押し当てることでアクションを起動できます]` の左上を `[アクションなし」` に変更。
    * `[最大化(M)]` チェックを解除。
    * `[タイル化(T)]` チェックを解除。
    * `[Edge barrier]` を `None` (`0 px`) に設定。
* `[入力/出力デバイス]` グループ
  - `[キーボード]`:
    * `[キーボード]` - `[Hardware]` タブ:
        * `[Delay]` を `[300]` に変更。
        * `[Rate]` を `[30.00]` に変更。
* `[入力/出力デバイス]` グループ
  - `[マウスとタッチパッド]`:
    * `[マウス]`:
        * `[スクロール]` - `[スクロール方向を反転]` チェックを付与。
    * `[タッチパッド]`:
        * `[Pointer accelaration]` を `[0.40]` に変更。
        * `[タップ]` - `[タップしてクリック]`, `[タップしてドラッグ]` チェックを付与。
        * `[スクロール]` - `[スクロールの方向を反転 (自然なスクロール)]` チェックを付与。
* `[外観とスタイル]` グループ
  - `[ウィンドウの管理]`
  - `[ウィンドウの挙動]`:
    * `[ウィンドウの挙動]` タブ:
        * `[ウィンドウの内部、タイトルバー、枠の操作]` グループ -
          `[修飾キー(D)]` を `[Alt]` に変更。
* `[外観とスタイル]` グループ
  - `[ウィンドウの管理]`
  - `[タスクスイッチャー]`:
    * `[Get New Task Switchers...]` で「Modern Informative」をインストールして選択。
* `[外観とスタイル]` グループ
  - `[ウィンドウの管理]`
- `[デスクトップ効果]`:
    * `フォーカス` グループ:
        * `[管理者モードでスクリーンを暗くする]` を有効化。
        * `[非アクティブなウィンドウを暗くする]` を有効化、プロパティの `[Strength]` を `10` に設定。
    * `[外観]` グループ:
        * `[半透明性]` を有効化、プロパティの `[Inactive windows]` の透明度を 90 程度に設定。
* `[外観とスタイル]` グループ
  - `[ウィンドウの管理]`
  - `[KWin スクリプト]`:
    * `[新しいスクリプトを入手...]` ボタン - `[新しい Window Manager Scripts をダウンロード]` ウィンドウ:
        * `[検索...]` 欄で `Window Geometry Inormation` を検索してインストール。
* `[外観とスタイル]` グループ - `[ウィンドウの管理]` - `[ウィンドウのルール]`:

  下記内容の `*.kwinrule` ファイルを作成してインポート。

  ```ini
  [Wanderlust]
  Description=Wanderlust
  desktopfile=emacs-mail.desktop
  desktopfilerule=3
  opacityactiverule=2
  opacityinactive=90
  opacityinactiverule=2
  wmclass=Wanderlust
  wmclassmatch=1

  [localhost 以外]
  Description=localhost 以外
  clientmachinematch=1
  opacityinactive=90
  opacityinactiverule=2

  [端末アイコン VIM]
  Description=端末アイコン VIM
  decocolor=Oxygen
  decocolorrule=2
  desktopfile=vim.desktop
  desktopfilerule=2
  opacityactiverule=2
  opacityinactive=90
  opacityinactiverule=2
  title=- VIM$
  titlematch=3
  wmclass=term(-gui)?$
  wmclassmatch=3

  [端末アイコン WezTerm]
  Description=端末アイコン WezTerm
  desktopfile=org.wezfurlong.wezterm.desktop
  desktopfilerule=2
  opacityactiverule=2
  opacityinactive=90
  opacityinactiverule=2
  title=(?<! - VIM)$
  titlematch=3
  wmclass=wezterm
  wmclassmatch=2

  [端末アイコン mlterm]
  Description=端末アイコン mlterm
  desktopfile=mlterm.desktop
  desktopfilerule=2
  opacityactiverule=2
  opacityinactive=90
  opacityinactiverule=2
  title=(?<! - VIM)$
  titlematch=3
  wmclass=mlterm
  wmclassmatch=2
  ```

  `*.kwinrule` ファイルにエクスポートするときにルールの順番を維持してくれないし、インポートしたときにファイル内の順番通りにならないため、インポート後に順番を調整する必要があるかもしれない。現在のルール設定は順番に依存しないように記述したので、そのままで問題ない。
* `[システム]` グループ - `[セッション]`:
    * `[ログイン時]` を `[手動で保存したセッションを復元する]` に変更。
* `[システム]` グループ - `[電源管理]`:
    * `[省エネルギー]`:
        * `[ボタンイベント設定]` - `[ラップトップのふたが閉じられたとき]` を `[何もしない]` に変更。

以下の設定は KDE 6 で見当らなくなった。どうすればよいのか不明。

* `[個人設定]` グループ - `[地域の設定]` - `[入力メソッド]` - `[グローバルオプションを設定…]`:
    * `[ホットキー]` グループ:
        * 不要なホットキー設定を削除する。
        * `[入力メソッドを有効にする]` を `[変換]` に変更。
        * `[入力メソッドをオフにする]` を `[無変換]` に変更。
    * `[動作]` グループ:
        * `[入力状態を共有する]` を `[すべて]` に変更。
        * `[フォーカスを変更する際に入力メソッドの情報を表示する]` チェックを付与。

KDE Connect
----------------------------------------------------------------------

```
$ sudo apt install kdeconnect
$ sudo firewall-cmd --permanent --zone=public --add-service=kdeconnect
$ sudo firewall-cmd --reload
```

ネットワーク
======================================================================

SSH サーバーの `PubkeyAuthentication` 認証設定以外の無効化
----------------------------------------------------------------------

```console
# sed -n -E \
    -e '/^#*Pubkey/d' \
    -e 's/^#*([a-zA-Z]*Authentication).*/\1 no/p'
    /etc/ssh/sshd_config \
>/etc/sshd_config.d/local.conf \
;
# systemctl reload sshd
```

USB NIC のネットワークインターフェイス名
----------------------------------------------------------------------

現代の Linux はネットワークインターフェイスの命名の一貫性を保つため、
暗号めいた名前が割り当てられる。デスクトップやモバイル用途のマシンなら
一貫性よりも単純な名前のほうが便利なときがある。

```
SUBSYSTEM=="net", \
ACTION=="add", \
KERNEL=="eth0", \
  NAME="usb0"
```

```console
# udevadm control --reload
```

パッケージ
======================================================================

DKMS によるカーネルモジュールビルド時の並列ジョブ数
----------------------------------------------------------------------

デフォルトは `nproc`(1) の出力、つまり全 CPU 数 (ハイパースレッドも含む)
となるため、デスクトップの反応が悪くなるほど重い。

```console
# mkdir -p /etc/sysconfig
# echo 'parallel_jobs=$(($(nproc) / 3))' >/etc/sysconfig/module-init-tools
```

Ubuntu の unzip パッケージの利用
----------------------------------------------------------------------

ファイル名の文字エンコード変更オプション `-O`, `-I` に対応するため。
[ziprename2utf8](https://github.com/fumiyas/home-commands/blob/master/ziprename2utf8)
で充分?

`/etc/apt/preferences`:

```
Package: unzip
Pin: release l=Ubuntu
Pin-Priority: 500

Package: *
Pin: release l=Ubuntu
Pin-Priority: 90
```

`/etc/apt/sources.list`:

```
deb [arch=amd64] http://jp.archive.ubuntu.com/ubuntu noble-updates main
deb [arch=amd64] http://jp.archive.ubuntu.com/ubuntu noble main
```
