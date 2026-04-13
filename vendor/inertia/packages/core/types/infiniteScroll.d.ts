import { UseInfiniteScrollOptions, UseInfiniteScrollProps } from './types';
/**
 * Core infinite scroll composable that orchestrates data fetching, DOM management,
 * scroll preservation, and URL synchronization.
 *
 * This is the main entry point that coordinates four sub-systems:
 * - Data management: Handles pagination state and server requests
 * - Element management: DOM observation and intersection detection
 * - Query string sync: Updates URL as user scrolls through pages
 * - Scroll preservation: Maintains scroll position during content updates
 */
export default function useInfiniteScroll(options: UseInfiniteScrollOptions): UseInfiniteScrollProps;
