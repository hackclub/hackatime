import { router, UseFormUtils } from '@inertiajs/core';
import { cloneDeep } from 'lodash-es';
import useFormState, {} from './useFormState.svelte';
let reservedFormKeys = null;
let bootstrapping = false;
function validateFormDataKeys(data) {
    if (bootstrapping) {
        return;
    }
    if (reservedFormKeys === null) {
        bootstrapping = true;
        const store = useForm({});
        reservedFormKeys = new Set(Object.keys(store));
        bootstrapping = false;
    }
    const conflicts = Object.keys(data).filter((key) => reservedFormKeys.has(key));
    if (conflicts.length > 0) {
        console.error(`[Inertia] useForm() data contains field(s) that conflict with form properties: ${conflicts.map((k) => `"${k}"`).join(', ')}. ` +
            `These fields will be overwritten by form methods/properties. Please rename these fields.`);
    }
}
export default function useForm(...args) {
    const { rememberKey, data, precognitionEndpoint } = UseFormUtils.parseUseFormArguments(...args);
    const resolvedData = typeof data === 'function' ? data() : data;
    validateFormDataKeys(resolvedData);
    let cancelToken = null;
    let pendingOptimisticCallback = null;
    const { form: baseForm, setDefaults, getTransform, getPrecognitionEndpoint, setFormState, markAsSuccessful, wasDefaultsCalledInOnSuccess, resetDefaultsCalledInOnSuccess, setRememberExcludeKeys, resetBeforeSubmit, finishProcessing, } = useFormState({
        data,
        rememberKey,
        precognitionEndpoint,
    });
    const formWithPrecognition = () => baseForm;
    const submit = (...args) => {
        const { method, url, options } = UseFormUtils.parseSubmitArguments(args, getPrecognitionEndpoint());
        resetDefaultsCalledInOnSuccess();
        const transformedData = getTransform()(form.data());
        const _options = {
            ...options,
            onCancelToken: (token) => {
                cancelToken = token;
                return options.onCancelToken?.(token);
            },
            onBefore: (visit) => {
                resetBeforeSubmit();
                return options.onBefore?.(visit);
            },
            onStart: (visit) => {
                setFormState('processing', true);
                return options.onStart?.(visit);
            },
            onProgress: (event) => {
                setFormState('progress', event || null);
                return options.onProgress?.(event);
            },
            onSuccess: async (page) => {
                markAsSuccessful();
                const onSuccess = options.onSuccess ? await options.onSuccess(page) : null;
                if (!wasDefaultsCalledInOnSuccess()) {
                    setDefaults(cloneDeep(form.data()));
                }
                return onSuccess;
            },
            onError: (errors) => {
                form.clearErrors().setError(errors);
                return options.onError?.(errors);
            },
            onCancel: () => {
                return options.onCancel?.();
            },
            onFinish: (visit) => {
                finishProcessing();
                cancelToken = null;
                return options.onFinish?.(visit);
            },
        };
        _options.optimistic = _options.optimistic ?? pendingOptimisticCallback ?? undefined;
        pendingOptimisticCallback = null;
        if (method === 'delete') {
            router.delete(url, { ..._options, data: transformedData });
        }
        else {
            router[method](url, transformedData, _options);
        }
    };
    const cancel = () => {
        cancelToken?.cancel();
    };
    const createSubmitMethod = (method) => (url, options = {}) => {
        submit(method, url, options);
    };
    Object.assign(baseForm, {
        submit,
        get: createSubmitMethod('get'),
        post: createSubmitMethod('post'),
        put: createSubmitMethod('put'),
        patch: createSubmitMethod('patch'),
        delete: createSubmitMethod('delete'),
        cancel,
        dontRemember(...keys) {
            setRememberExcludeKeys(keys);
            return form;
        },
        optimistic(callback) {
            pendingOptimisticCallback = callback;
            return form;
        },
    });
    const form = baseForm;
    const originalWithPrecognition = formWithPrecognition().withPrecognition;
    form.withPrecognition = (...args) => {
        originalWithPrecognition(...args);
        return form;
    };
    return getPrecognitionEndpoint() ? form : form;
}
