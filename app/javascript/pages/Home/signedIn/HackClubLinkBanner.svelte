<script lang="ts">
  import Button from "../../../components/Button.svelte";
  import HackClubLogo from "../../../components/HackClubLogo.svelte";
  import { sessions } from "../../../api";
</script>

<div class="bg-dark border border-primary/40 rounded-xl p-4 md:p-5 mb-4">
  <div
    class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
  >
    <div class="flex items-center gap-3 min-w-0">
      <HackClubLogo class="h-6 w-6 text-surface-content shrink-0" />
      <span class="text-surface-content"
        >Hackatime is moving to Hack Club sign-in only. Link your Hack Club
        account to keep access to this account!</span
      >
    </div>
    <Button
      href={sessions.hcaNew.path()}
      native
      class="rounded-lg shrink-0 w-full md:w-fit">Link Hack Club account</Button
    >
  </div>
</div>
