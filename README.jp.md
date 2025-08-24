# ArkImg
[![GitHub tag](https://img.shields.io/github/tag/shoo/arkimg.svg?maxAge=86400)](#)
[![CI Status](https://github.com/shoo/arkimg/actions/workflows/main.yml/badge.svg)](https://github.com/shoo/arkimg/actions/workflows/main.yml)
[![downloads](https://img.shields.io/dub/dt/arkimg.svg?cacheSeconds=3600)](https://code.dlang.org/packages/arkimg)
[![BSL-1.0](http://img.shields.io/badge/license-BSL--1.0-blue.svg?style=flat)](./LICENSE)
[![codecov](https://codecov.io/gh/shoo/arkimg/branch/main/graph/badge.svg)](https://codecov.io/gh/shoo/arkimg)
[![Document](http://img.shields.io/badge/API_Document-purple.svg?style=flat)](https://shoo.github.io/arkimg)
[![WebUI](http://img.shields.io/badge/WebUI-green.svg?style=flat)](https://shoo.github.io/arkimg/webui.html)

ArkImgは、画像ファイル（PNG, JPEG, BMP, WebP）内に暗号化したデータを埋め込むことができるライブラリです。  
秘密情報やファイルを画像に隠蔽し、安全に保存・転送する用途に利用できます。

ライブラリのサンプルとして付属する形で、コマンドラインインターフェースと、ウェブインターフェースを用意しています。

---

[<img src="./.gendoc/public/icon.svg" width="32" />](https://shoo.github.io/arkimg/webui.html)  
[Webインターフェースはこちらから](https://shoo.github.io/arkimg/webui.html)

---

注意：ウィルスの混入に注意してください。信頼のある配布元のデータかどうかを必ず確認してください。確認のため、作成時は秘密鍵で署名データを追加し、秘密データ展開時には配布元の公開鍵で署名を検証することをお勧めします。


## 特徴

- PNG/JPEG/BMP/WebP画像へのデータ埋め込み・抽出
- AESによるデータ暗号化
- Ed25519による署名・検証機能
- 複数ファイル・メタデータの埋め込み対応


# ライブラリとしての利用方法
## 使用方法

```sh
dub add arkimg
```

## サンプルコード

```d
import arkimg;
import std.file;
auto commonKey = createCommonKey();
auto prvKey    = createPrivateKey();
auto pubKey    = createPublicKey(prvKey);

auto img = new ArkPng;
// Set the AES common key. 128bits/192bits/256bits
img.setKey(commonKey);
// Load and set the base image to be used as a thumbnail
img.baseImage = cast(immutable(ubyte)[])std.file.read("input.bmp");
// Insert a hidden file
img.addSecretItem(cast(immutable(ubyte)[])std.file.read("secret.png"));
// Optionally, you can sign the image
// The key used for image signing must be a 32-byte Ed25519 private key.
img.sign(prvKey);
assert(img.hasSign);
assert(img.verify(pubKey));

std.file.write("encrypted.png", img.save());
```

## API
- ArkImg: interface
  - `void load(in ubyte[] binary)`: 画像ファイルのデータ読み込み
  - `immutable(ubyte)[] save() const`: 画像ファイルへのデータ保存
  - `void setKey(in ubyte[] commonKey)`: 暗号化/復号のための共通鍵を設定
  - `void sign(in ubyte[] prvKey)`: 全データにまとめて署名
  - `bool verify(in ubyte[] pubKey) const`: 全データの署名をまとめて検証
  - `bool hasSign() const`: 署名を持っているか確認
  - `void metadata(in JSONValue metadata)`: メタデータを設定
  - `JSONValue metadata() const`: メタデータを取得
  - `void baseImage(in ubyte[] binary, string mimeType = "image/bmp")`: ベース画像設定
  - `immutable(ubyte)[] baseImage(string mimeType = "image/bmp")`: ベース画像取得
  - `void addSecretItem(in ubyte[] binary, string name = null, string mimeType = null, in ubyte[] prvKey = null)`: 添付するデータを追加(平文で指定)
  - `void clearSecretItems()`: 添付するデータを全削除
  - `size_t getSecretItemCount() const`: 添付されている暗号化されたデータの数
  - `immutable(ubyte)[] getDecryptedItem(size_t idx) const`: 添付されている復号されたデータ
  - `immutable(ubyte)[] getEncryptedItem(size_t idx) const`: 添付されている暗号化されたデータ
- ArkBmp: ArkImg
- ArkPng: ArkImg
- ArkJpg: ArkImg
- ArkWebp: ArkImg
- ヘルパ関数
  - `string mimeType(string filename)`: ファイル名からMIMEタイプの取得
  - `immutable(ubyte)[] createCommonKey(size_t keySize = 32)`: 共通鍵生成
  - `immutable(ubyte)[] createRandomIV()`: 初期ベクトル(通常使用しない)
  - `immutable(ubyte)[] createPrivateKey()`: 署名用の秘密鍵を生成
  - `immutable(ubyte)[] createPublicKey(in ubyte[] prvKey)`: 検証用の公開鍵を生成
  - `ArkImg loadImage(immutable(ubyte)[] binary, string mimeType = "image/png", in ubyte[] commonKey, in ubyte[] iv = null)`: 画像読み込み(ファイルの中身のバイト列から)
  - `ArkImg loadImage(string filename, in ubyte[] commonKey = null, in ubyte[] iv = null)`: 画像読み込み(ファイル名から)
  - `immutable(ubyte)[] saveImage(ArkImg img, string mimeType = "image/png", in ubyte[] commonKey, in ubyte[] iv = null)`: 画像の保存(ファイルの中身のバイト列へ/ファイルへは別途保存)

# ファイル構造に関する仕様
### PNG
任意位置だが、たいていの場合はIDAT チャンク(画像データ)の後に以下が含まれる。
- eDAt チャンク: **暗号データ本体** 1つのファイルにつき複数含まれる場合あり。
- eMDt チャンク: **メタデータ** 1つのファイルにつき0個または1つ含まれる

注意: IDATチャンクの後ろのチャンクが含まれる場合に、PNG画像を取り扱えなくなるブラウザやビューワーなどがある可能性があります。
※PNGのeDAtチャンクおよびeMDtチャンクはPNGのカスタムチャンクとして扱うことができる。

### JPG
EOI (エンドマーカ)の後に以下の構造でデータを含む。

- 暗号化チャンク: 複数
  - シグネチャ: 4 byte LittleEndian
  - データ長: 4 byte LittleEndian 符号なし32bit整数 (データ N byteのバイト数)
  - データ: N byte

`[SOI] | [Segment 1] | [Segment 2] | ... | [EOI] | [Encrypted Chunk 1] | [Encrypted Chunk 2] ... ` <br/>
`[Encrypted Chunk]`: `[Type: 4 bytes] | [Length: 4 bytes] | [Data: N bytes]`

暗号化チャンクは複数含まれます。
暗号化チャンクはデータの中身の種別であるシグネチャと、データのバイト数を意味するデータ長と、可変長のデータが含まれます。
- シグネチャ `['E', 'D', 'A', 'T']`: データは **暗号データ本体** 1つのファイルにつき複数含まれる場合あり。"EDAT"のASCIIコード4桁。先頭から順に`[0x45, 0x44, 0x41, 0x54]`の4バイト。
- シグネチャ `['E', 'M', 'D', 'T']`: データは **メタデータ** 1つのファイルにつき0個または1つ含まれる。"EMDT"のASCIIコード4桁。先頭から順に`[0x45, 0x4d, 0x44, 0x54]`の4バイト。

注意: EOIマーカの後ろにデータが含まれる場合に、JPG画像を取り扱えなくなるブラウザやビューワーなどがある可能性があります。
※JPEGの暗号化チャンクは、JPEGのセグメント形式ではないので注意。カスタムセグメント形式(APPnセグメント)だとEOI以降にデータ挿入できず、ブラウザ等でのデータ表示に時間がかかり、また64KBまでしか対応できず不便なため独自のチャンク形式とした。


### BMP
BMP情報ヘッダの画像サイズで指定される画素データの末尾の後ろに、以下の構造でデータを含む。

`[Bitmap File Header] | [Bitmap Info Header] | [Color Pallete] | [Pixel Data] | [Encrypted Chunk 1] | [Encrypted Chunk 2] ... ` <br/>
`[Encrypted Chunk]`: `[Signature: 4 bytes] | [Length: 4 bytes] | [Data: N bytes]`

- 暗号化チャンク: 複数
  - シグネチャ: 4 byte
  - データ長: 4 byte LittleEndian 符号なし32bit整数 (データ N byteのバイト数)
  - データ: N byte

暗号化チャンクは複数含まれます。
暗号化チャンクはデータの中身の種別であるシグネチャと、データのバイト数を意味するデータ長と、可変長のデータが含まれます。
- シグネチャ `['E', 'D', 'A', 'T']`: データは **暗号データ本体** 1つのファイルにつき複数含まれる場合あり。先頭から順に`[0x45, 0x44, 0x41, 0x54]`の4バイト。
- シグネチャ `['E', 'M', 'D', 'T']`: データは **メタデータ** 1つのファイルにつき0個または1つ含まれる。"EDAT"のASCIIコード4桁。先頭から順に`[0x45, 0x4d, 0x44, 0x54]`の4バイト。

### WebP
通常VP8やVP8L、VP8X、ANIM、ANMF等、ベース画像の画素データの後ろにカスタムチャンクとして、以下の構造でデータを含む。
- 暗号化チャンク: 複数
  - チャンクFourCC: 4 byte
  - チャンクサイズ: 4 byte LittleEndian 符号なし32bit整数 (データ N byteのバイト数)
  - ペイロード: N byte

`[Webp File Header] | [Chunks] | ... | [Encrypted Chunk 1] | [Encrypted Chunk 2] ... ` <br/>
`[Encrypted Chunk]`: `[FourCC: 4 bytes] | [Chunk Size: 4 bytes] | [Data: N bytes]`

暗号化チャンクは複数含まれます。
暗号化チャンクはデータの中身の種別であるFourCCと、ペイロードのバイト数を意味するチャンクサイズと、可変長のデータであるペイロードが含まれます。
- FourCC `['E', 'D', 'A', 'T']`: データは **暗号データ本体** 1つのファイルにつき複数含まれる場合あり。先頭から順に`[0x45, 0x44, 0x41, 0x54]`の4バイト。
- FourCC `['E', 'M', 'D', 'T']`: データは **メタデータ** 1つのファイルにつき0個または1つ含まれる。"EDAT"のASCIIコード4桁。先頭から順に`[0x45, 0x4d, 0x44, 0x54]`の4バイト。

※WebPの暗号化チャンク(EMDT, EDAT)はWebPのカスタムチャンクとして扱うことができる。

### 暗号データ本体
以下のいずれかのデータで暗号化されたバイト列
- GCM暗号モード
  - 先頭: IV(12Byte)
  - データ: AES暗号化されたデータ
  - 末尾: 認証データ(16Byte)
- CBC暗号モード(IV指定なし/IVがデータに含まれる場合)
  - 先頭: IV(16Byte)
  - データ: AES暗号化されたデータ
- CBC暗号モード(IV指定あり/IVがデータに含まれない場合)
  - データ: AES暗号化されたデータ

暗号データ本体は復号すると秘密情報のバイト列が得られます。

### メタデータ
以下のいずれかのデータで暗号化されたバイト列
- GCM暗号モード
  - 先頭: IV(12Byte)
  - データ: AES暗号化されたデータ
  - 末尾: 認証データ(16Byte)
- CBC暗号モード(IV指定なし/IVがデータに含まれる場合)
  - 先頭: IV(16Byte)
  - データ: AES暗号化されたデータ
- CBC暗号モード(IV指定あり/IVがデータに含まれない場合)
  - データ: AES暗号化されたデータ

メタデータの情報は復号すると以下のJSONデータが得られます
- `(root)`: Object
- `(root).items`: Array, optional
- `(root).items[*]`: Object / N番目の暗号データのメタ情報
- `(root).items[*].name`: String, optional / 暗号データのファイル名
- `(root).items[*].mime`: String, optional / 暗号データのファイル種別
- `(root).items[*].sign`: String, optional / 署名情報を示す 32byte のEd25519署名データをBase64URLNoPaddingでエンコードしたもの
- `(root).items[*].modified`: String, optional / ファイルの更新日時(ISO8601/UTC)形式 `YYYY-MM-DDTHH:mm:SS.SSSZ`
- `(root).items[*].comment`: String, optional / 任意のコメント
- `(root).items[*].(任意)`: Any, optional / 上記以外の任意のデータを暗号データ毎に付与可能。
- `(root).(任意)`: Any, optional / 上記以外の任意のデータをファイル全体に付与可能。

メタデータのJSON例:
```json
{
  "items": [
    {
      "comment": "Test encrypted image",
      "mime": "image/png",
      "modified": "2025-05-02T10:10:02.1455478Z",
      "name": "secret.png",
      "sign": "C5S8mzGFto9X8aUStlkvue06cGKYA6G7bi4alClNQAveq1GfZKxNnhlUsBBWqxzjm-umSIUSuPvR5m0gb9e_Bw"
    }
  ]
}
```


# 付属コマンドラインツールの使用方法

## 主な機能

- 画像への秘密データの埋め込み（アーカイブ）
- 埋め込んだデータの抽出（エクストラクト）
- データの暗号化・復号
- 埋め込みデータの編集・削除・一覧表示
- 鍵生成・署名・検証

## ビルド方法

```sh
cd examples/arkimg_cli
dub build
```

## 使い方

### コマンドライン例

```sh
# 鍵を作成
# CommonKey:  F25B09DF39C113BD5F81871ED12221C2
# などのように鍵が出力される。以下の <key> にこのCommonKeyを指定する
$ arkimg keyutil --genkey

# ファイルを画像に埋め込む(ファイル指定)
# input.png の画像に secret.png ファイルを暗号化して埋め込み encrypted.png に保存
arkimg encrypt -i input.png -s secret.png -o encrypted.png -k <key>

# 埋め込んだファイルを抽出(ファイル指定)
# encrypted.png の画像に含まれる secret.png ファイルを復号して decrypted.png に保存
arkimg decrypt -i encrypted.png -s secret.png -o decrypted.png -k <key>

# ファイルを画像に埋め込む(ディレクトリの中身全部)
# input.png の画像に secretdir 内に含まれる全ファイルを暗号化して埋め込み encrypted.png に保存
arkimg archive -i input.png -s secretdir -o encrypted.png -k <key>

# 埋め込んだファイルを抽出(ディレクトリに吐き出し)
# encrypted.png の画像に含まれる全ファイルを復号して outdir 内に保存
arkimg extract -i encrypted.png -o outdir -k <key>
```

# ライセンス
[BSL-1.0](./LICENSE)

本プログラムはBSL-1.0で提供されていますが、以下のライブラリに依存しており、それぞれのライブラリは各ライセンスのもとで提供されています。

このプロジェクトは以下のライブラリに依存しています。
- [libpng (Deimos)](https://github.com/D-Programming-Deimos/libpng): [BSL-1.0](https://github.com/D-Programming-Deimos/libpng/blob/master/dub.json)
  - [libpng](https://libpng.org/): [Zlib](https://libpng.org/pub/png/src/libpng-LICENSE.txt)
- [openssl-static](https://github.com/bildhuus/deimos-openssl-static): [Apache-2.0](https://github.com/bildhuus/deimos-openssl-static/blob/master/dub.sdl)
  - [openssl (Deimos)](https://github.com/D-Programming-Deimos/openssl) [OpenSSL or SSLeay](https://github.com/D-Programming-Deimos/openssl/blob/master/dub.sdl)
    - [OpenSSL](https://github.com/openssl/openssl): [Apache-2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt)

オプションで以下のライブラリを有効にすることが可能です。
- [jpeg-turbo(Deimos)](https://github.com/D-Programming-Deimos/jpeg-turbo) [BSL-1.0](https://github.com/D-Programming-Deimos/jpeg-turbo/blob/master/package.json)
  - [libjpeg-turbo](https://www.libjpeg-turbo.org/) [BSD 3-clause, IJG Licnese](https://github.com/libjpeg-turbo/libjpeg-turbo/blob/main/LICENSE.md)
- [libwebp(Deimos)](https://github.com/D-Programming-Deimos/libwebp) [BSD 3-clause](https://github.com/D-Programming-Deimos/libwebp/blob/master/package.json)
  - [libwebp](https://developers.google.com/speed/webp/) [BSD 3-clause](https://chromium.googlesource.com/webm/libwebp/+/refs/heads/main/COPYING)
