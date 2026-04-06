import { isUrlMethodPair, mergeDataIntoQueryString, router, shouldIntercept, shouldNavigate, } from '@inertiajs/core';
import { config } from '.';
function link(node, initialParams = {}) {
    let inFlightCount = 0;
    let hoverTimeout;
    let prefetchModes = [];
    let cacheForValue;
    let cacheTags = [];
    let method;
    let href;
    let data;
    let baseParams;
    let visitParams;
    const regularEvents = {
        click: (event) => {
            if (shouldIntercept(event)) {
                event.preventDefault();
                router.visit(href, visitParams);
            }
        },
    };
    const prefetchHoverEvents = {
        mouseenter: () => (hoverTimeout = setTimeout(() => prefetch(), config.get('prefetch.hoverDelay'))),
        mouseleave: () => clearTimeout(hoverTimeout),
        click: regularEvents.click,
    };
    const prefetchClickEvents = {
        mousedown: (event) => {
            if (shouldIntercept(event)) {
                event.preventDefault();
                prefetch();
            }
        },
        keydown: (event) => {
            if (shouldNavigate(event)) {
                event.preventDefault();
                prefetch();
            }
        },
        mouseup: (event) => {
            if (shouldIntercept(event)) {
                event.preventDefault();
                router.visit(href, visitParams);
            }
        },
        keyup: (event) => {
            if (shouldNavigate(event)) {
                event.preventDefault();
                router.visit(href, visitParams);
            }
        },
        click: (event) => {
            if (shouldIntercept(event)) {
                event.preventDefault();
            }
        },
    };
    function update({ cacheFor = 0, prefetch = false, cacheTags: cacheTagValues = [], viewTransition = false, ...params }) {
        prefetchModes = (() => {
            if (prefetch === true) {
                return ['hover'];
            }
            if (prefetch === false) {
                return [];
            }
            return Array.isArray(prefetch) ? prefetch : [prefetch];
        })();
        cacheForValue = (() => {
            if (cacheFor !== 0) {
                return cacheFor;
            }
            if (prefetchModes.length === 1 && prefetchModes[0] === 'click') {
                return 0;
            }
            return config.get('prefetch.cacheFor');
        })();
        cacheTags = Array.isArray(cacheTagValues) ? cacheTagValues : [cacheTagValues];
        method = isUrlMethodPair(params.href) ? params.href.method : params.method?.toLowerCase() || 'get';
        [href, data] = hrefAndData(method, params);
        if (node.tagName === 'A') {
            node.href = href;
        }
        baseParams = {
            data,
            method,
            replace: params.replace || false,
            preserveScroll: params.preserveScroll || false,
            preserveState: params.preserveState ?? method !== 'get',
            preserveUrl: params.preserveUrl || false,
            only: params.only || [],
            except: params.except || [],
            headers: params.headers || {},
            async: params.async || false,
        };
        visitParams = {
            ...baseParams,
            viewTransition,
            onStart: (visit) => {
                inFlightCount++;
                updateNodeAttributes();
                return dispatchEvent('start', { detail: { visit } });
            },
            onProgress: (progress) => dispatchEvent('progress', { detail: { progress } }),
            onFinish: (visit) => {
                inFlightCount--;
                updateNodeAttributes();
                return dispatchEvent('finish', { detail: { visit } });
            },
            onBefore: (visit) => dispatchEvent('before', { cancelable: true, detail: { visit } }),
            onCancel: () => dispatchEvent('cancel'),
            onSuccess: (page) => dispatchEvent('success', { detail: { page } }),
            onError: (errors) => dispatchEvent('error', { detail: { errors } }),
            onCancelToken: (token) => dispatchEvent('cancel-token', { detail: { token } }),
            onPrefetching: (visit) => dispatchEvent('prefetching', { detail: { visit } }),
            onPrefetched: (response, visit) => dispatchEvent('prefetched', { detail: { response, visit } }),
        };
        updateEventListeners();
    }
    function dispatchEvent(type, detail = {}) {
        return node.dispatchEvent(new CustomEvent(type, detail));
    }
    function hrefAndData(method, params) {
        return mergeDataIntoQueryString(method, isUrlMethodPair(params.href) ? params.href.url : node.href || params.href || '', params.data || {}, params.queryStringArrayFormat || 'brackets');
    }
    function prefetch() {
        router.prefetch(href, {
            ...baseParams,
            onPrefetching: (visit) => dispatchEvent('prefetching', { detail: { visit } }),
            onPrefetched: (response, visit) => dispatchEvent('prefetched', { detail: { response, visit } }),
        }, { cacheFor: cacheForValue, cacheTags });
    }
    function updateNodeAttributes() {
        if (inFlightCount > 0) {
            node.setAttribute('data-loading', '');
            return;
        }
        node.removeAttribute('data-loading');
    }
    function updateEventListeners() {
        removeEventListeners();
        if (prefetchModes.includes('hover')) {
            addEventListeners(prefetchHoverEvents);
            return;
        }
        if (prefetchModes.includes('click')) {
            addEventListeners(prefetchClickEvents);
            return;
        }
        addEventListeners(regularEvents);
    }
    function addEventListeners(eventHandlers) {
        Object.entries(eventHandlers).forEach(([event, handler]) => {
            node.addEventListener(event, handler);
        });
    }
    function removeEventListeners() {
        ;
        [prefetchHoverEvents, prefetchClickEvents, regularEvents].forEach((eventHandlers) => {
            Object.entries(eventHandlers).forEach(([event, handler]) => {
                node.removeEventListener(event, handler);
            });
        });
    }
    function destroy() {
        clearTimeout(hoverTimeout);
        removeEventListeners();
    }
    update(initialParams);
    if (prefetchModes.includes('mount')) {
        prefetch();
    }
    return { update, destroy };
}
export default link;
