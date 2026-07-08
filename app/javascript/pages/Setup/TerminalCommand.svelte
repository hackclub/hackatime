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

  type OsKey = "windows" | "mac" | "linux" | "wsl";

  const OS_TABS: { key: OsKey; label: string }[] = [
    { key: "windows", label: "Windows" },
    { key: "mac", label: "macOS" },
    { key: "linux", label: "Linux" },
    { key: "wsl", label: "WSL" },
  ];

  function normalizeOs(value: string): OsKey {
    return value === "windows" || value === "mac" || value === "linux"
      ? value
      : "mac";
  }

  let os: OsKey = $state(untrack(() => normalizeOs(setupOs)));

  const macCmd = $derived(
    `curl -fsSL https://raw.githubusercontent.com/hackclub/hackatime-setup/refs/heads/main/install.sh | bash -s -- ${apiKey}`,
  );
  const winCmd = $derived(
    `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hackclub/hackatime-setup/refs/heads/main/install.ps1))) -ApiKey ${apiKey}`,
  );

  const isWindows = $derived(os === "windows");
  const command = $derived(isWindows ? winCmd : macCmd);
  const videoTime = $derived(isWindows ? 54 : 219);

  // How to open a terminal and paste, per operating system.
  const INSTRUCTIONS: Record<OsKey, { open: string; paste: string }> = {
    windows: {
      open: 'Open the Start menu, type "PowerShell", and open Windows PowerShell (or Windows Terminal).',
      paste: "right-click the window (or press Ctrl + V)",
    },
    mac: {
      open: 'Open Spotlight with ⌘ + Space, type "Terminal", and press Enter.',
      paste: "press ⌘ + V",
    },
    linux: {
      open: 'Open your terminal - try Ctrl + Alt + T, or search "Terminal" in your apps.',
      paste: "press Ctrl + Shift + V",
    },
    wsl: {
      open: "Open Windows Terminal (or PowerShell) and type wsl to drop into your Linux distro.",
      paste: "press Ctrl + Shift + V",
    },
  };

  const steps = $derived([
    INSTRUCTIONS[os].open,
    `Copy the command below, paste it into the terminal (${INSTRUCTIONS[os].paste}), then press Enter.`,
  ]);

  const toggleBase = "flex-1 rounded-lg px-3 py-2 text-sm font-medium sm:px-4";
  const toggleClass = (value: string) =>
    `${toggleBase} ${os === value ? "bg-surface-300 text-surface-content" : "text-secondary hover:text-surface-content"}`;
</script>

<div class="space-y-8 sm:space-y-10">
  <ScreenHeader
    emoji="/images/emojis/ms-lightning.svg"
    title="Let's do it!"
    html="<b>Pick your operating system</b>, then follow the steps to run the setup command. It installs Hackatime and your editor plugins for you."
  />

  <div class="mx-auto max-w-2xl space-y-4">
    <div
      class="flex gap-1 rounded-xl border border-surface-300 bg-surface-100 p-1"
    >
      {#each OS_TABS as tab (tab.key)}
        <button class={toggleClass(tab.key)} onclick={() => (os = tab.key)}>
          {tab.label}
        </button>
      {/each}
    </div>

    <ol class="space-y-3 text-left">
      {#each steps as instruction, index (index)}
        <li class="flex items-start gap-3">
          <span
            class="flex size-6 shrink-0 items-center justify-center rounded-full bg-surface-300 text-xs font-semibold text-surface-content"
          >
            {index + 1}
          </span>
          <span class="text-sm text-secondary">{instruction}</span>
        </li>
      {/each}
    </ol>

    <SetupCodeBlock code={command} />

    <VideoTutorial
      src={`https://www.youtube.com/embed/grriwsX5mIo?modestbranding=1&rel=0&t=${videoTime}`}
      iframeTitle="Hackatime setup video tutorial"
    />
  </div>

  <div class="text-center">
    <Button variant="dark" size="lg" onclick={onDone}>I'm done!</Button>
  </div>
</div>
