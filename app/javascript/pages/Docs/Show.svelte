<script lang="ts">
  import { inertia } from "@inertiajs/svelte";

  let {
    doc_path,
    title,
    rendered_content,
    breadcrumbs,
    edit_url,
    meta,
  }: {
    doc_path: string;
    title: string;
    rendered_content: string;
    breadcrumbs: { name: string; href: string | null; is_link: boolean }[];
    edit_url: string;
    meta: { description: string; keywords: string };
  } = $props();
</script>

<svelte:head>
  <title>{title} - Hackatime Documentation</title>
  <meta name="description" content={meta.description} />
  <meta name="keywords" content={meta.keywords} />
  <meta property="og:title" content={`${title} - Hackatime Documentation`} />
  <meta property="og:description" content={meta.description} />
  <meta property="og:type" content="article" />
</svelte:head>

<div class="min-h-screen text-white">
  <div class="max-w-6xl mx-auto px-6 py-8">
    <!-- Breadcrumbs -->
    <nav class="mb-8">
      {#each breadcrumbs as crumb, index}
        {#if index === breadcrumbs.length - 1}
          <span class="text-primary">{crumb.name}</span>
        {:else}
          {#if crumb.is_link && crumb.href}
            <a href={crumb.href} use:inertia class="text-secondary hover:text-primary">{crumb.name}</a>
          {:else}
            <span class="text-secondary">{crumb.name}</span>
          {/if}
          <span class="text-secondary mx-2">/</span>
        {/if}
      {/each}
    </nav>

    <!-- Content -->
    <div
      class="bg-dark rounded-lg p-8 mb-8 prose prose-invert prose-lg max-w-none
             prose-headings:text-primary prose-headings:font-bold prose-headings:leading-tight
             prose-h1:text-4xl prose-h1:mb-6 prose-h1:text-primary prose-h1:mt-0
             prose-h2:text-2xl prose-h2:mt-10 prose-h2:mb-4 prose-h2:text-primary prose-h2:border-b prose-h2:border-primary/20 prose-h2:pb-2
             prose-h3:text-xl prose-h3:mt-8 prose-h3:mb-3 prose-h3:text-primary
             prose-h4:text-lg prose-h4:mt-4 prose-h4:mb-2 prose-h4:text-white prose-h4:font-semibold
             prose-p:text-white prose-p:leading-7 prose-p:mb-5
             prose-a:text-primary prose-a:hover:text-red prose-a:underline prose-a:font-medium
             prose-strong:text-white prose-strong:font-semibold
             prose-em:text-secondary prose-em:italic
             prose-code:bg-darkless prose-code:text-primary prose-code:px-2 prose-code:py-1 prose-code:rounded prose-code:text-sm prose-code:font-mono
             prose-pre:bg-darkless prose-pre:border prose-pre:border-primary/20 prose-pre:rounded-lg prose-pre:p-4 prose-pre:overflow-x-auto
             prose-pre:text-white prose-pre:text-sm
             prose-blockquote:border-l-4 prose-blockquote:border-primary prose-blockquote:bg-darkless prose-blockquote:pl-6 prose-blockquote:py-4 prose-blockquote:rounded-r-lg
             prose-blockquote:text-secondary prose-blockquote:italic prose-blockquote:font-normal prose-blockquote:my-6
             prose-ul:text-white prose-ul:mb-4 prose-ul:pl-6
             prose-ol:text-white prose-ol:mb-4 prose-ol:pl-6
             prose-li:text-white prose-li:mb-3 prose-li:leading-7 prose-li:pl-2
             prose-table:border-collapse prose-table:border prose-table:border-primary/20 prose-table:rounded-lg prose-table:overflow-hidden prose-table:my-6
             prose-th:bg-darkless prose-th:text-primary prose-th:font-semibold prose-th:p-3 prose-th:border prose-th:border-primary/20
             prose-td:text-white prose-td:p-3 prose-td:border prose-td:border-primary/20
             prose-img:rounded-lg prose-img:shadow-lg prose-img:mx-auto prose-img:block prose-img:max-w-24 prose-img:h-auto prose-img:my-4
             prose-hr:border-primary/20 prose-hr:my-8
             [&_ol>li::marker]:text-primary [&_ol>li::marker]:font-semibold
             [&_ul>li::marker]:text-primary
             [&_ol>li]:mb-3 [&_ol>li]:pl-2
             [&_h2:not(:first-child)]:mt-10
             [&_h3:not(:first-child)]:mt-8
             [&_p_strong:first-child]:text-primary
             [&_pre[class*='language-json']]:bg-darkless [&_pre[class*='language-json']]:border [&_pre[class*='language-json']]:border-primary/10
             [&_pre[class*='language-bash']]:bg-darkless [&_pre[class*='language-bash']]:border [&_pre[class*='language-bash']]:border-primary/10
             [&_img[alt*='PyCharm']]:w-16 [&_img[alt*='PyCharm']]:h-16 [&_img[alt*='PyCharm']]:mx-auto [&_img[alt*='PyCharm']]:block [&_img[alt*='PyCharm']]:my-4
             [&_img[alt*='VS_Code']]:w-16 [&_img[alt*='VS_Code']]:h-16 [&_img[alt*='VS_Code']]:mx-auto [&_img[alt*='VS_Code']]:block [&_img[alt*='VS_Code']]:my-4
             [&_img[alt*='IntelliJ']]:w-16 [&_img[alt*='IntelliJ']]:h-16 [&_img[alt*='IntelliJ']]:mx-auto [&_img[alt*='IntelliJ']]:block [&_img[alt*='IntelliJ']]:my-4
             [&_img[src*='/images/editor-icons/']]:w-16 [&_img[src*='/images/editor-icons/']]:h-16 [&_img[src*='/images/editor-icons/']]:mx-auto [&_img[src*='/images/editor-icons/']]:block [&_img[src*='/images/editor-icons/']]:my-4
             [&_.editor-steps]:bg-darkless [&_.editor-steps]:p-6 [&_.editor-steps]:rounded-lg [&_.editor-steps]:my-4
             [&_.editor-steps_ol]:m-0
             [&_.editor-steps_li]:mb-2"
    >
      {@html rendered_content}
    </div>

    <!-- Edit on GitHub -->
    <div class="text-center bg-darkless rounded-lg p-6">
      <p class="text-secondary">
        Found an issue with this page?
        <a href={edit_url} target="_blank" class="text-primary hover:text-red underline">
          Edit it on GitHub
        </a>
        - we'd love your help making the docs better!
      </p>
    </div>
  </div>
</div>
