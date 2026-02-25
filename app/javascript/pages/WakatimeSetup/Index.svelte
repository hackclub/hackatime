<script lang="ts">
  import { onMount } from "svelte";
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Stepper from "./Stepper.svelte";

  interface Props {
    current_user_api_key: string;
    setup_os: string;
    api_url: string;
    heartbeat_check_url: string;
  }

  let { current_user_api_key, setup_os, api_url, heartbeat_check_url }: Props =
    $props();

  let activeSection = $state(setup_os === "windows" ? "windows" : "mac-linux");
  let isWindows = setup_os === "windows";

  const tabBase =
    "flex-1 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)]";
  const tabActive = "bg-darkless text-surface-content shadow-sm";
  const tabInactive = "text-secondary hover:text-surface-content";
  function tabClass(section: string) {
    return `${tabBase} ${activeSection === section ? tabActive : tabInactive}`;
  }

  let hasHeartbeat = $state(false);
  let heartbeatTimeAgo = $state("");
  let checkCount = $state(0);
  let statusMessage = $state(
    "Run the command below, then we'll automatically detect when you're ready.",
  );
  let statusPanelClass = $state("border-darkless");

  const messages = [
    "Copy the command below and run it in your terminal!",
    "Paste the command and press Enter...",
    "The script will configure everything automatically!",
    "Almost there - just run the command!",
    "We'll detect it as soon as the script runs!",
  ];

  const sharedTitle = "Configure Hackatime";
  const macLinuxSubtitle =
    "This creates your config file and validates your API key. And if you're using VS Code, a JetBrains IDE, Zed, or Xcode, we'll even set up the plugins for you!";
  const windowsSubtitle =
    "This creates your config file and validates your API key. And if you're using VS Code, a JetBrains IDE, or Zed, we'll even set up the plugins for you!";
  const advancedSubtitle = windowsSubtitle;

  function showSuccess(timeAgo: string) {
    hasHeartbeat = true;
    heartbeatTimeAgo = timeAgo;
    statusPanelClass = "border-green bg-green/5";
  }

  async function checkHeartbeat() {
    try {
      const response = await fetch(heartbeat_check_url, {
        headers: {
          Authorization: `Bearer ${current_user_api_key}`,
        },
      });
      const data = await response.json();

      if (data.has_heartbeat) {
        const heartbeatTime = new Date(data.heartbeat.created_at);
        const now = new Date();
        const secondsAgo = (now.getTime() - heartbeatTime.getTime()) / 1000;
        const recentThreshold = 300;

        if (secondsAgo <= recentThreshold) {
          showSuccess(data.time_ago);
          return;
        }
      }
      throw new Error("No heartbeats yet");
    } catch (error) {
      checkCount++;

      if (checkCount % 3 === 0) {
        const msgIndex = Math.floor(checkCount / 3) % messages.length;
        statusMessage = messages[msgIndex];
      }
    }
  }

  onMount(() => {
    checkHeartbeat();
    const interval = setInterval(() => {
      if (!hasHeartbeat) {
        checkHeartbeat();
      }
    }, 5000);
    return () => clearInterval(interval);
  });
</script>

