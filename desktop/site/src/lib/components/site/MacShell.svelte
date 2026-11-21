<script lang="ts">
	// The site's frame inside the Mac app: a toolbar row beside the window's
	// traffic lights, a sidebar over the window's native material and a
	// scrolling content pane. The app sets --native-titlebar and
	// --native-controls-inset on <html> before the page loads.
	import type { Snippet } from 'svelte';
	import { navigating, page } from '$app/state';
	import House from 'phosphor-svelte/lib/House';
	import Laptop from 'phosphor-svelte/lib/Laptop';
	import Package from 'phosphor-svelte/lib/Package';
	import CaretLeft from 'phosphor-svelte/lib/CaretLeft';
	import CaretRight from 'phosphor-svelte/lib/CaretRight';
	import SidebarSimple from 'phosphor-svelte/lib/SidebarSimple';
	import SignOut from 'phosphor-svelte/lib/SignOut';
	import SignIn from 'phosphor-svelte/lib/SignIn';
	import LinkSimple from 'phosphor-svelte/lib/LinkSimple';
	import { desktop, post, type NativeEvent } from '#lib/native.svelte.js';
	import type { Overview } from '#lib/server/hackatime.js';

	let { overview, children }: { overview: Overview | null; children: Snippet } = $props();

	const nav = [
		{ href: '/', label: 'Home', icon: House },
		{ href: '/devices', label: 'Devices', icon: Laptop },
		{ href: '/ships', label: 'Shipped', icon: Package }
	];
	const path = $derived(navigating.to?.url.pathname ?? page.url.pathname);
	const current = (href: string) => (href === '/' ? path === '/' : path.startsWith(href));
	const title = $derived(
		path === '/pair' ? 'Pair this Mac' : (nav.findLast((item) => current(item.href))?.label ?? 'Hackatime Desktop')
	);

	let mounted = $state(false);
	let sidebar = $state(true);
	const paired = $derived(mounted && desktop.current?.paired);

	$effect(() => {
		mounted = true;
		sidebar = localStorage.getItem('hkd:sidebar') !== 'hidden';
		// The app keeps the window hidden behind a native placeholder until now.
		post('ready');
		const listen = (event: Event) => {
			const detail = (event as CustomEvent<NativeEvent>).detail;
			if (detail?.type === 'command' && detail.name === 'toggleSidebar') toggle();
		};
		addEventListener('hackatime-native', listen);
		return () => removeEventListener('hackatime-native', listen);
	});

	function toggle() {
		sidebar = !sidebar;
		localStorage.setItem('hkd:sidebar', sidebar ? 'shown' : 'hidden');
	}

	// Empty toolbar and sidebar space moves the window, like a titlebar.
	// WebKit can't do that itself, so the app does the drag.
	function drag(event: MouseEvent) {
		const target = event.target as Element;
		if (event.button !== 0 || !target.closest('[data-drag]')) return;
		if (target.closest('a, button, input, textarea, select, label, [role="button"], [data-no-drag]')) return;
		event.preventDefault();
		post('windowDrag', { clicks: event.detail });
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="mac-shell" class:collapsed={!sidebar} onmousedown={drag}>
	{#if sidebar}
		<aside class="mac-sidebar sidebar" data-drag>
			<div class="h-[var(--native-titlebar,38px)] shrink-0"></div>
			{#if overview}
				<nav aria-label="Main" class="flex flex-col gap-px px-2.5">
					{#each nav as item (item.href)}
						<a href={item.href} class="mac-row" aria-current={current(item.href) ? 'page' : undefined}>
							<item.icon class="size-4 shrink-0" weight={current(item.href) ? 'fill' : 'regular'} />
							{item.label}
						</a>
					{/each}
				</nav>
			{/if}
			<div class="flex-1"></div>
			<div class="flex flex-col gap-1 px-2.5 pb-3">
				{#if overview}
					{#if mounted && !paired && path !== '/pair'}
						<a href="/pair" class="mac-row"><LinkSimple class="size-4 shrink-0" />Pair this Mac</a>
					{/if}
					<div class="flex items-center gap-2 px-2 pt-1">
						<span class="mac-avatar" aria-hidden="true">{(overview.user.username ?? overview.user.name).slice(0, 1)}</span>
						<span class="min-w-0 flex-1 truncate text-[13px] text-dim">{overview.user.username ?? overview.user.name}</span>
						<form method="POST" action="/auth/logout">
							<button class="mac-icon-button" aria-label="Sign out" title="Sign out"><SignOut class="size-4" /></button>
						</form>
					</div>
				{:else}
					<a href="/auth/login" class="mac-row"><SignIn class="size-4 shrink-0" />Sign in</a>
				{/if}
			</div>
		</aside>
	{/if}

	<div class="mac-pane">
		<header class="mac-toolbar" data-drag>
			<button class="mac-icon-button" onclick={toggle} aria-label={sidebar ? 'Hide sidebar' : 'Show sidebar'} title="Toggle sidebar (⌘B)">
				<SidebarSimple class="size-[17px]" />
			</button>
			<button class="mac-icon-button" onclick={() => post('navigate', { to: 'back' })} disabled={!desktop.current?.canGoBack} aria-label="Back" title="Back (⌘[)">
				<CaretLeft class="size-4" weight="bold" />
			</button>
			<button class="mac-icon-button" onclick={() => post('navigate', { to: 'forward' })} disabled={!desktop.current?.canGoForward} aria-label="Forward" title="Forward (⌘])">
				<CaretRight class="size-4" weight="bold" />
			</button>
			<h1 class="ml-1.5 truncate text-[13px] font-semibold">{title}</h1>
		</header>
		<main id="main" class="mac-content">
			{@render children()}
		</main>
	</div>
</div>

<style>
	.mac-shell {
		display: flex;
		height: 100dvh;
		overflow: hidden;
	}
	.mac-sidebar {
		display: flex;
		flex-direction: column;
		width: 212px;
		flex-shrink: 0;
		/* The window's material shows through, tinted towards the theme. */
		background: color-mix(in srgb, var(--ink) 40%, transparent);
	}
	.mac-pane {
		display: flex;
		min-width: 0;
		flex: 1;
		flex-direction: column;
		background: color-mix(in srgb, var(--ink) 94%, transparent);
		border-left: 1px solid color-mix(in srgb, var(--cream) 9%, transparent);
	}
	.collapsed .mac-pane {
		border-left: 0;
	}
	.mac-toolbar {
		display: flex;
		height: var(--native-titlebar, 38px);
		flex-shrink: 0;
		align-items: center;
		gap: 2px;
		padding: 0 12px;
	}
	/* With the sidebar hidden the traffic lights sit over the toolbar. */
	.collapsed .mac-toolbar {
		padding-left: var(--native-controls-inset, 84px);
	}
	.mac-content {
		min-height: 0;
		flex: 1;
		overflow-y: auto;
		padding: 18px 28px 32px;
	}
	.mac-row {
		display: flex;
		height: 28px;
		align-items: center;
		gap: 8px;
		border-radius: 7px;
		padding: 0 8px;
		font-size: 13px;
		color: var(--cream);
		transition: background-color var(--fast) var(--ease);
	}
	.mac-row:hover {
		background: color-mix(in srgb, var(--cream) 7%, transparent);
	}
	.mac-row[aria-current] {
		background: color-mix(in srgb, var(--cream) 13%, transparent);
		font-weight: 600;
	}
	.mac-row :global(svg) {
		color: color-mix(in srgb, var(--cream) 70%, transparent);
	}
	.mac-row[aria-current] :global(svg) {
		color: var(--link);
	}
	.mac-icon-button {
		display: grid;
		width: 28px;
		height: 26px;
		place-items: center;
		border-radius: 6px;
		color: color-mix(in srgb, var(--cream) 75%, transparent);
		transition: background-color var(--fast) var(--ease);
	}
	.mac-icon-button:hover:not(:disabled) {
		background: color-mix(in srgb, var(--cream) 9%, transparent);
		color: var(--cream);
	}
	.mac-icon-button:disabled {
		opacity: 0.35;
	}
	.mac-avatar {
		display: grid;
		width: 20px;
		height: 20px;
		place-items: center;
		border-radius: 999px;
		background: color-mix(in srgb, var(--link) 85%, transparent);
		color: var(--ink);
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
	}
</style>
