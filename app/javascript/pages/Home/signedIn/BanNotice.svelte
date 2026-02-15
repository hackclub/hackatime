<script lang="ts">
  import { Link } from "@inertiajs/svelte";
</script>

<div class="text-primary bg-red-500/10 border-2 border-red-500/20 p-4 text-center rounded-lg mb-4">
  <div class="flex items-center justify-center">
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 16 16"><path fill="currentColor" fill-rule="evenodd" d="M8 14.5a6.5 6.5 0 1 0 0-13a6.5 6.5 0 0 0 0 13M8 16A8 8 0 1 0 8 0a8 8 0 0 0 0 16m1-5a1 1 0 1 1-2 0a1 1 0 0 1 2 0m-.25-6.25a.75.75 0 0 0-1.5 0v3.5a.75.75 0 0 0 1.5 0z" clip-rule="evenodd" /></svg>
    <span class="text-3xl font-bold block ml-2">Hold up! Your account has been banned for suspicious activity.</span>
  </div>
  <div>
    <p class="text-primary text-left text-lg mb-2"><b>What does this mean?</b> Your account was convicted for fraud or abuse of Hackatime, such as using methods to gain an unfair advantage on the leaderboards or attempting to manipulate your coding time in any way. This restricts your access to participate in public leaderboards, but Hackatime will still track and display your time. This may also affect your ability to participate in current and future Hack Club events.</p>
    <p class="text-primary text-left text-lg mb-2"><b>What can I do?</b> Account bans are non-negotiable, and will not be removed unless determined to have been issued incorrectly. In that case, it will automatically be removed. We take fraud very seriously and have a zero-tolerance policy for abuse. If you believe this was a mistake, please DM the <Link href="https://hackclub.slack.com/team/U091HC53CE8" target="_blank" class="underline">Fraud Department</Link> on Slack. We do not respond in any other channel, DM or thread.</p>
    <p class="text-primary text-left text-lg mb-0"><b>Can I know what caused this?</b> No. We do not disclose the patterns that were detected. Releasing this information would only benefit fraudsters. The fraud team regularly investigates claims of false bans to increase the effectiveness of our detection systems to combat fraud.</p>
  </div>
</div>
