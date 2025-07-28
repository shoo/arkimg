# arkimg-cli
ArkImgのコマンドラインツール

## ビルド方法
```sh
dub build --root examples/arkimg_cli
```

## 使用方法
```sh
arkimg <SUBCOMMANDS> <OPTION>
```

## 主なサブコマンドと用途

| サブコマンド | 用途                           |
|:-------------|:-------------------------------|
| archive (a)  | ファイルを画像にアーカイブ     |
| extract (x)  | アーカイブからファイル抽出     |
| encrypt (e)  | ファイルを暗号化して追加       |
| decrypt (d)  | 暗号化ファイルの復号           |
| list (ls)    | アーカイブ内ファイル一覧       |
| remove (rm)  | アーカイブからファイル削除     |
| edit         | アーカイブ内ファイル情報の編集 |
| keyutil      | 暗号鍵の生成・管理             |

# サブコマンドの説明
## `archive` サブコマンド

`archive` サブコマンドは、指定されたディレクトリ内の全ファイルをアーカイブするための機能を提供します。
このサブコマンドを使用することで、複数のファイルを一つの画像に秘密データとして追加することができます。

```sh
arkimg archive <OPTIONS>
 -i      --in | * Input image file name.
 -o     --out |   Output image file name including encrypted data.
                  If not specified, the input image will be overwritten.
                  In this case, the --force flag is required.
 -s  --secret | * Directory path of the plaintext secret data.
                  Alternatively, multiple files can also be specified.
 -k     --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
         --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_IV` will be used.
                  If neither is set, a random 16-byte sequence will be prepended to the data.
                  It is recommended not to specify this for security reasons.
     --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used.
                  If neither is set, signing will not be performed.
 -f   --force |   Overwrite the output file if it already exists.
 -v --verbose |   Display verbose messages.
 -h    --help |   This help information.
```

`-i`(入力画像), `-s`(秘密情報を格納したディレクトリ), `-k`(暗号化のための共通鍵) は指定必須です。

### 鍵の指定方法

- 暗号化鍵は `-k` オプションで16桁または32桁の16進数（AES128/256）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_KEY` が利用されます。  
- IV（初期化ベクトル）は `--iv` オプションで16桁の16進数を指定できますが、未指定の場合は環境変数 `ARKIMG_CLI_IV` が利用され、どちらも未設定の場合はランダムな値が自動生成され、暗号化された秘密データと一緒にファイル内に保存されます。IVが指定された場合は暗号化ファイルの内部にはIVが含まれなくなり、復号の際にはIVを指定する必要が生じます。
- **NOTE**: セキュリティ上はIVは **未指定にする** (自動生成しファイルと同時に保存する)ことを推奨します。

### 署名の仕方

署名を行う場合は `--prvkey` オプションで秘密鍵（PEMファイルまたは32桁の16進数）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_PRIVATE_KEY` が利用されます。どちらも未設定の場合は署名は行われません。
署名を有効にすることで、アーカイブしたデータの改ざん検知が可能となります。

### サンプル

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg archive -i input.png -o output.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
```

## `extract` サブコマンド

`extract` サブコマンドは、arkimgファイルから埋め込まれたすべての秘密データを指定のディレクトリ内に抽出するためのコマンドです。
暗号化されたデータを復号し、必要に応じて署名の検証も行います。

```sh
arkimg extract <OPTIONS>
 -i        --in | * Input arkimg file name.
 -o       --out |   Output file name of secret data including arkimg.
                    If not specified, the file name of the meta information will be used.
                    And if there is no meta information, the default name will be used.
 -k       --key |   Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
           --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_IV` will be used.
                    If neither is set, a random 16-byte sequence will be prepended to the data.
                    It is recommended not to specify this for security reasons.
       --pubkey |   Public key pem file for signing or 32-byte hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_PUBLIC_KEY` will be used.
                    If neither is set, signing will not be performed.
 -p --parameter |   Specify cryptographic information in parameter spec format instead of --key and --pubkey.
 -f     --force |   Overwrite the output file if it already exists.
 -v   --verbose |   Display verbose messages.
 -h      --help |   This help information.
```

