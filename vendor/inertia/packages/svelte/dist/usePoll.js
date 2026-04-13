import { router } from '@inertiajs/core';
import { onDestroy, onMount } from 'svelte';
export default function usePoll(interval, requestOptions = {}, options = {
    keepAlive: false,
    autoStart: true,
}) {
    const { stop, start } = router.poll(interval, requestOptions, {
        ...options,
        autoStart: false,
    });
    onMount(() => {
        if (options.autoStart ?? true) {
            start();
        }
    });
    onDestroy(() => {
        stop();
    });
    return { stop, start };
}
