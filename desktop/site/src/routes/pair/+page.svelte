<script lang="ts">
	import { enhance } from '$app/forms';
	import { fly } from 'svelte/transition';
	import { ms } from '#lib/motion.js';
	import Headline from '#lib/components/site/Headline.svelte';
	import Entry from '#lib/components/site/Entry.svelte';
	import { Button } from '#lib/components/ui/button/index.js';
	import { Checkbox } from '#lib/components/ui/checkbox/index.js';
	import { Label } from '#lib/components/ui/label/index.js';
	import { clock } from '#lib/format.js';
	import { desktop, post, type NativeEvent } from '#lib/native.svelte.js';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	let consent = $state(false);
	let busy = $state(false);
	const pairing = $derived(form && 'pairing' in form ? form.pairing : null);

	let failed = $state<string | null>(null);
	let mounted = $state(false);

	$effect(() => {
		mounted = true;
		if (!data.native) return;
		const listen = (event: Event) => {
			const detail = (event as CustomEvent<NativeEvent>).detail;
			if (detail?.type === 'pairFailed') failed = detail.error;
		};
		addEventListener('hackatime-native', listen);
		return () => removeEventListener('hackatime-native', listen);
	});

	$effect(() => {
		if (!pairing) return;
		// In the Mac app the code goes straight to it. In a browser the deep
		// link hands it over, and the code on screen is the fallback.
		failed = null;
		if (data.native) post('pair', { code: pairing.code });
		else location.href = pairing.deep_link;
	});
</script>

<svelte:head><title>Pair a Mac · Hackatime Desktop</title></svelte:head>

<section class="flex max-w-[720px] flex-col gap-8">
	<Headline text={data.challenge || pairing ? 'Pair a Mac' : data.native ? 'Pair this Mac' : 'Get the Mac app'} />

	{#if pairing && data.native}
		<div class="flex flex-col gap-4" in:fly={{ y: 8, duration: ms(160) }}>
			{#if failed}
				<p class="text-xl leading-snug">This Mac couldn't finish pairing.</p>
				<p role="alert" class="w-fit bg-warn px-3 py-1.5 text-ink">{failed}</p>
				<div><Button size="lg" onclick={() => post('startPairing')}>Start Again</Button></div>
			{:else}
				<p class="text-xl leading-snug">Pairing <strong class="text-link">{data.name || 'this Mac'}</strong>. This takes a second.</p>
			{/if}
		</div>
	{:else if pairing}
		<div class="flex flex-col gap-4" in:fly={{ y: 8, duration: ms(160) }}>
			<p class="text-xl">Your Mac should pick this up by itself. If it doesn't, type this code into the app:</p>
			<p class="text-sm text-dim" id="code-label">pairing code</p>
			<p class="-mt-3 w-fit bg-cream px-5 py-3 font-mono text-4xl font-bold tracking-[0.2em] text-ink" aria-labelledby="code-label">{pairing.code}</p>
			<p class="text-dim">The code works once and runs out at {clock(pairing.expires_at)}.</p>
			<div class="flex flex-wrap gap-3">
				<Button href={pairing.deep_link} size="lg">Open Hackatime Desktop</Button>
				<Button href="/devices" size="lg" variant="outline">See Your Macs</Button>
			</div>
		</div>
	{:else if !data.challenge && data.native}
		<div class="flex flex-col gap-4 text-xl leading-snug">
			{#if mounted && desktop.current?.paired}
				<p>This Mac is paired and tracking from the menu bar, even with this window closed.</p>
				<div><Button href="/devices" size="lg" variant="outline">See Your Macs</Button></div>
			{:else}
				<p>Pair this Mac with your Hackatime account. You'll see what the timelapse records and agree to it first.</p>
				<div><Button size="lg" onclick={() => post('startPairing')}>Pair This Mac</Button></div>
			{/if}
		</div>
	{:else if !data.challenge}
		<div class="flex flex-col gap-4 text-xl leading-snug">
			<p>Hackatime Desktop runs in your Mac's menu bar and keeps a timelapse of the windows you code in.</p>
			<div><Button href={data.download} size="lg">Download for macOS</Button></div>
			<ol class="flex flex-col text-lg">
				<Entry index={0}>{#snippet title()}Open the app. It opens this site in its own window.{/snippet}</Entry>
				<Entry index={1}>{#snippet title()}Sign in and agree to the timelapse. The app pairs itself.{/snippet}</Entry>
				<Entry index={2}>{#snippet title()}Close the window whenever you like. Tracking carries on from the menu bar.{/snippet}</Entry>
			</ol>
			<p class="text-base text-dim">Already have it? Start pairing from the app, so the code can only go to your Mac.</p>
		</div>
	{:else}
		<form
			method="POST"
			class="flex flex-col gap-6"
			use:enhance={() => {
				busy = true;
				return async ({ update }) => {
					await update({ reset: false });
					busy = false;
				};
			}}
		>
			<input type="hidden" name="challenge" value={data.challenge} />
			<p class="text-xl leading-snug">
				You're pairing <strong class="text-link">{data.name || 'a Mac'}</strong> with your Hackatime account.
			</p>

			<div class="flex flex-col gap-1 border-4 border-cream p-5">
				<h2 class="text-2xl font-bold lowercase">what the timelapse records</h2>
				<ul>
					<Entry index={0}>{#snippet title()}A frame every 20 seconds of the window you're coding in: your editor, terminal, docs, AI chat or the app you're building.{/snippet}</Entry>
					<Entry index={1}>{#snippet title()}Never password managers, banking, private windows, messages or notifications. Secrets on screen are blacked out on your Mac.{/snippet}</Entry>
					<Entry index={2}>{#snippet title()}It stays locked on your Mac. Nobody else can see it, not even Hack Club.{/snippet}</Entry>
					<Entry index={3}>{#snippet title()}When you ship a project, you preview the frames first and blur anything you like. Then Hack Club reviewers can watch them to approve your hours, and this site lists every time they look.{/snippet}</Entry>
					<Entry index={4}>{#snippet title()}Anything you don't ship is deleted from your Mac after 30 days. Pause from the menu bar or unpair whenever you like. To delete everything, including shipped frames, use your <a class="link" href="{data.hackatime}/my/settings/privacy" target="_blank" rel="noreferrer">Hackatime privacy settings</a>.{/snippet}</Entry>
				</ul>
			</div>

			<div class="flex items-start gap-3">
				<Checkbox id="consent" name="consent" bind:checked={consent} class="mt-1 size-5 border-2 border-cream" />
				<Label for="consent" class="text-lg leading-snug font-normal">
					<span>
					I agree to Hackatime Desktop keeping a timelapse of my work on this Mac as described above and in
					<a class="link" href="https://hackclub.com/privacy" target="_blank" rel="noreferrer">Hack Club's privacy policy</a>.
					</span>
				</Label>
			</div>

			{#if form && 'error' in form}
				<p role="alert" class="w-fit bg-warn px-3 py-1.5 text-ink">{form.error}</p>
			{/if}

			<div><Button type="submit" size="lg" disabled={busy}>{busy ? 'Pairing…' : 'Pair This Mac'}</Button></div>
		</form>
	{/if}
</section>
