<script lang="ts">
	import type { Snippet } from 'svelte';
	import { fly } from 'svelte/transition';
	import { ms, stagger } from '#lib/motion.js';

	// One bullet in a list, like manitej.com's project entries. Staggers in fast.
	let { index = 0, title, children }: { index?: number; title: Snippet; children?: Snippet } = $props();
</script>

<li class="flex w-full items-start gap-2 py-2" in:fly={{ y: 6, duration: ms(140), delay: stagger(index) }}>
	<span class="mt-[9px] size-1 shrink-0 bg-current" aria-hidden="true"></span>
	<div class="flex min-w-0 flex-col gap-0.5">
		<div class="text-base">{@render title()}</div>
		{#if children}<div class="text-sm text-dim">{@render children()}</div>{/if}
	</div>
</li>
