import { fail } from '@sveltejs/kit';
import { api, ApiError, downloadURL, hackatimeURL, requireToken } from '#lib/server/hackatime.js';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals, url }) => {
	requireToken(locals.token, url);
	return { challenge: url.searchParams.get('challenge'), name: url.searchParams.get('name'), hackatime: hackatimeURL(), download: downloadURL() };
};

export const actions: Actions = {
	default: async ({ locals, url, request }) => {
		const token = requireToken(locals.token, url);
		const form = await request.formData();
		const challenge = String(form.get('challenge') ?? '');
		if (form.get('consent') !== 'on') return fail(400, { error: 'Tick the box to agree to the timelapse first.' });
		try {
			const pairing = await api<{ code: string; deep_link: string; expires_at: string }>(token, '/pairings', {
				method: 'POST',
				body: JSON.stringify({ code_challenge: challenge, consent: true })
			});
			return { pairing };
		} catch (e) {
			if (e instanceof ApiError) return fail(422, { error: e.message });
			throw e;
		}
	}
};
