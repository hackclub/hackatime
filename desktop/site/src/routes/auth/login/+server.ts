import { createHash, randomBytes } from 'node:crypto';
import { redirect } from '@sveltejs/kit';
import * as env from '$app/env/private';
import { hackatimeURL, safeNext, siteURL } from '#lib/server/hackatime.js';
import { writeFlow } from '#lib/server/session.js';
import type { RequestHandler } from './$types';

// Sign in with Hackatime: OAuth authorisation code with PKCE.
export const GET: RequestHandler = ({ url, cookies }) => {
	const next = url.searchParams.get('next') ?? '/';
	const verifier = randomBytes(48).toString('base64url');
	const state = randomBytes(16).toString('base64url');
	writeFlow(cookies, { state, verifier, next: safeNext(next, url.origin) });
	const authorize = new URL(`${hackatimeURL()}/oauth/authorize`);
	authorize.search = new URLSearchParams({
		client_id: env.OAUTH_CLIENT_ID ?? '',
		redirect_uri: `${siteURL(url)}/auth/callback`,
		response_type: 'code',
		scope: 'profile desktop',
		state,
		code_challenge: createHash('sha256').update(verifier).digest('base64url'),
		code_challenge_method: 'S256'
	}).toString();
	redirect(303, authorize.toString(), { external: [hackatimeURL()] });
};
