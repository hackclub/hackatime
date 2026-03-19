import { config, type FormComponentProps, type FormDataConvertible } from '@inertiajs/core';
import { type NamedInputEvent, type ValidationConfig, type Validator } from 'laravel-precognition';
interface $$__sveltets_2_IsomorphicComponent<Props extends Record<string, any> = any, Events extends Record<string, any> = any, Slots extends Record<string, any> = any, Exports = {}, Bindings = string> {
    new (options: import('svelte').ComponentConstructorOptions<Props>): import('svelte').SvelteComponent<Props, Events, Slots> & {
        $$bindings?: Bindings;
    } & Exports;
    (internal: unknown, props: Props & {
        $$events?: Events;
        $$slots?: Slots;
    }): Exports & {
        $set?: any;
        $on?: any;
    };
    z_$$bindings?: Bindings;
}
type $$__sveltets_2_PropsWithChildren<Props, Slots> = Props & (Slots extends {
    default: any;
} ? Props extends Record<string, never> ? any : {
    children?: any;
} : {});
declare const Form: $$__sveltets_2_IsomorphicComponent<$$__sveltets_2_PropsWithChildren<{
    [x: string]: any;
    action?: FormComponentProps["action"];
    method?: FormComponentProps["method"];
    headers?: FormComponentProps["headers"];
    queryStringArrayFormat?: FormComponentProps["queryStringArrayFormat"];
    errorBag?: FormComponentProps["errorBag"];
    showProgress?: FormComponentProps["showProgress"];
    transform?: FormComponentProps["transform"];
    options?: FormComponentProps["options"];
    onCancelToken?: FormComponentProps["onCancelToken"];
    onBefore?: FormComponentProps["onBefore"];
    onStart?: FormComponentProps["onStart"];
    onProgress?: FormComponentProps["onProgress"];
    onFinish?: FormComponentProps["onFinish"];
    onCancel?: FormComponentProps["onCancel"];
    onSuccess?: FormComponentProps["onSuccess"];
    onError?: FormComponentProps["onError"];
    onSubmitComplete?: FormComponentProps["onSubmitComplete"];
    disableWhileProcessing?: boolean | undefined;
    invalidateCacheTags?: FormComponentProps["invalidateCacheTags"];
    resetOnError?: FormComponentProps["resetOnError"];
    resetOnSuccess?: FormComponentProps["resetOnSuccess"];
    setDefaultsOnSuccess?: FormComponentProps["setDefaultsOnSuccess"];
    validateFiles?: FormComponentProps["validateFiles"];
    validationTimeout?: FormComponentProps["validationTimeout"];
    withAllErrors?: FormComponentProps["withAllErrors"];
    getFormData?: ((submitter?: HTMLElement | null) => FormData) | undefined;
    getData?: ((submitter?: HTMLElement | null) => Record<string, FormDataConvertible>) | undefined;
    submit?: ((submitter?: HTMLElement | null) => void) | undefined;
    reset?: ((...fields: string[]) => void) | undefined;
    clearErrors?: ((...fields: string[]) => void) | undefined;
    resetAndClearErrors?: ((...fields: string[]) => void) | undefined;
    setError?: ((fieldOrFields: string | Record<string, string>, maybeValue?: string) => void) | undefined;
    defaults?: (() => void) | undefined;
    validate?: ((field?: string | NamedInputEvent | ValidationConfig, config?: ValidationConfig) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>) | undefined;
    valid?: ((field: string) => boolean) | undefined;
    invalid?: ((field: string) => boolean) | undefined;
    touch?: ((field: string | NamedInputEvent | string[], ...fields: string[]) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>) | undefined;
    touched?: ((field?: string) => boolean) | undefined;
    validator?: (() => Validator) | undefined;
}, {
    default: {
        errors: Errors;
        hasErrors: boolean;
        processing: boolean;
        progress: any;
        wasSuccessful: boolean;
        recentlySuccessful: boolean;
        clearErrors: (...fields: string[]) => void;
        resetAndClearErrors: (...fields: string[]) => void;
        setError: (fieldOrFields: string | Record<string, string>, maybeValue?: string) => void;
        isDirty: boolean;
        submit: (submitter?: HTMLElement | null) => void;
        defaults: () => void;
        reset: (...fields: string[]) => void;
        getData: (submitter?: HTMLElement | null) => Record<string, FormDataConvertible>;
        getFormData: (submitter?: HTMLElement | null) => FormData;
        validator: () => Validator;
        validate: (field?: string | NamedInputEvent | ValidationConfig, config?: ValidationConfig) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>;
        touch: (field: string | NamedInputEvent | string[], ...fields: string[]) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>;
        validating: boolean;
        valid: <K extends config<Record<string, any>>>(field: K) => boolean;
        invalid: <K extends config<Record<string, any>>>(field: K) => boolean;
        touched: <K extends config<Record<string, any>>>(field?: K | undefined) => boolean;
    };
}>, {
    [evt: string]: CustomEvent<any>;
}, {
    default: {
        errors: Errors;
        hasErrors: boolean;
        processing: boolean;
        progress: any;
        wasSuccessful: boolean;
        recentlySuccessful: boolean;
        clearErrors: (...fields: string[]) => void;
        resetAndClearErrors: (...fields: string[]) => void;
        setError: (fieldOrFields: string | Record<string, string>, maybeValue?: string) => void;
        isDirty: boolean;
        submit: (submitter?: HTMLElement | null) => void;
        defaults: () => void;
        reset: (...fields: string[]) => void;
        getData: (submitter?: HTMLElement | null) => Record<string, FormDataConvertible>;
        getFormData: (submitter?: HTMLElement | null) => FormData;
        validator: () => Validator;
        validate: (field?: string | NamedInputEvent | ValidationConfig, config?: ValidationConfig) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>;
        touch: (field: string | NamedInputEvent | string[], ...fields: string[]) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>;
        validating: boolean;
        valid: <K extends config<Record<string, any>>>(field: K) => boolean;
        invalid: <K extends config<Record<string, any>>>(field: K) => boolean;
        touched: <K extends config<Record<string, any>>>(field?: K | undefined) => boolean;
    };
}, {
    getFormData: (submitter?: HTMLElement | null) => FormData;
    getData: (submitter?: HTMLElement | null) => Record<string, FormDataConvertible>;
    submit: (submitter?: HTMLElement | null) => void;
    reset: (...fields: string[]) => void;
    clearErrors: (...fields: string[]) => void;
    resetAndClearErrors: (...fields: string[]) => void;
    setError: (fieldOrFields: string | Record<string, string>, maybeValue?: string) => void;
    defaults: () => void;
    validate: (field?: string | NamedInputEvent | ValidationConfig, config?: ValidationConfig) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>;
    valid: (field: string) => boolean;
    invalid: (field: string) => boolean;
    touch: (field: string | NamedInputEvent | string[], ...fields: string[]) => import("svelte/store").Writable<import("../useForm").InertiaPrecognitiveForm<Record<string, any>>> & import("../useForm").InertiaFormProps<Record<string, any>> & Record<string, any> & import("../useForm").InertiaFormValidationProps<Record<string, any>>;
    touched: (field?: string) => boolean;
    validator: () => Validator;
}, string>;
type Form = InstanceType<typeof Form>;
export default Form;