`-i`(入力画像), `-k`(暗号化のための共通鍵) または `-p`(パラメータ形式の鍵) は指定必須です。

### 鍵の指定方法

- 暗号化鍵は `-k` オプションで16桁または32桁の16進数（AES128/256）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_KEY` が利用されます。  
- IV（初期化ベクトル）は `--iv` オプションで16桁の16進数を指定できますが、未指定の場合は環境変数 `ARKIMG_CLI_IV` が利用され、どちらも未設定の場合は暗号化された秘密データと一緒にファイル内に保存されているIVが使用されます。ファイルにIVが埋め込まれていない場合は復号の際に明示的にIVを指定する必要があります。

### 署名の確認方法

`extract` サブコマンドでは、埋め込まれたデータの署名検証を行うことができます。  
署名検証を有効にするには、`--pubkey` オプションで公開鍵（PEMファイルまたは32桁の16進数）を指定してください。  
未指定の場合は環境変数 `ARKIMG_CLI_PUBLIC_KEY` が利用されます。どちらも未設定の場合は署名検証は行われません。

署名検証が有効な場合、抽出したデータが改ざんされていないことを確認できます。  
検証に失敗した場合は警告が表示され、データの信頼性が保証されません。

### サンプル

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg extract -i input.png -o output.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2
```

## `encrypt` サブコマンド

`encrypt` サブコマンドは、既存の画像ファイルに暗号化した秘密データを追加するための機能です。複数のファイルやディレクトリを指定して追加でき、コメントや追加情報（JSON形式）も付与できます。新規アーカイブ作成は `archive`、既存画像へのデータ追加やメタ情報付与は `encrypt` が適しています。

```sh
arkimg encrypt <OPTIONS>
 -i      --in | * Input image file name.
 -o     --out |   Output image file name including encrypted data.
                  If not specified, the input image will be overwritten. In this case, the -f flag is required.
 -s  --secret | * Directory path of the plaintext secret data. Alternatively, multi-files can also be specified.
 -k     --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
         --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_IV` will be used.
                  If neither is set, a random 16-byte sequence will be prepended to the data.
                  It is recommended not to specify this for security reasons.
     --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used.
                  If neither is set, signing will not be performed.
    --comment |   Specify comment messages of secret data.
      --extra |   Specify JSON file of additional values of secret data.
 -f   --force |   Overwrite the output file if it already exists.
 -v --verbose |   Display verbose messages.
 -h    --help |   This help information.
```

`-i`(入力画像), `-k`(暗号化のための共通鍵), `-s`(秘密データ) は指定必須です。  
`-o` の指定がない場合は入力画像を上書きします。その場合は `-f` を指定して上書きを許可します。

### 秘密データ追加方法

`encrypt` サブコマンドは、既存の画像ファイルに暗号化した秘密データを追加するために使用します。
複数のファイルやディレクトリを指定して追加でき、`--comment` でコメント、`--extra` で追加情報(JSON)を付与できます。

- `-i` で入力画像ファイルを指定します。
- `-s` で追加したい秘密データ（ファイルまたはディレクトリ）を指定します。
- `-k` で暗号化鍵（16/32桁の16進数）を指定します。
- 必要に応じて `--comment` や `--extra` でメタ情報を付与できます。
- `-o` で出力画像ファイル名を指定し、省略時は上書き保存となります（`-f` 必須）。

### 鍵の指定方法

- 暗号化鍵は `-k` オプションで16桁または32桁の16進数（AES128/256）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_KEY` が利用されます。  
- IV（初期化ベクトル）は `--iv` オプションで16桁の16進数を指定できますが、未指定の場合は環境変数 `ARKIMG_CLI_IV` が利用され、どちらも未設定の場合はランダムな値が自動生成され、暗号化された秘密データと一緒にファイル内に保存されます。IVが指定された場合は暗号化ファイルの内部にはIVが含まれなくなり、復号の際にはIVを指定する必要が生じます。
- **NOTE**: セキュリティ上はIVは **未指定にする** (自動生成しファイルと同時に保存する)ことを推奨します。

### 署名の仕方

