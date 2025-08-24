import { describe, it, expect, vi } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import CryptoKeyInput from '@/components/CryptoKeyInput.vue';
import type { CryptoContext } from '@/types/crypto';
import { encodeBase64URLNoPadding } from '@/utils/misc';
import { ref } from 'vue';

// Mock necessary dependencies
const mockCryptoContext: CryptoContext = {
	key: ref(null),
	iv: ref(null),
	prvkey: ref(null),
	pubkey: ref(null),
	isKeyValid: () => { return true; }
};
const mockNotificationManager = {
	notify: vi.fn(),
};

describe('CryptoKeyInput.vue', () => {
	it('renders correctly with initial empty values', () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});

		expect(wrapper.find('input[type="text"]').exists()).toBe(true);
		expect(wrapper.find('button').text()).toBe('生成');
		expect(wrapper.find('label[for="common-key"]').text()).toBe('暗号鍵:');
		expect(wrapper.find('label[for="private-key"]').text()).toBe('秘密鍵:');
		expect(wrapper.find('label[for="public-key"]').text()).toBe('公開鍵:');
	})

	it('updates AES key when input changes', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});

		const aesKeyInput = wrapper.find('input[id="common-key"]');
		const validAesKey = encodeBase64URLNoPadding(new Uint8Array(16)); // 128-bit key
		await aesKeyInput.setValue(validAesKey);
		await wrapper.vm.$nextTick();

		expect(mockCryptoContext.key.value).toEqual(new Uint8Array(Buffer.from(validAesKey, 'base64url')));
		expect(wrapper.find('.text-red-500').exists()).toBe(false);
	})

	it('shows error for invalid AES key length', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});
		
		const aesKeyInput = wrapper.find('input[id="common-key"]');
		const invalidAesKey = encodeBase64URLNoPadding(new Uint8Array(10)); // Invalid length
		await aesKeyInput.setValue(invalidAesKey);
		await wrapper.vm.$nextTick();
		
		expect(wrapper.find('.text-red-500').text()).toContain('暗号鍵長は128/192/256bitである必要があります');
		expect(mockCryptoContext.key.value).toBeNull();
	});

	it('shows error for invalid AES key format', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});

		const aesKeyInput = wrapper.find('input[id="common-key"]');
		const invalidFormatKey = 'ほげほげ-invalid-base64';
		await aesKeyInput.setValue(invalidFormatKey);
		await wrapper.vm.$nextTick();

		expect(wrapper.find('.text-red-500').text()).toContain('暗号鍵は128/192/256bitのものをBase64またはHexDecimalで指定してください');
		expect(mockCryptoContext.key.value).toBeNull();
	});

	it('updates private key when input changes', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});

		const privateKeyInput = wrapper.find('input[id="private-key"]');
		const validPrivateKey = encodeBase64URLNoPadding(new Uint8Array(32)); // 256-bit private key
		await privateKeyInput.setValue(validPrivateKey);
		await wrapper.vm.$nextTick();

		expect(mockCryptoContext.prvkey.value).toEqual(new Uint8Array(Buffer.from(validPrivateKey, 'base64url')));
		expect(wrapper.find('.text-red-500').exists()).toBe(false);
	});

	it('shows error for invalid private key length', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});
		
		const privateKeyInput = wrapper.find('input[id="private-key"]');
		const invalidPrivateKey = encodeBase64URLNoPadding(new Uint8Array(31)); // Invalid length
		await privateKeyInput.setValue(invalidPrivateKey);
		await wrapper.vm.$nextTick();
		
		expect(wrapper.find('input[id="private-key"] + .text-red-500').text()).toContain('秘密鍵長は256bit(32Byte)である必要があります');
		expect(mockCryptoContext.prvkey.value).toBeNull();
	});
	
	it('updates public key when input changes', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});
		
		const publicKeyInput = wrapper.find('input[id="public-key"]');
		const validPublicKey = encodeBase64URLNoPadding(new Uint8Array(64)); // 512-bit public key
		await publicKeyInput.setValue(validPublicKey);
		await wrapper.vm.$nextTick();
		
		expect(mockCryptoContext.pubkey.value).toEqual(new Uint8Array(Buffer.from(validPublicKey, 'base64url')));
		expect(wrapper.find('.text-red-500').exists()).toBe(false);
	})
	
	it('shows error for invalid public key length', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});
		
		const publicKeyInput = wrapper.find('input[id="public-key"]');
		const invalidPublicKey = encodeBase64URLNoPadding(new Uint8Array(63)); // Invalid length
		await publicKeyInput.setValue(invalidPublicKey);
		await wrapper.vm.$nextTick();
		
		expect(wrapper.find('input[id="public-key"] + .text-red-500').text()).toContain('公開鍵長は512bit(64Byte)である必要があります');
		expect(mockCryptoContext.pubkey.value).toBeNull();
	});

	it('generates AES key and updates input', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});

		const generateButton = wrapper.find('button');
		await generateButton.trigger('click');
		await wrapper.vm.$nextTick();

		const aesKeyInput = wrapper.find('input[id="common-key"]').element as HTMLInputElement;
		expect(aesKeyInput.value).not.toBe('');
		expect(mockNotificationManager.notify).toHaveBeenCalledWith('AES鍵を生成しました', 'success');
		const key = mockCryptoContext.key.value;
		expect(key).not.toBeNull();
		expect(key?.length).toBe(16);
	})

	it('watches cryptoContext.key and updates local input', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});
		
		const newAesKey = encodeBase64URLNoPadding(new Uint8Array(16));
		mockCryptoContext.key.value = new Uint8Array(Buffer.from(newAesKey, 'base64url'));
		await wrapper.vm.$nextTick();
		
		const input = wrapper.find('input[id="common-key"]').element as HTMLInputElement;
		expect(input.value).toBe(newAesKey);
	});

	it('watches cryptoContext.pubkey and updates local input', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});
		const input = wrapper.find("#public-key").element as HTMLInputElement;
		const newPublicKey = encodeBase64URLNoPadding(new Uint8Array(64));
		mockCryptoContext.pubkey.value = new Uint8Array(Buffer.from(newPublicKey, 'base64url'));
		await wrapper.vm.$nextTick();
		
		expect(input.value).toBe(newPublicKey);
	})
	
	it('watches cryptoContext.prvkey and updates local input', async () => {
		const wrapper = shallowMount(CryptoKeyInput, {
			global: {
				provide: {
					cryptoContext: mockCryptoContext,
					notificationManager: mockNotificationManager,
				},
			},
		});
		
		const input = wrapper.find("#private-key").element as HTMLInputElement;
		const newPrivateKey = encodeBase64URLNoPadding(new Uint8Array(32));
		mockCryptoContext.prvkey.value = new Uint8Array(Buffer.from(newPrivateKey, 'base64url'));
		await wrapper.vm.$nextTick();
		
		expect(input.value).toBe(newPrivateKey);
	})
})
