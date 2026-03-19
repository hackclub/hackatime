import type { LinkComponentBaseProps } from '@inertiajs/core';
interface $$__sveltets_2_IsomorphicComponent<Props extends Record<string, any> = any, Events extends Record<string, any> = any, Slots extends Record<string, any> = any, Exports = {}, Bindings = string> {
    new (options: import('svelte').ComponentConstructorOptions<Props>): import('svelte').SvelteComponent<Props, Events, Slots> & {
        $$bindings?: Bindings;
    } & Exports;
    (internal: unknown, props: Props & {
        $$events?: Events;
        $$slots?: Slots;
    }): Exports & {
        $set?: any;
        $on?: any;
    };
    z_$$bindings?: Bindings;
}
type $$__sveltets_2_PropsWithChildren<Props, Slots> = Props & (Slots extends {
    default: any;
} ? Props extends Record<string, never> ? any : {
    children?: any;
} : {});
declare const Link: $$__sveltets_2_IsomorphicComponent<$$__sveltets_2_PropsWithChildren<{
    [x: string]: any;
    href?: LinkComponentBaseProps["href"];
    as?: keyof HTMLElementTagNameMap | undefined;
    data?: LinkComponentBaseProps["data"];
    method?: LinkComponentBaseProps["method"];
    replace?: LinkComponentBaseProps["replace"];
    preserveScroll?: LinkComponentBaseProps["preserveScroll"];
    preserveState?: LinkComponentBaseProps["preserveState"] | null;
    preserveUrl?: LinkComponentBaseProps["preserveUrl"];
    only?: LinkComponentBaseProps["only"];
    except?: LinkComponentBaseProps["except"];
    headers?: LinkComponentBaseProps["headers"];
    queryStringArrayFormat?: LinkComponentBaseProps["queryStringArrayFormat"];
    async?: LinkComponentBaseProps["async"];
    prefetch?: LinkComponentBaseProps["prefetch"];
    cacheFor?: LinkComponentBaseProps["cacheFor"];
    cacheTags?: LinkComponentBaseProps["cacheTags"];
    viewTransition?: LinkComponentBaseProps["viewTransition"];
}, {
    default: {};
}>, {
    focus: FocusEvent;
    blur: FocusEvent;
    click: PointerEvent;
    dblclick: MouseEvent;
    mousedown: MouseEvent;
    mousemove: MouseEvent;
    mouseout: MouseEvent;
    mouseover: MouseEvent;
    mouseup: MouseEvent;
    'cancel-token': Event | InputEvent | UIEvent | SubmitEvent | ProgressEvent<EventTarget> | AnimationEvent | PointerEvent | MouseEvent | ToggleEvent | FocusEvent | CompositionEvent | ClipboardEvent | DragEvent | ErrorEvent | FormDataEvent | KeyboardEvent | SecurityPolicyViolationEvent | TouchEvent | TransitionEvent | WheelEvent;
    before: Event | InputEvent | UIEvent | SubmitEvent | ProgressEvent<EventTarget> | AnimationEvent | PointerEvent | MouseEvent | ToggleEvent | FocusEvent | CompositionEvent | ClipboardEvent | DragEvent | ErrorEvent | FormDataEvent | KeyboardEvent | SecurityPolicyViolationEvent | TouchEvent | TransitionEvent | WheelEvent;
    start: Event | InputEvent | UIEvent | SubmitEvent | ProgressEvent<EventTarget> | AnimationEvent | PointerEvent | MouseEvent | ToggleEvent | FocusEvent | CompositionEvent | ClipboardEvent | DragEvent | ErrorEvent | FormDataEvent | KeyboardEvent | SecurityPolicyViolationEvent | TouchEvent | TransitionEvent | WheelEvent;
    progress: ProgressEvent<EventTarget>;
    finish: Event | InputEvent | UIEvent | SubmitEvent | ProgressEvent<EventTarget> | AnimationEvent | PointerEvent | MouseEvent | ToggleEvent | FocusEvent | CompositionEvent | ClipboardEvent | DragEvent | ErrorEvent | FormDataEvent | KeyboardEvent | SecurityPolicyViolationEvent | TouchEvent | TransitionEvent | WheelEvent;
    cancel: Event;
    success: Event | InputEvent | UIEvent | SubmitEvent | ProgressEvent<EventTarget> | AnimationEvent | PointerEvent | MouseEvent | ToggleEvent | FocusEvent | CompositionEvent | ClipboardEvent | DragEvent | ErrorEvent | FormDataEvent | KeyboardEvent | SecurityPolicyViolationEvent | TouchEvent | TransitionEvent | WheelEvent;
    error: ErrorEvent;
    prefetching: Event | InputEvent | UIEvent | SubmitEvent | ProgressEvent<EventTarget> | AnimationEvent | PointerEvent | MouseEvent | ToggleEvent | FocusEvent | CompositionEvent | ClipboardEvent | DragEvent | ErrorEvent | FormDataEvent | KeyboardEvent | SecurityPolicyViolationEvent | TouchEvent | TransitionEvent | WheelEvent;
    prefetched: Event | InputEvent | UIEvent | SubmitEvent | ProgressEvent<EventTarget> | AnimationEvent | PointerEvent | MouseEvent | ToggleEvent | FocusEvent | CompositionEvent | ClipboardEvent | DragEvent | ErrorEvent | FormDataEvent | KeyboardEvent | SecurityPolicyViolationEvent | TouchEvent | TransitionEvent | WheelEvent;
} & {
    [evt: string]: CustomEvent<any>;
}, {
    default: {};
}, {}, string>;
type Link = InstanceType<typeof Link>;
export default Link;
