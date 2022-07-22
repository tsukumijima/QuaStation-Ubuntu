
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
apt-get install -y apt-transport-https autoconf build-essential cmake curl ethtool ffmpeg git gnupg htop \
    inxi iw linux-firmware neofetch net-tools p7zip-full pkg-config python-is-python3 rfkill \
    software-properties-common u-boot-tools wireless-tools wvdial zip

# 追加のデーモン系ソフトのインストール
## avahi-daemon は mDNS 対応のためのデーモン
## bluez は Bluetooth 対応のためのデーモン
## network-manager は CLI (nmcli) / TUI (nmtui) からネットワーク接続を管理できるデーモン
## ちなみに、NetworkManager をインストールすると systemd-networkd は競合するため無効になる
## Samba は SMB ファイル共有サーバー
## ssh はその名の通り SSH サーバー
apt-get install -y at avahi-daemon bluez network-manager samba ssh

# ----------------------------------------------------------------------------------------------------
# HDD の自動マウントと Samba のセットアップ
# ----------------------------------------------------------------------------------------------------

# HDD マウント用のディレクトリを作成
mkdir -p /mnt/hdd

# /etc/fstab を設定
## /dev/sataa1 は Linux 4.9.119 用の設定、Linux 4.1.17 を使うなら /dev/sda1 にするか UUID を取得して設定する必要がある
cat <<EOF > /etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/sataa1     /mnt/hdd        ext4    defaults        0       0
EOF

# Samba の設定ファイルを作成
cat <<EOF > /etc/samba/smb.conf
#
# Sample configuration file for the Samba suite for Debian GNU/Linux.
#
#
# This is the main Samba configuration file. You should read the
# smb.conf(5) manual page in order to understand the options listed
# here. Samba has a huge number of configurable options most of which
# are not shown in this example
#
# Some options that are often worth tuning have been included as
# commented-out examples in this file.
#  - When such options are commented with ";", the proposed setting
#    differs from the default Samba behaviour
#  - When commented with "#", the proposed setting is the default
#    behaviour of Samba but the option is considered important
#    enough to be mentioned here
#
# NOTE: Whenever you modify this file you should run the command
# "testparm" to check that you have not made any basic syntactic
# errors.

#======================= Global Settings =======================

[global]

## Browsing/Identification ###

# Change this to the workgroup/NT-domain name your Samba server will part of
   workgroup = WORKGROUP

# server string is the equivalent of the NT Description field
   server string = %h server (Samba, Ubuntu)

#### Networking ####

# The specific set of interfaces / networks to bind to
# This can be either the interface name or an IP address/netmask;
# interface names are normally preferred
;   interfaces = 127.0.0.0/8 eth0

# Only bind to the named interfaces and/or networks; you must use the
# 'interfaces' option above to use this.
# It is recommended that you enable this feature if your Samba machine is
# not protected by a firewall or is a firewall itself.  However, this
# option cannot handle dynamic or non-broadcast interfaces correctly.
;   bind interfaces only = yes



#### Debugging/Accounting ####

# This tells Samba to use a separate log file for each machine
# that connects
   log file = /var/log/samba/log.%m

# Cap the size of the individual log files (in KiB).
   max log size = 1000

# We want Samba to only log to /var/log/samba/log.{smbd,nmbd}.
# Append syslog@1 if you want important messages to be sent to syslog too.
   logging = file

# Do something sensible when Samba crashes: mail the admin a backtrace
   panic action = /usr/share/samba/panic-action %d


####### Authentication #######

# Server role. Defines in which mode Samba will operate. Possible
# values are "standalone server", "member server", "classic primary
# domain controller", "classic backup domain controller", "active
# directory domain controller".
#
# Most people will want "standalone server" or "member server".
# Running as "active directory domain controller" will require first
# running "samba-tool domain provision" to wipe databases and create a
# new domain.
   server role = standalone server

   obey pam restrictions = yes

# This boolean parameter controls whether Samba attempts to sync the Unix
# password with the SMB password when the encrypted SMB password in the
# passdb is changed.
   unix password sync = yes

