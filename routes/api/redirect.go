package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

type RedirectApiHandler struct{}

func NewRedirectApiHandler() *RedirectApiHandler {
	return &RedirectApiHandler{}
}

func (h *RedirectApiHandler) RegisterRoutes(router chi.Router) {
	router.Get("/", h.Redirect)
}

// Redirect redirects the user to /
func (h *RedirectApiHandler) Redirect(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "/", http.StatusFound)
}