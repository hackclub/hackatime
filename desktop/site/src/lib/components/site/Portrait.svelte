<script lang="ts">
	import { onMount } from 'svelte';
	import { cssVar, ditherInto } from './dither.js';

	// The student's avatar, dithered like manitej.com's portrait. Falls back
	// to their initial on a crosshatch when there is no avatar.
	let { src, name, class: className = '' }: { src: string | null; name: string; class?: string } = $props();
	let canvas: HTMLCanvasElement;
	let shown = $state(false);
	const SIZE = 150;

	onMount(() => {
		const ctx = canvas.getContext('2d', { willReadFrequently: true })!;
		canvas.width = canvas.height = SIZE;
		const paint = (source?: HTMLImageElement) => {
			if (source) {
				ctx.drawImage(source, 0, 0, SIZE, SIZE);
			} else {
				ctx.fillStyle = '#222';
				ctx.fillRect(0, 0, SIZE, SIZE);
				ctx.fillStyle = '#ddd';
				ctx.font = `700 ${SIZE * 0.6}px 'Familjen Grotesk Variable', sans-serif`;
				ctx.textAlign = 'center';
				ctx.textBaseline = 'middle';
				ctx.fillText(name.slice(0, 1).toUpperCase(), SIZE / 2, SIZE / 2 + 6);
			}
			const pixels = ctx.getImageData(0, 0, SIZE, SIZE);
			const src = new Uint8ClampedArray(pixels.data);
			const luma = (i: number) => (0.2126 * src[i] + 0.7152 * src[i + 1] + 0.0722 * src[i + 2]) / 255;
			// Stretch to the image's own range so mid-grey avatars keep their detail.
			let min = 1, max = 0;
			for (let i = 0; i < src.length; i += 4) {
				const l = luma(i);
				if (l < min) min = l;
				if (l > max) max = l;
			}
			const range = Math.max(0.05, max - min);
			ditherInto(
				pixels,
				(x, y) => ((luma((y * SIZE + x) * 4) - min) / range) ** 0.8,
				cssVar('--ink'),
				cssVar('--cream')
			);
			ctx.putImageData(pixels, 0, 0);
			shown = true;
		};
		if (!src) return paint();
		const image = new Image();
		image.onload = () => paint(image);
		image.onerror = () => paint();
		image.src = src;
	});
</script>

<div role="img" aria-label="{name}'s avatar">
	<canvas
		bind:this={canvas}
		class="block aspect-square w-full [image-rendering:pixelated] transition-opacity duration-150 {shown ? 'opacity-100' : 'opacity-0'} {className}"
		aria-hidden="true"
	></canvas>
</div>
