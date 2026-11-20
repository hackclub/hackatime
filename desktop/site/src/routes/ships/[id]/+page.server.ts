import { fail } from '@sveltejs/kit';
import { api, ApiError, requireToken, type Ship } from '#lib/server/hackatime.js';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url, params }) => {
	const token = requireToken(locals.token, url);
	return { ship: await api<Ship>(token, `/ships/${Number(params.id)}`) };
};

async function send(token: string, path: string, field: 'answer' | 'appeal', request: Request) {
	const text = String((await request.formData()).get(field) ?? '').trim();
	if (!text) return fail(400, { field, error: field === 'answer' ? 'Write your answer first.' : 'Say why first.' });
	try {
		await api(token, path, { method: 'POST', body: JSON.stringify({ [field]: text }) });
		return { sent: field };
	} catch (e) {
		if (e instanceof ApiError) return fail(422, { field, error: e.message });
		throw e;
	}
}

export const actions: Actions = {
	answer: async ({ locals, url, params, request }) =>
		send(requireToken(locals.token, url), `/ships/${Number(params.id)}/answer`, 'answer', request),
	appeal: async ({ locals, url, params, request }) =>
		send(requireToken(locals.token, url), `/ships/${Number(params.id)}/appeal`, 'appeal', request)
};
