
# ----------------------------------------------------------------------------------------------------
# 最低限の設定
# ----------------------------------------------------------------------------------------------------

echo '--------------------------------------------------------------------------------'
echo 'Minimum settings are made...'
echo '--------------------------------------------------------------------------------'

# ホスト名の設定
echo "QuaStation" > /etc/hostname

# IP とホスト名の関連付け
cat <<EOF > /etc/hosts
127.0.0.1       localhost
127.0.1.1       QuaStation

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# DNS サーバーの設定
cat <<EOF > /etc/resolv.conf
nameserver 1.1.1.1 1.0.0.1
EOF

# root ユーザーにパスワードを設定
## 本来 Ubuntu では root でログインするのは好ましくないのだが、緊急時などに root でログインできないと困ることも多々ある
## 念のため、root でログインできるようにしておく (パスワードは ”quastation”)
echo "root:quastation" | chpasswd

# "qua" ユーザーを作成 (パスワードは ”quastation”)
useradd -G sudo -m -s /bin/bash qua
echo "qua:quastation" | chpasswd

# apt パッケージのダウンロード先サーバーを変更
## 標準の http://ports.ubuntu.com/ubuntu-ports/ は結構遅いが、残念ながら日本には arm64 向けのパッケージを置いているミラーはない
## 調べたところ http://mirror.misakamikoto.network/ubuntu-ports/ (韓国にあるサーバーらしい) が一番速かったので、とりあえずこれを使う
## ref: https://zenn.dev/tetsu_koba/articles/c980cb3371c4bb
cat <<EOF > /etc/apt/sources.list
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal main restricted
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal-updates main restricted
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal universe
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal universe
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal-updates universe
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal multiverse
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal multiverse
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal-updates multiverse
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal-updates multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal-backports main restricted universe multiverse
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal-backports main restricted universe multiverse

## Uncomment the following two lines to add software from Canonical's
## 'partner' repository.
## This software is not part of Ubuntu, but is offered by Canonical and the
## respective vendors as a service to Ubuntu users.
# deb http://archive.canonical.com/ubuntu focal partner
# deb-src http://archive.canonical.com/ubuntu focal partner

deb http://mirror.misakamikoto.network/ubuntu-ports/ focal-security main restricted
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal-security main restricted
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal-security universe
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal-security universe
deb http://mirror.misakamikoto.network/ubuntu-ports/ focal-security multiverse
# deb-src http://mirror.misakamikoto.network/ubuntu-ports/ focal-security multiverse

EOF

# ----------------------------------------------------------------------------------------------------
# 各種ソフトウェアのインストール前の事前準備（プリインストールソフトのアップグレードなど）
# ----------------------------------------------------------------------------------------------------

## tzdata などのインストール時に設定ダイヤログを出さないためのテクニック
## Docker のイメージビルド時に発生する問題としてよく知られているものと同じ
## ref: https://dev.to/0xbf/set-timezone-in-your-docker-image-d22
export DEBIAN_FRONTEND=noninteractive

echo '--------------------------------------------------------------------------------'
echo 'Updating package information...'
echo '--------------------------------------------------------------------------------'

# パッケージ情報の更新
apt-get update

# dialog・perl がないと apt-get uprade / apt-get install 自体まともに動かないっぽい…
apt-get install -y dialog perl

echo '--------------------------------------------------------------------------------'
echo 'Updating locale and timezone...'
echo '--------------------------------------------------------------------------------'

# 日本語のロケールと言語パックをインストールする
## ここでインストールしておかないと今後のインストールに支障する
apt-get install -y language-pack-ja locales
locale-gen "ja_JP.UTF-8"
update-locale LANG=ja_JP.UTF8

# タイムゾーンを Asia/Tokyo に設定
apt-get install -y tzdata
ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

echo '--------------------------------------------------------------------------------'
echo 'Upgrading pre-installed softwares...'
echo '--------------------------------------------------------------------------------'

