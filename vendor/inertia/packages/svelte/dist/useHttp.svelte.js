import { hasFiles, http, HttpCancelledError, HttpResponseError, mergeDataIntoQueryString, objectToFormData, UseFormUtils, } from '@inertiajs/core';
import { toSimpleValidationErrors } from 'laravel-precognition';
import { cloneDeep } from 'lodash-es';
import useFormState, {} from './useFormState.svelte';
export default function useHttp(...args) {
    const { rememberKey, data, precognitionEndpoint } = UseFormUtils.parseUseFormArguments(...args);
    let abortController = null;
    let pendingOptimisticCallback = null;
    const { form: baseForm, setDefaults, getTransform, getPrecognitionEndpoint, setFormState, markAsSuccessful, wasDefaultsCalledInOnSuccess, resetDefaultsCalledInOnSuccess, setRememberExcludeKeys, resetBeforeSubmit, finishProcessing, withAllErrors, } = useFormState({
        data,
        rememberKey,
        precognitionEndpoint,
    });
    const formWithPrecognition = () => baseForm;
    setFormState('response', null);
    const submit = async (method, url, options) => {
        const onBefore = options.onBefore?.();
        if (onBefore === false) {
            return Promise.reject(new Error('Request cancelled by onBefore'));
        }
        resetDefaultsCalledInOnSuccess();
        resetBeforeSubmit();
        abortController = new AbortController();
        const cancelToken = {
            cancel: () => abortController?.abort(),
        };
        options.onCancelToken?.(cancelToken);
        options.optimistic = options.optimistic ?? pendingOptimisticCallback ?? undefined;
        pendingOptimisticCallback = null;
        let snapshot;
        if (options.optimistic) {
            snapshot = cloneDeep(form.data());
            const optimisticData = options.optimistic(cloneDeep(snapshot));
            Object.keys(optimisticData).forEach((key) => {
                ;
                baseForm[key] = optimisticData[key];
            });
        }
        setFormState('processing', true);
        options.onStart?.();
        const transformedData = getTransform()(form.data());
        const useFormData = hasFiles(transformedData);
        let requestUrl = url;
        let requestData;
        let contentType;
        if (method === 'get') {
            const [urlWithParams] = mergeDataIntoQueryString(method, url, transformedData);
            requestUrl = urlWithParams;
        }
        else {
            if (useFormData) {
                requestData = objectToFormData(transformedData);
            }
            else {
                requestData = JSON.stringify(transformedData);
                contentType = 'application/json';
            }
        }
        try {
            const response = await http.getClient().request({
                method,
                url: requestUrl,
                data: requestData,
                headers: {
                    Accept: 'application/json',
                    ...(contentType ? { 'Content-Type': contentType } : {}),
                    ...options.headers,
                },
                signal: abortController.signal,
                onUploadProgress: (event) => {
                    setFormState('progress', event);
                    options.onProgress?.(event);
                },
            });
            const responseData = JSON.parse(response.data);
            if (response.status >= 200 && response.status < 300) {
                markAsSuccessful();
                setFormState('response', responseData);
                options.onSuccess?.(responseData);
                if (!wasDefaultsCalledInOnSuccess()) {
                    setDefaults(cloneDeep(form.data()));
                }
                setFormState('isDirty', false);
                return responseData;
            }
            throw new HttpResponseError(`Request failed with status ${response.status}`, response, url);
        }
        catch (error) {
            if (snapshot) {
                Object.keys(snapshot).forEach((key) => {
                    ;
                    baseForm[key] = snapshot[key];
                });
            }
            if (error instanceof HttpResponseError) {
                if (error.response.status === 422) {
                    const responseData = JSON.parse(error.response.data);
                    const validationErrors = responseData.errors || {};
                    const processedErrors = (withAllErrors.enabled() ? validationErrors : toSimpleValidationErrors(validationErrors));
                    form.clearErrors().setError(processedErrors);
                    options.onError?.(processedErrors);
                }
                throw error;
            }
            if (error instanceof HttpCancelledError || (error instanceof Error && error.name === 'AbortError')) {
                options.onCancel?.();
                throw new HttpCancelledError('Request was cancelled', url);
            }
            throw error;
        }
        finally {
            finishProcessing();
            abortController = null;
            options.onFinish?.();
        }
    };
    const cancel = () => {
        abortController?.abort();
    };
    const createSubmitMethod = (method) => async (url, options = {}) => {
        return submit(method, url, options);
    };
    Object.assign(baseForm, {
        submit(...args) {
            const parsed = UseFormUtils.parseSubmitArguments(args, getPrecognitionEndpoint());
            return submit(parsed.method, parsed.url, parsed.options);
        },
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
        withAllErrors() {
            withAllErrors.enable();
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
