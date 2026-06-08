<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Stepper from "./Stepper.svelte";
  import HeartbeatPanel from "./components/HeartbeatPanel.svelte";
  import EditorCard from "./components/EditorCard.svelte";
  import CodeBlock from "./components/CodeBlock.svelte";
  import NumberedStep from "./components/NumberedStep.svelte";
  import HowDoIKnow from "./components/HowDoIKnow.svelte";
  import Checkmark from "hcicons-svelte/checkmark";
  import YoutubeFill from "hcicons-svelte/youtube-fill";

  interface Props {
    current_user_api_key: string;
    editor: string;
  }

  let { current_user_api_key, editor }: Props = $props();

  const vscodeMessages = [
    "Open any code file and start typing!",
    "Try editing some code in VS Code...",
    "Type a few characters in your editor!",
    "We're watching for your first keystroke...",
    "Make any edit in VS Code to continue!",
  ];

  type Method = { name: string; code: string; note?: string };
  const editorData: Record<
    string,
    { name: string; icon: string; methods: Method[] }
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

  const docLinks = [
    {
      href: "/docs/editors/pycharm",
      icon: "/images/editor-icons/pycharm-128.png",
      name: "PyCharm",
      external: false,
    },
    {
      href: "/docs/editors/sublime-text",
      icon: "/images/editor-icons/sublime-text-128.png",
      name: "Sublime Text",
      external: false,
    },
    {
      href: "/docs/editors/unity",
      icon: "/images/editor-icons/unity-128.png",
      name: "Unity",
      external: false,
    },
  ];
</script>