# For Unix password sync to work on a Debian GNU/Linux system, the following
# parameters must be set (thanks to Ian Kahan <<kahan@informatik.tu-muenchen.de> for
# sending the correct chat script for the passwd program in Debian Sarge).
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .

# This boolean controls whether PAM will be used for password changes
# when requested by an SMB client instead of the program listed in
# 'passwd program'. The default is 'no'.
   pam password change = yes

# This option controls how unsuccessful authentication attempts are mapped
# to anonymous connections
   map to guest = bad user

########## Domains ###########

#
# The following settings only takes effect if 'server role = primary
# classic domain controller', 'server role = backup domain controller'
# or 'domain logons' is set
#

# It specifies the location of the user's
# profile directory from the client point of view) The following
# required a [profiles] share to be setup on the samba server (see
# below)
;   logon path = \\%N\profiles\%U
# Another common choice is storing the profile in the user's home directory
# (this is Samba's default)
#   logon path = \\%N\%U\profile

# The following setting only takes effect if 'domain logons' is set
# It specifies the location of a user's home directory (from the client
# point of view)
;   logon drive = H:
#   logon home = \\%N\%U

# The following setting only takes effect if 'domain logons' is set
# It specifies the script to run during logon. The script must be stored
# in the [netlogon] share
# NOTE: Must be store in 'DOS' file format convention
;   logon script = logon.cmd

# This allows Unix users to be created on the domain controller via the SAMR
# RPC pipe.  The example command creates a user account with a disabled Unix
# password; please adapt to your needs
; add user script = /usr/sbin/adduser --quiet --disabled-password --gecos "" %u

# This allows machine accounts to be created on the domain controller via the
# SAMR RPC pipe.
# The following assumes a "machines" group exists on the system
; add machine script  = /usr/sbin/useradd -g machines -c "%u machine account" -d /var/lib/samba -s /bin/false %u

# This allows Unix groups to be created on the domain controller via the SAMR
# RPC pipe.
; add group script = /usr/sbin/addgroup --force-badname %g

############ Misc ############

# Using the following line enables you to customise your configuration
# on a per machine basis. The %m gets replaced with the netbios name
# of the machine that is connecting
;   include = /home/samba/etc/smb.conf.%m

# Some defaults for winbind (make sure you're not using the ranges
# for something else.)
;   idmap config * :              backend = tdb
;   idmap config * :              range   = 3000-7999
;   idmap config YOURDOMAINHERE : backend = tdb
;   idmap config YOURDOMAINHERE : range   = 100000-999999
;   template shell = /bin/bash

# Setup usershare options to enable non-root users to share folders
# with the net usershare command.

# Maximum number of usershare. 0 means that usershare is disabled.
#   usershare max shares = 100

# Allow users who've been granted usershare privileges to create
# public shares, not just authenticated ones
   usershare allow guests = yes

#======================= Share Definitions =======================

# Un-comment the following (and tweak the other settings below to suit)
# to enable the default home directory shares. This will share each
# user's home directory as \\server\username
;[homes]
;   comment = Home Directories
;   browseable = no

# By default, the home directories are exported read-only. Change the
# next parameter to 'no' if you want to be able to write to them.
;   read only = yes

# File creation mask is set to 0700 for security reasons. If you want to
# create files with group=rw permissions, set next parameter to 0775.
;   create mask = 0700

# Directory creation mask is set to 0700 for security reasons. If you want to
# create dirs. with group=rw permissions, set next parameter to 0775.
;   directory mask = 0700

# By default, \\server\username shares can be connected to by anyone
# with access to the samba server.
# Un-comment the following parameter to make sure that only "username"
# can connect to \\server\username
# This might need tweaking when using external authentication schemes
;   valid users = %S

# Un-comment the following and create the netlogon directory for Domain Logons
# (you need to configure Samba to act as a domain controller too.)
;[netlogon]
;   comment = Network Logon Service
;   path = /home/samba/netlogon
;   guest ok = yes
;   read only = yes

