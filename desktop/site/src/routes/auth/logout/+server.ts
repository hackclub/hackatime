import { redirect } from '@sveltejs/kit';
import * as env from '$app/env/private';
import { apiURL } from '#lib/server/hackatime.js';
import { clearToken, readToken } from '#lib/server/session.js';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ cookies }) => {
	const token = readToken(cookies);
	if (token) {
		await fetch(`${apiURL()}/oauth/revoke`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
			body: new URLSearchParams({ token, client_id: env.OAUTH_CLIENT_ID ?? '', ...(env.OAUTH_CLIENT_SECRET ? { client_secret: env.OAUTH_CLIENT_SECRET } : {}) })
		}).catch(() => {});
	}
	clearToken(cookies);
	redirect(303, '/');
};
