import type { Handle } from '@sveltejs/kit/hooks';
import { readTheme, readToken } from '#lib/server/session.js';
import { DEFAULT_THEME, themeStyle, type Theme } from '#lib/theme.js';

export const handle: Handle = async ({ event, resolve }) => {
	event.locals.token = readToken(event.cookies);
	event.locals.theme = (readTheme(event.cookies) as Theme | null) ?? DEFAULT_THEME;
	// Pages that load a fresher theme from Hackatime set it on locals before render.
	return resolve(event, {
		transformPageChunk: ({ html }) => {
			const theme = event.locals.theme;
			return html
				.replace('%theme.attrs%', `data-theme="${theme.value.replace(/[^a-z_]/g, '')}" style="${themeStyle(theme)}"`)
				.replace('%theme.scheme%', theme.color_scheme === 'light' ? 'light' : 'dark');
		}
	});
};
