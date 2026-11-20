import { api, type Overview } from '#lib/server/hackatime.js';
import { writeTheme } from '#lib/server/session.js';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, cookies, depends }) => {
	depends('app:overview');
	let overview: Overview | null = null;
	let offline = false;
	if (locals.token) {
		try {
			overview = await api<Overview>(locals.token, '');
			locals.theme = overview.user.theme;
			writeTheme(cookies, overview.user.theme);
		} catch (e) {
			// Hackatime unreachable: keep the site up and say so.
			if (!(e instanceof TypeError)) throw e;
			offline = true;
		}
	}
	return { overview, offline, theme: locals.theme };
};
