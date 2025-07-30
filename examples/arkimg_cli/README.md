# arkimg-cli
Command-line tool for ArkImg

## Build Instructions
```sh
dub build --root examples/arkimg_cli
```

## Usage
```sh
arkimg <SUBCOMMANDS> <OPTION>
```

## Subcommands and Usage

| Subcommand   | Description                       |
|:-------------|:----------------------------------|
| archive (a)  | Archive files into an image       |
| extract (x)  | Extract files from the archive    |
| encrypt (e)  | Add encrypted files               |
| decrypt (d)  | Decrypt encrypted files           |
| list (ls)    | List files in the archive         |
| remove (rm)  | Remove files from the archive     |
| edit         | Edit file metadata in the archive |
| keyutil      | Generate/manage encryption keys   |

# Subcommand Descriptions
## `archive` Subcommand

The `archive` subcommand allows you to archive all files within a specified directory.
With this subcommand, multiple files can be embedded into a single image as hidden data.

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

`-i`(input image), `-s`(directory including secret data) and `-k`(common key of encryption) are required.

### Key Specification

- Use `-k` to provide a 16/32-digit hexadecimal encryption key. If omitted, `ARKIMG_CLI_KEY` is used.  
- The IV can be specified with `--iv`, or falls back to `ARKIMG_CLI_IV`. If neither is set, a random IV is generated and stored with the encrypted data. If you specify an IV manually, it will not be included in the encrypted file. You must provide it manually when decrypting.
- **NOTE**: For better security, it is recommended to **not specify an IV manually**, so a random one is used and saved with the file.

### Signing
To enable signing, specify a private key using `--prvkey` (PEM file or 32-digit hex). If omitted, `ARKIMG_CLI_PRIVATE_KEY` is used.
If signing is enabled, tamper detection is possible for the archive.

### Sample

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg archive -i input.png -o output.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
```

## `extract` Subcommand

The `extract` subcommand extracts all embedded secret data from an ArkImg file to a specified directory.
It can also decrypt encrypted data and verify signatures if necessary.

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

`-i`(input image), `-k`(encryption key) or `-p` (parameter spec) are required.

### Key Specification

- Use `-k` to provide a 16/32-digit hexadecimal encryption key. If omitted, `ARKIMG_CLI_KEY` is used.  
- The IV can be specified with `--iv`, or falls back to `ARKIMG_CLI_IV`. If neither is set, a random IV is generated and stored with the encrypted data. If you specify an IV manually, it will not be included in the encrypted file. You must provide it manually when decrypting.
- **NOTE**: For better security, it is recommended to **not specify an IV manually**, so a random one is used and saved with the file.

### Signature Verification

The `extract` subcommand can verify digital signatures embedded with the data.  
To enable signature verification, specify the public key with --pubkey (PEM file or 32-digit hex). If omitted, `ARKIMG_CLI_PUBLIC_KEY` is used. If neither is set, verification will not be performed.

If verification is enabled, it checks whether the data has been tampered with.
If the verification fails, a warning will be displayed, and the integrity of the data cannot be guaranteed.

### Sample

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg extract -i input.png -o output.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2
```

## `encrypt` Subcommands

The `encrypt` subcommand adds encrypted secret data to an existing image file.
You can specify multiple files or directories to embed, along with optional metadata such as comments or additional info in JSON format.
While `archive` is used for creating a new archive, `encrypt` is better suited for adding encrypted data or metadata to an existing image.

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

`-i`(input image), `-k`(encryption key) and `-s`(secret data) are required.
If `-o` is omitted, the input image is overwritten, and `-f` must be used to confirm.

### How to Add Secret Data

Use the `encrypt` subcommand to embed encrypted secret data into an existing image file.
Optionally, you can add metadata using `--comment` and `--extra` (JSON format).

- Use `-i` to specify the input image file.
- Use `-s` to specify the secret data (file or directory) you want to add.
- Use `-k` to specify the encryption key.
- If `-o` is omitted, the input image will be overwritten. In that case, use `-f` to allow overwriting.