<svelte:head>
  <title>Setup {editor} - Step 3</title>
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={3} />

    {#if editor === "vscode"}
      <div class="space-y-6">
        <EditorCard
          icon="/images/editor-icons/vs-code-128.png"
          iconAlt="VS Code"
          title="Install the VS Code Extension"
          subtitle={'Search for "WakaTime" in the marketplace.'}
        >
          <div class="space-y-4">
            <NumberedStep n={1} title="Install the extension">
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
            </NumberedStep>

            <NumberedStep n={2} title="Restart & Code">
              <p class="text-sm text-secondary">
                Restart VS Code if prompted. Then, open any file and start
                typing to send your first heartbeat.
              </p>
            </NumberedStep>

            <HowDoIKnow
              image="/images/editor-toolbars/vs-code.png"
              description="You'll see a clock icon and time spent coding in your status bar:"
            />
          </div>
        </EditorCard>

        <HeartbeatPanel
          apiKey={current_user_api_key}
          waitingTitle="Waiting for you to code..."
          messages={vscodeMessages}
          recentThresholdSeconds={86400}
        >
          {#snippet success({ timeAgo, editor: detected })}
            <div class="text-center py-2">
              <div
                class="w-16 h-16 mx-auto mb-4 rounded-full bg-green/10 flex items-center justify-center"
              >
                <Checkmark size={32} class="text-green" />
              </div>
              <h4 class="text-xl font-bold text-surface-content mb-2">
                Heartbeat detected!
              </h4>
              <p class="text-secondary text-sm mb-6">
                Received {timeAgo} from {detected &&
                detected.toLowerCase() !== "vscode" &&
                detected.toLowerCase() !== "vs code"
                  ? detected
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
          {/snippet}
        </HeartbeatPanel>

        <div class="text-center">
          <Link
            href="/my/wakatime_setup/step-4"
            class="text-xs text-secondary hover:text-surface-content transition-colors"
            >Skip to finish</Link
          >
        </div>
      </div>
    {:else if editor === "godot"}
      <div class="mb-8">
        <EditorCard
          icon="/images/editor-icons/godot-128.png"
          title="Godot Setup"
          subtitle="Install the plugin with your preferred package manager."
        >
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
                  Enable in <strong>Project → Project Settings → Plugins</strong
                  >
                </li>
              </ol>
            </div>
            <div class="pt-2">
              <a
                href="https://www.youtube.com/watch?v=a938RgsBzNg&t=29s"
                target="_blank"
                class="inline-flex items-center gap-2 text-cyan hover:underline text-sm font-medium"
              >
                <YoutubeFill size={16} />
                Watch setup tutorial
              </a>
            </div>
          </div>
        </EditorCard>
      </div>
      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full"
        >Next Step</Button
      >
    {:else if editor === "jetbrains"}
      <div class="mb-8">
        <EditorCard
          icon="/images/editor-icons/jetbrains-128.png"
          title="Set Up JetBrains IDEs"
          subtitle="Install the WakaTime extension for JetBrains IDEs (like IntelliJ and PyCharm)."
        >
          <div class="space-y-4">
            <p class="text-sm">
              JetBrains IDEs require a plugin installed for each IDE separately.
            </p>

            <NumberedStep n={1} title="Open Settings">
              <p class="text-sm text-secondary">
                Open your IDE and go to <b>Settings</b> (Ctrl+Alt+S on
                Windows/Linux, Command+, on macOS), <b>Plugins</b>, then
                <b>Marketplace</b>.
              </p>
            </NumberedStep>
            <NumberedStep n={2} title="Install WakaTime Plugin">
              <p class="text-sm text-secondary">
                Search for <b>WakaTime</b> in the marketplace and click Install.
                <a
                  href="https://plugins.jetbrains.com/plugin/7425-wakatime"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-cyan hover:underline">View on Marketplace</a
                >
              </p>
            </NumberedStep>
            <NumberedStep n={3} title="Restart & Code">
              <p class="text-sm text-secondary">
                Restart your IDE if prompted. Then, open any file and start
                typing to send your first heartbeat.
              </p>
            </NumberedStep>

            <HowDoIKnow image="/images/editor-toolbars/jetbrains.png" />
          </div>
        </EditorCard>
      </div>
      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full"
        >Next Step</Button
      >
    {:else if editor === "sublime"}
      <div class="mb-8">
        <EditorCard
          icon="/images/editor-icons/sublime-text-128.png"
          title="Set Up Sublime Text"
          subtitle="Use Package Control to install WakaTime for Sublime Text."
        >
          <div class="space-y-4">
            <NumberedStep n={1} title="Install Package Control">
              <p class="text-sm text-secondary">
                If you don't have Package Control installed, install it at
                <a
                  href="https://packagecontrol.io/installation"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-cyan hover:underline">packagecontrol.io</a
                >
                to set it up first.
              </p>
            </NumberedStep>
            <NumberedStep n={2} title="Install WakaTime Plugin">
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
            </NumberedStep>
            <NumberedStep n={2} title="Start Coding">
              <p class="text-sm text-secondary">
                After installing WakaTime, open any file and start typing to
                send your first heartbeat.
              </p>
            </NumberedStep>

            <HowDoIKnow
              description={"You'll see your time spent coding in your status bar, which looks something like <code>Today: 1h 23m</code>."}
            />
          </div>
        </EditorCard>
      </div>
      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full"
        >Next Step</Button
      >
    {:else if editorData[editor]}
      {@const data = editorData[editor]}
      <div class="mb-8">
        <EditorCard
          icon={data.icon}
          title={`${data.name} Setup`}
          subtitle="Install the plugin with your preferred package manager."
        >
          <div class="space-y-6">
            {#each data.methods as method, i}
              {#if i > 0}<div class="pt-6 border-t border-darkless"></div>{/if}
              <div>
                <h4 class="text-sm font-medium mb-2 text-surface-content">
                  {method.name}
                </h4>
                <CodeBlock code={method.code} whitespace="pre" />
                {#if method.note}
                  <p class="text-xs text-secondary mt-2">{@html method.note}</p>
                {/if}
              </div>
            {/each}
          </div>
        </EditorCard>
      </div>
      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full"
        >Next Step</Button
      >
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
            {#each docLinks as link}
              <Link
                href={link.href}
                class="flex items-center gap-3 bg-darkless/50 rounded-lg p-3 hover:bg-darkless transition-colors"
              >
                <img src={link.icon} alt={link.name} class="w-6 h-6" />
                <span class="text-sm">{link.name}</span>
              </Link>
            {/each}
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

      <Button href="/my/wakatime_setup/step-4" size="xl" class="w-full"
        >Next Step</Button
      >
    {/if}
  </div>
</div>
