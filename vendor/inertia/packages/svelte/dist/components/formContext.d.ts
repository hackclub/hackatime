import type { FormComponentRef } from '@inertiajs/core';
declare const setFormContext: (context: FormComponentRef) => FormComponentRef;
export declare function useFormContext<TForm extends object = Record<string, any>>(): FormComponentRef<TForm> | undefined;
export { setFormContext };