署名を行う場合は `--prvkey` オプションで秘密鍵（PEMファイルまたは32桁の16進数）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_PRIVATE_KEY` が利用されます。どちらも未設定の場合は署名は行われません。
署名を有効にすることで、アーカイブしたデータの改ざん検知が可能となります。

### `archive` との違い

`archive` は新規アーカイブ作成、`encrypt` は既存画像への暗号化データ追加やメタ情報付与に適しています。

### サンプル

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg encrypt -i input.png -o output.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --comment="機密データ追加" --extra=extra.json --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
```

## `decrypt` サブコマンド

`decrypt` サブコマンドは、arkimgファイルに埋め込まれた特定の秘密データ（ファイル名またはインデックス指定）を復号・抽出するためのコマンドです。  
指定した暗号化鍵と必要に応じてIV（初期化ベクトル）や公開鍵を使い、暗号化されたデータを復号し、署名検証も行えます。  
`extract` が全データ抽出なのに対し、`decrypt` は個別データの復号・抽出に特化しています。

```sh
arkimg decrypt <OPTIONS>
 -i        --in | * Input arkimg file name.
 -o       --out |   Output file name of secret data including arkimg.
                    If not specified, the file name of the meta information will be used.
                    And if there is no meta information, the default name will be used.
 -s    --secret | * Secret data file name or index includeing arkimg.
 -k       --key |   Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
           --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_IV` will be used.
                    If neither is set, a random 16-byte sequence will be prepended to the data.
                    It is recommended not to specify this for security reasons.
       --pubkey |   Public key pem file for signing or 32-byte hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_PUBLIC_KEY` will be used.
                    If neither is set, signing will not be performed.
 -p --parameter |   Specify cryptographic information in parameter spec format instead of --key and --pubkey.
 -f     --force |   Overwrite the output file if it already exists.
 -v   --verbose |   Display verbose messages.
 -h      --help |   This help information.
```

`-i`(入力画像), `-k`(暗号化のための共通鍵) または `-p`(パラメータ形式の鍵) は指定必須です。  
`-o` の指定がない場合はメタ情報やデフォルト名を仕様します。

### 復号の流れ

`decrypt` サブコマンドは、arkimgファイルに埋め込まれた特定の秘密データ（ファイル名またはインデックス指定）を復号・抽出します。

- `-i` で入力arkimgファイルを指定します。
- `-s` で復号したい秘密データのファイル名またはインデックスを指定します。
- `-k` で暗号化鍵（16/32桁の16進数）を指定します。
- 必要に応じて `--iv` でIV（初期化ベクトル）を指定します。
- `-o` で出力ファイル名を指定し、省略時はメタ情報やデフォルト名が使われます。

### 鍵の指定方法

- 暗号化鍵は `-k` オプションで16桁または32桁の16進数（AES128/256）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_KEY` が利用されます。  
- IV（初期化ベクトル）は `--iv` オプションで16桁の16進数を指定できますが、未指定の場合は環境変数 `ARKIMG_CLI_IV` が利用され、どちらも未設定の場合は暗号化された秘密データと一緒にファイル内に保存されているIVが使用されます。ファイルにIVが埋め込まれていない場合は復号の際に明示的にIVを指定する必要があります。
- `-k`, `--iv`の代わりに `-p` によるパラメータ指定が可能です。

### 署名検証方法

`--pubkey` で公開鍵（PEMファイルまたは32桁の16進数）を指定すると、復号時に署名検証が行われます。
未指定の場合は環境変数 `ARKIMG_CLI_PUBLIC_KEY` が利用されます。どちらも未設定の場合は署名検証は行われません。

### `extract` との違い

`extract` は全データ抽出、`decrypt` は特定データのみ復号・抽出できます。

### サンプル

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg decrypt -i input.png -s=secret.txt -o=output.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2
```

## `list` サブコマンド

`list` サブコマンドは、arkimgファイル内に格納された秘密データの一覧を表示するためのコマンドです。  
ファイル名やインデックス、コメント、ダイジェスト（SHA-256）、署名、MIMEタイプ、タイムスタンプ、extra情報などを表示できます。  
`--detail` オプションで詳細表示が有効になり、`--disp-*` オプションで表示項目を個別に制御できます。  
`--pubkey` で公開鍵を指定すると、署名の検証結果も表示されます。

