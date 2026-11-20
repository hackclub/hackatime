<script lang="ts">
	// The diagonal stripe panel: a flat SVG pattern that holds still.
	let { class: className = '' }: { class?: string } = $props();
	const uid = $props.id();
	const id = `stripes-${uid}`;
</script>

<div class="relative overflow-clip border-4 border-cream {className}" aria-hidden="true">
	<svg class="absolute inset-0 size-full">
		<defs>
			<pattern {id} width="44" height="44" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
				<rect width="44" height="44" fill="var(--cream)" />
				<rect width="18" height="44" fill="var(--ink)" />
			</pattern>
		</defs>
		<rect width="100%" height="100%" fill="url(#{id})" />
	</svg>
</div>