# Un-comment the following and create the profiles directory to store
# users profiles (see the "logon path" option above)
# (you need to configure Samba to act as a domain controller too.)
# The path below should be writable by all users so that their
# profile directory may be created the first time they log on
;[profiles]
;   comment = Users profiles
;   path = /home/samba/profiles
;   guest ok = no
;   browseable = no
;   create mask = 0600
;   directory mask = 0700

;[printers]
;   comment = All Printers
;   browseable = no
;   path = /var/spool/samba
;   printable = yes
;   guest ok = no
;   read only = yes
;   create mask = 0700

# Windows clients look for this share name as a source of downloadable
# printer drivers
;[print$]
;   comment = Printer Drivers
;   path = /var/lib/samba/printers
;   browseable = yes
;   read only = yes
;   guest ok = no

# Uncomment to allow remote administration of Windows print drivers.
# You may need to replace 'lpadmin' with the name of the group your
# admin users are members of.
# Please note that you also need to set appropriate Unix permissions
# to the drivers directory for these users to have write rights in it
;   write list = root, @lpadmin

[QuaStation]
   # 共有するフォルダのパス
   path = /mnt/hdd
   # ゲストを許可する
   public = yes
   guest ok = yes
   # 書き込みを許可する
   writable = yes
   # 強制的に利用する UNIX ユーザーの名前 (root)
   force user = root
   force create mode = 0744
   force directory mode = 0775
EOF

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
# 起動後に QuaStation に搭載されている電源 LED を緑に点灯するようにセットアップ
# ----------------------------------------------------------------------------------------------------

cat <<EOF > /etc/rc.local
#!/bin/bash

# Turn on the POWER LED (green) at startup
echo none > /sys/class/leds/pwr_led_g/trigger
echo 0 > /sys/class/leds/pwr_led_g/brightness
EOF
chmod 700 /etc/rc.local

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

# Docker を qua ユーザーで操作できるようにする
usermod -aG docker qua

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
# DTV 関連で必要なソフトのインストール
# ----------------------------------------------------------------------------------------------------

echo '--------------------------------------------------------------------------------'
echo 'Installing DTV tools...'
echo '--------------------------------------------------------------------------------'

# dvb-tools (dvbv5-zap が含まれる) 以外はスマートカード関連
apt-get install -y dvb-tools libccid libpcsclite1 libpcsclite-dev libtool pcscd pcsc-tools

# PX-S1UD (MyGica S270, MyGica VT20) のファームウェアをインストール
## ドライバ自体はカーネルに組み込まれている
cd /tmp/
wget http://plex-net.co.jp/plex/px-s1ud/PX-S1UD_driver_Ver.1.0.1.zip
unzip PX-S1UD_driver_Ver.1.0.1.zip && rm PX-S1UD_driver_Ver.1.0.1.zip
cp PX-S1UD_driver_Ver.1.0.1/x64/amd64/isdbt_rio.inp /lib/firmware/
cd /
rm -rf /tmp/PX-S1UD_driver_Ver.1.0.1/

# px4_drv (PLEX / e-better 製チューナーのドライバ) のファームウェアをインストール
cd /tmp/
git clone https://github.com/nns779/px4_drv.git
cd /tmp/px4_drv/fwtool/
make
wget http://plex-net.co.jp/plex/pxw3u4/pxw3u4_BDA_ver1x64.zip -O pxw3u4_BDA_ver1x64.zip
unzip -oj pxw3u4_BDA_ver1x64.zip pxw3u4_BDA_ver1x64/PXW3U4.sys && rm pxw3u4_BDA_ver1x64.zip
./fwtool PXW3U4.sys it930x-firmware.bin
cp it930x-firmware.bin /lib/firmware/

# px4_drv (PLEX / e-better 製チューナーのドライバ) のカーネルモジュール本体をインストール
## kref_read() 関数を 4.11 からバックポートしないとビルドが通らなかったので、実際に動くかは微妙…
cd /tmp/px4_drv/driver/
export KVER=`ls /lib/modules/`
make revision.h
make -C /lib/modules/$KVER/build M=`pwd` KBUILD_VERBOSE=0
install -D -v -m 644 px4_drv.ko /lib/modules/$KVER/kernel/extra/px4_drv.ko
install -D -v -m 644 ../etc/99-px4video.rules /etc/udev/rules.d/99-px4video.rules
depmod --all $KVER
cd /
rm -rf /tmp/px4_drv/

