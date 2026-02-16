<script lang="ts">
  import { onMount } from "svelte";
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Stepper from "./Stepper.svelte";

  interface Props {
    current_user_api_key: string;
    editor: string;
    heartbeat_check_url: string;
  }

  let { current_user_api_key, editor, heartbeat_check_url }: Props = $props();

  let hasHeartbeat = $state(false);
  let heartbeatTimeAgo = $state("");
  let detectedEditor = $state("");
  let checkCount = $state(0);
  let statusMessage = $state("Open a file in VS Code and start typing!");
  let statusPanelClass = $state("border-darkless");
  let copiedCode = $state("");

  const messages = [
    "Open any code file and start typing!",
    "Try editing some code in VS Code...",
    "Type a few characters in your editor!",
    "We're watching for your first keystroke...",
    "Make any edit in VS Code to continue!",
  ];

  const editorData: Record<
    string,
    {
      name: string;
      icon: string;
      methods: Array<{ name: string; code: string; note?: string }>;
    }
  > = {
    vim: {
      name: "Vim",
      icon: "/images/editor-icons/vim-128.png",
      methods: [
        {
          name: "Using vim-plug",
          code: "Plug 'wakatime/vim-wakatime'",
          note: "Then run :PlugInstall",
        },
        {
          name: "Using Vundle",
          code: "Plugin 'wakatime/vim-wakatime'",
          note: "Then run :PluginInstall",
        },
      ],
    },
    neovim: {
      name: "Neovim",
      icon: "/images/editor-icons/neovim-128.png",
      methods: [
        {
          name: "Using lazy.nvim",
          code: '{ "wakatime/vim-wakatime", lazy = false }',
        },
        { name: "Using packer.nvim", code: "use 'wakatime/vim-wakatime'" },
        {
          name: "Using vim-plug",
          code: "Plug 'wakatime/vim-wakatime'",
          note: "Then run :PlugInstall",
        },
      ],
    },
    emacs: {
      name: "Emacs",
      icon: "/images/editor-icons/emacs-128.png",
      methods: [
        {
          name: "Using MELPA",
          code: "M-x package-install RET wakatime-mode RET",
          note: "Then add (global-wakatime-mode) to your config.",
        },
        {
          name: "Using use-package",
          code: "(use-package wakatime-mode\n  :ensure t\n  :config\n  (global-wakatime-mode))",
        },
      ],
    },
  };

  function showSuccess(timeAgo: string, editorName: string) {
    hasHeartbeat = true;
    heartbeatTimeAgo = timeAgo;
    detectedEditor = editorName;
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
        const recentThreshold = 86400;

        if (secondsAgo <= recentThreshold) {
          showSuccess(data.time_ago, data.editor);
          return;
        }
      }
      throw new Error("No recent heartbeats");
    } catch (error) {
      checkCount++;

      if (checkCount % 3 === 0) {
        const msgIndex = Math.floor(checkCount / 3) % messages.length;
        statusMessage = messages[msgIndex];
      }
    }
  }

  onMount(() => {
    if (editor === "vscode") {
      checkHeartbeat();
      const interval = setInterval(() => {
        if (!hasHeartbeat) {
          checkHeartbeat();
        }
      }, 5000);
      return () => clearInterval(interval);
    }
  });
</script>

