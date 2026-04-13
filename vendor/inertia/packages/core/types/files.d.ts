import { FormDataConvertible, RequestPayload } from './types';
export declare const isFile: (value: unknown) => boolean;
export declare function hasFiles(data: RequestPayload | FormDataConvertible): boolean;
