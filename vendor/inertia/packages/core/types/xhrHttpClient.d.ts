import { HttpClient, HttpClientOptions, HttpRequestConfig, HttpResponse } from './types';
/**
 * Inertia's built-in HTTP client using XMLHttpRequest
 */
export declare class XhrHttpClient implements HttpClient {
    protected xsrfCookieName: string;
    protected xsrfHeaderName: string;
    constructor(options?: HttpClientOptions);
    request(config: HttpRequestConfig): Promise<HttpResponse>;
    protected doRequest(config: HttpRequestConfig): Promise<HttpResponse>;
}
export declare const xhrHttpClient: XhrHttpClient;
