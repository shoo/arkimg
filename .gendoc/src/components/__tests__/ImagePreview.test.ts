import { describe, it, expect, } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import ImagePreview from '../ImagePreview.vue';

// Helper function to create a mock image file from base64
function createImageFile(base64Data: string, fileName: string = 'test.png'): File {
	const byteCharacters = atob(base64Data);
	const byteNumbers = new Array(byteCharacters.length);
	for (let i = 0; i < byteCharacters.length; i++) {
		byteNumbers[i] = byteCharacters.charCodeAt(i);
	}
	const byteArray = new Uint8Array(byteNumbers);
	return new File([byteArray], fileName, { type: 'image/png' });
}

// Helper function to convert File to Uint8Array
async function fileToUint8Array(file: File): Promise<Uint8Array> {
	return new Promise((resolve, reject) => {
		const reader = new FileReader();
		reader.onload = () => resolve(new Uint8Array(reader.result as ArrayBuffer));
		reader.onerror = reject;
		reader.readAsArrayBuffer(file);
	});
}

describe('ImagePreview.vue', () => {
	const base64Image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
	const imageFile = createImageFile(base64Image);
	
	it('displays the image when valid decryptedImageData is provided', async () => {
		const wrapper = shallowMount(ImagePreview, {
			props: {
				decryptedImageData: await fileToUint8Array(imageFile),
			},
		});
		
		// Wait for the image URL to be created
		await wrapper.vm.$nextTick();
		
		const imgElement = wrapper.find('img.object-contain');
		expect(imgElement.exists()).toBe(true);
		expect(imgElement.attributes('src')?.startsWith('blob://')).toBe(true);
		expect(imgElement.attributes('alt') ?? false).toBe(false);
		expect(wrapper.find('.text-base').exists()).toBe(false);
	});

	it('displays the image when valid decryptedImageData with fileName are provided', async () => {
		const wrapper = shallowMount(ImagePreview, {
			props: {
				decryptedImageData: await fileToUint8Array(imageFile),
				fileName: 'test.png',
			},
		});
		
		// Wait for the image URL to be created
		await wrapper.vm.$nextTick();
		
		const imgElement = wrapper.find('img.object-contain');
		expect(imgElement.exists()).toBe(true);
		expect(imgElement.attributes('src')?.startsWith('blob://')).toBe(true);
		expect(imgElement.attributes('alt')).toBe('test.png');
		expect(wrapper.find('.text-base').exists()).toBe(false);
		
		expect((wrapper.vm as any).imageUrl).toBe(imgElement.attributes('src'));
		wrapper.unmount();
		
		expect((wrapper.vm as any).imageUrl).toBe(null);
	});

	it('displays "Failed to display image." when an error occurs during URL creation', async () => {
		const wrapper = shallowMount(ImagePreview, {
			props: {
				// Providing an invalid type to trigger an error in Blob creation
				decryptedImageData: 'not a Uint8Array' as any,
			},
		});
		
		await wrapper.vm.$nextTick();
		
		expect(wrapper.find('.text-red-500').text()).toBe('Failed to display image.');
		expect(wrapper.find('img').exists()).toBe(false);
	});

	it('displays "No Image Data" when decryptedImageData is an empty Uint8Array', async () => {
		const wrapper = shallowMount(ImagePreview, {
			props: {
				decryptedImageData: null as unknown as Uint8Array,
			},
		});

		await wrapper.vm.$nextTick();

		expect(wrapper.find('.text-gray-400').text()).toBe('No Image Data');
		expect(wrapper.find('img').exists()).toBe(false);
	});
});
