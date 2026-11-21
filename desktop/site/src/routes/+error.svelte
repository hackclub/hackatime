<script lang="ts">
	import { page } from '$app/state';
	import Headline from '#lib/components/site/Headline.svelte';
	import { Button } from '#lib/components/ui/button/index.js';
</script>

<svelte:head><title>{page.status} · Hackatime Desktop</title></svelte:head>

<section class="flex max-w-[720px] flex-col gap-6">
	<Headline text={page.status === 404 ? 'not here' : 'oops'} />
	<p class="text-xl leading-snug">
		{page.status === 404 ? "There's nothing at this address." : (page.error?.message ?? 'Something went wrong.')}
	</p>
	<div><Button href="/" size="lg">Go Home</Button></div>
</section>
