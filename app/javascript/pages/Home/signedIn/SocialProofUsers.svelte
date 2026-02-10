<script lang="ts">
  type SocialProofUser = { display_name: string; avatar_url: string };

  let {
    users,
    total_size,
    message,
  }: {
    users: SocialProofUser[];
    total_size: number;
    message?: string | null;
  } = $props();
</script>

<div class="flex items-center mt-4 flex-nowrap">
  {#if users.length > 0}
    <div class="flex m-0 ml-0 shrink-0">
      {#each users as user, index}
        <div
          class={`relative cursor-pointer transition-transform duration-200 hover:-translate-y-1 hover:z-10 group ${index > 0 ? "-ml-4" : ""}`}
        >
          <div
            class="absolute -top-9 left-1/2 transform -translate-x-1/2 bg-gray-800 text-white px-2 py-1 rounded text-xs whitespace-nowrap opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-20"
          >
            {user.display_name}
            <div
              class="absolute top-full left-1/2 -ml-1 border-l-2 border-r-2 border-t-2 border-transparent border-t-gray-800"
            ></div>
          </div>
          <img
            src={user.avatar_url}
            alt={user.display_name}
            class="w-10 h-10 rounded-full border-2 border-primary object-cover shadow-sm"
          />
        </div>
      {/each}
      {#if total_size > 5}
        <div
          class="relative cursor-pointer transition-transform duration-200 hover:-translate-y-1 hover:z-10 group -ml-4"
          title={`See all ${total_size} users`}
        >
          <div
            class="w-10 h-10 rounded-full border-2 border-primary bg-primary text-white font-bold text-sm flex items-center justify-center shadow-sm"
          >
            +{total_size - 5}
          </div>
          <div
            class="absolute -left-5 top-11 bg-gray-800 rounded-lg shadow-xl p-4 w-80 z-50 max-h-96 overflow-y-auto opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200"
          >
            <h4
              class="mt-0 mb-2 text-base text-gray-200 border-b border-gray-600 pb-2"
            >
              All users who set up Hackatime
            </h4>
            <div class="flex flex-col gap-2">
              {#each users as user}
                <div
                  class="flex items-center p-1 rounded hover:bg-gray-700 transition-colors duration-200"
                >
                  <img
                    src={user.avatar_url}
                    alt={user.display_name}
                    class="w-8 h-8 rounded-full mr-2 border border-primary"
                  />
                  <span class="font-medium text-sm">{user.display_name}</span>
                </div>
              {/each}
            </div>
            <div
              class="absolute -top-2 left-8 w-0 h-0 border-l-2 border-r-2 border-b-2 border-transparent border-b-gray-800"
            ></div>
          </div>
        </div>
      {/if}
    </div>
  {/if}
  {#if message}
    <p class="m-0 ml-2 italic text-gray-400">
      {message} (this is real data)
    </p>
  {/if}
</div>