# libaribb25 / arib-b25-stream-test のインストール
cd /tmp/
git clone https://github.com/tsukumijima/libaribb25.git
cd /tmp/libaribb25
cmake -B build -DWITH_PCSC_PACKAGE=libpcsclite -DPCSC_INCLUDE_DIRS=/usr/include/PCSC
cd build
make
make install
cd /
rm -rf /tmp/libaribb25

# recpt1 のインストール
cd /tmp/
git clone https://github.com/stz2012/recpt1.git
cd /tmp/recpt1/recpt1/
sed -i -e 's/arib25/aribb25/g' configure.ac
./autogen.sh
./configure --enable-b25
make
make install
cd /
rm -rf /tmp/recpt1/

# pm2 のインストール
## サービス周りは自前でセットアップする
npm install pm2 -g
systemctl disable pm2-undefined.service
rm /etc/systemd/system/pm2-undefined.service
cat <<EOF > /etc/systemd/system/pm2-root.service
[Unit]
Description=PM2 process manager
Documentation=https://pm2.keymetrics.io/
After=network.target

[Service]
Type=forking
User=root
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
Environment=PM2_HOME=/root/.pm2
PIDFile=/root/.pm2/pm2.pid
Restart=on-failure

ExecStart=/usr/lib/node_modules/pm2/bin/pm2 resurrect
ExecReload=/usr/lib/node_modules/pm2/bin/pm2 reload all
ExecStop=/usr/lib/node_modules/pm2/bin/pm2 kill

[Install]
WantedBy=multi-user.target
EOF
systemctl enable pm2-root.service

echo '--------------------------------------------------------------------------------'
echo 'Installing Mirakurun...'
echo '--------------------------------------------------------------------------------'

# Mirakurun のインストール
npm install mirakurun -g --production
mirakurun init
mirakurun stop

# Mirakurun の設定

## サーバー設定
cat <<EOF > /usr/local/etc/mirakurun/tuner.yml
logLevel: 2
path: /var/run/mirakurun.sock
port: 40772
allowIPv4CidrRanges:
  - 10.0.0.0/8
  - 100.64.0.0/10
  - 127.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16
allowIPv6CidrRanges:
  - fc00::/7
hostname: quastation
EOF

## チャンネル設定 (地上波はスカイツリー波 + tvk)
cat <<EOF > /usr/local/etc/mirakurun/channels.yml
- name: ＴＯＫＹＯ　ＭＸ
  type: GR
  channel: '16'
  isDisabled: false
- name: ｔｖｋ
  type: GR
  channel: '18'
  isDisabled: false
- name: フジテレビ
  type: GR
  channel: '21'
  isDisabled: false
- name: ＴＢＳ
  type: GR
  channel: '22'
  isDisabled: false
- name: テレビ東京
  type: GR
  channel: '23'
  isDisabled: false
- name: テレビ朝日
  type: GR
  channel: '24'
  isDisabled: false
- name: 日テレ
  type: GR
  channel: '25'
  isDisabled: false
- name: ＮＨＫＥテレ
  type: GR
  channel: '26'
  isDisabled: false
- name: ＮＨＫ総合
  type: GR
  channel: '27'
  isDisabled: false
- name: ＢＳ朝日１
  type: BS
  channel: BS01_0
  serviceId: 151
  isDisabled: false
- name: ＢＳ朝日２
  type: BS
  channel: BS01_0
  serviceId: 152
  isDisabled: false
- name: ＢＳ朝日３
  type: BS
  channel: BS01_0
  serviceId: 153
  isDisabled: false
- name: ＢＳ－ＴＢＳ
  type: BS
  channel: BS01_1
  serviceId: 161
  isDisabled: false
- name: ＢＳ－ＴＢＳ
  type: BS
  channel: BS01_1
  serviceId: 162
  isDisabled: false
