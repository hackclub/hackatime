import { FormDataConvertible } from './types';
/**
 * Convert a FormData instance into an object structure.
 */
export declare function formDataToObject(source: FormData): Record<string, FormDataConvertible>;