### Key Specification

- Use `-k` to provide a 16/32-digit hexadecimal encryption key. If omitted, `ARKIMG_CLI_KEY` is used.  
- The IV can be specified with `--iv`, or falls back to `ARKIMG_CLI_IV`. If neither is set, a random IV is generated and stored with the encrypted data. If you specify an IV manually, it will not be included in the encrypted file. You must provide it manually when decrypting.
- **NOTE**: For better security, it is recommended to **not specify an IV manually**, so a random one is used and saved with the file.

### Signing

To enable signing, specify a private key using `--prvkey` (PEM file or 32-digit hex). If omitted, `ARKIMG_CLI_PRIVATE_KEY` is used.
If signing is enabled, tamper detection is possible for the archive.

### Difference from `archive`

`archive` creates a new archive image with embedded encrypted data, and `encrypt` adds encrypted data or metadata to an existing image.

### Sample

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg encrypt -i input.png -o output.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --comment="Add secret data" --extra=extra.json --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
```

## `decrypt` Subcommand

The `decrypt` subcommand decrypts and extracts a specific secret data item embedded in an ArkImg file.
It uses the specified encryption key and, if necessary, an IV and a public key for signature verification.
Unlike `extract`, which retrieves all data, `decrypt` is tailored for extracting a specific file by name or index.

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
`-i`(input image), `-s`(secret data to decrypt), and `-k`(decryption key) or `-p`(parameter spec keys) are required unless using parameter format.
If `-o` is not specified, the file name of the meta information will be used.

### Decryption

To `decrypt` a specific piece of embedded data:

- Use `-i` to specify the input ArkImg file.
- Use `-s` to specify the file name or index of the secret data to decrypt.
- Use `-k` to provide the encryption key.
- Optionally, use `--iv` to specify an IV if not stored in the file.
- Use `-o` to set the output filename. If omitted, a name is auto-assigned from metadata or default name.

### Key Specification

- Use `-k` to provide a 16/32-digit hexadecimal encryption key (AES128/256). If omitted, `ARKIMG_CLI_KEY` environment variable is used.
- The IV can be specified with `--iv` option as a 16-digit hexadecimal value. If omitted, `ARKIMG_CLI_IV` environment variable is used. If neither is set, the IV stored with the encrypted data in the file will be used. If no IV is embedded in the file, you must explicitly specify the IV during decryption.
- Instead of `-k` and `--iv`, you can use `-p` to specify parameters in parameter specification format.

### Signature Verification

If `--pubkey` is specified, the embedded signature will be verified during decryption.
If omitted, the environment variable `ARKIMG_CLI_PUBLIC_KEY` is used. If neither is set, verification is skipped.

### Difference from `extract`

`extract` retrieves all embedded data, while `decrypt` can decrypt and extract only specific data.


### Sample

```sh
$ arkimg keyutil --genkey --genprvkey --genpubkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790
PrivateKey: CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg decrypt -i input.png -s=secret.txt -o=output.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --pubkey=B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2
```

## `list` Subcommand

The `list` subcommand displays a list of secret data items stored in an ArkImg file.
It can show metadata such as file name, index, comment, digest (SHA-256), signature, MIME type, timestamp, and extra information.
You can enable detailed mode using the `--detail` option, and customize visible fields using `--disp-*` options.
If a public key is specified by `--pubkey`, signature verification results will also be shown.

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
`-i` and `-k` (or a `-p` parameter-style key) are required.

### Key Specification

- Use `-k` to provide a 16/32-digit hexadecimal encryption key (AES128/256). If omitted, `ARKIMG_CLI_KEY` environment variable is used.
- The IV can be specified with `--iv` option as a 16-digit hexadecimal value. If omitted, `ARKIMG_CLI_IV` environment variable is used. If neither is set, the IV stored with the encrypted data in the file will be used. If no IV is embedded in the file, you must explicitly specify the IV during decryption.
- Instead of `-k` and `--iv`, you can use `-p` to specify parameters in parameter specification format.

### Signature Verification

If `--pubkey` is specified with a public key (PEM file or 32-digit hexadecimal string), signature verification will be performed during decryption.
If omitted, the environment variable `ARKIMG_CLI_PUBLIC_KEY` is used. If neither is set, signature verification will not be performed.

### Sample

```sh
$ arkimg list -i input.png -k=9DEACD01A6AA5BD438B2C7D08B5B7790 --detail --disp-digest --disp-sign --disp-comment
```

## `remove` Subcommand

The remove subcommand deletes a specified secret data item (by file name or index) from an ArkImg file.

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


`-i`(input image), `-s`(secret data to decrypt), and `-k`(decryption key) or `-p`(parameter spec keys) are required unless using parameter format.
If `-o` is not specified, the file name of the meta information will be used.

### Explanation
- Use `-i` to specify the input ArkImg file.
- Use `-s` to specify the file name or index of the embedded data to remove.
- Use `-k` to provide the encryption key.
- Optionally, use `--iv` or `--prvkey` if needed for validation or re-signing.
- Use `-o` to set the output image file name. If omitted, the original will be used with metadata or default.

### Key Specification

- Use `-k` to provide a 16/32-digit hexadecimal encryption key. If omitted, `ARKIMG_CLI_KEY` is used.
- The IV can be specified with `--iv`, or falls back to `ARKIMG_CLI_IV`. If neither is set, a random IV is generated and stored with the encrypted data. If you specify an IV manually, it will not be included in the encrypted file. You must provide it manually when decrypting.
- **NOTE**: For better security, it is recommended to **not specify an IV manually**, so a random one is used and saved with the file.

### Verification and Signing

To perform verification and signing, specify a private key (PEM file or 32-digit hexadecimal string) using the `--prvkey` option. If unspecified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used. If neither is set, verification and signing will not be performed.
Verification enables tamper detection of the data before modification, while signing ensures tamper detection capability for the archive after editing.

### Sample
```sh
$ arkimg remove -i input.png -s=secret.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790

