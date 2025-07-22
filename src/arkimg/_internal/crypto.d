module arkimg._internal.crypto;

import std.exception;
import deimos.openssl.evp;
import std.random;
package(arkimg):

/*******************************************************************************
 * 共通鍵生成
 */
immutable(ubyte)[] createCommonKey(RandomGen = Random)(size_t keySize, RandomGen rng) @safe
{
	import std.exception: assumeUnique;
	auto dat = new ubyte[keySize];
	foreach (ref e; cast(uint[])dat)
	{
		e = rng.front;
		rng.popFront();
	}
	return (() @trusted => dat.assumeUnique )();
}
/// ditto
immutable(ubyte)[] createCommonKey(size_t keySize = 16) @safe
{
	return createCommonKey(keySize, rndGen);
}
/// ditto
immutable(ubyte)[] createCommonKeyAES256(RandomGen = Random)(RandomGen rng) @safe
{
	return createCommonKey(32, rng);
}
/// ditto
immutable(ubyte)[] createCommonKeyAES256() @safe
{
	return createCommonKeyAES256(rndGen);
}

/// ditto
immutable(ubyte)[] createCommonKeyAES192(RandomGen = Random)(RandomGen rng) @safe
{
	return createCommonKey(24, rng);
}
/// ditto
immutable(ubyte)[] createCommonKeyAES192() @safe
{
	return createCommonKeyAES192(rndGen);
}

/// ditto
immutable(ubyte)[] createCommonKeyAES128(RandomGen = Random)(RandomGen rng) @safe
{
	return createCommonKey(16, rng);
}
/// ditto
immutable(ubyte)[] createCommonKeyAES128() @safe
{
	return createCommonKeyAES128(rndGen);
}


/*******************************************************************************
 * 初期ベクトル
 */
immutable(ubyte)[] createRandomIV(RandomGen = Random)(RandomGen rng) @safe
{
	import std.exception: assumeUnique;
	auto dat = new ubyte[16];
	foreach (ref e; cast(uint[])dat)
	{
		e = rng.front;
		rng.popFront();
	}
	return (() @trusted => dat.assumeUnique )();
}
/// ditto
immutable(ubyte)[] createRandomIV() @safe
{
	return createRandomIV(rndGen);
}

private void evpEnforce(int resultValue, string message, string f = __FILE__, size_t l = __LINE__)
{
	cast(void)enforce(resultValue > 0, message, f, l);
}
/*******************************************************************************
 * 暗号化
 * 
 * $(D encryptAES):
 *      IVを指定しない場合、アルゴリズムはGCMを使用しIVは自動生成。
 *      IVを指定した場合、12バイトならGCM、さもなくばCBCが使用される。
 * $(D encryptAESCBC):
 *      IVの指定必須。16Byte(128bits), 24Byte(192bits), 32Byte(256bits)のいずれかを指定する。
 * $(D encryptAESGCM):
 *      IVの指定必須。12Byteを指定する。ただし、IVはこの関数の呼び出しごとにランダムに作成すること。
 * Params:
 *      decrypted = 平文
 *      key = 共通鍵
 *      iv = 初期化ベクトル。
 * Returns:
 *      暗号文が返る。
 *      GCMの場合: IV(12 byte) ~ 暗号文(16*N byte) ~ TAG(16 byte) のバイト列が返る
 *      CBCの場合: 暗号文(16*N byte) のバイト列が返る
 */
