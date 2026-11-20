<script lang="ts">
	import * as Tooltip from '#lib/components/ui/tooltip/index.js';

	// A person in the access log: avatar, then name. Admins get HCB's zap
	// tucked against the avatar, and hovering the avatar or name says so.
	let { name, avatar, admin = false }: { name: string; avatar: string | null; admin?: boolean } = $props();
</script>

{#snippet body(props: Record<string, unknown> = {})}
	<span {...props} class="inline-flex items-center align-middle font-medium whitespace-nowrap">
		{#if avatar}
			<img src={avatar} alt="" width="24" height="24" loading="lazy" class="mr-2 size-6 shrink-0 rounded-full bg-panel-2" />
		{:else}
			<span class="mr-2 grid size-6 shrink-0 place-items-center rounded-full bg-panel-2 text-xs" aria-hidden="true">{name.slice(0, 1)}</span>
		{/if}
		{#if admin}
			<!-- HCB's admin-badge.svg, overlapping the avatar's edge. -->
			<svg viewBox="0 0 32 32" class="-mr-[0.2rem] -ml-2.5 h-5 w-6 shrink-0 text-warn" fill="currentColor" aria-hidden="true">
				<path
					fill-rule="evenodd"
					clip-rule="evenodd"
					d="M16.8745 6.04701C17.7913 6.24894 18.4443 7.06137 18.4443 8.00015L18.4443 12.4001H19.9998C20.6823 12.4001 21.3176 12.7481 21.6851 13.3231C22.0525 13.8982 22.1014 14.621 21.8147 15.2403L17.3703 24.8401C16.9759 25.692 16.0421 26.1549 15.1253 25.953C14.2085 25.7511 13.5555 24.9386 13.5555 23.9998V19.5999H12C11.3175 19.5999 10.6822 19.2519 10.3147 18.6769C9.94722 18.1018 9.89835 17.379 10.1851 16.7597L14.6294 7.15993C15.0238 6.30801 15.9577 5.84508 16.8745 6.04701Z"
				/>
			</svg>
		{/if}
		<span>{name}</span>
	</span>
{/snippet}

{#if admin}
	<Tooltip.Root delayDuration={80}>
		<Tooltip.Trigger>
			{#snippet child({ props })}{@render body({ ...props, 'aria-label': `${name} is an admin` })}{/snippet}
		</Tooltip.Trigger>
		<Tooltip.Content sideOffset={6} class="bg-cream text-sm font-medium text-ink" arrowClasses="bg-cream fill-cream">{name} is an admin</Tooltip.Content>
	</Tooltip.Root>
{:else}
	{@render body()}
{/if}
