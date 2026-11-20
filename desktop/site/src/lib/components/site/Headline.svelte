<script lang="ts">
	// The page title: big, flat and straight, sliding in fast.
	let { text }: { text: string } = $props();
</script>

<h1 class="headline text-[clamp(2.5rem,6vw,4.75rem)] leading-[0.95] font-bold tracking-tight lowercase break-words">
	{text}
</h1>

<style>
	.headline {
		animation: in 160ms cubic-bezier(0.2, 0.8, 0.2, 1) both;
	}
	@keyframes in {
		from {
			transform: translateX(16px);
			opacity: 0;
		}
	}
</style>
