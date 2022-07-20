
# 1つのタスクに対して1つのシェルを使う
# ref: https://stackoverflow.com/questions/1789594/how-do-i-write-the-cd-command-in-a-makefile
.ONESHELL:

#「ディレクトリに入ります」/「ディレクトリから出ます」のメッセージを抑制
MAKEFLAGS += --no-print-directory

# この Makefile があるディレクトリ
BASE_DIR := $(shell pwd)

# au カーネル (QuaStation-Kernel: Linux 4.1.17) ベースの Docker イメージを構築する
docker-image-au:
	make -C $(BASE_DIR)/QuaStation-Kernel/ docker-image

# BPi カーネル (QuaStation-Kernel-BPi: Linux 4.9.119) ベースの Docker イメージを構築する
docker-image-bpi:
	make -C $(BASE_DIR)/QuaStation-Kernel-BPi/ docker-image

# Ubuntu 20.04 LTS の rootfs を構築するための Docker イメージを構築する
docker-image-ubuntu-rootfs:
	@echo '--------------------------------------------------------------------------------'
	@echo 'Building Docker image for Ubuntu rootfs...'
	@echo '--------------------------------------------------------------------------------'
	mkdir -p $(BASE_DIR)/build
	docker build -t quastation-ubuntu -f Dockerfile $(BASE_DIR)/build/
	rm -rf $(BASE_DIR)/build
	@echo '--------------------------------------------------------------------------------'
	@echo 'Docker image build for Ubuntu rootfs is completed.'
	@echo '--------------------------------------------------------------------------------'

# au カーネル (QuaStation-Kernel: Linux 4.1.17) ベースで構築する
build-all-au:
	make build-kernel-au
	make build-ubuntu-rootfs
build-kernel-au:
	make -C $(BASE_DIR)/QuaStation-Kernel/ build
	docker run --rm -i -t -h QuaStation -v `pwd`:/build/ quastation-ubuntu /bin/bash -c 'cp -a /build/QuaStation-Kernel/usbflash/ /build/'

# BPi カーネル (QuaStation-Kernel-BPi: Linux 4.9.119) ベースで構築する
build-all-bpi:
	make build-kernel-bpi
	make build-ubuntu-rootfs
build-kernel-bpi:
	make -C $(BASE_DIR)/QuaStation-Kernel-BPi/ build
	docker run --rm -i -t -h QuaStation -v `pwd`:/build/ quastation-ubuntu /bin/bash -c 'cp -a /build/QuaStation-Kernel-BPi/usbflash/ /build/'

# QuaStation 向けの Ubuntu 20.04 LTS の rootfs を構築する
## --privileged がないと chroot 時に必要な tmpfs などのマウントができない
## ref: https://kazuhira-r.hatenablog.com/entry/20180220/1519112450
build-ubuntu-rootfs:
	docker run --privileged --rm -i -t -h QuaStation -v `pwd`:/build/ quastation-ubuntu /bin/bash -c 'make build-ubuntu-rootfs-in-container'
build-ubuntu-rootfs-in-container:
	@echo '--------------------------------------------------------------------------------'
	@echo 'Building Ubuntu 20.04 LTS rootfs...'
	@echo '--------------------------------------------------------------------------------'
	mkdir -p usbflash/
	mkdir -p usbflash/rootfs/
    # ベースにする Ubuntu Base 20.04 LTS をダウンロード
	wget http://ftp.jaist.ac.jp/pub/Linux/ubuntu-cdimage/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-arm64.tar.gz
	tar xvf ubuntu-base-20.04.4-base-arm64.tar.gz -C usbflash/rootfs/ && rm ubuntu-base-20.04.4-base-arm64.tar.gz
    # chroot のための事前準備
	chmod 755 usbflash/rootfs/
	chown root:root usbflash/rootfs/
	cd usbflash/rootfs/
    # amd64 環境で arm64 のバイナリを実行するために必要
	cp -a /usr/bin/qemu-arm-static ./usr/bin/qemu-arm-static
    # sysfs や tmpfs などの特殊なファイルシステムを rootfs にマウント
    # これをやっておかないとまともに動かない
	mount -t devtmpfs udev ./dev
	mount -t devpts devpts ./dev/pts
	mount -t proc proc ./proc
	mount -t sysfs sysfs ./sys
	mount -t tmpfs tmpfs ./tmp
    # ビルドスクリプトを実行
	cp -a /build/build_ubuntu_rootfs.sh ./build_ubuntu_rootfs.sh
	chroot ./ /bin/bash /build_ubuntu_rootfs.sh
	rm ./build_ubuntu_rootfs.sh
    # sysfs や tmpfs などの特殊なファイルシステムを rootfs からアンマウント
	umount ./tmp
	umount ./sys
	umount ./proc
	umount ./dev/pts
	umount ./dev
	@echo '--------------------------------------------------------------------------------'
	@echo 'Ubuntu 20.04 LTS rootfs build is completed.'
	@echo '--------------------------------------------------------------------------------'

# au カーネル (QuaStation-Kernel: Linux 4.1.17) ベースで構築したビルド成果物を削除する
clean-au:
	make -C $(BASE_DIR)/QuaStation-Kernel/ clean

# BPi カーネル (QuaStation-Kernel-BPi: Linux 4.9.119) ベースで構築したビルド成果物を削除する
clean-bpi:
	make -C $(BASE_DIR)/QuaStation-Kernel-BPi/ clean
