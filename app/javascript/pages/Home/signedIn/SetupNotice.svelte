<script lang="ts">
  import Button from "../../../components/Button.svelte";
  import SocialProofUsers from "./SocialProofUsers.svelte";

  type SocialProofUser = { display_name: string; avatar_url: string };

  let {
    wakatime_setup_path,
    ssp_message,
    ssp_users_recent,
    ssp_users_size,
  }: {
    wakatime_setup_path: string;
    ssp_message?: string | null;
    ssp_users_recent: SocialProofUser[];
    ssp_users_size: number;
  } = $props();
</script>

<div class="text-left mt-2 mb-4 flex flex-col">
  <p class="mb-4 text-xl text-primary">
    Hello friend! Looks like you are new around here, let's get you set up so
    you can start tracking your coding time.
  </p>
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
        href={wakatime_setup_path}
        size="lg"
        class="w-full md:w-auto shrink-0"
        >Let&apos;s setup Hackatime! Click me :D</Button
      >
    </div>
  </div>
  <SocialProofUsers
    users={ssp_users_recent}
    total_size={ssp_users_size}
    message={ssp_message}
  />
</div>
