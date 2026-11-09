package mail

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestResendSend(t *testing.T) {
	var got map[string]any
	var auth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/emails" || r.Method != http.MethodPost {
			t.Errorf("request %s %s", r.Method, r.URL.Path)
		}
		auth = r.Header.Get("Authorization")
		json.NewDecoder(r.Body).Decode(&got)
		w.Write([]byte(`{"id":"abc"}`))
	}))
	defer srv.Close()

	r := &Resend{APIKey: "re_test", From: "Películas <no-reply@creapolis.dev>", BaseURL: srv.URL}
	if err := r.Send(context.Background(), Message{To: "a@b.co", Subject: "Hola", Text: "t", HTML: "<p>h</p>"}); err != nil {
		t.Fatal(err)
	}
	if auth != "Bearer re_test" || got["subject"] != "Hola" || got["from"] != r.From {
		t.Fatalf("auth=%q body=%v", auth, got)
	}
	if to, _ := got["to"].([]any); len(to) != 1 || to[0] != "a@b.co" {
		t.Fatalf("to=%v", got["to"])
	}
}

func TestResendErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, `{"message":"domain not verified"}`, http.StatusForbidden)
	}))
	defer srv.Close()
	if err := (&Resend{APIKey: "k", BaseURL: srv.URL}).Send(context.Background(), Message{To: "a@b.co"}); err == nil {
		t.Fatal("expected error")
	}
	if err := (&Resend{}).Send(context.Background(), Message{}); !errors.Is(err, ErrNotConfigured) {
		t.Fatalf("got %v", err)
	}
}
