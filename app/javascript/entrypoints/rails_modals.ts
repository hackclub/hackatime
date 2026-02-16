import { mount, unmount } from "svelte";
import RailsModal from "../components/RailsModal.svelte";

type ModalComponent = ReturnType<typeof mount>;

const mountedModals = new Map<HTMLElement, ModalComponent>();

function templateHtml(host: HTMLElement, selector: string): string {
  const template = host.querySelector<HTMLTemplateElement>(selector);
  return template?.innerHTML.trim() ?? "";
}

function mountModal(host: HTMLElement) {
  if (mountedModals.has(host)) return;
  if (!host.id) return;

  const props = {
    modalId: host.id,
    title: host.dataset.modalTitle ?? "Confirm",
    description: host.dataset.modalDescription ?? "",
    maxWidth: host.dataset.modalMaxWidth ?? "max-w-md",
    iconHtml: templateHtml(host, "template[data-modal-icon]"),
    customHtml: templateHtml(host, "template[data-modal-custom]"),
    actionsHtml: templateHtml(host, "template[data-modal-actions]"),
  };

  host.replaceChildren();
  const component = mount(RailsModal, { target: host, props });
  mountedModals.set(host, component);
}

function pruneUnmounted() {
  for (const [host, component] of mountedModals) {
    if (!host.isConnected) {
      unmount(component);
      mountedModals.delete(host);
    }
  }
}

function mountAllRailsModals() {
  pruneUnmounted();
  document
    .querySelectorAll<HTMLElement>("[data-bits-modal]")
    .forEach((host) => mountModal(host));
}

["DOMContentLoaded", "turbo:load", "turbo:render", "turbo:frame-load"].forEach(
  (eventName) => {
    document.addEventListener(eventName, mountAllRailsModals);
  },
);

mountAllRailsModals();
