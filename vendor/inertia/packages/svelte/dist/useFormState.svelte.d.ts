import type { ErrorValue, FormDataErrors, FormDataKeys, FormDataValues, Progress, UrlMethodPair, UseFormTransformCallback, UseFormWithPrecognitionArguments } from '@inertiajs/core';
import type { NamedInputEvent, ValidationConfig, Validator } from 'laravel-precognition';
type TransformCallback<TForm> = (data: TForm) => object;
type PrecognitionValidationConfig<TKeys> = ValidationConfig & {
    only?: TKeys[] | Iterable<TKeys> | ArrayLike<TKeys>;
};
export interface FormStateProps<TForm extends object> {
    isDirty: boolean;
    errors: FormDataErrors<TForm>;
    hasErrors: boolean;
    progress: Progress | null;
    wasSuccessful: boolean;
    recentlySuccessful: boolean;
    processing: boolean;
    setStore(data: TForm): void;
    setStore<T extends FormDataKeys<TForm>>(key: T, value: FormDataValues<TForm, T>): void;
    data(): TForm;
    transform(callback: UseFormTransformCallback<TForm>): this;
    defaults(): this;
    defaults(fields: Partial<TForm>): this;
    defaults<T extends FormDataKeys<TForm>>(field: T, value: FormDataValues<TForm, T>): this;
    reset<K extends FormDataKeys<TForm>>(...fields: K[]): this;
    clearErrors<K extends FormDataKeys<TForm>>(...fields: K[]): this;
    resetAndClearErrors<K extends FormDataKeys<TForm>>(...fields: K[]): this;
    setError<K extends FormDataKeys<TForm>>(field: K, value: ErrorValue): this;
    setError(errors: FormDataErrors<TForm>): this;
    withPrecognition: (...args: UseFormWithPrecognitionArguments) => FormStateWithPrecognition<TForm>;
}
export interface FormStateValidationProps<TForm extends object> {
    invalid<K extends FormDataKeys<TForm>>(field: K): boolean;
    setValidationTimeout(duration: number): this;
    touch<K extends FormDataKeys<TForm>>(field: K | NamedInputEvent | Array<K>, ...fields: K[]): this;
    touched<K extends FormDataKeys<TForm>>(field?: K): boolean;
    valid<K extends FormDataKeys<TForm>>(field: K): boolean;
    validate<K extends FormDataKeys<TForm>>(field?: K | NamedInputEvent | PrecognitionValidationConfig<K>, config?: PrecognitionValidationConfig<K>): this;
    validateFiles(): this;
    validating: boolean;
    validator: () => Validator;
    withAllErrors(): this;
    withoutFileValidation(): this;
    setErrors(errors: FormDataErrors<TForm> | Record<string, string | string[]>): this;
    forgetError<K extends FormDataKeys<TForm> | NamedInputEvent>(field: K): this;
}
export interface InternalPrecognitionState {
    __touched: string[];
    __valid: string[];
}
export interface InternalRememberState<TForm extends object> {
    __rememberable: boolean;
    __remember: () => {
        data: TForm;
        errors: FormDataErrors<TForm>;
    };
    __restore: (restored: {
        data: TForm;
        errors: FormDataErrors<TForm>;
    }) => void;
}
export type FormState<TForm extends object> = FormStateProps<TForm> & TForm;
export type FormStateWithPrecognition<TForm extends object> = FormState<TForm> & FormStateValidationProps<TForm> & InternalPrecognitionState;
export interface UseFormStateOptions<TForm extends object> {
    data: TForm | (() => TForm);
    rememberKey?: string | null;
    precognitionEndpoint?: (() => UrlMethodPair) | null;
}
export interface UseFormStateReturn<TForm extends object> {
    form: FormState<TForm> & InternalRememberState<TForm>;
    setDefaults: (newDefaults: TForm) => void;
    getTransform: () => TransformCallback<TForm>;
    getPrecognitionEndpoint: () => (() => UrlMethodPair) | null;
    setFormState: <K extends string>(key: K, value: any) => void;
    markAsSuccessful: () => void;
    wasDefaultsCalledInOnSuccess: () => boolean;
    resetDefaultsCalledInOnSuccess: () => void;
    setRememberExcludeKeys: (keys: FormDataKeys<TForm>[]) => void;
    resetBeforeSubmit: () => void;
    finishProcessing: () => void;
    withAllErrors: {
        enabled: () => boolean;
        enable: () => void;
    };
}
export default function useFormState<TForm extends object>(options: UseFormStateOptions<TForm>): UseFormStateReturn<TForm>;
export {};
