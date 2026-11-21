import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';
import type { Cookies } from '@sveltejs/kit';
import { dev } from '$app/env';
import * as env from '$app/env/private';

// The Hackatime OAuth token lives in an encrypted, httpOnly cookie (AES-256-GCM
// keyed from SESSION_SECRET), so the browser never sees it.
const COOKIE = 'hkd_session';
const key = () => createHash('sha256').update(env.SESSION_SECRET).digest();

export function seal(value: string): string {
	const iv = randomBytes(12);
	const cipher = createCipheriv('aes-256-gcm', key(), iv);
	const body = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
	return Buffer.concat([iv, cipher.getAuthTag(), body]).toString('base64url');
}

export function unseal(sealed: string | undefined): string | null {
	if (!sealed) return null;
	try {
		const raw = Buffer.from(sealed, 'base64url');
		const decipher = createDecipheriv('aes-256-gcm', key(), raw.subarray(0, 12));
		decipher.setAuthTag(raw.subarray(12, 28));
		return Buffer.concat([decipher.update(raw.subarray(28)), decipher.final()]).toString('utf8');
	} catch {
		return null;
	}
}

const options = { path: '/', httpOnly: true, sameSite: 'lax' as const, secure: !dev };

export const readToken = (cookies: Cookies) => unseal(cookies.get(COOKIE));
export const writeToken = (cookies: Cookies, token: string) =>
	cookies.set(COOKIE, seal(token), { ...options, maxAge: 60 * 60 * 24 * 30 });
export const clearToken = (cookies: Cookies) => cookies.delete(COOKIE, options);

// Short-lived PKCE state for the sign-in round trip.
export const writeFlow = (cookies: Cookies, flow: object) =>
	cookies.set('hkd_flow', seal(JSON.stringify(flow)), { ...options, maxAge: 600 });
export function takeFlow(cookies: Cookies): { state: string; verifier: string; next: string; redirectURI?: string } | null {
	const raw = unseal(cookies.get('hkd_flow'));
	cookies.delete('hkd_flow', options);
	return raw ? JSON.parse(raw) : null;
}

// The last theme seen, so signed-out pages keep the student's colours.
export const writeTheme = (cookies: Cookies, theme: object) =>
	cookies.set('hkd_theme', seal(JSON.stringify(theme)), { ...options, maxAge: 60 * 60 * 24 * 365 });
export function readTheme(cookies: Cookies) {
	const raw = unseal(cookies.get('hkd_theme'));
	return raw ? JSON.parse(raw) : null;
}
