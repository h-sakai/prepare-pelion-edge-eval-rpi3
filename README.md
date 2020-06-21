# prepare-pelion-edge-eval-rpi3

## What is this?

arm Pelion EdgeのRaspberry Pi3向け評価用イメージをビルドするための環境を、半自動で準備するためのスクリプトです。

元となった手順書は以下のURLに存在します。

https://gist.github.com/ryuatarm/b537e12facc80014df126e972cce0810

## 想定動作環境

- Ubuntu 18.04
- なるべく速いCPU
- なるべくたくさんのメモリ
- 30GB以上のストレージの空き
- ユーザーがrootに昇格(sudo)できること

## 事前準備

先述したURLの4.5にある、ブートストラップ証明書の作成・ダウンロードを行っておいてください。

## 使用例

カレントディレクトリにあるブートストラップ証明書ファイルmbed_cloud_credentials.cを使い、カレントディレクトリ下にあるbuildディレクトリにビルド環境を配置する場合の例

    $ ./prepare-pelion-edge-eval-rpi3.sh -b ./mbed_cloud_credentials.c -d ./build

## オプション

- -b 使用するブートストラップ証明書ファイル(指定必須)
- -d ビルド環境を配置するディレクトリ(指定必須)
- -v manifest-toolに与えるVendor GUID
- -c manifest-toolに与えるClass GUID
- -p git/sshプロトコルの代わりにhttpsを使用する

## 制限事項

- git/sshプロトコルを使用する場合には、あらかじめGitHubアカウントへのSSH Public Keyの登録が必要です。
- 場合によってリブートが必要な場合があります。
  - リブート後に同じ条件で再度実行してください。
- 場合によって一度もしくは複数回sudoのパスワード入力を要求されます。
  - 面倒な人はパスワード入力を回避するようにsudoersを適切に設定してください。
- たぶんProxyの後ろにいると使えません。
- manifest-toolで作成される証明書の有効期限は90日になります。
  - 期限を延ばしたい場合は手動でmanifest-toolを実行し、上書きしてください。

## 免責等

- prepare-pelion-edge-eval-rpi3.sh(以下本スクリプト)は自由に改変、配布が可能です。
  - 煮るなり焼くなりご自由にどうぞ。
- 本スクリプトの動作は無保証です。
- 本スクリプトを使用することで、いかなる損害が発生しても作者は一切の責任を負いません。
