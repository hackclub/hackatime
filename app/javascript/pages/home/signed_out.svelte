<script lang="ts">
  type HomeStats = { seconds_tracked?: number; users_tracked?: number };

  let {
    flavor_text,
    hca_auth_path,
    slack_auth_path,
    email_auth_path,
    sign_in_email,
    show_dev_tool,
    dev_magic_link,
    csrf_token,
    home_stats,
  }: {
    flavor_text: string;
    hca_auth_path: string;
    slack_auth_path: string;
    email_auth_path: string;
    sign_in_email: boolean;
    show_dev_tool: boolean;
    dev_magic_link?: string | null;
    csrf_token: string;
    home_stats: HomeStats;
  } = $props();

  let isSigningIn = $state(false);

  const editors = [
    { name: "VS Code", slug: "vs-code" },
    { name: "PyCharm", slug: "pycharm" },
    { name: "IntelliJ IDEA", slug: "intellij-idea" },
    { name: "Sublime Text", slug: "sublime-text" },
    { name: "Vim", slug: "vim" },
    { name: "Neovim", slug: "neovim" },
    { name: "Android Studio", slug: "android-studio" },
    { name: "Xcode", slug: "xcode" },
    { name: "Unity", slug: "unity" },
    { name: "Godot", slug: "godot" },
    { name: "Cursor", slug: "cursor" },
    { name: "Zed", slug: "zed" },
    { name: "Terminal", slug: "terminal" },
    { name: "WebStorm", slug: "webstorm" },
    { name: "Eclipse", slug: "eclipse" },
    { name: "Emacs", slug: "emacs" },
    { name: "Jupyter", slug: "jupyter" },
    { name: "OnShape", slug: "onshape" },
  ];

  const numberFormatter = new Intl.NumberFormat("en-US");

  const pluralize = (count: number, singular: string, plural: string) =>
    count === 1 ? singular : plural;

  const formatNumber = (value: number) => numberFormatter.format(value);

  const hoursTracked = $derived(
    home_stats?.seconds_tracked
      ? Math.floor(home_stats.seconds_tracked / 3600)
      : 0,
  );
  const usersTracked = $derived(home_stats?.users_tracked ?? 0);
  const showHomeStats = $derived(
    !!home_stats?.seconds_tracked && !!home_stats?.users_tracked,
  );
</script>