$ arkimg remove -i input.png -s="<0>" -o output.txt -k=9DEACD01A6AA5BD438B2C7D08B5B7790
```

## `edit` Subcommand

The `edit` subcommand modifies the content or metadata of a specific secret data item embedded in an ArkImg file.
You can update the file name, MIME type, timestamp, comment, extra fields, or even replace the content itself.

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

`-i`(input image), `-k`(encryption key) and `-s`(secret data) are required.
If `-o` is omitted, the input image is overwritten, and `-f` must be used to confirm.

### How to edit secret data

To modify a secret data item:
- Use `-i` to specify the input ArkImg file.
- Use `-s` to select the embedded file (by name or index).
- Use `-k` to provide the encryption key.
- Use `--`content to replace the embedded file.
- Use metadata options such as `--name`, `--mimetype`, `--timestamp`, `--comment`, or `--extra` as needed.
- Use `-o` to specify the output file name. If omitted, the original name or metadata-derived name will be used.

### Key Specification

- Use `-k` to provide a 16/32-digit hexadecimal encryption key. If omitted, `ARKIMG_CLI_KEY` is used.  
- The IV can be specified with `--iv`, or falls back to `ARKIMG_CLI_IV`. If neither is set, a random IV is generated and stored with the encrypted data. If you specify an IV manually, it will not be included in the encrypted file. You must provide it manually when decrypting.
- **NOTE**: For better security, it is recommended to **not specify an IV manually**, so a random one is used and saved with the file.

### Verification and Signing

To perform verification and signing, specify a private key (PEM file or 32-digit hexadecimal string) using the `--prvkey` option. If unspecified, the environment variable `ARKIMG_CLI_PRIVATE_KEY` will be used. If neither is set, verification and signing will not be performed.
Verification enables tamper detection of the data before modification, while signing ensures tamper detection capability for the archive after editing.

### Sample

```sh
arkimg edit -i input.png -s secret.txt -o output.png --comment "New comment" -k=9DEACD01A6AA5BD438B2C7D08B5B7790
```


## `keyutil` Subcommand

The `keyutil` subcommand is used to generate and manage keys for encryption, decryption, signing, and verification.
You can generate AES common keys, random IV, Ed25519 verifying/signing private/public key pairs, and output them in various formats including Base64 or parameter specs.

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

### About Parameter Specification Format

You can bundle an encryption key and public key together into a single parameter string.
Parameters follow a format represented by the following regular expression.

- `^((?:[0-9a-zA-Z-_]{22})|(?:[0-9a-zA-Z-_]{32})|(?:[0-9a-zA-Z-_]{43}))$`
  - This format is the common key encoded in Base64URL (NoPadding).
- `^(?:k(16|24|32))(?:i(16))?(?:p(32))?-([0-9a-zA-Z-_]+)$`
- `^([0-9a-fA-F]{32}|[0-9a-fA-F]{48}|[0-9a-fA-F]{64})(?:-([0-9a-fA-F]{32}))?(?:-([0-9a-fA-F]{64}))?$`


### Generating Keys

- `--genkey` generates a common key (for AES).
  - `--keysize` can specify the key size (128/192/256 bits).
- `--genprvkey` generates a private key for signing.
- `--genpubkey` generates a public key.
- `--base64` outputs keys in Base64 format.

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
### Generating a Common Key (for encryption/decryption)

- `--genkey` generates a common key (for AES).
  - `--keysize` allows specifying the key size (128/192/256 bits).
  - `--base64` outputs the key in Base64 format.

```sh
$ arkimg keyutil --genkey
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B7790

