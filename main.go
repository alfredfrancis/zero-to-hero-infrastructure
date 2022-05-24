package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
)

func main() {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/ready", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	errs := make(chan error)

	// serve http
	go func() {
		log.Println("listening on 80")
		errs <- http.ListenAndServe(":80", r)
	}()

	log.Println(fmt.Sprintf("exit %s", <-errs))
}
