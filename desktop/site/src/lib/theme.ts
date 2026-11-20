// The student's Hackatime theme (config/themes.yml in Hackatime, served by
// GET /api/v1/authenticated/desktop). Every colour on the site comes from it.
export type Palette = {
	darker: string;
	dark: string;
	darkless: string;
	primary: string;
	content: string;
	info: string;
	success: string;
	warning: string;
	border: string;
	muted: string;
};

export type Theme = { value: string; label: string; color_scheme: 'dark' | 'light'; palette: Palette };

// Hackatime's default theme, used until the student signs in.
export const DEFAULT_THEME: Theme = {
	value: 'neon',
	label: 'Neon',
	color_scheme: 'dark',
	palette: {
		darker: '#050505',
		dark: '#101312',
		darkless: '#242a28',
		primary: '#d7ff6a',
		content: '#e8eee9',
		info: '#6fd7ff',
		success: '#7dfc6a',
		warning: '#ffd166',
		border: '#2b3532',
		muted: '#8f9b95'
	}
};

const HEX = /^#[0-9a-f]{3,8}$/i;

function luminance(hex: string): number {
	const h = hex.slice(1);
	const full = h.length < 6 ? [...h.slice(0, 3)].map((c) => c + c).join('') : h.slice(0, 6);
	const [r, g, b] = [0, 2, 4].map((i) => {
		const c = parseInt(full.slice(i, i + 2), 16) / 255;
		return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
	});
	return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrast(a: string, b: string): number {
	const [x, y] = [luminance(a), luminance(b)].sort((m, n) => n - m);
	return (x + 0.05) / (y + 0.05);
}

/** CSS custom properties for <html>. Only hex colours pass, so a palette can't inject CSS. */
export function themeStyle(theme: Theme): string {
	const p = theme.palette;
	const vars: Record<string, string> = {
		'--ink': p.darker,
		'--panel': p.dark,
		'--panel-2': p.darkless,
		'--cream': p.content,
		'--link': p.primary,
		'--dim': p.muted,
		'--line': p.border || p.darkless,
		'--ok': p.success,
		'--warn': p.warning,
		'--info': p.info
	};
	// Text tokens that are hard to read on this theme's background fall back to
	// its main text colour (WCAG AA, 4.5:1).
	for (const key of ['--link', '--dim', '--warn', '--ok', '--info']) {
		if (HEX.test(vars[key] ?? '') && HEX.test(p.darker) && contrast(vars[key], p.darker) < 4.5) vars[key] = p.content;
	}
	return Object.entries(vars)
		.filter(([, value]) => HEX.test(value ?? ''))
		.map(([key, value]) => `${key}:${value}`)
		.join(';');
}
