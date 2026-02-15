import { type Page, type PageProps, type SharedPageProps } from '@inertiajs/core';
type SveltePage<TPageProps extends PageProps = PageProps> = Omit<Page<TPageProps & SharedPageProps>, 'props'> & {
    props: Page<TPageProps & SharedPageProps>['props'] & {
        [key: string]: any;
    };
};
declare const page: SveltePage<PageProps>;
export declare function setPage(newPage: SveltePage): void;
export declare function usePage<TPageProps extends PageProps = PageProps>(): SveltePage<TPageProps>;
export default page;
