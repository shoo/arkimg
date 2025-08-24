# ArkImg
[![GitHub tag](https://img.shields.io/github/tag/shoo/arkimg.svg?maxAge=86400)](#)
[![CI Status](https://github.com/shoo/arkimg/actions/workflows/main.yml/badge.svg)](https://github.com/shoo/arkimg/actions/workflows/main.yml)
[![downloads](https://img.shields.io/dub/dt/arkimg.svg?cacheSeconds=3600)](https://code.dlang.org/packages/arkimg)
[![BSL-1.0](http://img.shields.io/badge/license-BSL--1.0-blue.svg?style=flat)](./LICENSE)
[![codecov](https://codecov.io/gh/shoo/arkimg/branch/main/graph/badge.svg)](https://codecov.io/gh/shoo/arkimg)
[![Document](http://img.shields.io/badge/API_Document-purple.svg?style=flat)](https://shoo.github.io/arkimg)
[![WebUI](http://img.shields.io/badge/WebUI-green.svg?style=flat)](https://shoo.github.io/arkimg/webui.html)

ArkImg is a library that allows you to embed encrypted data into image files (PNG, JPEG, BMP, WebP).
It can be used to hide and securely store or transfer confidential information or files within images.

We provide both a command-line interface and a web interface as sample implementations included with the library.

---

[<img src="./.gendoc/public/icon.svg" width="32" />](https://shoo.github.io/arkimg/webui.html)  
[Web interface is here.](https://shoo.github.io/arkimg/webui.html)

---

Note: Beware of viruses. Always ensure that the data originates from a trusted source. To verify authenticity, it's recommended to include a digital signature using a private key during data creation. When extracting secret data, verify the signature using the public key of the distribution source.


## Features

- Embed and extract data in PNG/JPEG/BMP/WebP images
- Data encryption using AES
- Signing and verification using Ed25519
- Support for embedding multiple files and metadata

# How to Use as a Library
## Usage

```sh
dub add arkimg
```

## Sample Code

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
  - `void load(in ubyte[] binary)`: Load image file data
  - `immutable(ubyte)[] save() const`: Save data to image file
  - `void setKey(in ubyte[] commonKey)`: Set the common key for encryption/decryption
  - `void sign(in ubyte[] prvKey)`: Sign all data
  - `bool verify(in ubyte[] pubKey) const`: Verify the signature of all data
  - `bool hasSign() const`: Check if the image has a signature
  - `void metadata(in JSONValue metadata)`: Set metadata
  - `JSONValue metadata() const`: Get metadata
  - `void baseImage(in ubyte[] binary, string mimeType = "image/bmp")`: Set base image
  - `immutable(ubyte)[] baseImage(string mimeType = "image/bmp")`: Get base image
  - `void addSecretItem(in ubyte[] binary, string name = null, string mimeType = null, in ubyte[] prvKey = null)`: Add attached data (in plaintext)
  - `void clearSecretItems()`: Remove all attached data
  - `size_t getSecretItemCount() const`: Get the number of attached encrypted data
  - `immutable(ubyte)[] getDecryptedItem(size_t idx) const`: Get decrypted attached data
  - `immutable(ubyte)[] getEncryptedItem(size_t idx) const`: Get encrypted attached data
- ArkBmp: ArkImg
- ArkPng: ArkImg
- ArkJpg: ArkImg
- ArkWebp: ArkImg
- Helper functions
  - `string mimeType(string filename)`: Get MIME type from filename
  - `immutable(ubyte)[] createCommonKey(size_t keySize = 32)`: Generate a common key
  - `immutable(ubyte)[] createRandomIV()`: Generate an initialization vector (usually not used)
  - `immutable(ubyte)[] createPrivateKey()`: Generate a private key for signing
  - `immutable(ubyte)[] createPublicKey(in ubyte[] prvKey)`: Generate a public key for verification
  - `ArkImg loadImage(immutable(ubyte)[] binary, string mimeType = "image/png", in ubyte[] commonKey, in ubyte[] iv = null)`: Load image from byte array
  - `ArkImg loadImage(string filename, in ubyte[] commonKey = null, in ubyte[] iv = null)`: Load image from filename
  - `immutable(ubyte)[] saveImage(ArkImg img, string mimeType = "image/png", in ubyte[] commonKey, in ubyte[] iv = null)`: Save image to byte array (save to file separately)

# File Structure Specifications
### PNG
Data is included at any position, but usually after the IDAT chunk (image data):
- eDAt chunk: **Encrypted data body**. There may be multiple per file.
- eMDt chunk: **Metadata**. 0 or 1 per file.

Note: Some browsers or viewers may not be able to handle PNG images with chunks after the IDAT chunk.
*PNG custom chunk handling:* eDAt and eMDt chunks are treated as PNG custom chunks. Some viewers may not support PNG files with custom chunks after IDAT.

### JPG
Data is included after the EOI (end marker) in the following structure:

`[SOI] | [Segment 1] | [Segment 2] | ... | [EOI] | [Encrypted Chunk 1] | [Encrypted Chunk 2] ... ` <br/>
`[Encrypted Chunk]`: `[Type: 4 bytes] | [Length: 4 bytes] | [Data: N bytes]`

- Encrypted chunk: multiple
  - Signature: 4 bytes (LittleEndian)
  - Data length: 4 bytes LittleEndian unsigned 32-bit integer (number of bytes in data N)
  - Data: N bytes

There may be multiple encrypted chunks.
Each encrypted chunk contains a signature, a data length, and variable-length data.
- Signature `['E', 'D', 'A', 'T']`: Data is **encrypted data body**. There may be multiple per file. 4 bytes: [0x45, 0x44, 0x41, 0x54] as "EDAT" in ASCII codes.
- Signature `['E', 'M', 'D', 'T']`: Data is **metadata**. 0 or 1 per file. 4 bytes: [0x45, 0x4d, 0x44, 0x54] as "EMDT" in ASCII codes.


Note: Some browsers or viewers may not be able to handle JPG images with data after the EOI marker.
*JPEG chunk handling:* Encrypted chunks are not JPEG segment format. Custom segment format (APPn segment) cannot insert data after EOI, and is limited to 64KB, so an original chunk format is used. Some viewers may not support JPEG files with data after EOI.

### BMP
Data is included after the end of the pixel data specified by the image size in the BMP info header, in the following structure:

`[Bitmap File Header] | [Bitmap Info Header] | [Color Pallete] | [Pixel Data] | [Encrypted Chunk 1] | [Encrypted Chunk 2] ... ` <br/>
`[Encrypted Chunk]`: `[Signature: 4 bytes] | [Length: 4 bytes] | [Data: N bytes]`

- Encrypted chunk: multiple
  - Signature: 4 bytes
  - Data length: 4 bytes LittleEndian unsigned 32-bit integer (number of bytes in data N)
  - Data: N bytes

There may be multiple encrypted chunks.
Each encrypted chunk contains a signature, a data length, and variable-length data.
- Signature `['E', 'D', 'A', 'T']`: Data is **encrypted data body**. There may be multiple per file. 4 bytes: [0x45, 0x44, 0x41, 0x54] as "EDAT" in ASCII codes.
- Signature `['E', 'M', 'D', 'T']`: Data is **metadata**. 0 or 1 per file. 4 bytes: [0x45, 0x4d, 0x44, 0x54] as "EMDT" in ASCII codes.

### WebP
Custom chunks are typically included after the base image pixel data, such as VP8, VP8L, VP8X, ANIM, ANMF, etc., using the following structure:
- Encrypted chunk: multiple
  - Chunk FourCC: 4 bytes
  - Chunk size: 4 bytes LittleEndian unsigned 32-bit integer (number of bytes in data N)
  - Payload: N bytes

`[Webp File Header] | [Chunks] | ... | [Encrypted Chunk 1] | [Encrypted Chunk 2] ... ` <br/>
`[Encrypted Chunk]`: `[FourCC: 4 bytes] | [Chunk Size: 4 bytes] | [Data: N bytes]`

There may be multiple encrypted chunks.
Each encrypted chunk contains a FourCC, a chunk size, and variable-length payload.
- FourCC `['E', 'D', 'A', 'T']`: Data is **encrypted data body**. There may be multiple per file. 4 bytes: [0x45, 0x44, 0x41, 0x54] as "EDAT".
- FourCC `['E', 'M', 'D', 'T']`: Data is **metadata**. 0 or 1 per file. 4 bytes: [0x45, 0x4d, 0x44, 0x54] as "EMDT".

*WebP custom chunk handling:* EMDT and EDAT chunks are treated as WebP custom chunks.

### Encrypted Data Body
Encrypted byte array in one of the following formats:
- GCM encryption mode
  - Start: IV (12 bytes)
  - Data: AES-encrypted data
  - End: Authentication data (16 bytes)
- CBC encryption mode (no IV specified/IV included in data)
  - Start: IV (16 bytes)
  - Data: AES-encrypted data
- CBC encryption mode (IV specified/IV not included in data)
  - Data: AES-encrypted data

Decrypting the encrypted data body yields the confidential information as a byte array.

### Metadata
Encrypted byte array in one of the following formats:
- GCM encryption mode
  - Start: IV (12 bytes)
  - Data: AES-encrypted data
  - End: Authentication data (16 bytes)
- CBC encryption mode (no IV specified/IV included in data)
  - Start: IV (16 bytes)
  - Data: AES-encrypted data
- CBC encryption mode (IV specified/IV not included in data)
  - Data: AES-encrypted data

Decrypting the metadata yields the following JSON data:
- `(root)`: Object
- `(root).items`: Array, optional
- `(root).items[*]`: Object / Metadata for the Nth encrypted data
- `(root).items[*].name`: String, optional / Filename of the encrypted data
- `(root).items[*].mime`: String, optional / File type of the encrypted data
- `(root).items[*].sign`: String, optional / 32-byte Ed25519 signature data encoded in Base64URLNoPadding
- `(root).items[*].modified`: String, optional / File modification date (ISO8601/UTC) format `YYYY-MM-DDTHH:mm:SS.SSSZ`
- `(root).items[*].comment`: String, optional / Any comment
- `(root).items[*].(any)`: Any, optional / Any additional data per encrypted data
- `(root).(any)`: Any, optional / Any additional data for the entire file

Example JSON for metadata:
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

# How to Use the Command Line Tool

## Main Features

- Embed secret data into images (archive)
- Extract embedded data (extract)
- Encrypt and decrypt data
- Edit, delete, and list embedded data
- Key generation, signing, and verification

## Build

```sh
cd examples/arkimg_cli
dub build
```

## Usage

### Command Line Examples

```sh
# Generate a key
# CommonKey:  F25B09DF39C113BD5F81871ED12221C2
# The generated key will be output. Use this CommonKey for <key> below.
$ arkimg keyutil --genkey

# Embed a file into an image (file specified)
# Encrypt and embed secret.png into input.png, save as encrypted.png
arkimg encrypt -i input.png -s secret.png -o encrypted.png -k <key>

# Extract an embedded file (file specified)
# Decrypt and extract secret.png from encrypted.png, save as decrypted.png
arkimg decrypt -i encrypted.png -s secret.png -o decrypted.png -k <key>

# Embed all files in a directory into an image
# Encrypt and embed all files in secretdir into input.png, save as encrypted.png
arkimg archive -i input.png -s secretdir -o encrypted.png -k <key>

# Extract all embedded files to a directory
# Decrypt and extract all files from encrypted.png, save to outdir
arkimg extract -i encrypted.png -o outdir -k <key>
```


# License
[BSL-1.0](./LICENSE)

This program is provided under the BSL-1.0 license, but depends on the following libraries, each provided under their respective licenses.

This project depends on the following libraries:
- [libpng (Deimos)](https://github.com/D-Programming-Deimos/libpng): [BSL-1.0](https://github.com/D-Programming-Deimos/libpng/blob/master/dub.json)
  - [libpng](https://libpng.org/): [Zlib](https://libpng.org/pub/png/src/libpng-LICENSE.txt)
- [openssl-static](https://github.com/bildhuus/deimos-openssl-static): [Apache-2.0](https://github.com/bildhuus/deimos-openssl-static/blob/master/dub.sdl)
  - [openssl (Deimos)](https://github.com/D-Programming-Deimos/openssl) [OpenSSL or SSLeay](https://github.com/D-Programming-Deimos/openssl/blob/master/dub.sdl)
    - [OpenSSL](https://github.com/openssl/openssl): [Apache-2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt)

Optionally, the following libraries can be enabled:
- [jpeg-turbo(Deimos)](https://github.com/D-Programming-Deimos/jpeg-turbo) [BSL-1.0](https://github.com/D-Programming-Deimos/jpeg-turbo/blob/master/package.json)
  - [libjpeg-turbo](https://www.libjpeg-turbo.org/) [BSD 3-clause, IJG License](https://github.com/libjpeg-turbo/libjpeg-turbo/blob/main/LICENSE.md)
- [libwebp(Deimos)](https://github.com/D-Programming-Deimos/libwebp) [BSD 3-clause](https://github.com/D-Programming-Deimos/libwebp/blob/master/package.json)
  - [libwebp](https://developers.google.com/speed/webp/) [BSD 3-clause](https://chromium.googlesource.com/webm/libwebp/+/refs/heads/main/COPYING)
