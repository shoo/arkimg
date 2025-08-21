<template>
  <div class="my-4 flex flex-row items-center">
    <label for="common-key" class="mr-1 flex-shrink-0 w-16 block text-gray-700 text-sm font-bold text-right">暗号鍵:</label>
    <input type="text" id="common-key" v-model="aesKeyInput" @input="updateAesKey" placeholder="暗号鍵" class="shadow appearance-none border rounded flex-1 py-1 px-2 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />
    <button @click="generateAesKey" class="ml-2 flex-shrink-0 w-24 bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 px-2 rounded focus:outline-none focus:shadow-outline" type="button">生成</button>
    <p v-if="validationErrors.aesKey" class="text-red-500 text-xs italic">{{ validationErrors.aesKey }}</p>
  </div>

  <div class="mb-4 flex flex-row items-center">
    <label for="private-key" class="mr-1 flex-none w-16 block text-gray-700 text-sm font-bold text-right">秘密鍵:</label>
    <input type="text" id="private-key" v-model="privateKeyInput" @input="updatePrivateKey" placeholder="署名用 秘密鍵" class="shadow appearance-none border rounded flex-1 py-1 px-2 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />
    <p v-if="validationErrors.privateKey" class="text-red-500 text-xs italic">{{ validationErrors.privateKey }}</p>
  </div>

  <div class="mb-4 flex flex-row items-center">
    <label for="public-key" class="mr-1 flex-none w-16 block text-gray-700 text-sm font-bold text-right">公開鍵:</label>
    <input type="text" id="public-key" v-model="publicKeyInput" @input="updatePublicKey" placeholder="署名検証用 公開鍵" class="shadow appearance-none border rounded flex-1 py-1 px-2 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />
    <p v-if="validationErrors.publicKey" class="text-red-500 text-xs italic">{{ validationErrors.publicKey }}</p>
  </div>
</template>

<script setup lang="ts">
import { createRandomKey } from '@/arkimg/utils';
import type { CryptoContext } from '@/types/crypto'
import type { NotificationManager } from '@/types/ui'
import { decodeKeyInfo, encodeBase64URLNoPadding } from '@/utils/misc';
import { ref, inject, watch } from 'vue';

const cryptoContext = inject<CryptoContext>('cryptoContext')!;
const notificationManager = inject<NotificationManager>('notificationManager')!;

const aesKeyInput = ref('');
const privateKeyInput = ref('');
const publicKeyInput = ref('');
const validationErrors = ref({
  aesKey: '',
  privateKey: '',
  publicKey: ''
});

const validateAesKey = (key: string) => {
  if (!key) {
    return '暗号鍵を入力してください';
  }
  try {
    const keyBytes = decodeKeyInfo(key);
    const keyLength = keyBytes.length * 8;
    if (![128, 192, 256].includes(keyLength)) {
      return '暗号鍵長は128/192/256bitである必要があります';
    }
  } catch (e) {
    return '暗号鍵は128/192/256bitのものをBase64またはHexDecimalで指定してください';
  }
  return '';
}

const validatePrivateKey = (key: string) => {
  if (!key) {
    return '秘密鍵を入力してください';
  }
  try {
    const keyBytes = decodeKeyInfo(key);
    if (keyBytes.length != 32) {
      return '秘密鍵長は256bit(32Byte)である必要があります';
    }
  } catch (e) {
    return '公開鍵はEd25519のRaw形式で32バイトのものをBase64またはHexDecimalで指定してください';
  }
  return ''
}

const validatePublicKey = (key: string) => {
  if (key === '') {
    return '公開鍵を入力してください';
  }
  try {
    const keyBytes = decodeKeyInfo(key);
    if (keyBytes.length != 64) {
      return '公開鍵長は512bit(64Byte)である必要があります';
    }
  } catch (e) {
    return '公開鍵はEd25519のRaw形式で64バイトのものをBase64またはHexDecimalで指定してください';
  }
  return '';
}

const updateAesKey = () => {
  validationErrors.value.aesKey = validateAesKey(aesKeyInput.value);
  if (validationErrors.value.aesKey) {
    cryptoContext.key.value = null;
    return;
  }
  try {
    cryptoContext.key.value = decodeKeyInfo(aesKeyInput.value);
  } catch (e) {
    cryptoContext.key.value = null;
  }
}

const updatePrivateKey = () => {
  validationErrors.value.privateKey = validatePrivateKey(privateKeyInput.value);
  if (validationErrors.value.privateKey) {
    cryptoContext.prvkey.value = null;
    return
  }
  try {
    cryptoContext.prvkey.value = decodeKeyInfo(privateKeyInput.value);
  } catch (e) {
    cryptoContext.prvkey.value = null;
  }
}

const updatePublicKey = () => {
  validationErrors.value.publicKey = validatePublicKey(publicKeyInput.value);
  if (validationErrors.value.publicKey) {
    cryptoContext.pubkey.value = null;
    return;
  }

  try {
    cryptoContext.pubkey.value = decodeKeyInfo(publicKeyInput.value);
  } catch (e) {
    cryptoContext.pubkey.value = null;
  }
}

const generateAesKey = async () => {
  const key = await createRandomKey(16);
  aesKeyInput.value = encodeBase64URLNoPadding(key);
  updateAesKey();
  notificationManager.notify('AES鍵を生成しました', 'success');
}

watch(() => cryptoContext.key?.value, (newValue) => {
  if (newValue) {
    aesKeyInput.value = encodeBase64URLNoPadding(newValue);
  } else {
    aesKeyInput.value = '';
  }
});

watch(() => cryptoContext.pubkey?.value, (newValue) => {
  if (newValue) {
    publicKeyInput.value = encodeBase64URLNoPadding(newValue);
  } else {
    publicKeyInput.value = '';
  }
});

watch(() => cryptoContext.prvkey?.value, (newValue) => {
  if (newValue) {
    privateKeyInput.value = encodeBase64URLNoPadding(newValue);
  } else {
    privateKeyInput.value = '';
  }
});
</script>

<style scoped>
</style>
