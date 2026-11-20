<script lang="ts">
	import type { Overview } from '#lib/server/hackatime.js';
	import { duration } from '#lib/format.js';
	import { ms } from '#lib/motion.js';

	// The student's own numbers, drawn flat: four figures, a two-week bar
	// chart (today in the accent colour) and this week's top projects.
	let { stats, today }: { stats: Overview['stats']; today: number } = $props();

	const peak = $derived(Math.max(3600, ...stats.days.map((d) => d.seconds)));
	const lines = $derived(stats.human_lines + stats.ai_lines);
	const yours = $derived(lines ? Math.round((stats.human_lines / lines) * 100) : null);
	const topProject = $derived(Math.max(1, ...stats.projects.map((p) => p.seconds)));
	const weekday = (iso: string) => new Date(`${iso}T12:00:00`).toLocaleDateString('en-GB', { weekday: 'narrow' });
	const label = (iso: string) => new Date(`${iso}T12:00:00`).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' });
	let hovered = $state<number | null>(null);
	const shown = $derived(hovered == null ? null : stats.days[hovered]);
</script>

<section aria-labelledby="stats-heading" class="flex flex-col gap-6">
	<h2 id="stats-heading" class="sr-only">Your stats</h2>
	<dl class="grid grid-cols-2 border-4 border-cream sm:grid-cols-4">
		{#each [{ k: 'today', v: duration(today) }, { k: 'this week', v: duration(stats.week_seconds) }, { k: 'approved', v: duration(stats.approved_seconds) }, { k: 'written by you', v: yours == null ? '–' : `${yours}%` }] as stat, i (stat.k)}
			<div class="flex flex-col gap-1 p-4 {i % 2 ? 'border-l-4 border-cream' : ''} {i >= 2 ? 'max-sm:border-t-4 sm:border-l-4' : ''} border-cream">
				<dt class="text-sm text-dim">{stat.k}</dt>
				<dd class="text-3xl leading-none font-bold tabular-nums">{stat.v}</dd>
			</div>
		{/each}
	</dl>

	<div class="flex flex-col gap-2">
		<div class="flex items-baseline justify-between gap-4">
			<h3 class="text-xl font-bold lowercase">last two weeks</h3>
			<p class="text-sm text-dim tabular-nums" aria-live="polite">
				{shown ? `${label(shown.date)} · ${duration(shown.seconds)}` : `peak ${duration(Math.max(...stats.days.map((d) => d.seconds)))}`}
			</p>
		</div>
		<ol class="flex h-40 items-end gap-1 border-b-4 border-cream" aria-label="Time recorded per day">
			{#each stats.days as day, i (day.date)}
				<li class="group flex h-full flex-1 flex-col justify-end" onpointerenter={() => (hovered = i)} onpointerleave={() => (hovered = null)}>
					<span class="sr-only">{label(day.date)}: {duration(day.seconds)}</span>
					<span
						class="bar block w-full {i === stats.days.length - 1 ? 'bg-link' : 'bg-cream'} {hovered != null && hovered !== i ? 'opacity-40' : ''}"
						style:height="{day.seconds ? Math.max(4, (day.seconds / peak) * 100) : 0}%"
						style:animation-duration="{ms(160)}ms"
						style:animation-delay="{ms(i * 12)}ms"
						aria-hidden="true"
					></span>
				</li>
			{/each}
		</ol>
		<div class="flex gap-1 text-xs text-dim" aria-hidden="true">
			{#each stats.days as day (day.date)}<span class="flex-1 text-center">{weekday(day.date)}</span>{/each}
		</div>
	</div>

	{#if stats.projects.length}
		<div class="flex flex-col gap-2">
			<h3 class="text-xl font-bold lowercase">this week's projects</h3>
			<ul class="flex flex-col gap-2">
				{#each stats.projects as project (project.project)}
					<li class="grid grid-cols-[minmax(0,10rem)_1fr_auto] items-center gap-3">
						<span class="truncate">{project.project}</span>
						<span class="h-3 bg-panel-2" aria-hidden="true"><span class="bar-x block h-full bg-cream" style:width="{(project.seconds / topProject) * 100}%" style:animation-duration="{ms(160)}ms"></span></span>
						<span class="text-sm text-dim tabular-nums">{duration(project.seconds)}</span>
					</li>
				{/each}
			</ul>
		</div>
	{/if}
</section>

<style>
	.bar {
		transform-origin: bottom;
		animation: grow var(--ease) both;
		transition: opacity var(--fast) var(--ease);
	}
	.bar-x {
		transform-origin: left;
		animation: grow-x var(--ease) both;
	}
	@keyframes grow {
		from {
			transform: scaleY(0);
		}
	}
	@keyframes grow-x {
		from {
			transform: scaleX(0);
		}
	}
</style>