immutable(ubyte)[] encryptAESCBC(in ubyte[] decrypted, in ubyte[] key, in ubyte[] iv) @trusted
{
	import std.exception: assumeUnique;
	// 暗号化のコンテキスト作成・破棄
	auto encctx = EVP_CIPHER_CTX_new().enforce("Cannot cretae OpenSSL cipher context.");
	scope (exit)
		encctx.EVP_CIPHER_CTX_free();
	
	// 初期化
	encctx.EVP_EncryptInit_ex(
		key.length == 32 ? EVP_aes_256_cbc() : key.length == 24 ? EVP_aes_192_cbc() : EVP_aes_128_cbc(),
		null, key.ptr, iv.ptr).evpEnforce("Cannot initialize OpenSSL cipher context.");
	
	// 暗号化されたデータの格納先として、十分な量のバッファを用意。
	// 暗号化のロジックによって異なる。
	// AES256だったら元のデータよりブロックサイズ分の16バイト大きければ十分格納できる。
	auto encrypted = new ubyte[decrypted.length + 16];
	
	// 暗号化
	// ここでは一回で暗号化を行っているが、分割することもできる。
	int encryptedLen;
	int padLen;
	encctx.EVP_EncryptUpdate(encrypted.ptr, &encryptedLen, decrypted.ptr, cast(int)decrypted.length)
		.evpEnforce("Cannot encrypt update OpenSSL cipher context.");
	// 暗号化完了
	encctx.EVP_EncryptFinal_ex(encrypted.ptr + encryptedLen, &padLen)
		.evpEnforce("Cannot finalize OpenSSL cipher context.");
	return encrypted[0 .. encryptedLen + padLen].assumeUnique();
}
/// ditto
immutable(ubyte)[] encryptAESGCM(in ubyte[] decrypted, in ubyte[] key, in ubyte[] iv) @trusted
{
	enum size_t IVLEN = 12;
	enum size_t BLKSZ = 16;
	enum size_t TAGLEN = BLKSZ;
	enforce(iv.length == IVLEN, "Cannot cretae OpenSSL cipher context.");
	// 暗号化されたデータの格納先として、十分な量のバッファを用意。
	// 暗号化のロジックによって異なる。
	// 今回の場合、IV(12byte) + AES-256-GCM暗号文(decrypted.lengthを16の倍数に切り上げ) + タグ(16バイト)
	// AES256だったら元のデータよりブロックサイズ分の12+16+16バイト大きければ十分格納できる。
	auto retBuf = new ubyte[IVLEN + decrypted.length + BLKSZ + TAGLEN];
	import std.exception: assumeUnique;
	// 暗号化のコンテキスト作成・破棄
	auto encctx = EVP_CIPHER_CTX_new().enforce("Cannot cretae OpenSSL cipher context.");
	scope (exit)
		encctx.EVP_CIPHER_CTX_free();
	
	// 初期化
	encctx.EVP_EncryptInit_ex(
		key.length == 32 ? EVP_aes_256_gcm() : key.length == 24 ? EVP_aes_192_gcm() : EVP_aes_128_gcm(),
		null, null, null).evpEnforce("Cannot initialize OpenSSL cipher context.");
	retBuf[0..IVLEN] = iv[0..IVLEN];
	encctx.EVP_CIPHER_CTX_ctrl(EVP_CTRL_GCM_SET_IVLEN, cast(int)IVLEN, null)
		.evpEnforce("Cannot create cipher context.");
	encctx.EVP_EncryptInit_ex(null, null, key.ptr, iv.ptr).evpEnforce("Cannot create cipher context.");
	
	// 暗号化
	// ここでは一回で暗号化を行っているが、分割することもできる。
	int encryptedLen;
	encctx.EVP_EncryptUpdate(&retBuf[IVLEN], &encryptedLen, decrypted.ptr, cast(int)decrypted.length)
		.evpEnforce("Cannot encrypt update OpenSSL cipher context.");
	// 暗号化完了
	int outLen;
	encctx.EVP_EncryptFinal_ex(&retBuf[IVLEN + encryptedLen], &outLen).evpEnforce("AES encryption failed.");
	auto eod = cast(int)(IVLEN + encryptedLen + outLen);
	encctx.EVP_CIPHER_CTX_ctrl(EVP_CTRL_GCM_GET_TAG,
		cast(int)TAGLEN, &retBuf[eod]).evpEnforce("AES encryption failed.");
	return retBuf[0 .. eod + TAGLEN].assumeUnique();
}
/// ditto
immutable(ubyte)[] encryptAES(in ubyte[] decrypted, in ubyte[] key, in ubyte[] iv = null) @trusted
{
	enum size_t GCMIVLEN = 12;
	enum size_t GCMBLKSZ = 16;
	enum size_t GCMTAGLEN = GCMBLKSZ;
	if (iv.length == 0)
		return encryptAESGCM(decrypted, key, createRandomIV()[0..GCMIVLEN]);
	if (iv.length == GCMIVLEN)
		return encryptAESGCM(decrypted, key, iv);
	return encryptAESCBC(decrypted, key, iv);
}

