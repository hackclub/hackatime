export declare const objectsAreEqual: <T extends Record<string, any>>(obj1: T, obj2: T, excludeKeys: { [K in keyof T]: K; }[keyof T][]) => boolean;
