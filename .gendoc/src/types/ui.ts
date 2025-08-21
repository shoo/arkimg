import type { Ref, Component } from 'vue';

export interface NotificationMessage {
	id: number;                                 // ユニークなID
	title?: string;                             // タイトル
	message: string;                            // メッセージ内容
	type: 'success' | 'error' | 'info';         // 通知型
	timeout?: number;                           // 秒数
}

export interface NotificationManager {
	notify: (message: string, type: 'success' | 'error' | 'info', title?: string, timeout?: number) => void;
}

export interface ModalController {
	openModal: (options: ModalOptions) => void;
	closeModal: () => void;
}

export interface ModalOptions {
	title: string;
	message: string;
	component?: Component;
	props?: Record<string, any>;
	onConfirm?: () => void;
	onCancel?: () => void;
	confirmText?: string | null;
	cancelText?: string | null;
}

export interface ResponsiveContext {
	isMobile: Ref<boolean>
}
