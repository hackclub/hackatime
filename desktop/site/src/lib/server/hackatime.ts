import { error, redirect } from '@sveltejs/kit';
import { getRequestEvent } from '$app/server';
import { clearToken } from '#lib/server/session.js';
import * as env from '$app/env/private';
import type { Theme } from '#lib/theme.js';

export const hackatimeURL = () => (env.HACKATIME_URL || 'https://hackatime.hackclub.com').replace(/\/$/, '');
// Server-to-server calls may use a private address (in development, the
// Rails container) while the browser is sent to the public one.
// The site's own public origin, for the OAuth redirect URI. Behind a proxy the
// request URL can say http://; set SITE_URL to pin it.
export const siteURL = (url: URL) => (env.SITE_URL || url.origin).replace(/\/$/, '');
export const apiURL = () => (env.HACKATIME_API_URL || hackatimeURL()).replace(/\/$/, '');

export type Device = {
	id: number;
	name: string;
	platform: string;
	app_version: string | null;
	hardware_key: boolean;
	paired_at: string;
	last_seen_at: string | null;
};

export type ShipStatus = 'in_review' | 'appeal_in_review' | 'question' | 'approved' | 'approved_in_part' | 'rejected';

export type ShipRow = {
	id: number;
	project: string;
	status: ShipStatus;
	submitted_at: string | null;
	decided_at: string | null;
	claimed_seconds: number;
	approved_seconds: number | null;
};

export type Ship = ShipRow & {
	reflection: string;
	started_at: string | null;
	ended_at: string | null;
	frames_shared: number;
	reviewer_question: string | null;
	user_answer: string | null;
	decision_reason: string | null;
	appeal: string | null;
	appealable: boolean;
	access_log: { at: string; who: string; avatar_url: string | null; admin: boolean; what: string }[];
};

export type Overview = {
	user: { name: string; username: string | null; avatar_url: string | null; timezone: string; theme: Theme };
	today_seconds: number;
	stats: {
		days: { date: string; seconds: number }[];
		week_seconds: number;
		projects: { project: string; seconds: number }[];
		human_lines: number;
		ai_lines: number;
		approved_seconds: number;
	};
	devices: Device[];
	ships: ShipRow[];
};


export async function api<T>(token: string, path: string, init: RequestInit = {}): Promise<T> {
	const response = await fetch(`${apiURL()}/api/v1/authenticated/desktop${path}`, {
		...init,
		headers: { Authorization: `Bearer ${token}`, Accept: 'application/json', 'Content-Type': 'application/json', ...init.headers }
	});
	if (response.status === 401 || response.status === 403) {
		// Expired or revoked sign-in: forget it and sign in again, coming back here.
		const { cookies, url } = getRequestEvent();
		clearToken(cookies);
		redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname + url.search)}`);
	}
	if (response.status === 404) error(404, 'Not found');
	const body = response.status === 204 ? null : await response.json().catch(() => null);
	if (!response.ok) throw new ApiError(body?.error ?? `Hackatime returned ${response.status}`);
	return body as T;
}

export class ApiError extends Error {}

/** A same-origin path to return to after sign-in, or "/". */
export function safeNext(next: string | null, origin: string): string {
	try {
		const target = new URL(next ?? '/', origin);
		return target.origin === origin ? target.pathname + target.search : '/';
	} catch {
		return '/';
	}
}

export function requireToken(token: string | null, url: URL): string {
	if (!token) redirect(303, `/auth/login?next=${encodeURIComponent(url.pathname + url.search)}`);
	return token;
}
