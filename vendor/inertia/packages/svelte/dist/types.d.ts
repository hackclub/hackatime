import { type Page } from '@inertiajs/core';
import type { Component } from 'svelte';
import type { RenderFunction, RenderProps } from './components/Render.svelte';
export type ComponentResolver = (name: string, page?: Page) => ResolvedComponent | Promise<ResolvedComponent>;
export type LayoutResolver = (h: RenderFunction, page: RenderProps) => RenderProps;
export type LayoutTuple = [Component, Record<string, unknown>?];
export type LayoutObject = {
    component: Component;
    props?: Record<string, unknown>;
};
export type NamedLayouts = Record<string, Component | LayoutTuple | LayoutObject>;
export type LayoutType = LayoutResolver | Component | Component[] | LayoutTuple | LayoutObject | NamedLayouts | (Component | LayoutTuple | LayoutObject)[];
export type ResolvedComponent = {
    default: Component;
    layout?: LayoutType;
};
export type SvelteInertiaAppConfig = {};
