import { HttpResponse } from './types';
export declare class HttpResponseError extends Error {
    readonly response: HttpResponse;
    readonly url?: string;
    constructor(message: string, response: HttpResponse, url?: string);
}
export declare class HttpCancelledError extends Error {
    readonly url?: string;
    constructor(message?: string, url?: string);
}
export declare class HttpNetworkError extends Error {
    readonly cause?: Error;
    readonly code = "ERR_NETWORK";
    readonly url?: string;
    constructor(message: string, url?: string, cause?: Error);
}
