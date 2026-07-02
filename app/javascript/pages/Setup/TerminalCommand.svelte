<script lang="ts">
  import { untrack } from "svelte";
  import Button from "../../components/Button.svelte";
  import ScreenHeader from "./components/ScreenHeader.svelte";
  import SetupCodeBlock from "./components/SetupCodeBlock.svelte";
  import VideoTutorial from "./components/VideoTutorial.svelte";

  interface Props {
    apiKey: string;
    setupOs: string;
    onDone: () => void;
  }

  let { apiKey, setupOs, onDone }: Props = $props();

  const isWindowsUa = $derived(setupOs === "windows");
  let os = $state(untrack(() => (setupOs === "windows" ? "windows" : "mac")));

  const macCmd = $derived(
    `curl -fsSL https://raw.githubusercontent.com/hackclub/hackatime-setup/refs/heads/main/install.sh | bash -s -- ${apiKey}`,
  );
  const winCmd = $derived(
    `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hackclub/hackatime-setup/refs/heads/main/install.ps1))) -ApiKey ${apiKey}`,
  );

  const toggleBase = "flex-1 rounded-lg px-4 py-2 text-sm font-medium";
  const toggleClass = (value: string) =>
    `${toggleBase} ${os === value ? "bg-surface-300 text-surface-content" : "text-secondary hover:text-surface-content"}`;
</script>

<div class="space-y-8 sm:space-y-10">
  <ScreenHeader
    emoji="/images/emojis/ms-lightning.svg"
    title="Let's do it!"
    subtitle="Paste this command in your terminal and press Enter. It sets up Hackatime and installs the editor plugins for you."
  />

  <div class="mx-auto max-w-2xl space-y-4">
    <div
      class="flex gap-1 rounded-xl border border-surface-300 bg-surface-100 p-1"
    >
      <button class={toggleClass("mac")} onclick={() => (os = "mac")}>
        macOS / Linux{isWindowsUa ? " / WSL" : ""}
      </button>
      <button class={toggleClass("windows")} onclick={() => (os = "windows")}>
        Windows
      </button>
    </div>

    <SetupCodeBlock code={os === "windows" ? winCmd : macCmd} />

    <VideoTutorial
      src={`https://www.youtube.com/embed/grriwsX5mIo?modestbranding=1&rel=0&t=${os === "windows" ? 54 : 219}`}
      iframeTitle="Hackatime setup video tutorial"
    />
  </div>

  <div class="text-center">
    <Button variant="dark" size="lg" onclick={onDone}>I'm done!</Button>
  </div>
</div>
