<script lang="ts">
  import { Link } from "@inertiajs/svelte";

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
  <div class="max-w-8xl md:max-w-6xl mx-auto px-6 py-8">
    <!-- Breadcrumbs -->
    <nav class="mb-8">
      {#each breadcrumbs as crumb, index}
        {#if index === breadcrumbs.length - 1}
          <span class="text-primary">{crumb.name}</span>
        {:else}
          {#if crumb.is_link && crumb.href}
            <Link href={crumb.href} class="text-secondary hover:text-primary"
              >{crumb.name}</Link
            >
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
             prose-h2:text-2xl prose-h2:mt-10 prose-h2:mb-4 prose-h2:text-primary prose-h2:border-b prose-h2:border-b-[#6e6468] prose-h2:pb-2
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
             prose-hr:border-primary/30 prose-hr:my-8
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
    <div
      class="flex items-center justify-center gap-2 py-6 text-sm text-secondary/70"
    >
      <span>Found an issue with this page?</span>
      <Link
        href={edit_url}
        target="_blank"
        class="inline-flex items-center gap-1 text-primary hover:text-red transition-colors font-medium"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4"
          viewBox="0 0 16 16"
          fill="currentColor"
          ><path
            d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z"
          /></svg
        >
        Edit on GitHub
      </Link>
    </div>
  </div>
</div>
