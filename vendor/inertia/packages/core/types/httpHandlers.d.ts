import { HttpCancelledError, HttpNetworkError, HttpResponseError } from './httpErrors';
import { HttpErrorHandler, HttpRequestConfig, HttpRequestHandler, HttpResponse, HttpResponseHandler } from './types';
declare class HttpHandlers {
    protected requestHandlers: HttpRequestHandler[];
    protected responseHandlers: HttpResponseHandler[];
    protected errorHandlers: HttpErrorHandler[];
    onRequest(handler: HttpRequestHandler): () => void;
    onResponse(handler: HttpResponseHandler): () => void;
    onError(handler: HttpErrorHandler): () => void;
    processRequest(config: HttpRequestConfig): Promise<HttpRequestConfig>;
    processResponse(response: HttpResponse): Promise<HttpResponse>;
    processError(error: HttpResponseError | HttpNetworkError | HttpCancelledError): Promise<void>;
}
export declare const httpHandlers: HttpHandlers;
export {};
