<script lang="ts">
  import { page, router } from "@inertiajs/svelte";
  import { untrack } from "svelte";
  import { Icon, ArrowLeft } from "svelte-hero-icons";
  import TwoChoiceLayout from "./components/TwoChoiceLayout.svelte";
  import TwoChoiceCard from "./components/TwoChoiceCard.svelte";
  import LinkScreen from "./LinkScreen.svelte";
  import VsCodeSteps from "./VsCodeSteps.svelte";
  import TerminalCommand from "./TerminalCommand.svelte";
  import Finish from "./Finish.svelte";
  import { popIn } from "./transitions";

  type Step =
    | "welcome"
    | "install-programs"
    | "codespaces-link"
    | "vscode-steps"
    | "vscode-download"
    | "terminal-choice"
    | "terminal-command"
    | "finish";

  const STEPS = new Set<Step>([
    "welcome",
    "install-programs",
    "codespaces-link",
    "vscode-steps",
    "vscode-download",
    "terminal-choice",
    "terminal-command",
    "finish",
  ]);

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

  const initialStep: Step = untrack(() =>
    skip_setup_flow ? "finish" : "welcome",
  );

  function stepFromUrl(url: string): Step {
    const query = url.split("?")[1] ?? "";
    const value = new URLSearchParams(query).get("step") as Step | null;
    return value && STEPS.has(value) ? value : initialStep;
  }

  const step = $derived(stepFromUrl(page.url));

  function goToStep(next: Step) {
    const url = next === initialStep ? "/setup" : `/setup?step=${next}`;
    router.push({ url, preserveState: true, preserveScroll: true });
  }
</script>

<svelte:head>
  <title>Set Up Hackatime</title>
</svelte:head>

<div
  class="setup-grid pointer-events-none fixed inset-0 -z-10"
  aria-hidden="true"
></div>

{#if step !== initialStep}
  <button
    type="button"
    onclick={() => window.history.back()}
    class="fixed top-4 left-4 z-10 flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium text-secondary transition-colors hover:text-surface-content sm:top-6 sm:left-6"
  >
    <Icon src={ArrowLeft} size="18" />
    Back
  </button>
{/if}

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
            onclick={() => goToStep("terminal-choice")}
          />
          <TwoChoiceCard
            label="No, I don't have an editor installed"
            sublabel={'or: "what\'s a code editor?"'}
            onclick={() => goToStep("install-programs")}
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
            onclick={() => goToStep("vscode-download")}
          />
          <TwoChoiceCard
            label="No, I can't download programs"
            sublabel="We'll help you set up GitHub Codespaces, a free online code editor."
            onclick={() => goToStep("codespaces-link")}
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
          helpText="New to Codespaces?"
          helpUrl="https://github.blog/developer-skills/github/a-beginners-guide-to-learning-to-code-with-github-codespaces/"
          helpLabel="Read GitHub's beginner's guide"
          onDone={() => goToStep("vscode-steps")}
        />
      {:else if step === "vscode-steps"}
        <VsCodeSteps onDone={() => goToStep("finish")} />
      {:else if step === "vscode-download"}
        <LinkScreen
          emoji="/images/emojis/ms-computer.svg"
          title="VSCode setup"
          subtitle="Let's install Microsoft VSCode on your computer. It's our suggested code editor for making things for Hack Club!"
          lead="To download VSCode, go to this URL and select your system type:"
          url="https://code.visualstudio.com/download"
          urlLabel="code.visualstudio.com/download"
          onDone={() => goToStep("vscode-steps")}
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
            onclick={() => goToStep("terminal-command")}
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
          onDone={() => goToStep("finish")}
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
