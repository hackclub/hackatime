import { error, redirect } from '@sveltejs/kit';
import * as env from '$app/env/private';
import { api, apiURL, safeNext, siteURL, type Overview } from '#lib/server/hackatime.js';
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
	writeToken(cookies, access_token);
	const overview = await api<Overview>(access_token, '').catch(() => null);
	if (overview) writeTheme(cookies, overview.user.theme);
	redirect(303, safeNext(flow.next, url.origin));
};
