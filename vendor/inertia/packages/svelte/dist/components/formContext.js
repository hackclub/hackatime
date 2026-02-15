import { createContext } from 'svelte';
const [getFormContext, setFormContext] = createContext();
export function useFormContext() {
    try {
        return getFormContext();
    }
    catch {
        return undefined;
    }
}
export { setFormContext };