```sh
arkimg list <OPTIONS>
 -i            --in | * Input image file name.
 -l      --location |   Location of directory path of the secret data for list base.
 -k           --key |   Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
                        If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
               --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
                        If not specified, the environment variable `ARKIMG_CLI_IV` will be used.
                        If neither is set, a random 16-byte sequence will be prepended to the data.
                        It is recommended not to specify this for security reasons.
           --pubkey |   Public key pem file for signing or 32-byte hexadecimal format.
                        If not specified, the environment variable `ARKIMG_CLI_PUBLIC_KEY` will be used.
                        If neither is set, signing will not be performed.
 -p     --parameter |   Specify cryptographic information in parameter spec format instead of --key and --pubkey.
 -d        --detail |   Enable detailed mode. Default: false
             --json |   JSON output mode. Default: false
      --disp-digest |   Display the digest(SHA-256) of the secret data in detail mode. Default: true
        --disp-sign |   Display the  signature of the secret data in detail mode. Default: true
        --disp-mime |   Display the mime type of the secret data in detail mode. Default: true Default: true
    --disp-modified |   Display the last modified timestamp of the secret data in detail mode. Default: true
     --disp-comment |   Display the comment of the secret data in detail mode. Default: true
       --disp-extra |   Display the extra of the secret data in detail mode. Default: false
 -v       --verbose |   Display verbose messages.
 -h          --help |   This help information.
```

`-i`(入力画像), `-k`(暗号化のための共通鍵) または `-p`(パラメータ形式の鍵) は指定必須です。

### 鍵の指定方法
- 暗号化鍵は `-k` オプションで16桁または32桁の16進数（AES128/256）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_KEY` が利用されます。
- IV（初期化ベクトル）は `--iv` オプションで16桁の16進数を指定できますが、未指定の場合は環境変数 `ARKIMG_CLI_IV` が利用され、どちらも未設定の場合は暗号化された秘密データと一緒にファイル内に保存されているIVが使用されます。ファイルにIVが埋め込まれていない場合は復号の際に明示的にIVを指定する必要があります。
- `-k`, `--iv`の代わりに `-p` によるパラメータ指定が可能です。

### 署名検証方法

`--pubkey` で公開鍵（PEMファイルまたは32桁の16進数）を指定すると、復号時に署名検証が行われます。
未指定の場合は環境変数 `ARKIMG_CLI_PUBLIC_KEY` が利用されます。どちらも未設定の場合は署名検証は行われません。

### サンプル

```sh
$ arkimg list -i input.png -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --detail --disp-digest --disp-sign --disp-comment
```

## `remove` サブコマンド

`remove` サブコマンドは、arkimgファイルから指定した秘密データ（ファイル名またはインデックス）を削除するためのコマンドです。

```sh
arkimg remove <OPTIONS>
 -i      --in | * Input arkimg file name.
 -o     --out |   Output file name of secret data including arkimg.
                  If not specified, the file name of the meta information will be used.
                  And if there is no meta information, the default name will be used.
 -s  --secret | * Specify secret data file name or index includeing arkimg to remove.
 -k     --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
         --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_IV` will be used.
                  If neither is set, a random 16-byte sequence will be prepended to the data.
                  It is recommended not to specify this for security reasons.
     --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
                  If not specified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used.
                  If neither is set, signing will not be performed.
 -f   --force |   Overwrite the output file if it already exists.
 -v --verbose |   Display verbose messages.
 -h    --help |   This help information.
```

`-i`(入力画像), `-k`(暗号化のための共通鍵) または `-p`(パラメータ形式の鍵) は指定必須です。  
`-o` の指定がない場合はメタ情報やデフォルト名を仕様します。

### 説明
- `-i` で入力arkimgファイルを指定します。
- `-s` で削除したい秘密データのファイル名またはインデックスを指定します。
- `-k` で暗号化鍵（16/32桁の16進数）を指定します。
- 必要に応じて `--iv` や `--prvkey` でIVや署名鍵を指定します。
- `-o` で出力ファイル名を指定し、省略時はメタ情報やデフォルト名が使われます。