- name: ＢＳ－ＴＢＳ
  type: BS
  channel: BS01_1
  serviceId: 163
  isDisabled: false
- name: ＢＳテレ東
  type: BS
  channel: BS01_2
  serviceId: 171
  isDisabled: false
- name: ＢＳテレ東２
  type: BS
  channel: BS01_2
  serviceId: 172
  isDisabled: false
- name: ＢＳテレ東３
  type: BS
  channel: BS01_2
  serviceId: 173
  isDisabled: false
- name: ＷＯＷＯＷプライム
  type: BS
  channel: BS03_0
  serviceId: 191
  isDisabled: false
- name: ＮＨＫＢＳプレミアム
  type: BS
  channel: BS03_1
  serviceId: 103
  isDisabled: false
- name: ＮＨＫＢＳプレミアム
  type: BS
  channel: BS03_1
  serviceId: 104
  isDisabled: false
- name: ＷＯＷＯＷライブ
  type: BS
  channel: BS05_0
  serviceId: 192
  isDisabled: false
- name: ＷＯＷＯＷシネマ
  type: BS
  channel: BS05_1
  serviceId: 193
  isDisabled: false
- name: ＢＳ１１イレブン
  type: BS
  channel: BS09_0
  isDisabled: false
  serviceId: 211
- name: スターチャンネル１
  type: BS
  channel: BS09_1
  serviceId: 200
  isDisabled: false
- name: ＢＳ１２トゥエルビ
  type: BS
  channel: BS09_2
  serviceId: 222
  isDisabled: false
- name: ＢＳスカパー！
  type: BS
  channel: BS11_0
  serviceId: 241
  isDisabled: false
- name: 放送大学ｅｘ
  type: BS
  channel: BS11_1
  serviceId: 231
  isDisabled: false
- name: 放送大学ｏｎ
  type: BS
  channel: BS11_1
  serviceId: 232
  isDisabled: false
- name: ＢＳ釣りビジョン
  type: BS
  channel: BS11_2
  serviceId: 251
  isDisabled: false
- name: ＢＳ日テレ
  type: BS
  channel: BS13_0
  serviceId: 141
  isDisabled: false
- name: ＢＳ日テレ
  type: BS
  channel: BS13_0
  serviceId: 142
  isDisabled: false
- name: ＢＳ日テレ
  type: BS
  channel: BS13_0
  serviceId: 143
  isDisabled: false
- name: ＢＳフジ・１８１
  type: BS
  channel: BS13_1
  serviceId: 181
  isDisabled: false
- name: ＢＳフジ・１８２
  type: BS
  channel: BS13_1
  serviceId: 182
  isDisabled: false
- name: ＢＳフジ・１８３
  type: BS
  channel: BS13_1
  serviceId: 183
  isDisabled: false
- name: ＢＳアニマックス
  type: BS
  channel: BS13_2
  serviceId: 236
  isDisabled: false
- name: ＮＨＫＢＳ１
  type: BS
  channel: BS15_0
  serviceId: 101
  isDisabled: false
- name: ＮＨＫＢＳ１
  type: BS
  channel: BS15_0
  serviceId: 102
  isDisabled: false
- name: スターチャンネル２
  type: BS
  channel: BS15_1
  serviceId: 201
  isDisabled: false
- name: スターチャンネル３
  type: BS
  channel: BS15_1
  serviceId: 202
  isDisabled: false
- name: Ｊ　ＳＰＯＲＴＳ　４
  type: BS
  channel: BS19_0
  serviceId: 245
  isDisabled: false
- name: Ｊ　ＳＰＯＲＴＳ　１
  type: BS
  channel: BS19_1
  serviceId: 242
  isDisabled: false
- name: Ｊ　ＳＰＯＲＴＳ　２
  type: BS
  channel: BS19_2
  serviceId: 243
  isDisabled: false
- name: Ｊ　ＳＰＯＲＴＳ　３
  type: BS
  channel: BS19_3
  serviceId: 244
  isDisabled: false
- name: ＷＯＷＯＷプラス
  type: BS
  channel: BS21_0
  serviceId: 252
  isDisabled: false
