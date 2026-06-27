<script lang="ts">
  import { Checkbox } from "bits-ui";
  import { Link, router } from "@inertiajs/svelte";
  import { onMount, untrack } from "svelte";
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
    skip_setup_flow?: boolean;
    return_url?: string;
    return_button_text?: string;
  }

  let {
    current_user_api_key,
    setup_os,
    api_url,
    skip_setup_flow,
    return_url,
    return_button_text,
  }: Props = $props();

  let agreed = $state(false);

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
  <title
    >{skip_setup_flow
      ? "Setup Complete - Step 4"
      : "Configure Hackatime - Step 1"}</title
  >
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={skip_setup_flow ? 4 : 1} />

    {#if skip_setup_flow}
      <div class="space-y-6">
        <div class="bg-blue/5 border border-blue/20 rounded-xl p-5 flex gap-3">
          <Icon
            src={InformationCircle}
            size="22"
            class="text-blue shrink-0 mt-0.5"
          />
          <div class="text-sm">
            <p class="font-semibold text-blue mb-1">
              No code editor setup needed
            </p>
            <p class="text-secondary">
              Since you're joining through a hardware program, you don't need to
              set up a code editor right now. If you'd like to connect one
              later, you can always do so from
              <Link
                href="/my/wakatime_setup"
                class="text-primary underline hover:text-primary/80"
                >My&nbsp;Setup</Link
              > on your dashboard.
            </p>
          </div>
        </div>

        <div class="bg-dark border border-darkless rounded-xl p-6 text-center">
          <h1 class="text-lg font-bold mb-2">You're all set!</h1>
          <p class="mb-8 text-sm">
            Hackatime is configured and tracking your code.
          </p>

          <div class="bg-yellow text-black rounded-xl p-6 mb-8 text-left">
            <h3 class="font-bold mb-2">Fair Play Policy</h3>
            <p class="text-sm mb-3">
              Hackatime tracks the time you actually work on projects. Fraud
              means trying to make it look like you're working when you are not,
              including using scripts, bots, manipulated heartbeats, spoofed
              editor activity, or API abuse.
            </p>
            <p class="text-sm">
              We have a zero-tolerance policy for fraud. Attempting to cheat the
              system can result in a <strong>permanent ban</strong> from
              Hackatime and all Hack Club events. Read the full policy on the
              <a
                href="https://fraud.hackclub.com/fairplay"
                target="_blank"
                rel="noreferrer"
                class="underline font-semibold"
              >
                >Fraud page</a
              >.
            </p>
            <p class="text-sm mt-3">
              Hack Club is a non-profit running on donations, so please keep
              your activity honest and respect the community.
            </p>

            <div
              class="mt-2 pt-6 border-t border-yellow/10 flex justify-center"
            >
              <label
                class="flex items-center gap-3 cursor-pointer select-none group"
              >
                <Checkbox.Root
                  bind:checked={agreed}
                  class="inline-flex h-5 w-5 min-w-5 items-center justify-center rounded border border-darkless bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary"
                >
                  {#snippet children({ checked })}
                    <span
                      class={checked
                        ? "text-xs font-bold leading-none"
                        : "hidden"}>✓</span
                    >
                  {/snippet}
                </Checkbox.Root>
                <span class="font-medium"
                  >I understand and agree to the rules</span
                >
              </label>
            </div>
          </div>

          <Button
            href={return_url ?? "/"}
            size="xl"
            class="w-full sm:w-auto transition-all font-semibold transform active:scale-[0.98] text-center {agreed
              ? ''
              : 'opacity-50 cursor-not-allowed pointer-events-none'}"
          >
            {return_url ? (return_button_text ?? "Done") : "Let's get going!"}
          </Button>
        </div>
      </div>
    {:else}
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
                <p class="font-medium text-blue mb-1">
                  Using GitHub Codespaces?
                </p>
                <p class="text-secondary">
                  Look for the <strong>Terminal</strong> tab at the bottom of
                  your window. If you don't see it, press
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

            <div
              class="bg-purple/10 border border-purple/20 rounded-lg p-4 mb-4"
            >
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
    {/if}
  </div>
</div>
