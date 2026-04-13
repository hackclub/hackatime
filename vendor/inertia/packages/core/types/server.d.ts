import { InertiaAppResponse, Page } from './types';
export { BROWSER_APIS, type ClassifiedSSRError, type SSRErrorType } from './ssrErrors';
type AppCallback = (page: Page) => InertiaAppResponse;
type ServerOptions = {
    port?: number;
    cluster?: boolean;
    handleErrors?: boolean;
};
type Port = number;
declare const _default: (render: AppCallback, options?: Port | ServerOptions) => AppCallback;
export default _default;