# すでにインストールされているパッケージをアップグレード
# このタイミングでアップグレードした方がインストール中のトラブルが少ない
apt-get upgrade -y

# ----------------------------------------------------------------------------------------------------
# 各種ソフトウェアのインストール
# ----------------------------------------------------------------------------------------------------

echo '--------------------------------------------------------------------------------'
echo 'Installing systemd...'
echo '--------------------------------------------------------------------------------'

# systemd をインストール
## Ubuntu Base には systemd が入っていない
## 先に systemd をインストールしておかないと、今後のインストールに支障する
## systemd のインストールにより、Python 3.8 など他の標準ライブラリもドカっとインストールされる
apt-get install -y systemd

# シリアル接続を有効化
systemctl enable serial-getty@ttyS0.service

echo '--------------------------------------------------------------------------------'
echo 'Installing Ubuntu-Minimal and Ubuntu-Standard...'
echo '--------------------------------------------------------------------------------'

# Ubuntu Minimal + Ubuntu Standard 相当にする
## これをインストールするだけで最低限のパッケージはすべて入る
## パッケージが大量にインストールされるため、完了まで5分くらいかかる
## 多少は警告が出るが、事前に systemd をインストールしたおかげでスムーズにインストールできるはず
apt-get install -y ubuntu-minimal ubuntu-standard

echo '--------------------------------------------------------------------------------'
echo 'Installing the necessary softwares...'
echo '--------------------------------------------------------------------------------'

# Ubuntu Minimal + Ubuntu Standard に入ってないけど必要そうなパッケージを一括でインストール
## build-essential と cmake はビルド環境一式
## ffmpeg は言わずとしれたエンコードソフト (libav 系も一式入る)
## inxi と lshw はどちらもハードウェア情報を表示できるツール
## net-tools は ifconfig など
## iw は Wi-Fi を設定するソフト
## p7zip は 7z を解凍するソフト
## wireless-tools は iwconfig など
## wvdial はモデムに接続するためのツール (NetworkManager 単体で接続できるので本当は要らないんだけど、念のため)
## zip をインストールすると unzip もついてくる
apt-get install -y apt-transport-https build-essential cmake curl ethtool ffmpeg git gnupg htop \
    inxi iw linux-firmware neofetch net-tools p7zip-full pkg-config python-is-python3 rfkill \
    software-properties-common u-boot-tools wireless-tools wvdial zip

# 追加のデーモン系ソフトのインストール
## avahi-daemon は mDNS 対応のためのデーモン
## bluez は Bluetooth 対応のためのデーモン
## network-manager は CLI (nmcli) / TUI (nmtui) からネットワーク接続を管理できるデーモン
## ちなみに、NetworkManager をインストールすると systemd-networkd は競合するため無効になる
## ssh はその名の通り SSH サーバー
apt-get install -y at avahi-daemon bluez network-manager ssh

# ----------------------------------------------------------------------------------------------------
# QuaStation に搭載されている RTL8761ATV を Bluetooth サービス (BlueZ) で使えるようにセットアップ
# ----------------------------------------------------------------------------------------------------

echo '--------------------------------------------------------------------------------'
echo 'Setting up Bluetooth driver...'
echo '--------------------------------------------------------------------------------'

# rtk_hciattach (hciattach の Realtek カスタマイズ版) のビルドとインストール
## 対応するファームウェア (rtl8761a_fw) はカーネルコードの prebuilt/rtlbt/ 以下に配置されている
cd /tmp/
git clone https://github.com/radxa/rtkbt.git
cd rtkbt/uart/rtk_hciattach/
make
cp ./rtk_hciattach /usr/bin/rtk_hciattach
cd /
rm -rf /tmp/rtkbt/

# サービスファイルを作成
## ref: https://github.com/armbian/build/blob/master/packages/bsp/rk322x/rtk-bluetooth.service
cat <<EOF > /etc/systemd/system/rtk-bluetooth.service
[Unit]
Description=Realtek H5 protocol bluetooth support
Before=bluetooth.service

