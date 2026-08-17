<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { onMount } from "svelte";

  let { title, spec_url }: { title: string; spec_url: string } = $props();

  const scalarConfiguration = () => ({
    url: spec_url,
    theme: "purple",
    layout: "modern",
    hideDownloadButton: false,
    customCss:
      'main { margin-bottom: 0 !important; padding: 0 !important; } a.no-underline.hover\\:underline[href="https://www.scalar.com"][target="_blank"] { display: none !important; }',
    metaData: { title, description: "The API for Hackatime" },
  });

  type ScalarInstance = { destroy: () => void };
  type ScalarWindow = Window & {
    Scalar?: {
      createApiReference: (
        element: HTMLElement,
        configuration: ReturnType<typeof scalarConfiguration>,
      ) => ScalarInstance;
    };
  };

  onMount(() => {
    const app = document.getElementById("app");
    const originalBodyClasses = new Set(document.body.classList);
    const existingStyles = new Set(document.head.querySelectorAll("style"));
    const ownedStyles = new Set<HTMLStyleElement>();
    let instance: ScalarInstance | undefined;
    let disposed = false;

    const captureOwnedStyles = () => {
      document.head.querySelectorAll("style").forEach((style) => {
        if (!existingStyles.has(style)) ownedStyles.add(style);
      });
    };

    app?.style.setProperty("display", "none");
    document.body.style.setProperty("display", "block");

    const mount = document.createElement("div");
    mount.id = "scalar-api-reference";
    document.body.appendChild(mount);

    const loader = document.createElement("script");
    loader.src =
      "https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.58.0/dist/browser/standalone.js";
    loader.integrity =
      "sha384-blqXcztiBhcKCu5cq4LLXtLyV3ASqFluFLJZuJjiDGKBweY6ZJGHJhqOK84toOji";
    loader.crossOrigin = "anonymous";
    loader.onload = () => {
      captureOwnedStyles();
      if (disposed) {
        ownedStyles.forEach((style) => style.remove());
        return;
      }

      instance = (window as ScalarWindow).Scalar?.createApiReference(
        mount,
        scalarConfiguration(),
      );
    };
    document.body.appendChild(loader);

    return () => {
      disposed = true;
      instance?.destroy();
      loader.remove();
      mount.remove();
      ownedStyles.forEach((style) => style.remove());
      document.body.classList.forEach((className) => {
        if (!originalBodyClasses.has(className))
          document.body.classList.remove(className);
      });
      app?.style.removeProperty("display");
      document.body.style.removeProperty("display");
    };
  });
</script>

<svelte:head><title>{title}</title></svelte:head>

<style>
  :global(body) {
    margin: 0;
  }
</style>
