import { router, UseFormUtils } from '@inertiajs/core';
import { createValidator, resolveName, toSimpleValidationErrors } from 'laravel-precognition';
import { cloneDeep, get, has, isEqual, set } from 'lodash-es';
import { config } from '.';
export default function useFormState(options) {
    const { data: dataOption, rememberKey, precognitionEndpoint: initialPrecognitionEndpoint } = options;
    const isDataFunction = typeof dataOption === 'function';
    const resolveData = () => (isDataFunction ? dataOption() : dataOption);
    const restored = rememberKey
        ? router.restore(rememberKey)
        : null;
    const initialData = restored?.data ?? cloneDeep(resolveData());
    let defaults = cloneDeep(initialData);
    let transform = (data) => data;
    let validatorRef = null;
    let withAllErrors = null;
    const withAllErrorsEnabled = () => withAllErrors ?? config.get('form.withAllErrors');
    let precognitionEndpoint = initialPrecognitionEndpoint ?? null;
    let recentlySuccessfulTimeoutId = null;
    let defaultsCalledInOnSuccess = false;
    let rememberExcludeKeys = [];
    let setFormStateInternal;
    const tap = (value, callback) => {
        callback(value);
        return value;
    };
    const withPrecognition = (...args) => {
        precognitionEndpoint = UseFormUtils.createWayfinderCallback(...args);
        const formWithPrecognition = () => form;
        if (!validatorRef) {
            const validator = createValidator((client) => {
                const { method, url } = precognitionEndpoint();
                const f = formWithPrecognition();
                const transformedData = cloneDeep(transform(f.data()));
                return client[method](url, transformedData);
            }, cloneDeep(defaults));
            validatorRef = validator;
            validator
                .on('validatingChanged', () => {
                setFormStateInternal('validating', validator.validating());
            })
                .on('validatedChanged', () => {
                setFormStateInternal('__valid', validator.valid());
            })
                .on('touchedChanged', () => {
                setFormStateInternal('__touched', validator.touched());
            })
                .on('errorsChanged', () => {
                const validationErrors = withAllErrorsEnabled()
                    ? validator.errors()
                    : toSimpleValidationErrors(validator.errors());
                setFormStateInternal('errors', {});
                formWithPrecognition().setError(validationErrors);
                setFormStateInternal('__valid', validator.valid());
            });
        }
        Object.assign(form, {
            ...form,
            __touched: [],
            __valid: [],
            validating: false,
            validator: () => validatorRef,
            validate: (field, config) => {
                const f = formWithPrecognition();
                if (typeof field === 'object' && !('target' in field)) {
                    config = field;
                    field = undefined;
                }
                if (field === undefined) {
                    validatorRef.validate(config);
                }
                else {
                    field = resolveName(field);
                    const transformedData = transform(f.data());
                    validatorRef.validate(field, get(transformedData, field), config);
                }
                return f;
            },
            touch: (field, ...fields) => {
                const f = formWithPrecognition();
                if (Array.isArray(field)) {
                    validatorRef?.touch(field);
                }
                else if (typeof field === 'string') {
                    validatorRef?.touch([field, ...fields]);
                }
                else {
                    validatorRef?.touch(field);
                }
                return f;
            },
            validateFiles: () => tap(formWithPrecognition(), () => validatorRef?.validateFiles()),
            setValidationTimeout: (duration) => tap(formWithPrecognition(), () => validatorRef.setTimeout(duration)),
            withAllErrors: () => tap(formWithPrecognition(), () => (withAllErrors = true)),
            withoutFileValidation: () => tap(formWithPrecognition(), () => validatorRef?.withoutFileValidation()),
            valid: (field) => formWithPrecognition().__valid.includes(field),
            invalid: (field) => field in formWithPrecognition().errors,
            touched: (field) => {
                const touched = formWithPrecognition().__touched;
                return typeof field === 'string' ? touched.includes(field) : touched.length > 0;
            },
            setErrors: (errors) => tap(formWithPrecognition(), () => {
                const f = formWithPrecognition();
                f.setError(errors);
            }),
            forgetError: (field) => tap(formWithPrecognition(), () => {
                const f = formWithPrecognition();
                f.clearErrors(resolveName(field));
            }),
        });
        return form;
    };
    let form = $state({
        ...initialData,
        isDirty: false,
        errors: (restored?.errors ?? {}),
        hasErrors: false,
        progress: null,
        wasSuccessful: false,
        recentlySuccessful: false,
        processing: false,
        setStore(keyOrData, maybeValue = undefined) {
            if (typeof keyOrData === 'string') {
                set(form, keyOrData, maybeValue);
            }
            else {
                Object.assign(form, keyOrData);
            }
        },
        data() {
            return Object.keys(defaults).reduce((carry, key) => {
                return set(carry, key, get(this, key));
            }, {});
        },
        transform(callback) {
            transform = callback;
            return this;
        },
        defaults(fieldOrFields, maybeValue) {
            if (isDataFunction) {
                throw new Error('You cannot call `defaults()` when using a function to define your form data.');
            }
            defaultsCalledInOnSuccess = true;
            if (typeof fieldOrFields === 'undefined') {
                defaults = cloneDeep(this.data());
                this.isDirty = false;
            }
            else {
                defaults =
                    typeof fieldOrFields === 'string'
                        ? set(cloneDeep(defaults), fieldOrFields, maybeValue)
                        : Object.assign(cloneDeep(defaults), fieldOrFields);
            }
            validatorRef?.defaults(defaults);
            return this;
        },
        reset(...fields) {
            const resolvedData = isDataFunction ? cloneDeep(resolveData()) : defaults;
            const clonedData = cloneDeep(resolvedData);
            if (fields.length === 0) {
                if (isDataFunction) {
                    defaults = clonedData;
                }
                this.setStore(clonedData);
            }
            else {
                ;
                fields
                    .filter((key) => has(clonedData, key))
                    .forEach((key) => {
                    if (isDataFunction) {
                        set(defaults, key, get(clonedData, key));
                    }
                    set(this, key, get(clonedData, key));
                });
            }
            validatorRef?.reset(...fields);
            return this;
        },
        setError(fieldOrFields, maybeValue) {
            const errors = typeof fieldOrFields === 'string' ? { [fieldOrFields]: maybeValue } : fieldOrFields;
            setFormStateInternal('errors', {
                ...this.errors,
                ...errors,
            });
            validatorRef?.setErrors(errors);
            return this;
        },
        clearErrors(...fields) {
            setFormStateInternal('errors', Object.keys(this.errors).reduce((carry, field) => ({
                ...carry,
                ...(fields.length > 0 && !fields.includes(field) ? { [field]: this.errors[field] } : {}),
            }), {}));
            if (validatorRef) {
                if (fields.length === 0) {
                    validatorRef.setErrors({});
                }
                else {
                    fields.forEach(validatorRef.forgetError);
                }
            }
            return this;
        },
        resetAndClearErrors(...fields) {
            this.reset(...fields);
            this.clearErrors(...fields);
            return this;
        },
        withPrecognition,
        __rememberable: rememberKey === null,
        __remember() {
            const formData = this.data();
            if (rememberExcludeKeys.length > 0) {
                const filtered = { ...formData };
                rememberExcludeKeys.forEach((k) => delete filtered[k]);
                return { data: filtered, errors: $state.snapshot(this.errors) };
            }
            return { data: formData, errors: $state.snapshot(this.errors) };
        },
        __restore(restored) {
            Object.assign(this, restored.data);
            this.setError(restored.errors);
        },
    });
    setFormStateInternal = (key, value) => {
        form[key] = value;
    };
    $effect(() => {
        const newIsDirty = !isEqual(form.data(), defaults);
        if (form.isDirty !== newIsDirty) {
            setFormStateInternal('isDirty', newIsDirty);
        }
        const hasErrors = Object.keys(form.errors).length > 0;
        if (form.hasErrors !== hasErrors) {
            setFormStateInternal('hasErrors', hasErrors);
        }
    });
    $effect(() => {
        if (!rememberKey) {
            return;
        }
        const storedData = router.restore(rememberKey);
        const newData = form.__remember();
        if (!isEqual(storedData, newData)) {
            router.remember(newData, rememberKey);
        }
    });
    if (precognitionEndpoint) {
        form.withPrecognition(precognitionEndpoint);
    }
    return {
        form: form,
        setDefaults: (newDefaults) => {
            defaults = newDefaults;
        },
        getTransform: () => transform,
        getPrecognitionEndpoint: () => precognitionEndpoint,
        setFormState: setFormStateInternal,
        markAsSuccessful: () => {
            form.clearErrors();
            setFormStateInternal('wasSuccessful', true);
            setFormStateInternal('recentlySuccessful', true);
            recentlySuccessfulTimeoutId = setTimeout(() => setFormStateInternal('recentlySuccessful', false), config.get('form.recentlySuccessfulDuration'));
        },
        wasDefaultsCalledInOnSuccess: () => defaultsCalledInOnSuccess,
        resetDefaultsCalledInOnSuccess: () => {
            defaultsCalledInOnSuccess = false;
        },
        setRememberExcludeKeys: (keys) => {
            rememberExcludeKeys = keys;
        },
        resetBeforeSubmit: () => {
            setFormStateInternal('wasSuccessful', false);
            setFormStateInternal('recentlySuccessful', false);
            if (recentlySuccessfulTimeoutId) {
                clearTimeout(recentlySuccessfulTimeoutId);
            }
        },
        finishProcessing: () => {
            setFormStateInternal('processing', false);
            setFormStateInternal('progress', null);
        },
        withAllErrors: {
            enabled: withAllErrorsEnabled,
            enable: () => {
                withAllErrors = true;
            },
        },
    };
}
