import type { PageProps } from '@inertiajs/core';
import type { Component } from 'svelte';
export type RenderProps = {
    component: Component;
    props?: PageProps;
    children?: RenderProps[];
    key?: number | null;
    name?: string;
};
export type RenderFunction = {
    (component: Component, props?: PageProps, children?: RenderProps[], key?: number | null): RenderProps;
    (component: Component, children?: RenderProps[], key?: number | null): RenderProps;
};
export declare const h: RenderFunction;
import Render from './Render.svelte';
declare const Render: Component<RenderProps, {}, "">;
type Render = ReturnType<typeof Render>;
export default Render;