- name: 日本映画専門ｃｈ
  type: BS
  channel: BS21_1
  serviceId: 255
  isDisabled: false
- name: グリーンチャンネル
  type: BS
  channel: BS21_2
  serviceId: 234
  isDisabled: false
- name: ディズニーｃｈ
  type: BS
  channel: BS23_0
  serviceId: 256
  isDisabled: false
- name: ＢＳよしもと
  type: BS
  channel: BS23_1
  serviceId: 265
  isDisabled: false
- name: ＢＳＪａｐａｎｅｘｔ
  type: BS
  channel: BS23_2
  serviceId: 263
  isDisabled: false
- name: ＢＳ松竹東急
  type: BS
  channel: BS23_3
  serviceId: 260
  isDisabled: false
- name: ＴＢＳチャンネル１
  type: CS
  channel: CS2
  serviceId: 296
  isDisabled: false
- name: テレ朝チャンネル１
  type: CS
  channel: CS2
  serviceId: 298
  isDisabled: false
- name: テレ朝チャンネル２
  type: CS
  channel: CS2
  serviceId: 299
  isDisabled: false
- name: ディズニージュニア
  type: CS
  channel: CS2
  serviceId: 339
  isDisabled: false
- name: スカイＡ
  type: CS
  channel: CS4
  serviceId: 250
  isDisabled: false
- name: 時代劇専門ｃｈ
  type: CS
  channel: CS4
  serviceId: 292
  isDisabled: false
- name: エンタメ～テレ
  type: CS
  channel: CS4
  serviceId: 301
  isDisabled: false
- name: ＭＴＶ
  type: CS
  channel: CS4
  serviceId: 323
  isDisabled: false
- name: ホームドラマＣＨ
  type: CS
  channel: CS6
  serviceId: 294
  isDisabled: false
- name: ミュージック・エア
  type: CS
  channel: CS6
  serviceId: 324
  isDisabled: false
- name: 歌謡ポップス
  type: CS
  channel: CS6
  serviceId: 329
  isDisabled: false
- name: カートゥーン
  type: CS
  channel: CS6
  serviceId: 331
  isDisabled: false
- name: ディスカバリー
  type: CS
  channel: CS6
  serviceId: 340
  isDisabled: false
- name: アニマルプラネット
  type: CS
  channel: CS6
  serviceId: 341
  isDisabled: false
- name: ＣＮＮｊ
  type: CS
  channel: CS6
  serviceId: 354
  isDisabled: false
- name: 囲碁・将棋チャンネル
  type: CS
  channel: CS6
  serviceId: 363
  isDisabled: false
- name: ショップチャンネル
  type: CS
  channel: CS8
  serviceId: 55
  isDisabled: false
- name: 東映チャンネル
  type: CS
  channel: CS8
  serviceId: 218
  isDisabled: false
- name: Ｍｎｅｔ
  type: CS
  channel: CS8
  serviceId: 318
  isDisabled: false
- name: 日テレＮＥＷＳ２４
  type: CS
  channel: CS8
  serviceId: 349
  isDisabled: false
- name: 衛星劇場
  type: CS
  channel: CS10
  serviceId: 219
  isDisabled: false
- name: ＫＢＳ　Ｗｏｒｌｄ
  type: CS
  channel: CS10
  serviceId: 317
  isDisabled: false
- name: スポーツライブ＋
  type: CS
  channel: CS10
  serviceId: 800
  isDisabled: false
- name: スカチャン１
  type: CS
  channel: CS10
  serviceId: 801
  isDisabled: false
- name: ＧＡＯＲＡ
  type: CS
  channel: CS12
  serviceId: 254
  isDisabled: false
- name: エムオン！
  type: CS
  channel: CS12
  serviceId: 325
  isDisabled: false
- name: キッズステーション
  type: CS
  channel: CS12
  serviceId: 330
  isDisabled: false
- name: ナショジオ
  type: CS
  channel: CS12
  serviceId: 343
  isDisabled: false
- name: ザ・シネマ
  type: CS
  channel: CS14
  serviceId: 227
  isDisabled: false