[Service]
ExecStart=/usr/bin/rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5

[Install]
WantedBy=multi-user.target
EOF
echo '$ cat /etc/systemd/system/rtk-bluetooth.service'
cat /etc/systemd/system/rtk-bluetooth.service

# systemd サービスを有効化
systemctl enable rtk-bluetooth.service

# ----------------------------------------------------------------------------------------------------
# QuaStation に搭載されている GPIO ボタンのイベントを udev (uevent) でトリガーできるようにセットアップ
# ----------------------------------------------------------------------------------------------------

echo '--------------------------------------------------------------------------------'
echo 'Setting up GPIO button driver...'
echo '--------------------------------------------------------------------------------'

# 起動時に gpio_isr.ko (https://github.com/tsukumijima/QuaStation-Kernel-BPi/blob/master/phoenix/drivers/gpio_isr/gpio_isr.c) を読み込む
## gpio_isr.ko は Android 側の同名のプロプライエタリドライバをリバースエンジニアリングして独自に再実装したもの
echo "gpio_isr" >> /etc/modules-load.d/modules.conf

# gpio_isr.ko がボタンが押されたときに発火させる uevent を受け取れるように
## とりあえず POWER ボタンはシャットダウン、RESET ボタンは再起動に割り当ててある
## WPS ボタンと COPY (デバイス上は IMPORT ボタン扱い) ボタンは今のところ使い道がないので、とりあえず押すと LED が点灯するようにした
cat <<EOF > /etc/udev/rules.d/10-gpio-buttons.rules
# POWER button -> Shutdown
DRIVER=="gpio_isr", ENV{button}=="POWER", RUN="/usr/bin/systemctl poweroff"

# RESET button -> Reboot
DRIVER=="gpio_isr", ENV{button}=="RESET", RUN="/usr/bin/systemctl reboot"
DRIVER=="gpio_isr", ENV{button}=="INIT", RUN="/usr/bin/systemctl reboot"

# WPS button pressed down -> Turn on the LEDs
DRIVER=="gpio_isr", ENV{button}=="WPS_DOWN", RUN="/bin/bash -c \"echo 0 > /sys/class/leds/lte_led_g/brightness; echo 0 > /sys/class/leds/lte_led_r/brightness; echo 0 > /sys/class/leds/wifi_led_g/brightness; echo 0 > /sys/class/leds/wifi_led_r/brightness; echo 0 > /sys/class/leds/hdd_led_g/brightness; echo 0 > /sys/class/leds/hdd_led_r/brightness\""

# WPS button pressed up -> Turn off the LEDs
DRIVER=="gpio_isr", ENV{button}=="WPS_UP", RUN="/bin/bash -c \"echo 255 > /sys/class/leds/lte_led_g/brightness; echo 255 > /sys/class/leds/lte_led_r/brightness; echo 255 > /sys/class/leds/wifi_led_g/brightness; echo 255 > /sys/class/leds/wifi_led_r/brightness; echo 255 > /sys/class/leds/hdd_led_g/brightness; echo 255 > /sys/class/leds/hdd_led_r/brightness\""

# COPY (IMPORT) button -> Turn on the COPY LED
DRIVER=="gpio_isr", ENV{button}=="IMPORT", RUN="/bin/bash -c \"echo 0 > /sys/class/leds/imp_led_g/brightness\""

# COPY (IMPORT) button long pressed -> Turn off the COPY LED
DRIVER=="gpio_isr", ENV{button}=="UNMOUNT", RUN="/bin/bash -c \"echo 255 > /sys/class/leds/imp_led_g/brightness\""
EOF
echo '$ cat /etc/udev/rules.d/10-gpio-buttons.rules'
cat /etc/udev/rules.d/10-gpio-buttons.rules

