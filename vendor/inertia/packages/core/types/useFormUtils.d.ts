import { NamedInputEvent, ValidationConfig } from 'laravel-precognition';
import { FormDataType, Method, UrlMethodPair, UseFormArguments, UseFormSubmitArguments, UseFormSubmitOptions } from './types';
export declare class UseFormUtils {
    /**
     * Creates a callback that returns a UrlMethodPair.
     *
     * createWayfinderCallback(urlMethodPair)
     * createWayfinderCallback(method, url)
     * createWayfinderCallback(() => urlMethodPair)
     * createWayfinderCallback(() => method, () => url)
     */
    static createWayfinderCallback(...args: [UrlMethodPair | (() => UrlMethodPair)] | [Method | (() => Method), string | (() => string)]): () => UrlMethodPair;
    /**
     * Parses all useForm() arguments into { rememberKey, data, precognitionEndpoint }.
     *
     * useForm()
     * useForm(data)
     * useForm(rememberKey, data)
     * useForm(method, url, data)
     * useForm(urlMethodPair, data)
     *
     */
    static parseUseFormArguments<TForm extends FormDataType<TForm>>(...args: UseFormArguments<TForm>): {
        rememberKey: string | null;
        data: TForm | (() => TForm);
        precognitionEndpoint: (() => UrlMethodPair) | null;
    };
    /**
     * Parses all submission arguments into { method, url, options }.
     * It uses the Precognition endpoint if no explicit method/url are provided.
     *
     * form.submit(method, url)
     * form.submit(method, url, options)
     * form.submit(urlMethodPair)
     * form.submit(urlMethodPair, options)
     * form.submit()
     * form.submit(options)
     */
    static parseSubmitArguments(args: UseFormSubmitArguments, precognitionEndpoint: (() => UrlMethodPair) | null): {
        method: Method;
        url: string;
        options: UseFormSubmitOptions;
    };
    /**
     * Merges headers into the Precognition validate() arguments.
     */
    static mergeHeadersForValidation(field?: string | NamedInputEvent | ValidationConfig, config?: ValidationConfig, headers?: Record<string, string>): [string | NamedInputEvent | ValidationConfig | undefined, ValidationConfig | undefined];
}
