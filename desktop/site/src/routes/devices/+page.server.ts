import { error, fail, isHttpError } from '@sveltejs/kit';
import { api, ApiError, requireToken } from '#lib/server/hackatime.js';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals, url }) => {
	requireToken(locals.token, url);
};

export const actions: Actions = {
	unpair: async ({ locals, url, request }) => {
		const token = requireToken(locals.token, url);
		const id = Number((await request.formData()).get('id'));
		try {
			await api(token, `/devices/${id}`, { method: 'DELETE' });
		} catch (e) {
			// Already unpaired somewhere else: the list refresh shows it gone.
			if (isHttpError(e) && e.status === 404) return { unpaired: id };
			if (e instanceof ApiError) return fail(422, { error: e.message });
			throw e;
		}
		return { unpaired: id };
	}
};
