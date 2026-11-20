<script lang="ts">
	// A starburst badge, like the "New" sticker on manitej.com.
	let { label, class: className = '' }: { label: string; class?: string } = $props();
	const points = Array.from({ length: 28 }, (_, i) => {
		const r = i % 2 ? 13 : 18;
		const a = (Math.PI * 2 * i) / 28;
		return `${32 + r * 1.75 * Math.cos(a)},${18 + r * Math.sin(a)}`;
	}).join(' ');
</script>

<svg viewBox="0 0 64 36" class="h-[35px] w-[63px] {className}" role="img" aria-label={label}>
	<polygon {points} fill="var(--ink)" />
	<text x="32" y="22.5" text-anchor="middle" font-size="11" font-weight="700" font-style="italic" fill="var(--cream)">{label}</text>
</svg>
