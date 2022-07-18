
# Docker 環境を作成する Ubuntu のバージョンに合わせる
FROM ubuntu:20.04

# chroot 環境内で実行する rootfs 構築用スクリプト
ADD build_ubuntu_rootfs.sh ./

# qemu-user-static は x86_64 な PC で arm64 の実行ファイルを実行するために必要
RUN set -x && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && apt-get update
RUN apt-get install -y git make qemu-user-static wget

WORKDIR /build

CMD ["bash"]
