<script lang="ts">
  import { Link } from "@inertiajs/svelte";

  let {
    hoursTracked,
    usersTracked,
  }: {
    hoursTracked: string;
    usersTracked: string;
  } = $props();
</script>

<section class="py-24 w-full bg-primary">
  <div class="max-w-[1100px] mx-auto px-6 text-center">
    <h2
      class="text-3xl md:text-4xl font-semibold text-on-primary tracking-tight mb-4"
    >
      Start tracking your code.
    </h2>
    <p class="text-on-primary/90 text-lg mb-10">
      Join {usersTracked} users who have tracked {hoursTracked}+ hours of coding
      with Hackatime.
    </p>
    <Link
      href="/signin"
      class="inline-flex items-center justify-center px-10 py-3.5 bg-surface text-primary rounded-md font-semibold text-lg hover:bg-surface-100 transition-colors"
    >
      Create free account
    </Link>
    <div class="mt-6 text-sm text-on-primary/80">
      No credit card required · Open source (MIT)
    </div>
  </div>
</section>
