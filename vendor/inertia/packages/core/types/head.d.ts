import { HeadManager, HeadManagerOnUpdateCallback, HeadManagerTitleCallback } from '.';
export default function createHeadManager(isServer: boolean, titleCallback: HeadManagerTitleCallback, onUpdate: HeadManagerOnUpdateCallback): HeadManager;
