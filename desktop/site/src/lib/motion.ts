import { browser } from '$app/env';

// Svelte transitions run through the Web Animations API, which the CSS
// reduced-motion rule can't reach, so every duration goes through here.
const reduce = () => browser && matchMedia('(prefers-reduced-motion: reduce)').matches;
export const ms = (duration: number) => (reduce() ? 0 : duration);
export const stagger = (index: number) => (reduce() ? 0 : Math.min(index, 10) * 25);
