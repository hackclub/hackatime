<script lang="ts">
  import Button from "../../components/Button.svelte";
  import ScreenHeader from "./components/ScreenHeader.svelte";

  interface Props {
    emoji: string;
    title: string;
    subtitle: string;
    lead: string;
    url: string;
    urlLabel: string;
    onDone: () => void;
    helpText?: string;
    helpUrl?: string;
    helpLabel?: string;
  }

  let {
    emoji,
    title,
    subtitle,
    lead,
    url,
    urlLabel,
    onDone,
    helpText,
    helpUrl,
    helpLabel,
  }: Props = $props();
</script>

<div class="space-y-8 sm:space-y-10">
  <ScreenHeader {emoji} {title} {subtitle} />

  <div class="text-center">
    <p class="text-base font-semibold sm:text-lg">{lead}</p>
    <p class="mt-2">
      <a
        href={url}
        target="_blank"
        rel="noreferrer"
        class="text-xl font-semibold tracking-tight break-all text-primary underline underline-offset-4 sm:text-3xl"
      >
        {urlLabel}
      </a>
    </p>
    {#if helpUrl}
      <p class="mt-6 text-sm text-muted">
        {helpText}
        <a
          href={helpUrl}
          target="_blank"
          rel="noreferrer"
          class="font-medium text-primary underline underline-offset-4"
        >
          {helpLabel}
        </a>
      </p>
    {/if}
    <div class="mt-8">
      <Button variant="dark" size="lg" onclick={onDone}>Continue</Button>
    </div>
  </div>
</div>
