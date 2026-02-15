import { HttpClient, HttpClientOptions } from './types';
export declare const http: {
    /**
     * Get the current HTTP client
     */
    getClient(): HttpClient;
    /**
     * Set the HTTP client to use for all Inertia requests
     */
    setClient(clientOrOptions: HttpClient | HttpClientOptions): void;
    /**
     * Register a request handler that runs before each request
     */
    onRequest: (handler: import("./types").HttpRequestHandler) => () => void;
    /**
     * Register a response handler that runs after each successful response
     */
    onResponse: (handler: import("./types").HttpResponseHandler) => () => void;
    /**
     * Register an error handler that runs when a request fails
     */
    onError: (handler: import("./types").HttpErrorHandler) => () => void;
    /**
     * Process a request config through all registered request handlers.
     * For use by custom HttpClient implementations.
     */
    processRequest: (config: import("./types").HttpRequestConfig) => Promise<import("./types").HttpRequestConfig>;
    /**
     * Process a response through all registered response handlers.
     * For use by custom HttpClient implementations.
     */
    processResponse: (response: import("./types").HttpResponse) => Promise<import("./types").HttpResponse>;
    /**
     * Process an error through all registered error handlers.
     * For use by custom HttpClient implementations.
     */
    processError: (error: import("./httpErrors").HttpResponseError | import("./httpErrors").HttpNetworkError | import("./httpErrors").HttpCancelledError) => Promise<void>;
};
