import {} from '@inertiajs/core';
const page = $state({
    component: '',
    props: {},
    url: '',
    version: null,
});
export function setPage(newPage) {
    Object.assign(page, newPage);
}
export function usePage() {
    return page;
}
export default page;
