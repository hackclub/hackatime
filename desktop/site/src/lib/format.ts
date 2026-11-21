export function duration(seconds: number | null | undefined): string {
	if (seconds == null) return '–';
	const h = Math.floor(seconds / 3600);
	const m = Math.floor((seconds % 3600) / 60);
	// A no-break space, so "5h 20m" never splits across lines.
	return h ? `${h}h\u00a0${String(m).padStart(2, '0')}m` : `${m}m`;
}

const units: [Intl.RelativeTimeFormatUnit, number][] = [
	['year', 31_536_000],
	['month', 2_592_000],
	['week', 604_800],
	['day', 86_400],
	['hour', 3_600],
	['minute', 60]
];
const rtf = new Intl.RelativeTimeFormat('en-GB', { numeric: 'auto' });

export function ago(iso: string | null | undefined, now = Date.now()): string {
	if (!iso) return 'never';
	const seconds = (new Date(iso).getTime() - now) / 1000;
	for (const [unit, size] of units) {
		if (Math.abs(seconds) >= size) return rtf.format(Math.round(seconds / size), unit);
	}
	return 'just now';
}

export function day(iso: string | null | undefined, timeZone?: string): string {
	if (!iso) return '';
	return new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone });
}

export function clock(iso: string | null | undefined, timeZone?: string): string {
	if (!iso) return '';
	return new Date(iso).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone });
}

/** What a student reads about where their shipped work stands. */
export function statusLine(status: string, approved: number | null): string {
	switch (status) {
		case 'in_review':
			return 'with a reviewer';
		case 'appeal_in_review':
			return 'appeal with a new reviewer';
		case 'question':
			return 'your reviewer asked you something';
		case 'approved':
			return `approved · ${duration(approved)}`;
		case 'approved_in_part':
			return `approved in part · ${duration(approved)}`;
		case 'rejected':
			return 'not approved';
		default:
			return status.replace(/_/g, ' ');
	}
}
