import { describe, it, expect, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { markRaw } from 'vue';
import Modal from '../Modal.vue';


describe('Modal.vue', () => {
	it('renders the modal with default options when options are provided', async () => {
		vi.useFakeTimers();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					confirmText: 'Confirm',
					cancelText: 'Cancel',
					onConfirm: vi.fn(),
					onCancel: vi.fn(),
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});
		
		await wrapper.vm.$nextTick();

		expect(wrapper.find('.fixed').exists()).toBe(true);
		expect(wrapper.find('h2').text()).toBe('Test Title');
		expect(wrapper.find('.text-gray-700').text()).toBe('Test Message');
		expect(wrapper.find('button').text()).toBe('Cancel');
		expect(wrapper.findAll('button')[1].text()).toBe('Confirm');
	});
	
	it('closes the modal when the overlay is clicked', async () => {
		const mockCancel = vi.fn();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					onCancel: mockCancel,
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		const overlay = wrapper.find('.fixed');
		await overlay.trigger('click');

		expect(mockCancel).toHaveBeenCalledTimes(1);
		expect(wrapper.emitted('close')?.length).toBe(1); // close event is emitted by handleCancel after onCancel
	  });

	it('calls onConfirm and closes when the confirm button is clicked', async () => {
		const mockConfirm = vi.fn();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					confirmText: 'Confirm',
					onConfirm: mockConfirm,
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		const confirmButton = wrapper.findAll('button')[1];
		await confirmButton.trigger('click');

		expect(mockConfirm).toHaveBeenCalledTimes(1);
		expect(wrapper.emitted('close')?.length).toBe(1);
	});

	it('calls onCancel and closes when the cancel button is clicked', async () => {
		const mockCancel = vi.fn();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					cancelText: 'Cancel',
					onCancel: mockCancel,
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		const cancelButton = wrapper.find('button');
		await cancelButton.trigger('click');

		expect(mockCancel).toHaveBeenCalledTimes(1);
		expect(wrapper.emitted('close')?.length).toBe(1);
	});
	
	it('closes the modal when the Escape key is pressed', async () => {
		const mockCancel = vi.fn();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					onCancel: mockCancel,
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});
		
		await wrapper.vm.$nextTick();
		
		// Simulate the keydown event
		const event = new KeyboardEvent('keydown', { key: 'Escape' });
		document.dispatchEvent(event);
		
		await wrapper.vm.$nextTick();
		
		expect(mockCancel).toHaveBeenCalledTimes(1);
		expect(wrapper.emitted('close')?.length).toBe(1);
	});

	it('does not close the modal if isProcessing is true when Escape key is pressed', async () => {
		const mockCancel = vi.fn();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					onCancel: mockCancel,
					onConfirm: async () => {
						// Simulate processing
						(wrapper.vm as any).isProcessing = true;
						await new Promise(resolve => setTimeout(resolve, 50));
						(wrapper.vm as any).isProcessing = false;
					},
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		// Trigger confirm to set isProcessing to true
		const confirmButton = wrapper.findAll('button')[1];
		await confirmButton.trigger('click');

		// Simulate the keydown event while processing
		const event = new KeyboardEvent('keydown', { key: 'Escape' });
		document.dispatchEvent(event);

		expect(mockCancel).not.toHaveBeenCalled();
		expect(wrapper.emitted('close')).toBeUndefined();
	});
	
	it('handles component rendering correctly', async () => {
		const TestComponent = {
			template: '<div>Custom Component</div>',
			props: { someProp: 'value' },
		};
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: '',
					message: '',
					component: markRaw(TestComponent),
					props: { someProp: 'value' },
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		expect(wrapper.findComponent(TestComponent).exists()).toBe(true);
		expect(wrapper.findComponent(TestComponent).props('someProp')).toBe('value');
	});

	it('renders only confirm button if cancelText is null', async () => {
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: '',
					confirmText: 'OK',
					cancelText: null,
					onConfirm: vi.fn(),
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		const buttons = wrapper.findAll('button');
		expect(buttons.length).toBe(1);
		expect(buttons[0].text()).toBe('OK');
	});

	it('renders only cancel button if confirmText is null', async () => {
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: '',
					confirmText: null,
					cancelText: 'Cancel',
					onCancel: vi.fn(),
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		const buttons = wrapper.findAll('button');
		expect(buttons.length).toBe(1);
		expect(buttons[0].text()).toBe('Cancel');
	});

	it('renders no buttons if both confirmText and cancelText are null', async () => {
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					confirmText: null,
					cancelText: null,
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});
		
		await wrapper.vm.$nextTick();
		
		expect(wrapper.findAll('button').length).toBe(0);
	});

	it('updates modal visibility when options prop changes', async () => {
		const wrapper = mount(Modal, {
			props: {
				options: null,
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		expect((wrapper.vm as any).isVisible).toBe(false);

		await wrapper.setProps({
			options: {
				title: 'New Title',
				message: '',
			},
		});
		await wrapper.vm.$nextTick();
		expect((wrapper.vm as any).isVisible).toBe(true);

		await wrapper.setProps({
			options: null,
		});
		await wrapper.vm.$nextTick();
		expect((wrapper.vm as any).isVisible).toBe(false);
	});

	it('focuses the first focusable element when modal opens', async () => {
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					confirmText: 'Confirm',
					cancelText: 'Cancel',
				},
			},
			attachTo: document.body,
		});

		await wrapper.vm.$nextTick();
		await flushPromises();

		// Assuming confirm button is the first focusable element in this setup
		const confirmButton = document.querySelector('#ConfirmButton') as HTMLButtonElement;
		expect(confirmButton).not.toBeNull();
		expect(document.activeElement).toBe(confirmButton);
	});

	it('focuses the modal itself if no focusable elements are present', async () => {
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					// No buttons or focusable elements within the content by default
					confirmText: null,
					cancelText: null,
				},
			},
			attachTo: document.body,
		});
		
		await wrapper.vm.$nextTick();
		
		// Focus should be on the modal dialog div itself if it's focusable
		// For this test, we rely on the default behavior of the component
		expect(document.activeElement?.id).toEqual("ModalDialog");
	});
	
	it('emits close event when options become null', async () => {
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		await wrapper.setProps({
			options: null,
		});

		// The 'close' event is emitted inside closeModal, which is called when options become null
		expect(wrapper.emitted('close')?.length).toBe(1);
	});

	it('does not trigger onConfirm if confirmText is null', async () => {
		const mockConfirm = vi.fn();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					confirmText: null,
					onConfirm: mockConfirm,
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		const buttons = wrapper.findAll('#ConfirmButton');
		expect(buttons.length).toBe(0); // No confirm button should be rendered

		expect(mockConfirm).not.toHaveBeenCalled();
	});

	it('does not trigger onCancel if cancelText is null', async () => {
		const mockCancel = vi.fn();
		const wrapper = mount(Modal, {
			props: {
				options: {
					title: 'Test Title',
					message: 'Test Message',
					cancelText: null,
					onCancel: mockCancel,
				},
			},
			global: {
				stubs: {
					teleport: true // 中身を stub に残す
				}
			},
		});

		await wrapper.vm.$nextTick();

		const buttons = wrapper.findAll('#CancelButton');
		expect(buttons.length).toBe(0); // No cancel button should be rendered

		expect(mockCancel).not.toHaveBeenCalled();
	});
});
