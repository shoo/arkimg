/*******************************************************************************
 * ArkImg API
 * 
 * 画像処理ライブラリのAPIを提供するモジュールです。
 * このモジュールでは、ArkImgを継承した各クラスの基本的な操作を行うための関数や型を定義します。
 */
module arkimg.api;

import std.json;


/*******************************************************************************
 * ArkImg 秘密データ添付画像アーカイバー / encryption data image archiver
 * 
 * 画像ファイルに暗号化された秘密データを添付します。
 * 秘密データは複数添付することが可能です。
 * 秘密データはAES暗号化が施されます。 $(D Arkimg.setKey) により共通鍵を付与します。
 * ベースとなる画像ファイルは $(D Arkimg.baseImage) により設定/取得します。
 * 
 * # メタデータ
 * - `items[].sign` 署名/検証: (Optional) ファイル作成者が公開する公開鍵で検証することのできる署名を付与します。
 *      署名用のアルゴリズムはEd25519です。
 *      署名する場合はEd25519秘密鍵を使用し、検証する場合はEd25519公開鍵を使用して検証します。
 * - `items[].mime` MIME: (Optional) 暗号化されたデータのファイルタイプを示すMIMEデータを付与します。
 * - `items[].name` ファイル名: (Optional) 暗号化されたデータのファイル名を付与します。
 * - `items[].modified` 更新時刻: (Optional) ファイルの最終更新時刻を付与します。
 * - `items[].comment` コメント: (Optional) ファイルに追加のコメントを付与します。
 */
interface ArkImg
{
	/***************************************************************************
	 * 画像読込/保存 / Image load/save
	 */
	void load(in ubyte[] binary);
	/// ditto
	immutable(ubyte)[] save() const;
	/***************************************************************************
	 * 暗号化/復号のための共通鍵を設定 / Set common key for encryption/decryption
	 */
	void setKey(in ubyte[] commonKey, in ubyte[] iv = null);
	/***************************************************************************
	 * 全データにまとめて署名 / Signing for all secret data
	 * 
	 * - メタデータの `items[*].sign` をすべての添付データに対して作成する
	 */
	void sign(in ubyte[] prvKey);
	/// ditto
	void sign(size_t idx, in ubyte[] prvKey);
	/***************************************************************************
	 * 全データの署名をまとめて検証 / Verifying for all secret data
	 * 
	 * - メタデータの `items[*].sign` が存在して、その署名が prvKey の公開鍵で検証できるかどうかを確認する
	 */
	bool verify(in ubyte[] pubKey) const;
	/// ditto
	bool verify(size_t idx, in ubyte[] pubKey) const;
	/***************************************************************************
	 * 署名を持っているか確認 / Check existing signature
	 * 
	 * - メタデータの `items[*].sign` が存在するかどうかを確認する
	 */
	bool hasSign() const;
	/// ditto
	bool hasSign(size_t idx) const;
	/***************************************************************************
	 * メタデータを設定/取得 / Set/Get metadata
	 */
	void metadata(in JSONValue metadata);
	/// ditto
	JSONValue metadata() const;
	/***************************************************************************
	 * ベース画像設定/取得 / Set/Get base image
	 */
	void baseImage(in ubyte[] binary, string mimeType = null);
	/// ditto
	immutable(ubyte)[] baseImage(string mimeType = null);
	/***************************************************************************
	 * 添付するデータを追加(平文で指定)
	 * 
	 * - nameを指定した場合、メタデータの `items[*].name` に名前をセットする
	 * - mimeTypeを指定した場合、メタデータの `items[*].mime` にデータ種別をセットする
	 * - prvKeyを指定した場合、メタデータの `items[*].sign` に署名する
	 */
	void addSecretItem(in ubyte[] binary, string name = null, string mimeType = null, in ubyte[] prvKey = null);
	/***************************************************************************
	 * 添付するデータを全削除 / Clear all secret data
	 */
	void clearSecretItems();
	/***************************************************************************
	 * 添付されている暗号化されたデータの数 / Count of secret data
	 */
	size_t getSecretItemCount() const;
	/***************************************************************************
	 * 添付されている復号されたデータ / Get decrypted secret data
	 */
	immutable(ubyte)[] getDecryptedItem(size_t idx) const;
	/***************************************************************************
	 * 添付されている暗号化されたデータ / Get encrypted secret data
	 */
	immutable(ubyte)[] getEncryptedItem(size_t idx) const;
}
