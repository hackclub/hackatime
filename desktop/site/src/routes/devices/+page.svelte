<script lang="ts">
	import { enhance } from '$app/forms';
	import { notify } from '#lib/native.svelte.js';
	import { fly } from 'svelte/transition';
	import { flip } from 'svelte/animate';
	import { ms, stagger } from '#lib/motion.js';
	import Headline from '#lib/components/site/Headline.svelte';
	import { Button, buttonVariants } from '#lib/components/ui/button/index.js';
	import * as AlertDialog from '#lib/components/ui/alert-dialog/index.js';
	import { ago, day } from '#lib/format.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	const devices = $derived(data.overview?.devices ?? []);
	const zone = $derived(data.overview?.user.timezone);
	// The device being unpaired, so its button can say so on a slow connection.
	let pending = $state<number | null>(null);
</script>

<svelte:head><title>Devices · Hackatime Desktop</title></svelte:head>

<section class="flex flex-col gap-8">
	<Headline text="Your Macs" />

	{#if devices.length === 0}
		<p class="text-xl">No Mac paired yet.</p>
		<div><Button href="/pair" size="lg">{data.native ? 'Pair This Mac' : 'Get the Mac App'}</Button></div>
	{:else}
		<ul class="grid gap-4 md:grid-cols-2">
			{#each devices as device, i (device.id)}
				<li
					class="flex min-w-0 flex-col gap-3 border-4 border-cream p-5"
					in:fly={{ y: 8, duration: ms(140), delay: stagger(i) }}
					out:fly={{ x: -16, duration: ms(120) }}
					animate:flip={{ duration: ms(160) }}
				>
					<div class="flex items-baseline justify-between gap-3">
						<h2 class="min-w-0 text-2xl font-bold break-words">{device.name}</h2>
						<span class="shrink-0 text-sm text-dim">{device.platform}{device.app_version ? ` · ${device.app_version}` : ''}</span>
					</div>
					<dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-base">
						<dt class="text-dim">paired</dt>
						<dd>{day(device.paired_at, zone)}</dd>
						<dt class="text-dim">last seen</dt>
						<dd>{ago(device.last_seen_at)}</dd>
					</dl>
					<AlertDialog.Root>
						<AlertDialog.Trigger class="{buttonVariants({ variant: 'outline' })} w-fit">unpair</AlertDialog.Trigger>
						<AlertDialog.Content>
							<AlertDialog.Header>
								<AlertDialog.Title>unpair {device.name}?</AlertDialog.Title>
								<AlertDialog.Description>
									It stops recording for this account straight away. Work you already shipped stays shipped.
								</AlertDialog.Description>
							</AlertDialog.Header>
							<form
								method="POST"
								action="?/unpair"
								use:enhance={() => {
									pending = device.id;
									return async ({ result, update }) => {
										await update();
										pending = null;
										if (result.type === 'success') notify(`${device.name} unpaired`, { style: 'success' });
										else if (result.type === 'failure') notify(String(result.data?.error ?? "Couldn't unpair. Try again."), { style: 'error' });
									};
								}}
							>
								<input type="hidden" name="id" value={device.id} />
								<AlertDialog.Footer>
									<AlertDialog.Cancel>keep it</AlertDialog.Cancel>
									<AlertDialog.Action type="submit" disabled={pending === device.id} class="border-2 border-warn bg-warn text-ink hover:bg-warn/80">{pending === device.id ? 'unpairing…' : 'unpair'}</AlertDialog.Action>
								</AlertDialog.Footer>
							</form>
						</AlertDialog.Content>
					</AlertDialog.Root>
				</li>
			{/each}
		</ul>
	{/if}
</section>