<svelte:head>
  <title>Configure Hackatime - Step 1</title>
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={1} />

    <div class="space-y-8">
      <div
        class="border border-darkless rounded-xl p-6 bg-dark transition-all duration-300 {statusPanelClass}"
      >
        {#if !hasHeartbeat}
          <div
            class="flex flex-col items-center justify-center text-center py-2"
          >
            <h4 class="text-lg font-semibold text-surface-content mb-1">
              Waiting for setup...
            </h4>
            <p class="text-sm text-secondary mb-4 max-w-sm">{statusMessage}</p>
          </div>
        {:else}
          <div class="text-center py-2">
            <h4 class="text-xl font-bold text-surface-content">
              Setup complete!
            </h4>
            <p class="text-secondary text-sm mb-6">
              Heartbeat detected {heartbeatTimeAgo}.
            </p>

            <Button href="/my/wakatime_setup/step-2" size="lg">
              Continue to Step 2 →
            </Button>
          </div>
        {/if}
      </div>

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
            <h3 class="text-xl font-semibold mb-2">{sharedTitle}</h3>
            <p class="text-secondary text-sm">{macLinuxSubtitle}</p>
          </div>

          <div
            class="bg-blue/5 border border-blue/20 rounded-lg p-4 mb-6 flex gap-3"
          >
            <svg
              class="w-5 h-5 text-blue shrink-0 mt-0.5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
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
            <div class="flex items-start gap-4">
              <div
                class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
              >
                1
              </div>
              <div>
                <p class="font-medium mb-1">Open your terminal</p>
                <p class="text-sm text-secondary">
                  Search for "Terminal" in Spotlight (Mac) or your applications
                  menu.
                </p>
              </div>
            </div>

            <div class="flex items-start gap-4">
              <div
                class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
              >
                2
              </div>
              <div class="w-full">
                <p class="font-medium mb-1">Run the install command</p>
                <div class="relative group mt-2">
                  <div
                    class="bg-darker border border-darkless rounded-lg overflow-x-auto"
                  >
                    <pre
                      class="p-4 pr-20 text-sm font-mono text-cyan whitespace-pre-wrap break-all"><code
                        >curl -fsSL https://hack.club/setup/install.sh | bash -s -- {current_user_api_key}</code
                      ></pre>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 pt-6 border-t border-darkless">
            <details class="group">
              <summary
                class="cursor-pointer text-sm text-secondary hover:text-surface-content flex items-center gap-2 transition-colors"
              >
                <svg
                  class="w-4 h-4 transition-transform group-open:rotate-90"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
                Watch video tutorial
              </summary>
              <div
                class="mt-4 rounded-lg overflow-hidden border border-darkless"
              >
                <iframe
                  title="macOS setup video tutorial"
                  width="100%"
                  height="300"
                  src="https://www.youtube.com/embed/QTwhJy7nT_w?modestbranding=1&rel=0"
                  frameborder="0"
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowfullscreen
                ></iframe>
              </div>
            </details>
          </div>
        </div>
      {/if}

      {#if activeSection === "windows"}
        <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm">
          <div class="mb-6">
            <h3 class="text-xl font-semibold mb-2">{sharedTitle}</h3>
            <p class="text-secondary text-sm">{windowsSubtitle}</p>
          </div>

          <div class="space-y-4">
            <div class="flex items-start gap-4">
              <div
                class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
              >
                1
              </div>
              <div>
                <p class="font-medium mb-1">Open PowerShell</p>
                <p class="text-sm text-secondary">
                  Press <kbd
                    class="bg-darkless text-surface-content px-1.5 py-0.5 rounded text-xs font-mono"
                    >Win+R</kbd
                  >, type <code>powershell</code>, and press Enter.
                </p>
              </div>
            </div>

            <div class="flex items-start gap-4">
              <div
                class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
              >
                2
              </div>
              <div class="w-full">
                <p class="font-medium mb-1">Run the install command</p>
                <p class="text-sm text-secondary mb-2">
                  Right-click in PowerShell to paste the command.
                </p>
                <div class="relative group mt-2">
                  <div
                    class="bg-darker border border-darkless rounded-lg overflow-x-auto"
                  >
                    <pre
                      class="p-4 pr-20 text-sm font-mono text-cyan whitespace-pre-wrap break-all"><code
                        >& ([scriptblock]::Create((irm https://hack.club/setup/install.ps1))) -ApiKey {current_user_api_key}</code
                      ></pre>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 pt-6 border-t border-darkless">
            <details class="group">
              <summary
                class="cursor-pointer text-sm text-secondary hover:text-surface-content flex items-center gap-2 transition-colors"
              >
                <svg
                  class="w-4 h-4 transition-transform group-open:rotate-90"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
                Watch video tutorial
              </summary>
              <div
                class="mt-4 rounded-lg overflow-hidden border border-darkless"
              >
                <iframe
                  title="Windows setup video tutorial"
                  width="100%"
                  height="300"
                  src="https://www.youtube.com/embed/fX9tsiRvzhg?modestbranding=1&rel=0"
                  frameborder="0"
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowfullscreen
                ></iframe>
              </div>
            </details>
          </div>
        </div>
      {/if}

      {#if activeSection === "advanced"}
        <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm">
          <div class="mb-6">
            <h3 class="text-xl font-semibold mb-2">{sharedTitle}</h3>
            <p class="text-secondary text-sm">{advancedSubtitle}</p>
          </div>

          <div class="bg-purple/10 border border-purple/20 rounded-lg p-4 mb-4">
            <p class="text-sm text-purple">
              Create or edit <code
                class="bg-purple/20 px-1.5 py-0.5 rounded text-surface-content font-mono text-xs"
                >~/.wakatime.cfg</code
              > with the following content:
            </p>
          </div>

          <div class="relative group">
            <div
              class="bg-darker border border-darkless rounded-lg overflow-x-auto"
            >
              <pre
                class="p-4 pr-20 text-sm font-mono text-cyan whitespace-pre-wrap break-all"><code
                  >[settings]
api_url = {api_url}
api_key = {current_user_api_key}
heartbeat_rate_limit_seconds = 30</code
                ></pre>
            </div>
          </div>
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