### 鍵の指定方法

- 暗号化鍵は `-k` オプションで16桁または32桁の16進数（AES128/256）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_KEY` が利用されます。  
- IV（初期化ベクトル）は `--iv` オプションで16桁の16進数を指定できますが、未指定の場合は環境変数 `ARKIMG_CLI_IV` が利用され、どちらも未設定の場合はランダムな値が自動生成され、暗号化された秘密データと一緒にファイル内に保存されます。IVが指定された場合は暗号化ファイルの内部にはIVが含まれなくなり、復号の際にはIVを指定する必要が生じます。
- **NOTE**: セキュリティ上はIVは **未指定にする** (自動生成しファイルと同時に保存する)ことを推奨します。

### 検証・新規署名の仕方

検証と署名を行う場合は `--prvkey` オプションで秘密鍵（PEMファイルまたは32桁の16進数）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_PRIVATE_KEY` が利用されます。どちらも未設定の場合は検証および署名は行われません。
検証を行うことで編集前のデータの改ざんを検知し、署名を有効にすることで、編集後のデータの改ざん検知が可能となります。

### サンプル
```sh
$ arkimg remove -i input.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790

$ arkimg remove -i input.png -s="<0>" -o output.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790
```

## `edit` サブコマンド

`edit` サブコマンドは、arkimgファイル内の秘密データの内容やメタ情報（名前、MIMEタイプ、タイムスタンプ、コメント、extra情報など）を編集するためのコマンドです。

```sh
arkimg edit <OPTIONS>
 -i        --in | * Input arkimg file name.
 -o       --out |   Output file name of secret data including arkimg.
                    If not specified, the file name of the meta information will be used.
                    And if there is no meta information, the default name will be used.
 -s    --secret | * Specify secret data file name or index includeing arkimg to edit.
 -k       --key | * Specify the common key for encryption in 16/32-byte(AES128/256) hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
           --iv |   Specify the IV for encryption in 16-byte hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_IV` will be used.
                    If neither is set, a random 16-byte sequence will be prepended to the data.
                    It is recommended not to specify this for security reasons.
       --prvkey |   Private key pem file for signing or 32-digit hexadecimal format.
                    If not specified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used.
                    If neither is set, signing will not be performed.
      --content |   Specify the file name containing the new content of the secret data.
                    Specify only if you want to modify it.
         --name |   Specify the new name of the secret data. Specify only if you want to modify it.
     --mimetype |   Specify the mime type of the secret data. Specify only if you want to modify it.
    --timestamp |   Specify the time stamp of the secret data. Specify only if you want to modify it.
      --comment |   Specify the comment messages of the secret data. Specify only if you want to modify it.
        --extra |   Specify JSON file of extra values of secret data. Specify only if you want to modify it.
 -f     --force |   Overwrite the output file if it already exists.
 -v   --verbose |   Display verbose messages.
 -h      --help |   This help information.
```

`-i`(入力画像), `-k`(暗号化のための共通鍵), `-s`(秘密データ) は指定必須です。  
`-o` の指定がない場合は入力画像を上書きします。その場合は `-f` を指定して上書きを許可します。

### 編集の仕方

- `-i` で入力arkimgファイルを指定します。
- `-s` で編集したい秘密データのファイル名またはインデックスを指定します。
- `-k` で暗号化鍵（16/32桁の16進数）を指定します。
- `--content` で新しい内容ファイルを指定できます。
- `--name`, `--mimetype`, `--timestamp`, `--comment`, `--extra` で各種メタ情報を編集可能です。
- 必要に応じて `--iv` や `--prvkey` でIVや署名鍵を指定します。
- `-o` で出力ファイル名を指定し、省略時はメタ情報やデフォルト名が使われます。

### 鍵の指定方法

- 暗号化鍵は `-k` オプションで16桁または32桁の16進数（AES128/256）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_KEY` が利用されます。  
- IV（初期化ベクトル）は `--iv` オプションで16桁の16進数を指定できますが、未指定の場合は環境変数 `ARKIMG_CLI_IV` が利用され、どちらも未設定の場合はランダムな値が自動生成され、暗号化された秘密データと一緒にファイル内に保存されます。IVが指定された場合は暗号化ファイルの内部にはIVが含まれなくなり、復号の際にはIVを指定する必要が生じます。
- **NOTE**: セキュリティ上はIVは **未指定にする** (自動生成しファイルと同時に保存する)ことを推奨します。

