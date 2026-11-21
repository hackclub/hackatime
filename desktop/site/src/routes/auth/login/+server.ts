import { createHash, randomBytes } from 'node:crypto';
import { redirect } from '@sveltejs/kit';
import * as env from '$app/env/private';
import { hackatimeURL, safeNext, siteURL } from '#lib/server/hackatime.js';
import { writeFlow } from '#lib/server/session.js';
import type { RequestHandler } from './$types';

// Sign in with Hackatime: OAuth authorisation code with PKCE.
// The Mac app runs the Hackatime half in the system sign-in sheet, which hands
// the code back to the app on its own URL scheme; the app then opens
// /auth/callback in its window, where this flow's cookie lives.
const NATIVE_REDIRECT = 'hackatime-desktop://auth/callback';

export const GET: RequestHandler = ({ url, cookies, locals }) => {
	const next = url.searchParams.get('next') ?? '/';
	const verifier = randomBytes(48).toString('base64url');
	const state = randomBytes(16).toString('base64url');
	const redirectURI = locals.native ? NATIVE_REDIRECT : `${siteURL(url)}/auth/callback`;
	writeFlow(cookies, { state, verifier, next: safeNext(next, url.origin), redirectURI });
	const authorize = new URL(`${hackatimeURL()}/oauth/authorize`);
	authorize.search = new URLSearchParams({
		client_id: env.OAUTH_CLIENT_ID ?? '',
		redirect_uri: redirectURI,
		response_type: 'code',
		scope: 'profile desktop',
		state,
		code_challenge: createHash('sha256').update(verifier).digest('base64url'),
		code_challenge_method: 'S256'
	}).toString();
	redirect(303, authorize.toString(), { external: [hackatimeURL()] });
};
