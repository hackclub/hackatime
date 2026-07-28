<script lang="ts">
  import Button from "../../../components/Button.svelte";
  import { users } from "../../../api";
</script>

<div class="text-left mt-2 mb-4 flex flex-col">
  <div
    class="mb-4 rounded-xl border border-primary/40 bg-surface-100/70 p-4 md:p-5"
  >
    <div
      class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
    >
      <p class="m-0 text-base font-medium text-surface-content">
        Finish setup once and we&apos;ll start tracking your coding time
        automatically.
      </p>
      <Button
        href={users.setup.path()}
        size="lg"
        class="w-full md:w-auto shrink-0"
      >
        Let&apos;s setup Hackatime! Click me :D
      </Button>
    </div>
  </div>
</div>
