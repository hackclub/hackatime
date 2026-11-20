// Ordered (Bayer) dithering to the theme's two colours: every pixel becomes
// either ink or cream, so images read as flat crosshatch, never as gradients.
function bayer(n: number): number[][] {
	let m = [[0]];
	while (m.length < n) {
		const s = m.length;
		const next = Array.from({ length: s * 2 }, () => Array(s * 2).fill(0));
		for (let y = 0; y < s; y++)
			for (let x = 0; x < s; x++) {
				const v = m[y][x] * 4;
				next[y][x] = v;
				next[y][x + s] = v + 2;
				next[y + s][x] = v + 3;
				next[y + s][x + s] = v + 1;
			}
		m = next;
	}
	return m;
}
const MATRIX = bayer(4);

export function hexToRgb(hex: string): [number, number, number] {
	const h = hex.trim().replace('#', '');
	const full = h.length === 3 ? [...h].map((c) => c + c).join('') : h.slice(0, 6);
	const n = parseInt(full, 16);
	return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** `luma(x, y)` in 0..1 for each cell; writes ink/cream into `image`. */
export function ditherInto(image: ImageData, luma: (x: number, y: number) => number, ink: string, cream: string) {
	const [ir, ig, ib] = hexToRgb(ink);
	const [cr, cg, cb] = hexToRgb(cream);
	const { data, width, height } = image;
	for (let y = 0; y < height; y++) {
		const row = MATRIX[y % 4];
		for (let x = 0; x < width; x++) {
			const on = luma(x, y) > (row[x % 4] + 0.5) / 16;
			const i = (y * width + x) * 4;
			data[i] = on ? cr : ir;
			data[i + 1] = on ? cg : ig;
			data[i + 2] = on ? cb : ib;
			data[i + 3] = 255;
		}
	}
}

export const cssVar = (name: string) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
