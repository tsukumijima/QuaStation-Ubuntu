
# QuaStation-Ubuntu

Qua Station 向けの Linux カーネルのビルドと、Ubuntu 20.04 LTS の rootfs の構築を全自動で行うスクリプトです。

## 概要

Qua Station 向けの Ubuntu 20.04 LTS のインストールイメージを作成するためのツールです。  
Qua Station に搭載されているほとんどのハードウェアをフル活用できるように、Linux カーネルの構成やデバイスツリー、ソースコード、設定ファイルなどを大幅に調整しています。

動作確認は Ubuntu 20.04 LTS の Linux PC (x86_64) で行っています。  
ビルドはすべて Docker コンテナ内で実行されますが、WSL などではうまく動かないかもしれません。

> 注意: このリポジトリは2つの Linux カーネルをサブモジュールとして含んでいるため、展開後のサイズがかなり大きくなります (ソースと .git だけで 4GB 程度)。  
> Docker イメージのビルドやインストールイメージの構築でもストレージ容量を GB 単位で消費するため、最低でも 20GB はストレージ容量に余裕を持たせた状態でビルドすることを推奨します。

## ハードウェア

現時点で動作する Qua Station 搭載のハードウェアは以下の通りです。

- **CPU (SoC): Realtek RTD1295 (4 Core)**
  - CPU 自体は H.264 のハードウェアエンコード/デコードに対応しているが、残念ながら OpenMAX ライブラリがプロプライエタリで仕様が公開されていないことが枷となり、現時点では Linux では動作しない
    - どこかから流出した Linux 向けの OpenMAX ライブラリ (バイナリ) と組み合わせてハードウェアエンコードできるらしい [FFmpeg のフォーク](https://github.com/jjm2473/ffmpeg-rtk) があるが、現時点では上手く動いておらず…
    - このスクリプトで構築した Ubuntu では、事前に [こちら](https://github.com/jjm2473/rtd1296_prebuilt_target/releases) で公開されている OpenMAX ライブラリ (apps_ffmpeg_4.0.3_OpenWRT-gcc8.2-glibc2.27.tar.xz) を同梱している
  - GPU (Mali-T820) も付属しているが、Qua Station には映像出力がないため、搭載されている意味がない
  - Realtek SoC を採用した機器は Allwinner・Amlogic・Rockchip などと比べて少なく、情報も比例して少ない
  - RTD129x シリーズを採用しているメジャーな機器は他には Banana Pi W2・Zidoo X9S / Z9S 程度しかない
- **CPU ファン**
  - 素の Banana Pi W2 の BSP カーネル（後述）では認識されないが、デバイスツリーの記述を実機の eMMC から抽出したものを参考に変更したところ動くようになった
  - かなり静かに回っている
- **RAM: 2GB (Samsung K4B4G0846E)**
  - Linux カーネルや MMIO (メモリマップ I/O) などに 400MB ほど吸われるため、実際にユーザースペースで利用できるのは 1.6GB 程度
- **eMMC: 8GB (Samsung KLM8G1GEME)**
  - 実機で使われている Android が保存されている
  - eMMC から吸い出した Android のデータは [こちら](https://github.com/tsukumijima/Storehouse/releases/tag/Storehouse)
- **HDD: 1TB (HGST HCC541010B9E660)**
  - HGST 製の 2.5 インチ HDD で、裏蓋から比較的容易に取り外すことができる（ただし、フタのツメが硬いためツメを折らないように注意すること）
- **Wi-Fi IC: Realtek RTL8812AR**
  - オンボード PCIe 接続で、`lspci` では RTL8812AE として認識される
  - 5GHz 帯専用だが、なぜか手元の環境だとネットワーク速度が異常に遅い…
  - カタログスペックでは 2.4GHz 帯にも対応しているはずだが、スキャン結果に 2.4GHz 帯のアクセスポイントが一切ないため、少なくとも現在利用しているドライバでは認識しないものと思われる
  - 実機では 5GHz 帯のアクセスポイント用として使われている模様
- **Wi-Fi IC: Realtek RTL8192ER**
  - オンボード PCIe 接続で、`lspci` では RTL8192EE として認識される
  - 2.4GHz 帯専用だが、なぜか手元の環境だと 2.4GHz 帯とは思えないほどの高スピード (down/up ともに最高で 100Mbps 前後) で通信できる
  - 5GHz 帯向けの RTL8812AR は使い物にならないレベルの速度なため (ルーターから少しでも離すと数Mbpsしか出ない) 、基本こっちで接続することを推奨
  - 実機では 2.4GHz 帯のアクセスポイント用として使われている模様
- **Bluetooth IC: Realtek RTL8761ATV**
  - シリアルポート (UART) 接続の Bluetooth IC で、`/dev/ttyS1` に tty として認識される
  - Bluetooth デバイスとして認識させるには、別途バックグラウンドで [rtk_hciattach](https://github.com/radxa/rtkbt/tree/main/uart/rtk_hciattach)（ Realtek 製の UART 接続 Bluetooth IC を BlueZ に接続するためのソフト）を起動する必要がある
  - このスクリプトで構築した Ubuntu では事前にセットアップ済みのため、追加の設定は不要
  - 実機の eMMC から抽出したファームウェア (rtl8761a_fw) でないと起動しない点が嵌まりポイント
  - 以前は再起動するとなぜか認識しなくなってしまっていたが、[デバイスツリー側の調整](https://github.com/tsukumijima/QuaStation-Kernel-BPi/commit/058149f37a9540e68d3569c83aca98e29aaf4965) で解消された
- **LTE モデム: WWHC060-D111**
  - カーネル構成で USB-ACM を有効化することで、USB 接続の tty として認識される
  - `lsusb` でも USB で接続されていることが確認できる
  - Qualcomm 製の LTE モデムで、USB PID は 0x9026 (この機種のためのオリジナルモデルと思われる)
    - バンドは当然 au の範囲にしか対応していない
  - wvdial で AT コマンドが通るところまでは確認できたが、SIM は挿していないため実際に通信できるかは未確認
    - 楽天モバイルの SIM を挿して通信できたという情報がある ([ソース](https://jp.mercari.com/item/m74949972094))
    - Web UI があるらしい ([ソース](https://twitter.com/kirohi114/status/1396511222455889927))
- **USB ポート (USB 3.0 ポート × 1 / USB 2.0 ポート × 1)**
  - USB メモリを接続してブートできる程度には普通に認識する
  - ただ、今のところ 4.9.119 カーネルでは (USB 3.0 ポートなのにも関わらず) `lsusb` で USB 2.0 ポートとして扱われているのが引っかかる
- **SD カードスロット**
  - SD カードを挿入すると普通に `/dev` に `mmcblkX` として認識される (X は環境次第で変わる)
  - eMMC も `mmcblkX` として認識しているため、混同しないように注意
- **GPIO ボタン (POWER・RESET・WPS・COPY (IMPORT))**
  - 動作させるためにデバイスツリーへの項目の追加を行った (rtd-1295-quastation.dts の `gpio-btns` の項目)
  - 実機の Android ファームウェアに含まれている gpio_isr.ko が GPIO ボタンのドライバだが、ライセンス上 GPL になっているのにソースコードが公開されていないため、リバースエンジニアリングしてドライバを自作した ([phoenix/drivers/gpio_isr/gpio_isr.c](https://github.com/tsukumijima/QuaStation-Kernel-BPi/blob/master/phoenix/drivers/gpio_isr/gpio_isr.c))
  - 多少本家の挙動と異なる部分もあるが (uevent の細かいパラメータ周り)、ボタンが押された際のイベントは正しくトリガーできているため問題ない
  - /etc/udev/rules.d/10-gpio-buttons.rules に各ボタンが押された際に実行するコマンドを記述している
    - POWER ボタンを3秒以上長押しするとシャットダウンされる
      - 正確には、U-Boot の環境変数にある `PowerStatus` フラグを `on` から `off` に書き換えたあとに再起動している
      - こうすることで、U-Boot 側が POWER ボタンが押されるまで起動するのを中断してくれる
    - RESET ボタンを押すと再起動される
      - U-Boot の環境変数は書き換えないため、通常通り再起動される
    - WPS ボタンと COPY (IMPORT) ボタンは現状余っていることから、とりあえず押すと LED が光るように設定してある（お遊び）
- **LED ランプ (POWER・LTE・WLAN・HDD・COPY (IMPORT))**
  - 動作させるためにデバイスツリーへの項目の追加を行った (rtd-1295-quastation.dts の `leds` の項目)
  - カーネル構成で有効にしていれば、カーネルのデフォルトドライバだけで動作する
  - デバイスツリーの記述により、起動時は POWER の LED ランプが緑で点滅している
    - 起動後は /etc/rc.local に記述されたコマンドが実行されることで、緑点灯の状態になる
  - LTE・WLAN・HDD の LED ランプは暫定的に WPS ボタンを押している間光るように設定してある
  - COPY (IMPORT) の LED ランプは一度押すと点灯し、3秒以上長押しすると消灯する

### Linux カーネルの選択

Ubuntu 20.04 LTS と組み合わせるカーネルは、

- **Linux 4.9.119 ベース ([QuaStation-Kernel-BPi](https://github.com/tsukumijima/QuaStation-Kernel-BPi)) ← おすすめ**
  - Qua Station (SoC: RTD1295) と近い SoC を搭載している [Banana Pi W2 (SoC: RTD1296) 向けの BSP (Board Support Package) カーネル](https://github.com/BPI-SINOVOIP/BPI-W2-bsp) をベースに、Qua Station に搭載されているハードウェアを認識できるように改良したカーネル
- **Linux 4.1.17 ベース ([QuaStation-Kernel](https://github.com/tsukumijima/QuaStation-Kernel))**
  - KDDI テクノロジー（ Qua Station の販売元）から [GPL に基づき公開された Linux カーネル](https://github.com/Haruroid/linux-kernel-kts31) をベースに、Ubuntu 環境で一通り利用できるように改良したカーネル
  - 実機で用いられているカーネルとほぼ同じだが、デバイスツリーのコンパイル結果が異なる・2つ目の PCIe スロットが認識しないなどの点から、厳密には開発版（あるいは旧バージョン）のソースコードである可能性が高い
  - なお、U-Boot (GPL) のソースコードは [このリポジトリ](https://github.com/Haruroid/u-boot-kts31) で公開されている
    - KDDI テクノロジーから4年前に一緒に開示されたものの、つい最近まで GitHub に上げていなかったということらしい…

の2つから選択できます。

どちらも mainline のカーネルと比較すると、Realtek SoC 向けの大幅なカスタマイズ（ Realtek SoC 固有のドライバやデバイスツリーの追加など）が行われています。  
mainline のカーネルでは Realtek SoC 固有のドライバが実装されていないため、まずまともに動かないことでしょう。

4.9.119 ですら今となってはかなり古いバージョンですが、BSP カーネルを新しい Linux カーネルに移植するには多大な時間と労力が必要です（そして SoC メーカーは基本的にアップデートを公開しない…）。  
できるだけ多くの搭載ハードウェアを動かすため、やむを得ず古いカーネルを利用しています。  
ufw がうまく動作しないなど若干の問題はありますが、**基本的には Ubuntu 20.04 LTS でも問題なく動作します。一応 Docker も動きます。**  

**基本的には Linux 4.9.119 ベースの方をおすすめします。**  
4.1.17 ベースの方はバージョン自体が古い上に、5GHz の方の Wi-Fi IC が接続された PCIe スロット (PCIE2) がエラーで認識されない問題を抱えています。  
また、4.1.17 ではあまり動作確認をしていないため、もしかするとうまく起動できなかったりがあるかもしれません。安定性も 4.9.119 の方が高い印象です。

いずれのカーネルにも既知の問題があります。詳細は各カーネルの Readme.md を参照してください。

## ビルド

ビルドはすべて Docker コンテナ内で実行されるため、Docker 環境さえあれば、ホスト PC の環境を汚すことなく簡単にビルドできます。

> 下記で解説するコマンドのうち、`bpi` の部分を `au` に変更して実行すると、4.9.119 カーネルの代わりに 4.1.17 カーネルの方をビルドできます。

```bash
git clone --recursive https://github.com/tsukumijima/QuaStation-Ubuntu.git
cd QuaStation-Ubuntu
```

このリポジトリを clone します。  
サブモジュール（Linux カーネル）も同時に clone するため、この時点で 4GB 弱のストレージ容量を消費します。

```bash
make docker-image-bpi  # カーネルビルド用の Docker イメージを構築
make docker-image-ubuntu-rootfs  # rootfs 構築用の Docker イメージを構築
```

あらかじめ、ビルドに利用する Docker イメージを構築しておきます。

```bash
make build-all-bpi
make build-kernel-bpi  # カーネルのみビルドする場合
make build-ubuntu-rootfs  # Ubuntu の rootfs のみビルドする場合
```

あとは `make build-all-bpi` を実行するだけで、全自動でビルドが行われます。

PC のスペックにもよりますが、ビルドには 30 分程度時間がかかります。  
`Ubuntu 20.04 LTS rootfs build is completed.` と表示されたら完了です！

rootfs の構築スクリプトは `build_ubuntu_rootfs.sh` にあります。  
Ubuntu 20.04 LTS (x86_64) の Docker コンテナの中でさらに chroot 環境に入り、その中で実行しています。  
適宜 `build_ubuntu_rootfs.sh` をカスタマイズすることで、事前に様々なソフトをインストールしておくことができます。

> chroot 環境のため、一部の機能 (Systemd・Docker など) が動作しないことに注意してください。

-----

`make clean-bpi` で、カーネルのビルドされた成果物（ビルドキャッシュなど）をすべて削除できます。  
カーネルを最初からビルドし直したい際などに実行します。

> Ubuntu の rootfs を最初からビルドし直したいときは、`usbflash/rootfs/` をまるごと削除して、もう一度 `make build-all-bpi` を実行してください。

## 成果物

ビルドが終わると、`usbflash/` ディレクトリ以下に

- Linux カーネル (`bootfs/uImage`)
- Device Tree Blob (`bootfs/QuaStation.dtb`)
- カーネルモジュール (`rootfs/usr/lib/modules/4.9.119-quastation/`)
- カーネルヘッダー (`rootfs/usr/src/linux-headers-4.9.119-quastation/`)
- Ubuntu 20.04 LTS の rootfs (`rootfs/`)

がそれぞれ生成されています。各自 USB メモリにコピーしてください。

`bootfs/` 以下のファイルは FAT32 (VFAT) でフォーマットされた先頭 100MB のパーティションへ、`rootfs/` 以下のファイルは残りの ext4 パーティションに配置します。

> USB メモリに焼く手順や U-Boot のコマンドについては、u-haru 氏の記事 ([記事1](https://u-haru.com/post/quastation%E7%94%A8%E3%81%AEarchlinux%E3%82%A4%E3%83%A1%E3%83%BC%E3%82%B8%E3%82%92%E4%BD%9C%E6%88%90%E3%81%99%E3%82%8B/)・[記事2](https://u-haru.com/post/quastation%E3%81%A7archlinux%E3%82%92%E5%8B%95%E4%BD%9C%E3%81%95%E3%81%9B%E3%82%8B/)) が参考になると思います。  
> 現時点では USB ブートのみ想定しています。eMMC からのブートは未検証です。

その後、適切に U-Boot のコマンドを実行すれば、Qua Station 上で Ubuntu 20.04 LTS が起動できるはずです。
