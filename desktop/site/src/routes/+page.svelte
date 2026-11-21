<script lang="ts">
	import Headline from '#lib/components/site/Headline.svelte';
	import Stats from '#lib/components/site/Stats.svelte';
	import Stripes from '#lib/components/site/Stripes.svelte';
	import Portrait from '#lib/components/site/Portrait.svelte';
	import Burst from '#lib/components/site/Burst.svelte';
	import Entry from '#lib/components/site/Entry.svelte';
	import { page } from '$app/state';
	import { Button } from '#lib/components/ui/button/index.js';
	import { ago, duration, statusLine } from '#lib/format.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	const overview = $derived(data.overview);
	const firstName = $derived(overview?.user.name.split(' ')[0] ?? '');
</script>

{#if overview}
	<section class="flex flex-col gap-8">
		<Headline text="Hi {firstName}!" />

		<div class="grid gap-8 md:grid-cols-[minmax(0,1fr)_200px]">
			<div class="flex flex-col gap-6">
				<p class="max-w-[52ch] text-xl leading-snug">Your timelapse stays on your Mac until you ship a project.</p>
				<Stats stats={overview.stats} today={overview.today_seconds} />
			</div>

			<div class="flex flex-col gap-3 max-md:max-w-[160px]">
				<div class="border-4 border-cream">
					<Portrait src={overview.user.avatar_url ? `/avatar?src=${encodeURIComponent(overview.user.avatar_url)}` : null} name={overview.user.name} />
				</div>
				<p class="text-sm text-dim">{overview.user.username ? `@${overview.user.username}`: overview.user.name}</p>
			</div>
		</div>

		<div class="grid gap-8 md:grid-cols-[minmax(0,1fr)_200px]"><div class="grid gap-10 sm:grid-cols-2">
			<section aria-labelledby="devices-heading" class="flex flex-col gap-2">
				<h2 id="devices-heading" class="flex items-center gap-2 text-2xl font-bold lowercase native:normal-case">
					<span class="inline-block">Your Macs</span>
					{#if overview.devices.length === 0}<Burst label="New" />{/if}
				</h2>
				{#if overview.devices.length}
					<ul>
						{#each overview.devices as device, i (device.id)}
							<Entry index={i}>
								{#snippet title()}<a class="link" href="/devices">{device.name}</a>{/snippet}
								last seen {ago(device.last_seen_at)}
							</Entry>
						{/each}
					</ul>
				{:else}
					<p class="text-dim">No Mac paired yet.</p>
					<!-- Inside the app there's nothing to download: pair this Mac instead. -->
					<div><Button href="/pair" size="lg">{data.native ? 'Pair This Mac' : 'Get the Mac App'}</Button></div>
				{/if}
			</section>

			<section aria-labelledby="ships-heading" class="flex flex-col gap-2">
				<h2 id="ships-heading" class="text-2xl font-bold lowercase">recently shipped</h2>
				{#if overview.ships.length}
					<ul>
						{#each overview.ships.slice(0, 5) as ship, i (ship.id)}
							<Entry index={i}>
								{#snippet title()}<a class="link" href="/ships/{ship.id}">{ship.project}</a>{/snippet}
								{statusLine(ship.status, ship.approved_seconds)}
							</Entry>
						{/each}
					</ul>
				{:else}
					<p class="text-dim">Nothing shipped yet. When you ship from the app, it shows up here.</p>
				{/if}
			</section>
		</div></div>
	</section>
{:else}
	<section class="flex flex-col gap-8">
		<Headline text="your work, sped up" />
		<div class="grid gap-8 md:grid-cols-[minmax(0,1fr)_280px]">
			<div class="flex flex-col gap-5 text-xl leading-snug">
				<p class="max-w-[52ch]">
					Hackatime Desktop keeps a timelapse of the windows you code in, so the hours you put into a project
					count, even when an AI wrote some of the lines.
				</p>
				<ul class="flex flex-col text-lg">
					<Entry index={0}>{#snippet title()}Only your editor, terminal, docs and the app you are building.{/snippet}</Entry>
					<Entry index={1}>{#snippet title()}Passwords, banking, chats and private windows are never captured.{/snippet}</Entry>
					<Entry index={2}>{#snippet title()}Everything stays on your Mac until you ship. You preview it first.{/snippet}</Entry>
					<Entry index={3}>{#snippet title()}Pause from the menu bar whenever you like.{/snippet}</Entry>
				</ul>
				{#if page.url.searchParams.get('signin') === 'restricted'}
					<p role="alert" class="w-fit bg-warn px-3 py-1.5 text-base text-ink">
						Hackatime won't let this account use Hackatime Desktop right now. If your account is restricted or
						waiting to be deleted, ask Hack Club for help.
					</p>
				{/if}
				<div><Button href="/auth/login" size="lg">Sign In with Hackatime</Button></div>
			</div>
			{#if !data.native}<Stripes class="h-64 md:h-auto" />{/if}
		</div>
	</section>
{/if}
