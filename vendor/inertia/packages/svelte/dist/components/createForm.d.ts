import type { FormComponentSlotProps } from '@inertiajs/core';
import type { Component, ComponentProps, Snippet } from 'svelte';
import Form from './Form.svelte';
type TypedFormComponent<TForm extends Record<string, any>> = Component<Omit<ComponentProps<typeof Form>, 'children'> & {
    children?: Snippet<[FormComponentSlotProps<TForm>]>;
}>;
export declare function createForm<TForm extends Record<string, any> = Record<string, any>>(): TypedFormComponent<TForm>;
export {};
