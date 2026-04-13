import { router } from '@inertiajs/core';
import { cloneDeep } from 'lodash-es';
export default function useRemember(initialState, key) {
    const restored = router.restore(key);
    const state = $state(restored !== undefined ? cloneDeep(restored) : initialState);
    $effect(() => {
        router.remember(cloneDeep($state.snapshot(state)), key);
    });
    return state;
}