$ arkimg keyutil --genkey --keysize=32
CommonKey:  9DEACD01A6AA5BD438B2C7D08B5B77909DEACD01A6AA5BD438B2C7D08B5B7790

$ arkimg keyutil --genkey --base64
CommonKey:  nerNAaaqW9Q4ssfQi1t3kA
```

### Generating Private Key (for signing) and Public Key (for verification)
- Use `--genprvkey` to generate a private key.
- Use `--genpubkey` to generate a public key.
- Use `--base64` to output the keys in Base64 format.

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

### Generate a Public Key from a Private Key

- Use `--prvkey` to specify the private key.
- Use `--genpubkey` to generate the public key.
  - Use `--base64` to output it in Base64 format.

```sh
$ arkimg keyutil --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919 --genpubkey
PublicKey:  B366F7C64464672A9ED3F0D2625807D184444A535094D50D31319A1F06B44FA2

$ arkimg keyutil --prvkey=CF9AE7A844F1B3CD0CCF37223C4858A6E5D40E6BA4D1429B12B6B3086261F919 --genpubkey --base64
PublicKey:  s2b3xkRkZyqe0_DSYlgH0YRESlNQlNUNMTGaHwa0T6I
```

### Convert to Parameter Format

- Use `--key` to specify a common key.
  - `--iv` can also be specified.
- Use `--pubkey` to specify a public key.
- Use `--parameter` to specify key output in parameter specification format.
  - Use `--base64` to output it in Base64 format.

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

# Licnese
[BSL-1.0](../../LICENSE)

arkimg-cli depends on the following libraries:
- [libpng (Deimos)](https://github.com/D-Programming-Deimos/libpng): [BSL-1.0](https://github.com/D-Programming-Deimos/libpng/blob/master/dub.json)
  - [libpng](https://libpng.org/): [Zlib](https://libpng.org/pub/png/src/libpng-LICENSE.txt)
- [openssl-static](https://github.com/bildhuus/deimos-openssl-static): [Apache-2.0](https://github.com/bildhuus/deimos-openssl-static/blob/master/dub.sdl)
  - [openssl (Deimos)](https://github.com/D-Programming-Deimos/openssl) [OpenSSL or SSLeay](https://github.com/D-Programming-Deimos/openssl/blob/master/dub.sdl)
    - [OpenSSL](https://github.com/openssl/openssl): [Apache-2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt)
