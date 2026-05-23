<script lang="ts">
  import Section from "./Section.svelte";
  import {
    Icon,
    Clock,
    CodeBracketSquare,
    DocumentText,
    ArrowDownTray,
    UserGroup,
    LockClosed,
    type IconSource,
  } from "svelte-hero-icons";

  const features: { title: string; description: string; icon: IconSource }[] = [
    {
      title: "Time tracking",
      description:
        "Automatic tracking that starts when you type and stops when you take a break. Down to the second.",
      icon: Clock,
    },
    {
      title: "Language stats",
      description:
        "See your actual tech stack. How much Rust vs. how much time debugging config files.",
      icon: CodeBracketSquare,
    },
    {
      title: "File-level insights",
      description:
        "Drill into specific files. Find the ones consuming all your time.",
      icon: DocumentText,
    },
    {
      title: "Zero lock-in",
      description:
        "Your data is yours. Export your entire history to JSON or CSV via the REST API.",
      icon: ArrowDownTray,
    },
    {
      title: "Leaderboards (coming soon)",
      description:
        "Create private leaderboards for your team or hackathon. Compete on consistency.",
      icon: UserGroup,
    },
    {
      title: "Privacy-first",
      description:
        "We don't sell your data. We don't use it for AI training. Just heartbeats and charts.",
      icon: LockClosed,
    },
  ];
</script>

<Section id="features">
  <div class="text-center max-w-[700px] mx-auto mb-12">
    <h2
      class="text-3xl md:text-4xl font-semibold text-surface-content tracking-tight mb-4"
    >
      Everything you need, nothing you don't.
    </h2>
    <p class="text-secondary text-lg text-pretty">
      Granular telemetry for your development environment, delivered via a clean
      dashboard.
    </p>
  </div>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
    {#each features as { title, description, icon }}
      <div class="p-8 bg-surface border border-surface-200 rounded-lg">
        <Icon src={icon} solid size="32" class="text-purple mb-4" />
        <h3 class="text-lg font-semibold text-surface-content mb-2">{title}</h3>
        <p class="text-secondary text-base leading-relaxed">{description}</p>
      </div>
    {/each}
  </div>
</Section>
