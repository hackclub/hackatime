import { requireToken } from '#lib/server/hackatime.js';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals, url }) => {
	requireToken(locals.token, url);
};