<svelte:head>
  <title>Setup {editor} - Step 3</title>
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={3} />

    {#if editor === "vscode"}
      <div class="space-y-6">
        <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm">
          <div class="flex items-center gap-4 mb-6">
            <img
              src="/images/editor-icons/vs-code-128.png"
              alt="VS Code"
              class="w-12 h-12 object-contain"
            />
            <div>
              <h3 class="text-xl font-semibold">
                Install the VS Code Extension
              </h3>
              <p class="text-secondary text-sm">
                Search for "WakaTime" in the marketplace.
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
                <p class="font-medium mb-1">Install the extension</p>
                <p class="text-sm text-secondary">
                  Open VS Code, go to Extensions (squares icon), search for <strong
                    >WakaTime</strong
                  >, and click Install.
                  <a
                    href="https://marketplace.visualstudio.com/items?itemName=WakaTime.vscode-wakatime"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-cyan hover:underline">View on Marketplace</a
                  >
                </p>
              </div>
            </div>

            <div class="flex items-start gap-4">
              <div
                class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
              >
                2
              </div>
              <div>
                <p class="font-medium mb-1">Restart & Code</p>
                <p class="text-sm text-secondary">
                  Restart VS Code if prompted. Then, open any file and start
                  typing to send your first heartbeat.
                </p>
              </div>
            </div>

            <div class="pt-4 border-t border-darkless">
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
                  How do I know it's working?
                </summary>
                <div class="mt-4 pl-6">
                  <p class="text-sm mb-3 text-secondary">
                    You'll see a clock icon and time spent coding in your status
                    bar:
                  </p>
                  <img
                    src="/images/editor-toolbars/vs-code.png"
                    alt="WakaTime status bar"
                    class="rounded-lg border border-darkless"
                  />
                </div>
              </details>
            </div>
          </div>
        </div>

        <div
          class="border border-darkless rounded-xl p-6 bg-dark transition-all duration-300 {statusPanelClass}"
        >
          {#if !hasHeartbeat}
            <div
              class="flex flex-col items-center justify-center text-center py-2"
            >
              <h4 class="text-lg font-semibold text-surface-content mb-1">
                Waiting for you to code...
              </h4>
              <p class="text-sm text-secondary mb-4 max-w-sm">
                {statusMessage}
              </p>
            </div>
          {:else}
            <div class="text-center py-2">
              <div
                class="w-16 h-16 mx-auto mb-4 rounded-full bg-green/10 flex items-center justify-center"
              >
                <svg
                  class="w-8 h-8 text-green"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M5 13l4 4L19 7"
                  />
                </svg>
              </div>
              <h4 class="text-xl font-bold text-surface-content mb-2">
                Heartbeat detected!
              </h4>
              <p class="text-secondary text-sm mb-6">
                Received {heartbeatTimeAgo} from {detectedEditor &&
                detectedEditor.toLowerCase() !== "vscode" &&
                detectedEditor.toLowerCase() !== "vs code"
                  ? detectedEditor
                  : "VS Code"}.
              </p>

              <Button
                href="/my/wakatime_setup/step-4"
                size="xl"
                class="w-full transition-all transform hover:scale-[1.02] active:scale-[0.98]"
              >
                Continue →
              </Button>
            </div>
          {/if}
        </div>

        <div class="text-center">
          <Link
            href="/my/wakatime_setup/step-4"
            class="text-xs text-secondary hover:text-surface-content transition-colors"
            >Skip to finish</Link
          >
        </div>
      </div>
    {:else if editor === "godot"}
      <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm mb-8">
        <div class="flex items-center gap-4 mb-6">
          <img
            src="/images/editor-icons/godot-128.png"
            alt="Godot"
            class="w-12 h-12 object-contain"
          />
          <div>
            <h3 class="text-xl font-semibold">Godot Setup</h3>
            <p class="text-secondary text-sm">
              Install the plugin with your preferred package manager.
            </p>
          </div>
        </div>

        <div class="space-y-4">
          <p class="text-sm">
            Godot requires a plugin installed for each project separately.
          </p>

          <div class="bg-darkless/50 rounded-lg p-4">
            <ol class="list-decimal list-inside space-y-2 text-sm">
              <li>Open your Godot project</li>
              <li>Go to <strong>AssetLib</strong> tab</li>
              <li>Search for <strong>"Godot Super Wakatime"</strong></li>
              <li>Download and Install</li>
              <li>
                Enable in <strong>Project → Project Settings → Plugins</strong>
              </li>
            </ol>
          </div>

          <div class="pt-2">
            <a
              href="https://www.youtube.com/watch?v=a938RgsBzNg&t=29s"
              target="_blank"
              class="inline-flex items-center gap-2 text-cyan hover:underline text-sm font-medium"
            >
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"
                ><path
                  d="M19.615 3.184c-3.604-.246-11.631-.245-15.23 0-3.897.266-4.356 2.62-4.385 8.816.029 6.185.484 8.549 4.385 8.816 3.6.245 11.626.246 15.23 0 3.897-.266 4.356-2.62 4.385-8.816-.029-6.185-.484-8.549-4.385-8.816zm-10.615 12.816v-8l8 3.993-8 4.007z"
                /></svg
              >
              Watch setup tutorial
            </a>
          </div>
        </div>
      </div>

      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full">
        Next Step
      </Button>
    {:else if editor === "jetbrains"}
      <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm mb-8">
        <div class="flex items-center gap-4 mb-6">
          <img
            src="/images/editor-icons/jetbrains-128.png"
            alt="JetBrains"
            class="w-12 h-12 object-contain"
          />
          <div>
            <h3 class="text-xl font-semibold">Set Up JetBrains IDEs</h3>
            <p class="text-secondary text-sm">
              Install the WakaTime extension for JetBrains IDEs (like IntelliJ
              and PyCharm).
            </p>
          </div>
        </div>

        <div class="space-y-4">
          <p class="text-sm">
            JetBrains IDEs require a plugin installed for each IDE separately.
          </p>

          <div class="flex items-start gap-4">
            <div
              class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
            >
              1
            </div>
            <div>
              <p class="font-medium mb-1">Open Settings</p>
              <p class="text-sm text-secondary">
                Open your IDE and go to <b>Settings</b> (Ctrl+Alt+S on
                Windows/Linux, Command+, on macOS), <b>Plugins</b>, then
                <b>Marketplace</b>.
              </p>
            </div>
          </div>

          <div class="flex items-start gap-4">
            <div
              class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
            >
              2
            </div>
            <div>
              <p class="font-medium mb-1">Install WakaTime Plugin</p>
              <p class="text-sm text-secondary">
                Search for <b>WakaTime</b> in the marketplace and click Install.

                <a
                  href="https://plugins.jetbrains.com/plugin/7425-wakatime"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-cyan hover:underline">View on Marketplace</a
                >
              </p>
            </div>
          </div>

          <div class="flex items-start gap-4">
            <div
              class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
            >
              3
            </div>
            <div>
              <p class="font-medium mb-1">Restart & Code</p>
              <p class="text-sm text-secondary">
                Restart your IDE if prompted. Then, open any file and start
                typing to send your first heartbeat.
              </p>
            </div>
          </div>

          <div class="pt-4 border-t border-darkless">
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
                How do I know it's working?
              </summary>
              <div class="mt-4 pl-6">
                <p class="text-sm mb-3 text-secondary">
                  You'll see a WakaTime icon and time spent coding in your
                  status bar:
                </p>
                <img
                  src="/images/editor-toolbars/jetbrains.png"
                  alt="WakaTime status bar"
                  class="rounded-lg border border-darkless"
                />
              </div>
            </details>
          </div>
        </div>
      </div>

      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full">
        Next Step
      </Button>
    {:else if editor === "sublime"}
      <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm mb-8">
        <div class="flex items-center gap-4 mb-6">
          <img
            src="/images/editor-icons/sublime-text-128.png"
            alt="Sublime Text"
            class="w-12 h-12 object-contain"
          />
          <div>
            <h3 class="text-xl font-semibold">Set Up Sublime Text</h3>
            <p class="text-secondary text-sm">
              Use Package Control to install WakaTime for Sublime Text.
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
              <p class="font-medium mb-1">Install Package Control</p>
              <p class="text-sm text-secondary">
                If you don't have Package Control installed, install it at
                <a
                  href="https://packagecontrol.io/installation"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-cyan hover:underline">packagecontrol.io</a
                > to set it up first.
              </p>
            </div>
          </div>

          <div class="flex items-start gap-4">
            <div
              class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
            >
              2
            </div>
            <div>
              <p class="font-medium mb-1">Install WakaTime Plugin</p>
              <p class="text-sm text-secondary">
                Open the Command Palette (Ctrl+Shift+P on Windows/Linux,
                Command+Shift+P on macOS), type <b
                  >Package Control: Install Package</b
                >, and press Enter. Then type <b>WakaTime</b> and press Enter to
                install.
                <a
                  href="https://packagecontrol.io/packages/WakaTime"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-cyan hover:underline">View on Package Control</a
                >
              </p>
            </div>
          </div>

          <div class="flex items-start gap-4">
            <div
              class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
            >
              2
            </div>
            <div>
              <p class="font-medium mb-1">Start Coding</p>
              <p class="text-sm text-secondary">
                After installing WakaTime, open any file and start typing to
                send your first heartbeat.
              </p>
            </div>
          </div>

          <div class="pt-4 border-t border-darkless">
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
                How do I know it's working?
              </summary>
              <div class="mt-4 pl-6">
                <p class="text-sm mb-3 text-secondary">
                  You'll see your time spent coding in your status bar, which
                  looks something like <code>Today: 1h 23m</code>.
                </p>
              </div>
            </details>
          </div>
        </div>
      </div>

      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full">
        Next Step
      </Button>
    {:else if editorData[editor]}
      <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm mb-8">
        <div class="flex items-center gap-4 mb-6">
          <img
            src={editorData[editor].icon}
            alt={editorData[editor].name}
            class="w-12 h-12 object-contain"
          />
          <div>
            <h3 class="text-xl font-semibold">
              {editorData[editor].name} Setup
            </h3>
            <p class="text-secondary text-sm">
              Install the plugin with your preferred package manager.
            </p>
          </div>
        </div>

        <div class="space-y-6">
          {#each editorData[editor].methods as method, index}
            {#if index > 0}
              <div class="pt-6 border-t border-darkless"></div>
            {/if}
            <div>
              <h4 class="text-sm font-medium mb-2 text-surface-content">
                {method.name}
              </h4>
              <div class="relative group">
                <div
                  class="bg-darker border border-darkless rounded-lg overflow-x-auto"
                >
                  <pre
                    class="p-4 pr-20 text-sm font-mono text-cyan whitespace-pre"><code
                      >{method.code}</code
                    ></pre>
                </div>
              </div>
              {#if method.note}
                <p class="text-xs text-secondary mt-2">{@html method.note}</p>
              {/if}
            </div>
          {/each}
        </div>
      </div>

      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full">
        Next Step
      </Button>
    {:else}
      <div class="bg-dark border border-darkless rounded-xl p-8 shadow-sm mb-8">
        <div class="mb-6">
          <h3 class="text-xl font-semibold mb-2">Setup your Editor</h3>
          <p class="text-secondary text-sm">
            Install the plugin with your preferred package manager.
          </p>
        </div>

        <div class="space-y-4">
          <p class="text-sm">
            Find your editor in the WakaTime documentation and follow the
            installation steps. Use your Hackatime API key when prompted.
          </p>

          <div class="bg-yellow/10 border border-yellow/20 rounded-lg p-4">
            <p class="text-yellow text-sm font-medium mb-1">⚠️ Important</p>
            <p class="text-secondary text-sm">
              Since you already ran the setup script in Step 1, you don't need
              to configure the <code>api_url</code> or <code>api_key</code> again
              - just install the plugin!
            </p>
          </div>

          <div class="pt-4 grid grid-cols-2 gap-3">
            <Link
              href="/docs/editors/pycharm"
              class="flex items-center gap-3 bg-darkless/50 rounded-lg p-3 hover:bg-darkless transition-colors"
            >
              <img
                src="/images/editor-icons/pycharm-128.png"
                alt="PyCharm"
                class="w-6 h-6"
              />
              <span class="text-sm">PyCharm</span>
            </Link>
            <Link
              href="/docs/editors/sublime-text"
              class="flex items-center gap-3 bg-darkless/50 rounded-lg p-3 hover:bg-darkless transition-colors"
            >
              <img
                src="/images/editor-icons/sublime-text-128.png"
                alt="Sublime"
                class="w-6 h-6"
              />
              <span class="text-sm">Sublime Text</span>
            </Link>
            <Link
              href="/docs/editors/unity"
              class="flex items-center gap-3 bg-darkless/50 rounded-lg p-3 hover:bg-darkless transition-colors"
            >
              <img
                src="/images/editor-icons/unity-128.png"
                alt="Unity"
                class="w-6 h-6"
              />
              <span class="text-sm">Unity</span>
            </Link>
            <a
              href="https://wakatime.com/editors"
              target="_blank"
              class="flex items-center gap-3 bg-darkless/50 rounded-lg p-3 hover:bg-darkless transition-colors"
            >
              <div class="w-6 h-6 flex items-center justify-center">🌐</div>
              <span class="text-sm">View all editors</span>
            </a>
          </div>
        </div>
      </div>

      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full">
        Next Step
      </Button>
    {/if}
  </div>
</div>
