import type { FormComponentRef } from '@inertiajs/core';
import type { Readable } from 'svelte/store';
export declare const FormContextKey: any;
export declare function useFormContext(): Readable<FormComponentRef> | undefined;
