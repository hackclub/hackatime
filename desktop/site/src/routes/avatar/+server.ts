import { error } from '@sveltejs/kit';
import { api, type Overview } from '#lib/server/hackatime.js';
import type { RequestHandler } from './$types';

// Avatars come from these hosts only (GitHub, Slack, Hackatime's fallback).
const HOSTS = [/(^|\.)githubusercontent\.com$/, /(^|\.)slack-edge\.com$/, /(^|\.)slack\.com$/, /^ui-avatars\.com$/, /^i\d\.wp\.com$/, /(^|\.)gravatar\.com$/];
const TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'];
const MAX_BYTES = 2_000_000;

// Same-origin copy of the student's avatar, so the home page can dither it on
// a canvas (cross-origin images would taint the canvas). Raster only: an SVG
// served from this origin could run script.
export const GET: RequestHandler = async ({ locals }) => {
	if (!locals.token) error(401);
	const { user } = await api<Overview>(locals.token, '');
	const source = user.avatar_url ? URL.parse(user.avatar_url) : null;
	if (!source || source.protocol !== 'https:' || !HOSTS.some((host) => host.test(source.hostname))) error(404);
	const image = await fetch(source, { redirect: 'error', signal: AbortSignal.timeout(3000) }).catch(() => null);
	const type = image?.headers.get('content-type')?.split(';')[0].trim() ?? '';
	if (!image?.ok || !TYPES.includes(type)) error(404);
	const body = await image.arrayBuffer();
	if (body.byteLength > MAX_BYTES) error(404);
	return new Response(body, {
		headers: { 'Content-Type': type, 'X-Content-Type-Options': 'nosniff', 'Cache-Control': 'private, max-age=3600' }
	});
};
