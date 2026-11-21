import { error, redirect } from '@sveltejs/kit';
import * as env from '$app/env/private';
import { apiURL, safeNext, siteURL, type Overview } from '#lib/server/hackatime.js';
import { takeFlow, writeTheme, writeToken } from '#lib/server/session.js';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, cookies }) => {
	const flow = takeFlow(cookies);
	if (!flow || url.searchParams.get('state') !== flow.state) error(400, 'This sign-in link has expired. Try again.');
	if (url.searchParams.get('error')) redirect(303, '/?signin=cancelled');

	const response = await fetch(`${apiURL()}/oauth/token`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({
			grant_type: 'authorization_code',
			code: url.searchParams.get('code') ?? '',
			redirect_uri: flow.redirectURI ?? `${siteURL(url)}/auth/callback`,
			client_id: env.OAUTH_CLIENT_ID ?? '',
			...(env.OAUTH_CLIENT_SECRET ? { client_secret: env.OAUTH_CLIENT_SECRET } : {}),
			code_verifier: flow.verifier
		})
	});
	if (!response.ok) error(502, 'Hackatime did not accept the sign-in. Try again.');
	const { access_token } = await response.json().catch(() => ({}));
	if (typeof access_token !== 'string') error(502, 'Hackatime did not accept the sign-in. Try again.');
	// A token Hackatime has only just issued but will not accept belongs to a
	// restricted account. Say so here: sending the student back to sign in would
	// only bring them round to this point again.
	const check = await fetch(`${apiURL()}/api/v1/authenticated/desktop`, {
		headers: { Authorization: `Bearer ${access_token}`, Accept: 'application/json' }
	}).catch(() => null);
	if (check?.status === 401 || check?.status === 403) redirect(303, '/?signin=restricted');
	writeToken(cookies, access_token);
	const overview: Overview | null = check?.ok ? await check.json().catch(() => null) : null;
	if (overview) writeTheme(cookies, overview.user.theme);
	redirect(303, safeNext(flow.next, url.origin));
};
