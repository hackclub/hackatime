<script lang="ts">
  import type InertiaSspUser from "../../../types/serializers/Inertia/SspUser";
  import SocialProofUsers from "./SocialProofUsers.svelte";

  let {
    wakatime_setup_path,
    ssp_message,
    ssp_users_recent,
    ssp_users_size,
  }: {
    wakatime_setup_path: string;
    ssp_message?: string | null;
    ssp_users_recent: InertiaSspUser[];
    ssp_users_size: number;
  } = $props();
</script>

<div class="text-left my-8 flex flex-col">
  <p class="mb-4 text-xl text-primary">
    Hello friend! Looks like you are new around here, let's get you set up
    so you can start tracking your coding time.
  </p>
  <a
    href={wakatime_setup_path}
    class="inline-block w-auto text-3xl font-bold px-8 py-4 bg-primary text-white rounded shadow-md hover:shadow-lg hover:-translate-y-1 transition-all duration-300 animate-pulse"
    >Let's setup Hackatime! Click me :D</a
  >
  <SocialProofUsers
    users={ssp_users_recent}
    total_size={ssp_users_size}
    message={ssp_message}
  />
</div>
