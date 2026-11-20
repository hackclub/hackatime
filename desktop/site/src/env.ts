import { defineEnvVars } from '@sveltejs/kit/env';

const optional = (value: string | undefined) => value || undefined;

// Read when the server starts. See desktop/site/README.md.
export const variables = defineEnvVars({
	HACKATIME_URL: { schema: optional, description: 'Public Hackatime origin the browser is sent to for sign-in.' },
	HACKATIME_API_URL: { schema: optional, description: 'Origin for server-to-server API calls. Defaults to HACKATIME_URL.' },
	OAUTH_CLIENT_ID: { description: 'Hackatime OAuth application UID (scopes: profile desktop).' },
	OAUTH_CLIENT_SECRET: { schema: optional, description: 'OAuth secret, for a confidential application.' },
	SITE_URL: { schema: optional, description: "This site's public origin, when a proxy hides it." },
	SESSION_SECRET: {
		schema: (value) => {
			if (!value || value.length < 32) throw new Error('SESSION_SECRET must be at least 32 characters');
			return value;
		},
		description: 'At least 32 random characters; encrypts session cookies.' }
});