/*******************************************************************************
 * 復号
 * 
 * IVを指定しない場合、GCMを使用する。
 * GCMの場合 encrypted は IV(12 byte) ~ 暗号文(16*N byte) ~ TAG(16 byte)の構成となっている。
 * また、TAGが一致しない場合例外を発生させる。
 * 
 * Params:
 *      encrypted = 暗号文
 *      key = 共通鍵
 *      iv = 初期化ベクトル
 * Returns:
 *      平文
 */
immutable(ubyte)[] decryptAESCBC(in ubyte[] encrypted, in ubyte[] key, in ubyte[] iv) @trusted
{
	// 暗号化のコンテキスト作成・破棄
	auto decctx = EVP_CIPHER_CTX_new().enforce("Cannot cretae OpenSSL cipher context.");
	scope (exit)
		decctx.EVP_CIPHER_CTX_free();
	
	// 初期化・終了処理
	decctx.EVP_DecryptInit_ex(
		key.length == 32 ? EVP_aes_256_cbc() : key.length == 24 ? EVP_aes_192_cbc() : EVP_aes_128_cbc(),
		null, key.ptr, iv.ptr).enforce("Cannot initialize OpenSSL cipher context.");
	
	// 復号されたデータの格納先として、十分な量のバッファを用意。
	// 暗号化のロジックによって異なる。
	// AES256だったら元のデータよりブロックサイズ分の16バイト大きければ十分格納できる。
	auto decrypted = new ubyte[encrypted.length + 16];
	
	// 復号
	// ここでは一回で復号を行っているが、分割することもできる。
	int decryptedLen;
	int padLen;
	decctx.EVP_DecryptUpdate(decrypted.ptr, &decryptedLen, encrypted.ptr, cast(int)encrypted.length)
		.enforce("Cannot encrypt update OpenSSL cipher context.");
	// 復号完了
	decctx.EVP_DecryptFinal_ex(decrypted.ptr + decryptedLen, &padLen)
		.enforce("Cannot finalize OpenSSL cipher context.");
	
	return decrypted[0 .. decryptedLen + padLen].assumeUnique();
}
/// ditto
immutable(ubyte)[] decryptAESGCM(in ubyte[] encrypted, in ubyte[] key, in ubyte[] iv, in ubyte[] tag) @trusted
{
	enum size_t IVLEN = 12;
	enum size_t BLKSZ = 16;
	enum size_t TAGLEN = BLKSZ;
	// 暗号化のコンテキスト作成・破棄
	auto decctx = EVP_CIPHER_CTX_new().enforce("Cannot cretae OpenSSL cipher context.");
	scope (exit)
		decctx.EVP_CIPHER_CTX_free();
	
	// 初期化・終了処理
	decctx.EVP_DecryptInit_ex(
		key.length == 32 ? EVP_aes_256_gcm() : key.length == 24 ? EVP_aes_192_gcm() : EVP_aes_128_gcm(),
		null, null, null).evpEnforce("Cannot initialize OpenSSL cipher context.");
	decctx.EVP_CIPHER_CTX_ctrl(EVP_CTRL_GCM_SET_IVLEN, cast(int)iv.length, null)
		.evpEnforce("Cannot create cipher context.");
	decctx.EVP_DecryptInit_ex(null, null, key.ptr, iv.ptr).evpEnforce("Cannot initialize OpenSSL cipher context.");
	
	// 復号されたデータの格納先として、十分な量のバッファを用意。
	// 暗号化のロジックによって異なる。
	// AES256だったら元のデータよりブロックサイズ分の16バイト大きければ十分格納できる。
	auto decrypted = new ubyte[encrypted.length + BLKSZ];
	
	// 復号
	// ここでは一回で復号を行っているが、分割することもできる。
	int decryptedLen;
	decctx.EVP_DecryptUpdate(decrypted.ptr, &decryptedLen, encrypted.ptr, cast(int)encrypted.length)
		.enforce("Cannot encrypt update OpenSSL cipher context.");
	decctx.EVP_CIPHER_CTX_ctrl(EVP_CTRL_GCM_SET_TAG, cast(int)tag.length, cast(ubyte*)tag.ptr)
		.evpEnforce("OpenSSL AES decryption failed.");
	
	// 復号完了
	ubyte[16] outData;
	int outLen;
	decctx.EVP_DecryptFinal_ex(outData.ptr, &outLen)
		.enforce("Cannot finalize OpenSSL cipher context.");
	
	return decrypted[0 .. decryptedLen + outLen].assumeUnique();
}