- name: ファミリー劇場
  type: CS
  channel: CS14
  serviceId: 293
  isDisabled: false
- name: スーパー！ドラマＴＶ
  type: CS
  channel: CS14
  serviceId: 310
  isDisabled: false
- name: ヒストリーチャンネル
  type: CS
  channel: CS14
  serviceId: 342
  isDisabled: false
- name: ＳＫＹ　ＳＴＡＧＥ
  type: CS
  channel: CS16
  serviceId: 290
  isDisabled: false
- name: ＡＸＮ　海外ドラマ
  type: CS
  channel: CS16
  serviceId: 311
  isDisabled: false
- name: ＡＸＮミステリー
  type: CS
  channel: CS16
  serviceId: 316
  isDisabled: false
- name: スペシャプラス
  type: CS
  channel: CS16
  serviceId: 321
  isDisabled: false
- name: ＡＴ－Ｘ
  type: CS
  channel: CS16
  serviceId: 333
  isDisabled: false
- name: ＢＢＣワールド
  type: CS
  channel: CS16
  serviceId: 353
  isDisabled: false
- name: ムービープラス
  type: CS
  channel: CS18
  serviceId: 240
  isDisabled: false
- name: ゴルフネットワーク
  type: CS
  channel: CS18
  serviceId: 262
  isDisabled: false
- name: 銀河◆歴ドラ・サスペ
  type: CS
  channel: CS18
  serviceId: 305
  isDisabled: false
- name: 女性ｃｈ／ＬａＬａ
  type: CS
  channel: CS18
  serviceId: 314
  isDisabled: false
- name: フジテレビＯＮＥ
  type: CS
  channel: CS20
  serviceId: 307
  isDisabled: false
- name: フジテレビＴＷＯ
  type: CS
  channel: CS20
  serviceId: 308
  isDisabled: false
- name: フジテレビＮＥＸＴ
  type: CS
  channel: CS20
  serviceId: 309
  isDisabled: false
- name: スペースシャワーＴＶ
  type: CS
  channel: CS20
  serviceId: 322
  isDisabled: false
- name: ＱＶＣ
  type: CS
  channel: CS22
  serviceId: 161
  isDisabled: false
- name: ＴＢＳチャンネル２
  type: CS
  channel: CS22
  serviceId: 297
  isDisabled: false
- name: ＦＯＸ
  type: CS
  channel: CS22
  serviceId: 312
  isDisabled: false
- name: ＴＢＳ　ＮＥＷＳ
  type: CS
  channel: CS22
  serviceId: 351
  isDisabled: false
- name: 映画・ｃｈＮＥＣＯ
  type: CS
  channel: CS24
  serviceId: 223
  isDisabled: false
- name: 日テレジータス
  type: CS
  channel: CS24
  serviceId: 257
  isDisabled: false
- name: ＭＯＮＤＯ　ＴＶ
  type: CS
  channel: CS24
  serviceId: 295
  isDisabled: false
- name: 日テレプラス
  type: CS
  channel: CS24
  serviceId: 300
  isDisabled: false
EOF

# チューナー設定
## 使うチューナーに合わせて UI から適宜有効化すること
cat <<EOF > /usr/local/etc/mirakurun/tuners.yml
- name: PX-S1UD
  types:
    - GR
  command: >-
    dvbv5-zap -a 0 -c config/dvbconf-for-isdb/conf/dvbv5_channels_isdbt.conf -r
    -P <channel>
  decoder: arib-b25-stream-test
  dvbDevicePath: /dev/dvb/adapter0/dvr0
  isDisabled: true
- name: PX-W3U4-T1
  types:
    - GR
  command: recpt1 --device /dev/px4video2 <channel> - -
  decoder: arib-b25-stream-test
  isDisabled: true
- name: PX-W3U4-T2
  types:
    - GR
  command: recpt1 --device /dev/px4video3 <channel> - -
  decoder: arib-b25-stream-test
  isDisabled: true
