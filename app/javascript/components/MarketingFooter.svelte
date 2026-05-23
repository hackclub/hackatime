<script lang="ts">
  import { Link } from "@inertiajs/svelte";

  type FooterLink = {
    label: string;
    href: string;
    inertia?: boolean;
    external?: boolean;
  };
  type FooterSection = { title: string; links: FooterLink[] };

  const sections: FooterSection[] = [
    {
      title: "Platform",
      links: [
        { label: "Documentation", href: "/docs", inertia: true },
        { label: "Leaderboards", href: "/leaderboards" },
        { label: "Editor Setup", href: "/docs/editors/vs-code", inertia: true },
      ],
    },
    {
      title: "Community",
      links: [
        { label: "Slack", href: "https://hackclub.com/slack", external: true },
        {
          label: "GitHub",
          href: "https://github.com/hackclub/hackatime",
          external: true,
        },
        { label: "Hack Club", href: "https://hackclub.com", external: true },
      ],
    },
    {
      title: "Legal",
      links: [
        {
          label: "Privacy & Terms",
          href: "https://hackclub.com/privacy-and-terms",
          external: true,
        },
        {
          label: "Code of Conduct",
          href: "https://hackclub.com/conduct",
          external: true,
        },
      ],
    },
  ];

  const linkCls =
    "block text-sm text-secondary hover:text-primary transition-colors";
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
      {#each sections as section}
        <div>
          <h5
            class="text-xs uppercase tracking-wider text-muted font-semibold mb-4"
          >
            {section.title}
          </h5>
          <div class="space-y-3">
            {#each section.links as link}
              {#if link.inertia}
                <Link href={link.href} class={linkCls}>{link.label}</Link>
              {:else}
                <a
                  href={link.href}
                  target={link.external ? "_blank" : undefined}
                  class={linkCls}>{link.label}</a
                >
              {/if}
            {/each}
          </div>
        </div>
      {/each}
    </div>
  </div>
</footer>
