import type { ComponentResolver, ResolvedComponent } from '../types';
import { type Page, type PageProps } from '@inertiajs/core';
export interface InertiaAppProps<SharedProps extends PageProps = PageProps> {
    initialComponent: ResolvedComponent;
    initialPage: Page<SharedProps>;
    resolveComponent: ComponentResolver;
    defaultLayout?: (name: string, page: Page) => unknown;
}
import type { Component } from 'svelte';
interface Props {
    initialComponent: InertiaAppProps['initialComponent'];
    initialPage: InertiaAppProps['initialPage'];
    resolveComponent: InertiaAppProps['resolveComponent'];
    defaultLayout?: InertiaAppProps['defaultLayout'];
}
declare const App: Component<Props, {}, "">;
type App = ReturnType<typeof App>;
export default App;
