import { describe, it, expect, vi } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import TextPreview from '../TextPreview.vue';

describe('TextPreview.vue', () => {
	it('displays decrypted text correctly when decryptedText is provided', async () => {
		vi.useFakeTimers();
		const testText = 'This is a test.';
		const wrapper = shallowMount(TextPreview, {
			props: {
				decryptedText: testText,
			},
		});
		
		// 最初はスピン
		expect(wrapper.find('.animate-spin').exists()).toBe(true);
		
		vi.advanceTimersByTime(10);
		await wrapper.vm.$nextTick();
		
		const preElement = wrapper.find('pre');
		expect(preElement.exists()).toBe(true);
		expect(preElement.text()).toBe(testText);
		// 表示ししたあとスピンはなくなる
		expect(wrapper.find('.animate-spin').exists()).toBe(false);
		
		vi.useRealTimers();
	});

	it('displays "表示できる内容がありません。" when decryptedText is an empty string', async () => {
		vi.useFakeTimers();
		const wrapper = shallowMount(TextPreview, {
			props: {
				decryptedText: '',
			},
		});
		
		vi.advanceTimersByTime(10);
		await wrapper.vm.$nextTick();
		
		const noContentMessage = wrapper.find('.text-gray-500.text-lg.text-center');
		expect(noContentMessage.exists()).toBe(true);
		expect(noContentMessage.text()).toContain('表示できる内容がありません。');
		vi.useRealTimers();
	});
});
