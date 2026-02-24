<script lang="ts">
  import { Link } from "@inertiajs/svelte";
</script>

<footer class="py-16 w-full bg-surface">
  <div class="max-w-275 mx-auto px-6">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
      <div class="md:col-span-1">
        <a href="/" class="flex items-center gap-2 mb-4">
          <img
            src="/images/new-icon-rounded.png"
            class="w-8 h-8 rounded-lg"
            alt="Hackatime"
          />
          <span class="font-bold text-xl tracking-tight">Hackatime</span>
        </a>
        <p class="text-sm text-secondary max-w-[35ch] leading-relaxed">
          A project by Hack Club. We build tools, community, and events for the
          next generation of hackers.
        </p>
      </div>
      <div>
        <h5
          class="text-xs uppercase tracking-wider text-muted font-semibold mb-4"
        >
          Platform
        </h5>
        <div class="space-y-3">
          <Link
            href="/docs"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >Documentation</Link
          >
          <a
            href="/leaderboards"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >Leaderboards</a
          >
          <Link
            href="/docs/editors/vs-code"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >Editor Setup</Link
          >
        </div>
      </div>
      <div>
        <h5
          class="text-xs uppercase tracking-wider text-muted font-semibold mb-4"
        >
          Community
        </h5>
        <div class="space-y-3">
          <a
            href="https://hackclub.com/slack"
            target="_blank"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >Slack</a
          >
          <a
            href="https://github.com/hackclub/hackatime"
            target="_blank"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >GitHub</a
          >
          <a
            href="https://hackclub.com"
            target="_blank"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >Hack Club</a
          >
        </div>
      </div>
      <div>
        <h5
          class="text-xs uppercase tracking-wider text-muted font-semibold mb-4"
        >
          Legal
        </h5>
        <div class="space-y-3">
          <a
            href="https://hackclub.com/privacy-and-terms"
            target="_blank"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >Privacy & Terms</a
          >
          <a
            href="https://hackclub.com/conduct"
            target="_blank"
            class="block text-sm text-secondary hover:text-primary transition-colors"
            >Code of Conduct</a
          >
        </div>
      </div>
    </div>
  </div>
</footer>
