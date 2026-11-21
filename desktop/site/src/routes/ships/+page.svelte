<script lang="ts">
	import { fly } from 'svelte/transition';
	import { ms, stagger } from '#lib/motion.js';
	import Headline from '#lib/components/site/Headline.svelte';
	import { day, duration, statusLine } from '#lib/format.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	const ships = $derived(data.overview?.ships ?? []);
	const zone = $derived(data.overview?.user.timezone);
	const needsYou = (status: string) => status === 'question';
</script>

<svelte:head><title>Shipped · Hackatime Desktop</title></svelte:head>

<section class="flex flex-col gap-8">
	<Headline text="Shipped" />

	{#if ships.length === 0}
		<p class="max-w-[52ch] text-xl leading-snug">
			Nothing shipped yet. When a project is ready, choose <strong>Ship…</strong> in the app. You'll preview your
			timelapse before anyone else sees it.
		</p>
	{:else}
		<ul class="flex flex-col border-t-2 border-cream">
			{#each ships as ship, i (ship.id)}
				<li in:fly={{ y: 6, duration: ms(140), delay: stagger(i) }}>
					<a
						href="/ships/{ship.id}"
						class="row grid grid-cols-[minmax(0,1fr)_auto] items-baseline gap-x-6 gap-y-1 border-b-2 border-cream px-1 py-4 md:grid-cols-[minmax(0,1fr)_minmax(0,360px)_110px]"
					>
						<span class="truncate text-2xl font-bold">{ship.project}</span>
						<span class="text-right text-sm text-dim md:order-last">{day(ship.submitted_at, zone)}</span>
						<span class="col-span-2 text-base md:col-span-1 {needsYou(ship.status) ? 'font-bold text-link' : ''}">
							{statusLine(ship.status, ship.approved_seconds)}
							{#if !ship.approved_seconds}<span class="text-dim"> · {duration(ship.claimed_seconds)} recorded</span>{/if}
						</span>
					</a>
				</li>
			{/each}
		</ul>
	{/if}
</section>

<style>
	.row {
		transition:
			background-color var(--fast) var(--ease),
			color var(--fast) var(--ease);
	}
	.row:hover,
	.row:focus-visible {
		background: var(--cream);
		color: var(--ink);
	}
	.row:hover :global(.text-dim),
	.row:hover :global(.text-link),
	.row:focus-visible :global(.text-dim),
	.row:focus-visible :global(.text-link) {
		color: var(--ink);
	}
</style>