/// ditto
immutable(ubyte)[] decryptAES(in ubyte[] encrypted, in ubyte[] key, in ubyte[] iv = null) @trusted
{
	enum size_t GCMIVLEN = 12;
	enum size_t GCMBLKSZ = 16;
	enum size_t GCMTAGLEN = GCMBLKSZ;
	if (iv.length == 0)
		return decryptAESGCM(encrypted[GCMIVLEN..$-GCMTAGLEN], key, encrypted[0..GCMIVLEN], encrypted[$-GCMTAGLEN..$]);
	if (iv.length == GCMIVLEN)
		return decryptAESGCM(encrypted[0..$-GCMTAGLEN], key, iv, encrypted[$-GCMTAGLEN..$]);
	if (iv.length == GCMIVLEN + GCMTAGLEN)
		return decryptAESGCM(encrypted, key, iv[0..GCMIVLEN], iv[GCMIVLEN..$]);
	return decryptAESCBC(encrypted, key, iv);
}

@system unittest
{
	import std.string;
	auto msg = "Hello, world!".representation;
	auto key = createCommonKey();
	auto enc = encryptAES(msg, key);
	auto dec = decryptAES(enc, key);
	assert(dec == msg);
}

@system unittest
{
	import std.string;
	auto msg = "Hello, world!".representation;
	auto key = createCommonKey();
	auto iv = createRandomIV();
	auto enc = encryptAESCBC(msg, key, iv);
	auto dec = decryptAESCBC(enc, key, iv);
	assert(dec == msg);
}

/*******************************************************************************
 * 秘密鍵作成
 */
immutable(ubyte)[] createPrivateKeyEd25519() @trusted
{
	import std.exception: enforce, assumeUnique;
	auto ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_ED25519, null).enforce("Cannot cretae OpenSSL private key.");
	scope (exit)
		ctx.EVP_PKEY_CTX_free();
	ctx.EVP_PKEY_keygen_init();
	EVP_PKEY* pkey;
	ctx.EVP_PKEY_keygen(&pkey).enforce("Cannot cretae OpenSSL private key.");
	
	// 秘密鍵をDER形式に保存
	auto derlen = i2d_PrivateKey(pkey, null).enforce("Cannot cretae OpenSSL private key.");
	auto derPrvKey = new ubyte[derlen];
	auto pBuf = derPrvKey.ptr;
	i2d_PrivateKey(pkey, &pBuf).enforce("Cannot cretae OpenSSL private key.");
	return derPrvKey.assumeUnique;
}

/*******************************************************************************
 * 公開鍵作成
 */
