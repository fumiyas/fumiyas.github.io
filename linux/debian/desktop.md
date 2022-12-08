デバイス
======================================================================

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

initramfs に `setkeycodes`(1) の実行を組込む。

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

## Map Ctrl (left) scancode to CapsLock key(code)
setkeycodes 0x3a 29
## Map Esc scancode to Hankaku/Zenkaku key(code)
setkeycodes 0x29 1
## Map Hankaku/Zenkaku scancode to XXXX key(code)
#setkeycodes 0x29 XXXX
```

`PREREQS="keymap"` は `/usr/share/initramfs-tools/scripts/init-top/*`
のスクリプトのうち、先に実行してほしいものの名前。

```console
# chmod +x /etc/initramfs-tools/scripts/init-top/setkeycodes.sh
# update-initramfs -u
..
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

```console
FIXME: どっち?
$ echo gtk-key-theme-name=Emacs >>~/.config/gtk-3.0/settings.ini
$ gsettings set org.gnome.desktop.interface gtk-key-theme Emacs
```

KDE
----------------------------------------------------------------------

FIXME: GUI でなく CLI で変更を適用する方法

KDE システム設定:

* `[ワークスペース]` グループ - `[ウィンドウの操作]` - `[ウィンドウの挙動]`:
    * `[ウィンドウの挙動]` タブ:
        * `[ウィンドウの内部、タイトルバー、枠の操作]` グループ -
          `[修飾キー(D)]` を `[Alt]` に変更。
    * `[移動]` タブ:
        * `[ウィンドウのジオメトリ(G)]` - `[移動およびリサイズ中に表示]` チェックを付与。
* `[ワークスペース]` グループ - `[起動と終了]` - `[デスクトップセッション]`:
    * `[ログイン時]` を `[最後に手動で保存したセッションを復元]` に変更。
* `[個人設定]` グループ - `[地域の設定]` - `[入力メソッド]` - `[グローバルオプションを設定…]`:
    * `[ホットキー]` グループ:
        * 不要なホットキー設定を削除する。
        * `[入力メソッドを有効にする]` を `[変換]` に変更。
        * `[入力メソッドをオフにする]` を `[無変換]` に変更。
    * `[動作]` グループ:
        * `[入力状態を共有する]` を `[すべて]` に変更。
        * `[フォーカスを変更する際に入力メソッドの情報を表示する]` チェックを付与。
* `[ハードウェア]` グループ - `[入力デバイス]`:
    * `[キーボード]` - `[ハードウェア]` タブ:
        * `[遅延(Y)]` を `[300 ms]` に変更。
        * `[速度(T)]` を `[30.00 repeats/s]` に変更。
    * `[マウス]`:
        * `[スクロール]` - `[スクロール方向を反転]` チェックを付与。
    * `[タッチパッド]`:
        * `[Pointer accelaration]` を `[0.30]` に変更。
        * `[タップ]` - `[タップしてクリック]`, `[タップしてドラッグ]` チェックを付与。
        * `[スクロール]` - `[スクロールの方向を反転 (自然なスクロール)]` チェックを付与。
* `[ハードウェア]` グループ - `[電源管理]`:
    * `[省エネルギー]`:
        * `[ボタンイベント設定]` - `[ラップトップのふたが閉じられたとき]` を `[何もしない]` に変更。

ネットワーク
======================================================================

SSH サーバーの `PubkeyAuthentication` 認証設定以外の無効化
----------------------------------------------------------------------

```console
# sed -i.dist \
  -e 's/^\(PermitRootLogin\).*/\1 prohibit-password/' \
  -e 's/^#*\([a-zA-Z]*Authentication\).*/\1 no/' \
  -e 's/^\(PubkeyAuthentication\).*/\1 yes/' \
  /etc/ssh/sshd_config \
;
```

パッケージ
======================================================================

Ubuntu の unzip パッケージの利用
----------------------------------------------------------------------

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
deb [arch=amd64] http://jp.archive.ubuntu.com/ubuntu trusty-updates main
deb [arch=amd64] http://jp.archive.ubuntu.com/ubuntu trusty main
```
