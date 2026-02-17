import { InertiaAppConfig } from './types';
type ConfigKeys<T> = T extends Function ? never : string extends keyof T ? string : Extract<keyof T, string> | {
    [Key in Extract<keyof T, string>]: T[Key] extends object ? `${Key}.${ConfigKeys<T[Key]> & string}` : never;
}[Extract<keyof T, string>];
type ConfigValue<T, K extends ConfigKeys<T>> = K extends `${infer P}.${infer Rest}` ? P extends keyof T ? Rest extends ConfigKeys<T[P]> ? ConfigValue<T[P], Rest> : never : never : K extends keyof T ? T[K] : never;
type ConfigSetObject<T> = {
    [K in ConfigKeys<T>]?: ConfigValue<T, K>;
};
type FirstLevelOptional<T> = {
    [K in keyof T]?: T[K] extends object ? {
        [P in keyof T[K]]?: T[K][P];
    } : T[K];
};
export declare class Config<TConfig extends {} = {}> {
    protected config: FirstLevelOptional<TConfig>;
    protected defaults: TConfig;
    constructor(defaults: TConfig);
    extend<TExtension extends {}>(defaults?: TExtension): Config<TConfig & TExtension>;
    replace(newConfig: FirstLevelOptional<TConfig>): void;
    get<K extends ConfigKeys<TConfig>>(key: K): ConfigValue<TConfig, K>;
    set<K extends ConfigKeys<TConfig>>(keyOrValues: K | Partial<ConfigSetObject<TConfig>>, value?: ConfigValue<TConfig, K>): void;
}
export declare const config: Config<InertiaAppConfig>;
export {};
