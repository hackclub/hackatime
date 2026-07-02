<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import { untrack } from "svelte";
  import TwoChoiceLayout from "./components/TwoChoiceLayout.svelte";
  import TwoChoiceCard from "./components/TwoChoiceCard.svelte";
  import LinkScreen from "./LinkScreen.svelte";
  import CodespacesSteps from "./CodespacesSteps.svelte";
  import TerminalCommand from "./TerminalCommand.svelte";
  import Finish from "./Finish.svelte";
  import { popIn } from "./transitions";

  type Step =
    | "welcome"
    | "install-programs"
    | "codespaces-link"
    | "codespaces-steps"
    | "vscode-download"
    | "terminal-choice"
    | "terminal-command"
    | "finish";

  interface Props {
    current_user_api_key: string;
    setup_os: string;
    skip_setup_flow: boolean;
    return_url?: string;
    return_button_text: string;
  }

  let {
    current_user_api_key,
    setup_os,
    skip_setup_flow,
    return_url,
    return_button_text,
  }: Props = $props();

  let step: Step = $state(
    untrack(() => (skip_setup_flow ? "finish" : "welcome")),
  );
</script>

<svelte:head>
  <title>Set Up Hackatime</title>
</svelte:head>

<div
  class="setup-grid pointer-events-none fixed inset-0 -z-10"
  aria-hidden="true"
></div>

<div class="mx-auto max-w-3xl py-6 sm:py-10">
  {#key step}
    <div in:popIn>
      {#if step === "welcome"}
        <TwoChoiceLayout
          emoji="/images/emojis/ms-grinning.svg"
          title="Welcome to Hackatime!"
          subtitle="Hackatime is a free tool from Hack Club that tracks the time you spend working on projects."
          question="To get started, do you have a code editor (like VSCode) installed?"
        >
          <TwoChoiceCard
            label="Yes, I have an editor installed"
            sublabel="(we'll help you install the plugin for your editor(s))"
            onclick={() => (step = "terminal-choice")}
          />
          <TwoChoiceCard
            label="Nope!"
            sublabel={'or: "I don\'t even know what that is"'}
            onclick={() => (step = "install-programs")}
          />
        </TwoChoiceLayout>
      {:else if step === "install-programs"}
        <TwoChoiceLayout
          emoji="/images/emojis/ms-hugging-face.svg"
          title="Not a problem!"
          subtitle="We'll help you get set up with a code editor, so you can get started on your project."
          question="Are you able to install programs on your computer?"
        >
          <TwoChoiceCard
            label="Yes, I can download programs"
            sublabel="We'll help you install VSCode to your device."
            onclick={() => (step = "vscode-download")}
          />
          <TwoChoiceCard
            label="No, I can't download programs"
            sublabel="We'll help you set up GitHub Codespaces, a free online code editor."
            onclick={() => (step = "codespaces-link")}
          />
        </TwoChoiceLayout>
      {:else if step === "codespaces-link"}
        <LinkScreen
          emoji="/images/emojis/ms-cloud.svg"
          title="Codespaces setup"
          subtitle="We suggest using GitHub Codespaces, a free online code editor, to get started."
          lead="To use Codespaces, head here:"
          url="https://github.com/codespaces"
          urlLabel="github.com/codespaces"
          onDone={() => (step = "codespaces-steps")}
        />
      {:else if step === "codespaces-steps"}
        <CodespacesSteps onDone={() => (step = "finish")} />
      {:else if step === "vscode-download"}
        <LinkScreen
          emoji="/images/emojis/ms-computer.svg"
          title="VSCode setup"
          subtitle="Let's install Microsoft VSCode on your computer. It's our suggested code editor for making things for Hack Club!"
          lead="To download VSCode, go to this url and select your system type:"
          url="https://code.visualstudio.com/download"
          urlLabel="code.visualstudio.com/download"
          onDone={() => (step = "finish")}
        />
      {:else if step === "terminal-choice"}
        <TwoChoiceLayout
          emoji="/images/emojis/ms-cool.svg"
          title="Awesome!"
          subtitle="Let's get you set up with Hackatime directly."
          question="Are you comfortable with pasting a setup script in your terminal, or would you like to manually install each extension?"
        >
          <TwoChoiceCard
            label="Terminal (automatic)"
            sublabel="Supports VSCode and its forks, Zed, JetBrains IDEs, Xcode, and more"
            onclick={() => (step = "terminal-command")}
          />
          <TwoChoiceCard
            label="No terminal (manual setup)"
            sublabel="Follow the editor guides in our docs"
            onclick={() => router.visit("/docs")}
          />
        </TwoChoiceLayout>
      {:else if step === "terminal-command"}
        <TerminalCommand
          apiKey={current_user_api_key}
          setupOs={setup_os}
          onDone={() => (step = "finish")}
        />
      {:else if step === "finish"}
        <Finish
          returnUrl={return_url}
          returnButtonText={return_button_text}
          hardware={skip_setup_flow}
        />
      {/if}
    </div>
  {/key}
</div>

<style>
  .setup-grid {
    --grid-line: color-mix(
      in srgb,
      var(--color-surface-content) 7%,
      transparent
    );
    background-image:
      linear-gradient(to right, var(--grid-line) 1px, transparent 1px),
      linear-gradient(to bottom, var(--grid-line) 1px, transparent 1px);
    background-size: 44px 44px;
    mask-image: radial-gradient(ellipse at center, black 50%, transparent 95%);
  }
</style>