### 検証・新規署名の仕方

検証と署名を行う場合は `--prvkey` オプションで秘密鍵（PEMファイルまたは32桁の16進数）を指定します。未指定の場合は環境変数 `ARKIMG_CLI_PRIVATE_KEY` が利用されます。どちらも未設定の場合は検証および署名は行われません。
検証を行うことで編集前のデータの改ざんを検知し、署名を有効にすることで、編集後のデータの改ざん検知が可能となります。

# サンプル

```sh
arkimg edit -i input.png -s secret.txt -o output.png --comment "新しいコメント" -k=9DEACD01A6AA5BD438B2C7D08B5B7790
```


## `keyutil` サブコマンド

`keyutil` サブコマンドは、暗号化・復号・署名・検証に使用する各種鍵（共通鍵、IV、秘密鍵、公開鍵）の生成・管理を行うコマンドです。
AES暗号化/復号のための共通鍵生成、ランダムなIV生成、Ed25519署名・検証のための秘密鍵/公開鍵ペアの生成、それらのBase64やパラメータ形式の出力が行えます。

```sh
arkimg keyutil <OPTIONS>
 -k    --genkey |   Generate a common key for encryption/decryption.
      --keysize |   Specify size of the common key in bit length. (default=128 or 192 or 256)
        --geniv |   Specify the IV for encryption in 16-byte hexadecimal format.
                    If not specified, a random 16-byte sequence will be prepended to the data.
                    It is recommended not to specify this for security reasons.
    --genprvkey |   Generate a private key for sign.
       --prvkey |   Specify the private key in 32 bytes hexadecimal format for generating the public key.
                    If not specified, the environment variable `ARKIMG_CLI_KEY` will be used.
    --genpubkey |   Generate a public key for verifying signature.
       --base64 |   Generate keys with Base64 format (Base64 URL NoPadding).
    --parameter |   Generate keys with parameter specs format.
 -v   --verbose |   Display verbose messages.
 -h      --help |   This help information.
```

### パラメータ仕様形式について

暗号鍵と公開鍵をまとめて復号のためのパラメータ化することができます。
パラメータは以下の正規表現で表される形式です。

- `^(?:k(16|24|32))(?:i(16))?(?:p(32))?-([0-9a-zA-Z-_]+)$`
- `^([0-9a-fA-F]{32}|[0-9a-fA-F]{48}|[0-9a-fA-F]{64})(?:-([0-9a-fA-F]{32}))?(?:-([0-9a-fA-F]{64}))?$`

### 各種鍵の新規生成

- `--genkey` で共通鍵（AES用）を生成します。
  - `--keysize` で鍵サイズ（128/192/256bit）を指定可能です。
- `--genprvkey` で署名用の秘密鍵を生成します。
- `--genpubkey` で公開鍵を生成します。
- `--base64` でBase64形式で出力できます。

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg keyutil --genkey --genprvkey --genpubkey --base64
CommonKey:  nerNAaaqW9Q4ssfQi1t3kA
PrivateKey: z5rnqETxs80MzzciPEhYpuXUDmuk0UKbErazCGJh-Rk
PublicKey:  s2b3xkRkZyqe0_DSYlgH0YRESlNQlNUNMTGaHwa0T6I
```

### 共通鍵(暗号化/復号用の鍵)を作成

- `--genkey` で共通鍵（AES用）を生成します。
  - `--keysize` で鍵サイズ（128/192/256bit）を指定可能です。
  - `--base64` でBase64形式で出力できます。

```sh
$ arkimg keyutil --genkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790

$ arkimg keyutil --genkey --keysize=32
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B77909DEACD01A6AA5BD438B2C7D08B5B7790

