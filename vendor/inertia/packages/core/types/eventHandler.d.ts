import { GlobalEvent, GlobalEventNames, GlobalEventResult, InternalEvent } from './types';
declare class EventHandler {
    protected internalListeners: {
        event: InternalEvent;
        listener: (...args: any[]) => void;
    }[];
    init(): void;
    onGlobalEvent<TEventName extends GlobalEventNames>(type: TEventName, callback: (event: GlobalEvent<TEventName>) => GlobalEventResult<TEventName>): VoidFunction;
    on(event: InternalEvent, callback: (...args: any[]) => void): VoidFunction;
    onMissingHistoryItem(): void;
    fireInternalEvent(event: InternalEvent, ...args: any[]): void;
    protected registerListener(type: string, listener: EventListener): VoidFunction;
    protected handlePageshowEvent(event: PageTransitionEvent): void;
    protected handlePopstateEvent(event: PopStateEvent): void;
}
export declare const eventHandler: EventHandler;
export {};