immutable(ubyte)[] createPublicKeyEd25519(in ubyte[] prvKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import std.exception: enforce, assumeUnique;
	auto pBuf = prvKey.ptr;
	auto pkey = d2i_PrivateKey(EVP_PKEY_ED25519, null, cast(const(ubyte)**)&pBuf, cast(int)prvKey.length)
		.enforce("Cannot create public key with specified private key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	
	// 公開鍵をDER形式に保存
	auto derlen = i2d_PUBKEY(pkey, null).enforce("Cannot create public key with specified private key.");
	auto derPubKey = new ubyte[derlen];
	auto pBufPub = derPubKey.ptr;
	i2d_PUBKEY(pkey, &pBufPub);
	return derPubKey.assumeUnique;
}

/*******************************************************************************
 * 鍵形式変換
 */
string convertEd25519PrivateKeyDERToPEM(in ubyte[] prvKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import deimos.openssl.pem;
	import std.exception: enforce, assumeUnique;
	// 秘密鍵を読み込み
	auto pBuf = prvKey.ptr;
	auto pkey = d2i_PrivateKey(EVP_PKEY_ED25519, null, cast(const(ubyte)**)&pBuf, cast(int)prvKey.length)
		.enforce("Cannot convert specified private key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	// BIOメモリバッファを作成
	auto mem = BIO_new(BIO_s_mem()).enforce("Cannot convert specified private key.");
	scope (exit)
		mem.BIO_free();
	// PEM形式で秘密鍵を書き込む
	PEM_write_bio_PrivateKey(mem, pkey, null, null, 0, null, null).enforce("Cannot convert specified private key.");
	
	// 文字列の取り出し
	ubyte* pemData = null;
	auto pemLen = BIO_get_mem_data(mem, &pemData);
	auto pemStr = new char[pemLen];
	pemStr[0..pemLen] = cast(char[])pemData[0..pemLen];
	return pemStr.assumeUnique;
}

/// ditto
immutable(ubyte)[] convertEd25519PrivateKeyPEMToDER(string prvKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import deimos.openssl.pem;
	import std.exception: enforce, assumeUnique;
	// PEM形式の文字列をBIOメモリストリームに読み込む
	auto bio = BIO_new_mem_buf(cast(void*)prvKey.ptr, cast(int)prvKey.length)
		.enforce("Cannot cretae specified private key.");
	scope (exit)
		bio.BIO_free();
	auto pkey = PEM_read_bio_PrivateKey(bio, null, null, null);
	scope (exit)
		pkey.EVP_PKEY_free();
	
	// 秘密鍵をDER形式に保存
	auto derlen = i2d_PrivateKey(pkey, null).enforce("Cannot cretae specified private key.");
	auto derPrvKey = new ubyte[derlen];
	auto pBuf = derPrvKey.ptr;
	i2d_PrivateKey(pkey, &pBuf).enforce("Cannot cretae specified private key.");
	return derPrvKey.assumeUnique;
}

/// ditto
immutable(ubyte)[] convertEd25519PrivateKeyDERToRaw(in ubyte[] prvKey) @trusted
{
	import deimos.openssl.evp;
	import std.exception: enforce, assumeUnique;
	// 秘密鍵を読み込み
	auto pBuf = prvKey.ptr;
	auto pkey = d2i_PrivateKey(EVP_PKEY_ED25519, null, cast(const(ubyte)**)&pBuf, cast(int)prvKey.length)
		.enforce("Cannot convert specified private key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	// 生の鍵を取り出す
	size_t len;
	EVP_PKEY_get_raw_private_key(pkey, null, &len).enforce("Cannot convert specified private key.");
	auto prvKeyRaw = new ubyte[len];
	EVP_PKEY_get_raw_private_key(pkey, prvKeyRaw.ptr, &len).enforce("Cannot convert specified private key.");
	return prvKeyRaw.assumeUnique;
}

/// ditto
immutable(ubyte)[] convertEd25519PrivateKeyRawToDER(in ubyte[] prvKey) @trusted
{
	import deimos.openssl.evp;
	import std.exception: enforce, assumeUnique;
	// 生の秘密鍵を読み込み
	auto pkey = EVP_PKEY_new_raw_private_key(EVP_PKEY_ED25519, null, prvKey.ptr, prvKey.length)
		.enforce("Cannot convert specified private key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	// 秘密鍵をDER形式に保存
	auto derlen = i2d_PrivateKey(pkey, null).enforce("Cannot cretae specified private key.");
	auto derPrvKey = new ubyte[derlen];
	auto pBuf = derPrvKey.ptr;
	i2d_PrivateKey(pkey, &pBuf).enforce("Cannot cretae specified private key.");
	return derPrvKey.assumeUnique;
}

/// ditto
string convertEd25519PublicKeyDERToPEM(in ubyte[] pubKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import deimos.openssl.pem;
	import std.exception: enforce, assumeUnique;
	// 公開鍵を読み込み
	auto pBuf = pubKey.ptr;
	auto pkey = d2i_PUBKEY(null, cast(const(ubyte*)*)&pBuf, cast(int)pubKey.length)
		.enforce("Cannot convert specified public key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	// BIOメモリバッファを作成
	auto mem = BIO_new(BIO_s_mem()).enforce("Cannot convert specified public key.");
	scope (exit)
		mem.BIO_free();
	// PEM形式で公開鍵を書き込む
	PEM_write_bio_PUBKEY(mem, pkey).enforce("Cannot convert specified public key.");
	
	// 文字列の取り出し
	ubyte* pemData = null;
	auto pemLen = BIO_get_mem_data(mem, &pemData);
	auto pemStr = new char[pemLen];
	pemStr[0..pemLen] = cast(char[])pemData[0..pemLen];
	return pemStr.assumeUnique;
}

/// ditto
immutable(ubyte)[] convertEd25519PublicKeyPEMToDER(in char[] pubKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import deimos.openssl.pem;
	import std.exception: enforce, assumeUnique;
	// PEM形式の文字列をBIOメモリストリームに読み込む
	auto bio = BIO_new_mem_buf(cast(void*)pubKey.ptr, cast(int)pubKey.length)
		.enforce("Cannot cretae specified private key.");
	scope (exit)
		bio.BIO_free();
	auto pkey = PEM_read_bio_PUBKEY(bio, null, null, null);
	scope (exit)
		pkey.EVP_PKEY_free();
	
	// 公開鍵をDER形式に保存
	auto derlen = i2d_PUBKEY(pkey, null).enforce("Cannot create public key with specified private key.");
	auto derPubKey = new ubyte[derlen];
	auto pBufPub = derPubKey.ptr;
	i2d_PUBKEY(pkey, &pBufPub);
	return derPubKey.assumeUnique;
}

/// ditto
immutable(ubyte)[] convertEd25519PublicKeyDERToRaw(in ubyte[] pubKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import std.exception: enforce, assumeUnique;
	// 公開鍵を読み込み
	auto pBuf = pubKey.ptr;
	auto pkey = d2i_PUBKEY(null, cast(const(ubyte*)*)&pBuf, cast(int)pubKey.length)
		.enforce("Cannot convert specified public key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	// 生の鍵を取り出す
	size_t len;
	EVP_PKEY_get_raw_public_key(pkey, null, &len).enforce("Cannot convert specified public key.");
	auto pubKeyRaw = new ubyte[len];
	EVP_PKEY_get_raw_public_key(pkey, pubKeyRaw.ptr, &len).enforce("Cannot convert specified public key.");
	return pubKeyRaw.assumeUnique;
}

/// ditto
immutable(ubyte)[] convertEd25519PublicKeyRawToDER(in ubyte[] pubKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import std.exception: enforce, assumeUnique;
	// 生の秘密鍵を読み込み
	auto pkey = EVP_PKEY_new_raw_public_key(EVP_PKEY_ED25519, null, pubKey.ptr, pubKey.length)
		.enforce("Cannot convert specified public key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	// 秘密鍵をDER形式に保存
	auto derlen = i2d_PUBKEY(pkey, null).enforce("Cannot cretae specified public key.");
	auto derPubKey = new ubyte[derlen];
	auto pBuf = derPubKey.ptr;
	i2d_PUBKEY(pkey, &pBuf).enforce("Cannot cretae specified public key.");
	return derPubKey.assumeUnique;
}

/*******************************************************************************
 * 署名
 */
immutable(ubyte)[] signEd25519(in ubyte[] message, in ubyte[] prvKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	import std.exception: enforce, assumeUnique;
	// 秘密鍵で署名
	auto pBuf = prvKey.ptr;
	auto pkey = d2i_PrivateKey(EVP_PKEY_ED25519, null, cast(const(ubyte)**)&pBuf, cast(int)prvKey.length)
		.enforce("Cannot sign with specified private key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	auto ctxSign = EVP_MD_CTX_new();
	scope (exit)
		ctxSign.EVP_MD_CTX_free();
	ctxSign.EVP_DigestSignInit(null, null, null, pkey);
	
	// 署名のサイズを取得してバッファを作成
	size_t signLen;
	ctxSign.EVP_DigestSign(null, &signLen, null, 0);
	auto signData = new ubyte[signLen];
	
	// 署名のためのハッシュ計算
	ctxSign.EVP_DigestSign(signData.ptr, &signLen, message.ptr, message.length);
	return signData[0..signLen].assumeUnique;
}

/*******************************************************************************
 * 検証
 */
bool verifyEd25519(in ubyte[] sign, in ubyte[] message, in ubyte[] pubKey) @trusted
{
	import deimos.openssl.evp;
	import deimos.openssl.x509;
	// 公開鍵で検証
	auto pBuf = pubKey.ptr;
	auto pkey = d2i_PUBKEY(null, cast(const(ubyte*)*)&pBuf, cast(int)pubKey.length)
		.enforce("Cannot verify with specified public key.");
	scope (exit)
		pkey.EVP_PKEY_free();
	auto ctxVerify = EVP_MD_CTX_new();
	scope (exit)
		ctxVerify.EVP_MD_CTX_free();
	
	// 署名のためのハッシュ計算
	ctxVerify.EVP_DigestVerifyInit(null, null, null, pkey);
	auto verifyResult = ctxVerify.EVP_DigestVerify(sign.ptr, sign.length, cast(ubyte*)message.ptr, message.length);
	return verifyResult != 0;
}


@system unittest
{
	import std.exception: enforce, assumeUnique;
	import std.base64;
	import std.stdio;
	
	auto prvKey = createPrivateKeyEd25519();
	auto prvKeyPem = convertEd25519PrivateKeyDERToPEM(prvKey);
	auto prvKeyDer = convertEd25519PrivateKeyPEMToDER(prvKeyPem);
	assert(prvKey == prvKeyDer);
	auto prvKeyRaw = convertEd25519PrivateKeyDERToRaw(prvKey);
	auto prvKeyDer2 = convertEd25519PrivateKeyRawToDER(prvKeyRaw);
	assert(prvKey == prvKeyDer2);
	
	auto pubKey = createPublicKeyEd25519(prvKey);
	auto pubKeyPem = convertEd25519PublicKeyDERToPEM(pubKey);
	auto pubKeyDer = convertEd25519PublicKeyPEMToDER(pubKeyPem);
	assert(pubKey == pubKeyDer);
	auto pubKeyRaw = convertEd25519PublicKeyDERToRaw(pubKey);
	auto pubKeyDer2 = convertEd25519PublicKeyRawToDER(pubKeyRaw);
	assert(pubKey == pubKeyDer2);
	
	auto sign = signEd25519(cast(ubyte[])"testdata", prvKey);
	auto res = verifyEd25519(sign, cast(ubyte[])"testdata", pubKey);
	assert(res);
}
