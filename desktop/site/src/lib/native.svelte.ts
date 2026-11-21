import { browser } from '$app/env';
import { toast } from 'svelte-sonner';

// Hackatime Desktop's Mac window loads this site. It sets window.hackatimeDesktop
// before any script runs, updates it and fires `hackatime-native` when it
// changes, and takes messages on window.webkit.messageHandlers.hackatime.
export type DesktopState = { paired: boolean; paused: boolean; version: string; device: string };
export type NativeEvent = { type: 'pairFailed'; error: string } | undefined;

declare global {
	interface Window {
		hackatimeDesktop?: DesktopState;
		webkit?: { messageHandlers?: { hackatime?: { postMessage(message: unknown): void } } };
	}
}

export const desktop = $state<{ current: DesktopState | null }>({
	current: browser ? (window.hackatimeDesktop ?? null) : null
});
if (browser) addEventListener('hackatime-native', () => (desktop.current = window.hackatimeDesktop ?? null));

export const post = (type: string, payload: Record<string, unknown> = {}) =>
	window.webkit?.messageHandlers?.hackatime?.postMessage({ type, ...payload });

type Style = 'info' | 'success' | 'error' | 'loading';

/** A native toast in the Mac app, a sonner toast in a browser. */
export function notify(title: string, { detail, style = 'info' }: { detail?: string; style?: Style } = {}) {
	if (desktop.current) return post('toast', { title, detail, style });
	const show = style === 'success' ? toast.success : style === 'error' ? toast.error : toast;
	show(title, { description: detail });
}
