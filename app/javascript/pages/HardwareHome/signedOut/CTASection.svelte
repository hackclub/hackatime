<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Section from "./Section.svelte";

  let {
    hoursTracked,
    usersTracked,
  }: { hoursTracked: string; usersTracked: string } = $props();
</script>

<Section bg="bg-primary" py="py-24">
  <div class="text-center">
    <h2
      class="text-3xl md:text-4xl font-semibold text-on-primary tracking-tight mb-4"
    >
      Start tracking your designing.
    </h2>
    <p class="text-on-primary/90 text-lg mb-10">
      Join {usersTracked} users who have tracked {hoursTracked}+ hours of
      development with Hackatime.
    </p>
    <Link
      href="/signin"
      class="inline-flex items-center justify-center px-10 py-3.5 bg-surface text-primary rounded-md font-semibold text-lg hover:bg-surface-100 transition-colors"
    >
      Create free account
    </Link>
    <div class="mt-6 text-sm text-on-primary/80">
      Free to use, forever · Open source (MIT)
    </div>
  </div>
</Section>