- name: PX-W3U4-S1
  types:
    - BS
    - CS
  command: recpt1 --device /dev/px4video0 --lnb 0 <channel> - -
  decoder: arib-b25-stream-test
  isDisabled: true
- name: PX-W3U4-S2
  types:
    - BS
    - CS
  command: recpt1 --device /dev/px4video1 --lnb 0 <channel> - -
  decoder: arib-b25-stream-test
  isDisabled: true
EOF

echo '--------------------------------------------------------------------------------'
echo 'Installing EPGStation...'
echo '--------------------------------------------------------------------------------'

# EPGStation のインストール
## 実機だと npm ライブラリのインストールとビルドにかなり時間がかかるため、こっちで事前にやっておく
cd /opt/
git clone https://github.com/l3tnun/EPGStation.git
cd /opt/EPGStation
npm run all-install
npm run build

# EPGStation の設定
cat <<EOF > config/config.yml
# リッスンポート
port: 8888

# Mirakurun の URL (Unix ソケット経由で通信)
mirakurunPath: http+unix://%2Fvar%2Frun%2Fmirakurun.sock/

# データベースとして SQLite を使う
dbtype: sqlite

# 囲み文字を置換する
needToReplaceEnclosingCharacters: true

# ドロップチェックを有効化
isEnabledDropCheck: true

# EPG の更新間隔
epgUpdateIntervalTime: 10

# 録画時に Mirakurun へ渡される優先度
recPriority: 2

# 競合録画時に Mirakurun へ渡される優先度
conflictPriority: 1

# 録画ファイルのファイル名テンプレート
recordedFormat: '%HALF_WIDTH_TITLE%'
recordedFileExtension: .ts

# 録画フォルダ
recorded:
    - name: TV-Record
      path: '/mnt/hdd/TV-Record'

# サムネイルの設定
thumbnail: '%ROOT%/thumbnail'
thumbnailSize: 640x360
thumbnailPosition: 5

# FFmpeg / FFprobe のパス
ffmpeg: /usr/bin/ffmpeg
ffprobe: /usr/bin/ffprobe

# エンコードやストリーミングで使用されるプロセスの上限数
encodeProcessNum: 2

# 同時エンコード数
concurrentEncodeNum: 1

# エンコード設定
encode:
    - name: H.264
      cmd: '%NODE% %ROOT%/config/enc.js'
      suffix: .mp4
      rate: 4.0

# ストリーミング視聴時の URL スキームの設定 (iOS / Android 用)
urlscheme:
    m2ts:
        ios: vlc-x-callback://x-callback-url/stream?url=PROTOCOL://ADDRESS
        android: intent://ADDRESS#Intent;package=org.videolan.vlc;type=video;scheme=PROTOCOL;end
    video:
        ios: infuse://x-callback-url/play?url=PROTOCOL://ADDRESS
        android: intent://ADDRESS#Intent;package=com.mxtech.videoplayer.ad;type=video;scheme=PROTOCOL;end
    download:
        ios: vlc-x-callback://x-callback-url/download?url=PROTOCOL://ADDRESS&filename=FILENAME

# ストリーミング設定
## 現状 HW エンコードが利用できないため、ライブは無変換のみ、録画は無効化
stream:
    live:
        ts:
            m2ts:
                - name: 無変換
    recorded:
        ts:
            webm: []
            mp4: []
            hls: []
        encoded:
            webm: []
            mp4: []
            hls: []
EOF
cp config/operatorLogConfig.sample.yml config/operatorLogConfig.yml
cp config/epgUpdaterLogConfig.sample.yml config/epgUpdaterLogConfig.yml
cp config/serviceLogConfig.sample.yml config/serviceLogConfig.yml
cp config/enc.js.template config/enc.js

# PM2 での自動起動設定
pm2 start dist/index.js --name "EPGStation"
pm2 save
pm2 stop EPGStation
cd /

# ----------------------------------------------------------------------------------------------------
# 後処理
# ----------------------------------------------------------------------------------------------------

# apt-get のキャッシュを削除
apt-get clean
rm -rf /var/lib/apt/lists/*

# npm のキャッシュを削除
rm -rf ~/.npm
