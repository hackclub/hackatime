import type { QueryStringArrayFormatOption } from './types';
/**
 * Returns true if the given URL query string contains indexed array parameters.
 */
export declare function hasIndices(url: URL): boolean;
/**
 * Parse a query string into a nested object.
 */
export declare function parse(query: string): Record<string, unknown>;
/**
 * Convert an object to a query string.
 */
export declare function stringify(data: Record<string, unknown>, arrayFormat: QueryStringArrayFormatOption): string;
