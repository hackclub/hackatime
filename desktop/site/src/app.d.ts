import type { Theme } from '#lib/theme.js';

declare global {
	namespace App {
		interface Locals {
			token: string | null;
			theme: Theme;
			/** Loaded in Hackatime Desktop's Mac window. */
			native: boolean;
		}
	}
}

export {};
