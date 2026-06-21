<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import { untrack } from "svelte";
  import Button from "../../components/Button.svelte";
  import Stepper from "./Stepper.svelte";
  import HeartbeatPanel from "./components/HeartbeatPanel.svelte";
  import CodeBlock from "./components/CodeBlock.svelte";
  import NumberedStep from "./components/NumberedStep.svelte";
  import VideoTutorial from "./components/VideoTutorial.svelte";
  import { Icon, InformationCircle } from "svelte-hero-icons";

  interface Props {
    current_user_api_key: string;
    setup_os: string;
    api_url: string;
  }

  let { current_user_api_key, setup_os, api_url }: Props = $props();

  let activeSection = $state(
    untrack(() => (setup_os === "windows" ? "windows" : "mac-linux")),
  );
  const isWindows = $derived(setup_os === "windows");

  const tabBase =
    "flex-1 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]";
  const tabClass = (s: string) =>
    `${tabBase} ${activeSection === s ? "bg-darkless text-surface-content shadow-sm" : "text-secondary hover:text-surface-content"}`;

  const messages = [
    "Copy the command below and run it in your terminal!",
    "Paste the command and press Enter...",
    "The script will configure everything automatically!",
    "Almost there - just run the command!",
    "We'll detect it as soon as the script runs!",
  ];

  const macLinuxSubtitle =
    "This creates your config file and validates your API key. And if you're using VS Code, a JetBrains IDE, Zed, or Xcode, we'll even set up the plugins for you!";
  const windowsSubtitle =
    "This creates your config file and validates your API key. And if you're using VS Code, a JetBrains IDE, or Zed, we'll even set up the plugins for you!";

  const macCmd = $derived(
    `curl -fsSL https://raw.githubusercontent.com/hackclub/hackatime-setup/refs/heads/main/install.sh | bash -s -- ${current_user_api_key}`,
  );
  const winCmd = $derived(
    `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hackclub/hackatime-setup/refs/heads/main/install.ps1))) -ApiKey ${current_user_api_key}`,
  );
  const advancedCfg = $derived(
    `[settings]\napi_url = ${api_url}\napi_key = ${current_user_api_key}\nheartbeat_rate_limit_seconds = 30`,
  );
</script>

<svelte:head>
  <title>Configure Hackatime - Step 1</title>
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={1} />

    <div class="space-y-8">
      <HeartbeatPanel
        apiKey={current_user_api_key}
        waitingTitle="Waiting for setup..."
        {messages}
        sourceType="test_entry"
        recentThresholdSeconds={300}
      >
        {#snippet success({ timeAgo })}
          <div class="text-center py-2">
            <h4 class="text-xl font-bold text-surface-content">
              Setup complete!
            </h4>
            <p class="text-secondary text-sm mb-6">
              Heartbeat detected {timeAgo}.
            </p>
            <Button href="/my/wakatime_setup/step-2" size="lg">
              Continue to Step 2 →
            </Button>
          </div>
        {/snippet}
      </HeartbeatPanel>

      <div class="flex gap-1 p-1 bg-darker border border-darkless rounded-xl">
        <button
          class={tabClass("mac-linux")}
          onclick={() => (activeSection = "mac-linux")}
        >
          macOS / Linux{isWindows ? " / WSL" : ""} / Codespaces
        </button>
        <button
          class={tabClass("windows")}
          onclick={() => (activeSection = "windows")}
        >
          Windows
        </button>
        <button
          class={tabClass("advanced")}
          onclick={() => (activeSection = "advanced")}
        >
          Advanced
        </button>
      </div>

      {#if activeSection === "mac-linux"}
        <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm">
          <div class="mb-6">
            <h3 class="text-xl font-semibold mb-2">Configure Hackatime</h3>
            <p class="text-secondary text-sm">{macLinuxSubtitle}</p>
          </div>

          <div
            class="bg-blue/5 border border-blue/20 rounded-lg p-4 mb-6 flex gap-3"
          >
            <Icon
              src={InformationCircle}
              size="20"
              class="text-blue shrink-0 mt-0.5"
            />
            <div class="text-sm">
              <p class="font-medium text-blue mb-1">Using GitHub Codespaces?</p>
              <p class="text-secondary">
                Look for the <strong>Terminal</strong> tab at the bottom of your
                window. If you don't see it, press
                <kbd
                  class="bg-darkless text-surface-content px-1.5 py-0.5 rounded text-xs font-mono"
                  >Ctrl+`</kbd
                >.
              </p>
            </div>
          </div>

          <div class="space-y-4">
            <NumberedStep n={1} title="Open your terminal">
              <p class="text-sm text-secondary">
                Search for "Terminal" in Spotlight (Mac) or your applications
                menu.
              </p>
            </NumberedStep>
            <NumberedStep n={2} title="Run the install command">
              <div class="mt-2"><CodeBlock code={macCmd} /></div>
            </NumberedStep>
          </div>

          <div class="mt-6">
            <VideoTutorial
              src="https://www.youtube.com/embed/grriwsX5mIo?modestbranding=1&rel=0&t=219"
              iframeTitle="macOS setup video tutorial"
            />
          </div>
        </div>
      {/if}

      {#if activeSection === "windows"}
        <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm">
          <div class="mb-6">
            <h3 class="text-xl font-semibold mb-2">Configure Hackatime</h3>
            <p class="text-secondary text-sm">{windowsSubtitle}</p>
          </div>

          <div class="space-y-4">
            <NumberedStep n={1} title="Open PowerShell">
              <p class="text-sm text-secondary">
                Press <kbd
                  class="bg-darkless text-surface-content px-1.5 py-0.5 rounded text-xs font-mono"
                  >Win+R</kbd
                >, type <code>powershell</code>, and press Enter.
              </p>
            </NumberedStep>
            <NumberedStep n={2} title="Run the install command">
              <p class="text-sm text-secondary mb-2">
                Right-click in PowerShell to paste the command.
              </p>
              <div class="mt-2"><CodeBlock code={winCmd} /></div>
            </NumberedStep>
          </div>

          <div class="mt-6">
            <VideoTutorial
              src="https://www.youtube.com/embed/grriwsX5mIo?modestbranding=1&rel=0&t=54"
              iframeTitle="Windows setup video tutorial"
            />
          </div>
        </div>
      {/if}

      {#if activeSection === "advanced"}
        <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm">
          <div class="mb-6">
            <h3 class="text-xl font-semibold mb-2">Configure Hackatime</h3>
            <p class="text-secondary text-sm">{macLinuxSubtitle}</p>
          </div>

          <div class="bg-purple/10 border border-purple/20 rounded-lg p-4 mb-4">
            <p class="text-sm text-purple">
              Create or edit <code
                class="bg-purple/20 px-1.5 py-0.5 rounded text-surface-content font-mono text-xs"
                >~/.wakatime.cfg</code
              >
              with the following content:
            </p>
          </div>

          <CodeBlock code={advancedCfg} />
        </div>
      {/if}

      <div class="text-center">
        <Link
          href="/my/wakatime_setup/step-2"
          class="text-xs text-secondary hover:text-surface-content transition-colors"
          >Skip to next step</Link
        >
      </div>
    </div>
  </div>
</div>