<div class="container">
  <div class="flex items-center space-x-2 mt-2">
    <p class="italic text-gray-400 m-0">
      {flavor_text}
    </p>
  </div>
  <h1 class="font-bold mt-1 mb-4 text-5xl text-center">
    Track How Much You <span class="text-primary">Code</span>
  </h1>
  <div class="flex flex-col w-full max-w-[50vw] mx-auto mb-22">
    <a
      href={hca_auth_path}
      class={`inline-flex items-center justify-center w-full px-6 py-3 rounded text-white font-bold bg-primary hover:bg-primary/75 transition-colors ${isSigningIn ? "opacity-70 pointer-events-none" : ""}`}
      data-turbo="false"
      onclick={() => (isSigningIn = true)}
    >
      {#if isSigningIn}
        <span class="spinner mr-2">
          <svg class="h-6 w-6 animate-spin" viewBox="0 0 24 24" fill="none">
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            ></circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            ></path>
          </svg>
        </span>
      {:else}
        <img
          src="/images/icon-rounded.png"
          class="icon h-6 w-6 mr-2"
          alt="Hack Club"
        />
      {/if}
      <span>Sign in with your Hack Club account</span>
    </a>

    <div class="flex items-center my-4">
      <div class="flex-1 border-t border-darkless"></div>
      <span class="px-4 text-gray-400 text-sm">or</span>
      <div class="flex-1 border-t border-darkless"></div>
    </div>

    <div class="flex gap-2">
      <form
        class="relative flex-1"
        method="post"
        action={email_auth_path}
        data-turbo="false"
      >
        <input type="hidden" name="authenticity_token" value={csrf_token} />
        <div class="relative">
          <input
            type="email"
            name="email"
            placeholder="Enter your email to get a sign in link"
            required
            class="w-full px-3 py-3 pr-12 border border-darkless bg-dark placeholder-secondary rounded focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
          />
          <button
            type="submit"
            aria-label="Submit email"
            class="absolute right-2 top-1/2 transform -translate-y-1/2 w-8 h-8 p-1 bg-blue-600 hover:bg-blue-700 rounded cursor-pointer border-none flex items-center justify-center transition-colors"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
              ><path
                fill="currentColor"
                d="M13.3 20.275q-.3-.3-.3-.7t.3-.7L16.175 16H7q-.825 0-1.412-.587T5 14V5q0-.425.288-.712T6 4t.713.288T7 5v9h9.175l-2.9-2.9q-.3-.3-.288-.7t.288-.7q.3-.3.7-.312t.7.287L19.3 14.3q.15.15.212.325t.063.375t-.063.375t-.212.325l-4.575 4.575q-.3.3-.712.3t-.713-.3"
              /></svg
            >
          </button>
        </div>
      </form>
      <a
        href={slack_auth_path}
        class="flex items-center justify-center px-4 py-3 rounded cursor-pointer bg-dark hover:bg-darkless border border-darkless text-gray-300 transition-colors w-1/4 gap-2"
      >
        <span
          ><svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            class="w-6 h-6"
            ><path
              fill="currentColor"
              d="M6 15a2 2 0 0 1-2 2a2 2 0 0 1-2-2a2 2 0 0 1 2-2h2zm1 0a2 2 0 0 1 2-2a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2a2 2 0 0 1-2-2zm2-8a2 2 0 0 1-2-2a2 2 0 0 1 2-2a2 2 0 0 1 2 2v2zm0 1a2 2 0 0 1 2 2a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2a2 2 0 0 1 2-2zm8 2a2 2 0 0 1 2-2a2 2 0 0 1 2 2a2 2 0 0 1-2 2h-2zm-1 0a2 2 0 0 1-2 2a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2a2 2 0 0 1 2 2zm-2 8a2 2 0 0 1 2 2a2 2 0 0 1-2 2a2 2 0 0 1-2-2v-2zm0-1a2 2 0 0 1-2-2a2 2 0 0 1 2-2h5a2 2 0 0 1 2 2a2 2 0 0 1-2 2z"
            /></svg
          ></span
        >
        <span class="hidden xl:inline">Slack Sign In</span>
      </a>
    </div>
  </div>
  {#if sign_in_email}
    <div class="text-green-500 mt-4 text-center max-w-[50vw] mx-auto">
      Check your email for a sign-in link!
    </div>
    {#if show_dev_tool && dev_magic_link}
      <div class="dev-tool text-center max-w-[50vw] mx-auto mb-4">
        <a
          href={dev_magic_link}
          class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-dark hover:bg-darkless border border-darkless text-gray-300 transition-colors"
        >
          Open sign-in link
        </a>
      </div>
    {/if}
  {/if}
  <div class="w-full flex justify-center overflow-x-none">
    <p
      class="monospace text-center text-primary text-[22px] select-none whitespace-nowrap"
    >
      ==============================================/ h a c k
      /=============================================
    </p>
  </div>
  <div class="mt-8 mb-8">
    <h1 class="font-bold mt-1 mb-1 text-4xl">
      Compatible with your favourite IDEs
    </h1>
    <p class="text-primary monospace text-[20px]">
      Hackatime works with these code editors and more!
    </p>
    <div
      id="supported-editors"
      class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 mt-4"
    >
      {#each editors as editor}
        <a
          href={`/docs/editors/${editor.slug}`}
          class="bg-darkless rounded-lg p-3 hover:bg-primary/20 transition-all duration-200 text-center block hover:-translate-y-0.5 hover:shadow-lg hover:shadow-primary/20"
        >
          <img
            src={`/images/editor-icons/${editor.slug}-128.png`}
            alt={editor.name}
            class="w-12 h-12 mx-auto mb-2"
          />
          <div class="text-sm text-white">{editor.name}</div>
        </a>
      {/each}
    </div>
  </div>
  <div class="w-full flex justify-center overflow-x-none">
    <p
      class="monospace text-center text-primary text-[22px] select-none whitespace-nowrap"
    >
      -----------------------------------------------------------------------------------------------
    </p>
  </div>
  <div class="mt-8 mb-8">
    <h1 class="font-bold mt-1 mb-1 text-4xl">Why Hackatime?</h1>
    {#if showHomeStats}
      <p class="text-primary monospace text-[20px]">
        We've tracked over <span class="text-primary"
          >{formatNumber(hoursTracked)}
          {pluralize(hoursTracked, "hour", "hours")}</span
        >
        of coding time across
        <span class="text-primary"
          >{formatNumber(usersTracked)}
          {pluralize(usersTracked, "high schooler", "high schoolers")}</span
        >
        since <span class="text-primary">2025</span>!
      </p>
    {/if}
    <div class="overflow-x-auto -mx-4 px-4 pb-4 no-scrollbar">
      <div class="grid grid-cols-4 gap-4 mt-4 text-center h-30 min-w-200">
        <p
          class="flex flex-col text-3xl justify-center bg-darkless rounded-lg p-3"
        >
          <span class="text-primary font-bold text-4xl">100%</span><br />free
        </p>
        <p
          class="flex flex-col text-3xl justify-center bg-darkless rounded-lg p-3"
        >
          works<br /><span class="text-primary font-bold text-4xl">offline</span
          >
        </p>
        <p
          class="flex flex-col text-3xl justify-center bg-darkless rounded-lg p-3"
        >
          <span class="text-primary font-bold text-4xl">real time</span><br
          />stats
        </p>
        <p
          class="flex flex-col text-3xl justify-center bg-darkless rounded-lg p-3"
        >
          rise to the<br /><span class="text-primary font-bold text-4xl"
            >top #1</span
          >
        </p>
      </div>
    </div>
  </div>

  <div class="w-full flex justify-center overflow-x-none">
    <p
      class="monospace text-center text-primary text-[22px] select-none whitespace-nowrap"
    >
      ==============================================/ h a c k
      /=============================================
    </p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-8 my-8 items-center">
    <div>
      <h1 class="font-bold mt-1 mb-1 text-5xl">
        Start hacking with <span class="text-primary">Hackatime</span> now!
      </h1>
      <p class="text-primary monospace text-[20px]">
        It is super easy to setup, here is a quick guide!
      </p>
    </div>

    <div class="w-full relative pb-[56.25%] h-0 overflow-hidden">
      <iframe
        width="1280"
        height="720"
        src="https://www.youtube-nocookie.com/embed/FSIxV4u77WQ?rel=0"
        title="YouTube video player"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        class="absolute top-0 left-0 w-full h-full rounded-lg"
      ></iframe>
    </div>
  </div>
</div>