$ arkimg keyutil --genkey --base64
CommonKey:  nerNAaaqW9Q4ssfQi1t3kA
```

### 秘密鍵(署名用の鍵)と公開鍵(検証用の鍵)を生成
- `--genprvkey` で公開鍵を生成します。
- `--genpubkey` で公開鍵を生成します。
- `--base64` でBase64形式で出力できます。

```sh
$ arkimg keyutil --genprvkey
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919

$ arkimg keyutil --genprvkey --base64
PrivateKey: z5rnqETxs80MzzciPEhYpuXUDmuk0UKbErazCGJh-Rk

$ arkimg keyutil --genprvkey --genpubkey
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg keyutil --genprvkey --genpubkey --base64
PrivateKey: z5rnqETxs80MzzciPEhYpuXUDmuk0UKbErazCGJh-Rk
PublicKey:  s2b3xkRkZyqe0_DSYlgH0YRESlNQlNUNMTGaHwa0T6I
```

### 秘密鍵から公開鍵を作成

- `--prvkey` で秘密鍵を指定します。
- `--genpubkey` で公開鍵を生成します。
  - `--base64` でBase64形式で出力できます。

```sh
$ arkimg keyutil --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919 --genpubkey
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg keyutil --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919 --genpubkey --base64
PublicKey:  s2b3xkRkZyqe0_DSYlgH0YRESlNQlNUNMTGaHwa0T6I
```

### パラメータ形式に変換

- `--key` で共通鍵を指定します。
  - `--iv` も指定可能。
- `--pubkey` で公開鍵を指定します。
- `--parameter` でパラメータ仕様形式の鍵出力を指定します。
  - `--base64` でBase64形式の鍵出力も可能です。

```sh
$ arkimg keyutil --key=9DEACD01A6AA5BD438B2C7D08B5B7790 --parameter
Parameter: 9DEACD01A6AA5BD438B2C7D08B5B7790

$ arkimg keyutil --key=9DEACD01A6AA5BD438B2C7D08B5B7790 --parameter --base64
Parameter: k16-nerNAaaqW9Q4ssfQi1t3kA

$ arkimg keyutil --key=9DEACD01A6AA5BD438B2C7D08B5B7790 --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2 --parameter
Parameter: 9DEACD01A6AA5BD438B2C7D08B5B7790-B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg keyutil --key=9DEACD01A6AA5BD438B2C7D08B5B7790 --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2 --parameter --base64
Parameter: k16p32-nerNAaaqW9Q4ssfQi1t3kLNm98ZEZGcqntPw0mJYB9GEREpTUJTVDTExmh8GtE-i

$ arkimg keyutil --key=9DEACD01A6AA5BD438B2C7D08B5B7790 --iv=7015E8F3993846605479982491495DAF --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2 --parameter
Parameter: 9DEACD01A6AA5BD438B2C7D08B5B7790-7015E8F3993846605479982491495DAF-B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg keyutil --key=9DEACD01A6AA5BD438B2C7D08B5B7790 --iv=7015E8F3993846605479982491495DAF --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2 --parameter --base64
Parameter: k16i16p32-nerNAaaqW9Q4ssfQi1t3kHAV6POZOEZgVHmYJJFJXa-zZvfGRGRnKp7T8NJiWAfRhERKU1CU1Q0xMZofBrRPog
```

# ライセンス
[BSL-1.0](../../LICENSE)

arkimg-cli は以下のライブラリに依存しています。
- [libpng (Deimos)](https://github.com/D-Programming-Deimos/libpng): [BSL-1.0](https://github.com/D-Programming-Deimos/libpng/blob/master/dub.json)
  - [libpng](https://libpng.org/): [Zlib](https://libpng.org/pub/png/src/libpng-LICENSE.txt)
- [openssl-static](https://github.com/bildhuus/deimos-openssl-static): [Apache-2.0](https://github.com/bildhuus/deimos-openssl-static/blob/master/dub.sdl)
  - [openssl (Deimos)](https://github.com/D-Programming-Deimos/openssl) [OpenSSL or SSLeay](https://github.com/D-Programming-Deimos/openssl/blob/master/dub.sdl)
    - [OpenSSL](https://github.com/openssl/openssl): [Apache-2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt)
