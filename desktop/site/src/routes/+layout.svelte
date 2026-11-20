<script lang="ts">
	import '../app.css';
	import favicon from '#lib/assets/favicon.svg';
	import { onNavigate } from '$app/navigation';
	import { page } from '$app/state';
	import Stripes from '#lib/components/site/Stripes.svelte';
	import { Toaster } from '#lib/components/ui/sonner/index.js';
	import * as Tooltip from '#lib/components/ui/tooltip/index.js';
	import SignOut from 'phosphor-svelte/lib/SignOut';
	import type { LayoutProps } from './$types';

	let { children, data }: LayoutProps = $props();

	const nav = [
		{ href: '/', label: 'home' },
		{ href: '/devices', label: 'devices' },
		{ href: '/ships', label: 'shipped' }
	];
	const current = (href: string) =>
		href === '/' ? page.url.pathname === '/' : page.url.pathname.startsWith(href);

	// Pages cross-fade in 120ms where the browser supports view transitions.
	onNavigate((navigation) => {
		if (!document.startViewTransition) return;
		return new Promise((resolve) => {
			document.startViewTransition(async () => {
				resolve();
				await navigation.complete;
			});
		});
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>Hackatime Desktop</title>
</svelte:head>

<Toaster position="bottom-right" />
<Tooltip.Provider>

<a href="#main" class="sr-only z-50 bg-cream px-3 py-2 text-ink focus:not-sr-only focus:fixed focus:top-2 focus:left-2">Skip to content</a>

<div class="flex min-h-dvh w-full gap-9 px-5 pt-6 pb-24 md:px-6 md:pt-6 md:pb-6">
	<aside class="sidebar sticky top-6 hidden h-[calc(100dvh-48px)] w-[153px] shrink-0 flex-col gap-2 md:flex">
		<a href="/" class="mb-4 block text-[22px] leading-none font-bold tracking-tight" aria-label="Hackatime Desktop, home">
			hackatime<br /><span class="text-link">desktop</span>
		</a>

		{#if data.overview}
			<nav aria-label="Main" class="flex flex-col">
				{#each nav as item (item.href)}
					<a
						href={item.href}
						aria-current={current(item.href) ? 'page' : undefined}
						class="nav-link relative h-[30px] overflow-clip px-1.5 text-2xl leading-[30px] lowercase transition-colors duration-[var(--snap)] {current(item.href) ? 'font-bold text-ink' : 'hover:text-link'}"
					>
						<span class="relative">{item.label}</span>
					</a>
				{/each}
			</nav>
		{/if}

		<Stripes class="min-h-28 w-full flex-1" />

		<div class="flex flex-col gap-3">
			{#if data.overview}
				<a href="/pair" class="card block bg-cream p-3 text-ink">
					<span class="block text-lg leading-tight font-bold">pair a mac</span>
					<span class="block text-sm leading-snug">Open the app's menu and choose Pair, or start here.</span>
				</a>
				<div class="flex items-center justify-between gap-2 text-sm">
					<span class="truncate text-dim">{data.overview.user.username ?? data.overview.user.name}</span>
					<form method="POST" action="/auth/logout">
						<button class="flex items-center gap-1 text-dim transition-colors duration-[var(--fast)] hover:text-cream" aria-label="Sign out">
							<SignOut class="size-4" />
						</button>
					</form>
				</div>
			{:else}
				<a href="/auth/login" class="card block bg-cream p-3 text-ink">
					<span class="block text-lg leading-tight font-bold">sign in</span>
					<span class="block text-sm leading-snug">with your Hackatime account</span>
				</a>
			{/if}
		</div>
	</aside>

	<main id="main" class="min-w-0 flex-1">
		{#if data.offline}
			<p role="status" class="mb-6 w-fit bg-cream px-3 py-1.5 text-ink">Hackatime isn't answering right now. Try again in a minute.</p>
		{/if}
		{@render children()}
	</main>
</div>

{#if data.overview}
	<nav aria-label="Main" class="sidebar fixed inset-x-0 bottom-0 z-40 flex border-t-4 border-cream bg-ink md:hidden">
		{#each nav as item (item.href)}
			<a
				href={item.href}
				aria-current={current(item.href) ? 'page' : undefined}
				class="flex-1 py-3 text-center text-lg lowercase {current(item.href) ? 'bg-cream font-bold text-ink' : ''}"
			>
				{item.label}
			</a>
		{/each}
		<a href="/pair" class="flex-1 py-3 text-center text-lg lowercase {page.url.pathname === '/pair' ? 'bg-cream font-bold text-ink' : ''}">pair</a>
		<form method="POST" action="/auth/logout" class="flex">
			<button class="px-4 text-dim hover:text-cream" aria-label="Sign out"><SignOut class="size-5" /></button>
		</form>
	</nav>
{/if}

</Tooltip.Provider>

<style>
	/* Hover sweeps a faint fill in from the left, like manitej.com. */
	.nav-link::before {
		content: '';
		position: absolute;
		inset: 0;
		background: var(--cream);
		opacity: 0.14;
		transform: scaleX(0);
		transform-origin: left;
		transition: transform var(--fast) var(--ease);
	}
	.nav-link:not([aria-current]):hover::before {
		transform: scaleX(1);
	}
	/* The current page is a solid fill that sweeps in when you arrive. */
	.nav-link[aria-current]::before {
		opacity: 1;
		transform: scaleX(1);
		transition-duration: var(--snap);
	}
	.card {
		box-shadow: 0 0 0 var(--link);
		transition:
			transform var(--fast) var(--ease),
			box-shadow var(--fast) var(--ease);
	}
	.card:hover {
		transform: translate(-2px, -2px);
		box-shadow: 4px 4px 0 var(--link);
	}
</style>