# ----------------------------------------------------------------------------------------------------
# Python 3.10 / pip と Node.js 16 / npm / yarn のインストール
# ----------------------------------------------------------------------------------------------------

# Python 3.10 のインストール
echo '--------------------------------------------------------------------------------'
echo 'Installing Python 3.10...'
echo '--------------------------------------------------------------------------------'
add-apt-repository -y ppa:deadsnakes/ppa
apt-get install -y python3.10-minimal python3.10-distutils python3.10-venv

# pip のインストール
## python3-pip だと Python 3.8 ベースの pip がインストールされるため、get-pip.py でインストールする
curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.10

echo '$ python3.10 --version'
python3.10 --version
echo '$ pip --version'
pip --version

# Node.js 16 のインストール
echo '--------------------------------------------------------------------------------'
echo 'Installing Node.js 16...'
echo '--------------------------------------------------------------------------------'
curl -fsSL https://deb.nodesource.com/setup_16.x | bash
apt-get install -y nodejs

# npm を最新版にアップグレード
npm install -g npm

# yarn のインストール
npm install -g yarn

echo '$ node --version'
node --version
echo '$ npm --version'
npm --version
echo '$ yarn --version'
yarn --version

# ----------------------------------------------------------------------------------------------------
# Docker のインストール
# ----------------------------------------------------------------------------------------------------

echo '--------------------------------------------------------------------------------'
echo 'Installing Docker CE...'
echo '--------------------------------------------------------------------------------'

# Docker CE のインストール
# ref: https://matsuand.github.io/docs.docker.jp.onthefly/engine/install/ubuntu/
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
cat <<EOF > /etc/apt/sources.list.d/docker.list
deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable
EOF
apt-get update
apt-get install -y containerd.io docker-ce docker-ce-cli docker-compose-plugin

# Docker Compose v1 のインストール
## v2 は "docker compose" コマンドで実行できる
curl -fsSL https://github.com/zhangguanzhang/docker-compose-aarch64/releases/download/1.29.2/docker-compose-linux-arm64 > /usr/bin/docker-compose
chmod a+x /usr/bin/docker-compose

echo '$ docker version'
docker version
echo '$ docker-compose version (v1)'
docker-compose version
echo '$ docker compose version (v2)'
docker compose version

# ----------------------------------------------------------------------------------------------------
# そのほかのデフォルトのパッケージリストに含まれていないソフトのインストール
# ----------------------------------------------------------------------------------------------------

# speedtest-cli (ネットワーク速度を計測するツール) のインストール
echo '--------------------------------------------------------------------------------'
echo 'Installing speedtest-cli...'
echo '--------------------------------------------------------------------------------'
curl -fsSL https://packagecloud.io/ookla/speedtest-cli/gpgkey | gpg --dearmor -o /usr/share/keyrings/ookla_speedtest-cli-archive-keyring.gpg
cat <<EOF > /etc/apt/sources.list.d/ookla_speedtest-cli.list
deb [signed-by=/usr/share/keyrings/ookla_speedtest-cli-archive-keyring.gpg] https://packagecloud.io/ookla/speedtest-cli/ubuntu/ focal main
EOF
apt-get update
apt-get install -y speedtest
echo '$ speedtest --version'
speedtest --version

# Tailscale (便利なメッシュ型 VPN サービス) のインストール
# ref: https://tailscale.com/download/linux/ubuntu-2004
echo '--------------------------------------------------------------------------------'
echo 'Installing Tailscale...'
echo '--------------------------------------------------------------------------------'
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg > /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.tailscale-keyring.list > /etc/apt/sources.list.d/tailscale.list
apt-get update
apt-get install -y tailscale
echo '$ tailscale --version'
tailscale --version

# ----------------------------------------------------------------------------------------------------
# 後処理
# ----------------------------------------------------------------------------------------------------

# apt-get のキャッシュを削除
apt-get clean
rm -rf /var/lib/apt/lists/*

# npm のキャッシュを削除
rm -rf ~/.npm
