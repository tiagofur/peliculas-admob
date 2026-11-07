package tmdb

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"golang.org/x/time/rate"
)

// Fetcher gets a raw answer from TMDB.
type Fetcher interface {
	Fetch(ctx context.Context, path string, q url.Values) (status int, body []byte, err error)
}

// Client calls the TMDB v3 API with either a v3 API key or a v4 read token.
type Client struct {
	BaseURL   string
	APIKey    string
	ReadToken string
	HTTP      *http.Client
	limiter   *rate.Limiter
}

// NewClient keeps us under TMDB's ~40 req/s limit.
func NewClient(apiKey, readToken string) *Client {
	return &Client{
		BaseURL:   "https://api.themoviedb.org/3",
		APIKey:    apiKey,
		ReadToken: readToken,
		HTTP:      &http.Client{Timeout: 10 * time.Second},
		limiter:   rate.NewLimiter(35, 35),
	}
}

const maxBody = 5 << 20

func (c *Client) Fetch(ctx context.Context, path string, q url.Values) (int, []byte, error) {
	if err := c.limiter.Wait(ctx); err != nil {
		return 0, nil, err
	}
	params := url.Values{}
	for k, v := range q {
		params[k] = v
	}
	if c.ReadToken == "" {
		params.Set("api_key", c.APIKey)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.BaseURL+path+"?"+params.Encode(), nil)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Accept", "application/json")
	if c.ReadToken != "" {
		req.Header.Set("Authorization", "Bearer "+c.ReadToken)
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return 0, nil, fmt.Errorf("tmdb: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBody))
	if err != nil {
		return 0, nil, fmt.Errorf("tmdb: read body: %w", err)
	}
	return resp.StatusCode, body, nil
}
