<script lang="ts">
	import { enhance } from '$app/forms';
	import { notify } from '#lib/native.svelte.js';
	import { fly, slide } from 'svelte/transition';
	import { ms, stagger } from '#lib/motion.js';
	import ArrowLeft from 'phosphor-svelte/lib/ArrowLeft';
	import Headline from '#lib/components/site/Headline.svelte';
	import Person from '#lib/components/site/Person.svelte';
	import { Button } from '#lib/components/ui/button/index.js';
	import { Textarea } from '#lib/components/ui/textarea/index.js';
	import { ago, clock, day, duration, statusLine } from '#lib/format.js';
	import type { SubmitFunction } from '$app/forms';
	import type { PageProps } from './$types';

	let { data, form }: PageProps = $props();
	const ship = $derived(data.ship);
	const zone = $derived(data.overview?.user.timezone);
	let appealing = $state(false);
	let busy = $state(false);

	const submit: SubmitFunction = () => {
		busy = true;
		return async ({ result, update }) => {
			await update();
			busy = false;
			if (result.type === 'success') {
				appealing = false;
				notify(result.data?.sent === 'answer' ? 'Answer sent to your reviewer' : 'Appeal sent to a new reviewer', { style: 'success' });
			}
		};
	};
	const errorFor = (field: string) => (form && 'field' in form && form.field === field ? form.error : null);
</script>

<svelte:head><title>{ship.project} · Hackatime Desktop</title></svelte:head>

<section class="flex flex-col gap-8">
	<a href="/ships" class="link flex w-fit items-center gap-1 text-base"><ArrowLeft class="size-4" /> shipped</a>
	<Headline text={ship.project} />

	<div class="grid gap-10 md:grid-cols-[minmax(0,1fr)_260px]">
		<div class="flex flex-col gap-8">
			<p class="w-fit px-3 py-1.5 text-lg font-bold {ship.status === 'question' ? 'bg-link text-ink' : 'bg-cream text-ink'}">
				{statusLine(ship.status, ship.approved_seconds)}
			</p>

			{#if ship.reviewer_question && ship.status === 'question'}
				<section aria-labelledby="q" class="flex flex-col gap-3 border-4 border-link p-5">
					<h2 id="q" class="text-2xl font-bold lowercase">your reviewer asks</h2>
					<p class="text-lg leading-snug whitespace-pre-line">{ship.reviewer_question}</p>
					<form method="POST" action="?/answer" class="flex flex-col gap-3" use:enhance={submit}>
						<Textarea name="answer" rows={5} maxlength={5000} placeholder="Explain in your own words. Code snippets are fine." class="min-h-32 text-base md:text-base" aria-label="Your answer" />
						{#if errorFor('answer')}<p role="alert" class="text-warn">{errorFor('answer')}</p>{/if}
						<div><Button type="submit" size="lg" disabled={busy}>send answer</Button></div>
					</form>
				</section>
			{:else if ship.reviewer_question}
				<section aria-labelledby="q" class="flex flex-col gap-2">
					<h2 id="q" class="text-2xl font-bold lowercase">your reviewer asked</h2>
					<p class="text-lg leading-snug whitespace-pre-line">{ship.reviewer_question}</p>
					{#if ship.user_answer}<p class="border-l-4 border-cream pl-4 text-lg leading-snug whitespace-pre-line text-dim">{ship.user_answer}</p>{/if}
				</section>
			{/if}

			{#if ship.decision_reason}
				<section aria-labelledby="why" class="flex flex-col gap-2">
					<h2 id="why" class="text-2xl font-bold lowercase">from your reviewer</h2>
					<p class="text-lg leading-snug whitespace-pre-line">{ship.decision_reason}</p>
				</section>
			{/if}

			{#if ship.appeal}
				<section aria-labelledby="appeal" class="flex flex-col gap-2">
					<h2 id="appeal" class="text-2xl font-bold lowercase">your appeal</h2>
					<p class="border-l-4 border-cream pl-4 text-lg leading-snug whitespace-pre-line text-dim">{ship.appeal}</p>
				</section>
			{:else if ship.appealable}
				<div class="flex flex-col gap-3">
					{#if !appealing}
						<div><Button variant="outline" size="lg" onclick={() => (appealing = true)}>appeal this decision</Button></div>
					{:else}
						<form method="POST" action="?/appeal" class="flex flex-col gap-3" transition:slide={{ duration: ms(140) }} use:enhance={submit}>
							<p class="text-lg">A different reviewer will look again. Tell them what the first one missed.</p>
							<Textarea name="appeal" rows={4} maxlength={5000} class="min-h-32 text-base md:text-base" aria-label="Why you're appealing" />
							{#if errorFor('appeal')}<p role="alert" class="text-warn">{errorFor('appeal')}</p>{/if}
							<div class="flex gap-3">
								<Button type="submit" size="lg" disabled={busy}>send appeal</Button>
								<Button variant="ghost" size="lg" onclick={() => (appealing = false)}>cancel</Button>
							</div>
						</form>
					{/if}
				</div>
			{/if}

			<section aria-labelledby="reflection" class="flex flex-col gap-2">
				<h2 id="reflection" class="text-2xl font-bold lowercase">what you built</h2>
				<p class="max-w-[62ch] text-lg leading-relaxed whitespace-pre-line">{ship.reflection}</p>
			</section>
		</div>

		<aside class="flex flex-col gap-8">
			<dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 border-4 border-cream p-4 text-base">
				<dt class="text-dim">recorded</dt>
				<dd>{duration(ship.claimed_seconds)}</dd>
				{#if ship.approved_seconds != null}
					<dt class="text-dim">approved</dt>
					<dd class="font-bold">{duration(ship.approved_seconds)}</dd>
				{/if}
				<dt class="text-dim">worked</dt>
				<dd>{day(ship.started_at, zone)}{ship.ended_at && day(ship.ended_at, zone) !== day(ship.started_at, zone) ? ` to ${day(ship.ended_at, zone)}` : ''}</dd>
				<dt class="text-dim">shipped</dt>
				<dd>{day(ship.submitted_at, zone)}</dd>
				<dt class="text-dim">frames shared</dt>
				<dd>{ship.frames_shared}</dd>
			</dl>

			<section aria-labelledby="log" class="flex flex-col gap-1">
				<h2 id="log" class="text-xl font-bold lowercase">who watched</h2>
				<p class="text-sm text-dim">Every time someone opens your timelapse, it's listed here.</p>
				{#if ship.access_log.length}
					<ul class="text-sm">
						{#each ship.access_log as view, i (view.at + i)}
							<!-- The avatar is the row's marker; the time lines up under the name. -->
							<li class="flex flex-col gap-0.5 py-2" in:fly={{ y: 6, duration: ms(140), delay: stagger(i) }}>
								<span class="flex flex-wrap items-center gap-x-1.5 leading-6">
									<Person name={view.who} avatar={view.avatar_url} admin={view.admin} />
									<span>{view.what}</span>
								</span>
								<span class="pl-8 text-dim" title="{day(view.at, zone)} {clock(view.at, zone)}">{ago(view.at)}</span>
							</li>
						{/each}
					</ul>
				{:else}
					<p class="pt-2 text-sm">No one yet.</p>
				{/if}
			</section>
		</aside>
	</div>
</section>
