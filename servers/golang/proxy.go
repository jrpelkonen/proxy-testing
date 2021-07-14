package main

import (
	"io"
	"log"
	"net"
	"net/http"
	"time"
)

type proxy struct {
	client *http.Client
	host   string
	scheme string
}

func copyHeaders(dst http.Header, src http.Header) {
	for k, vv := range src {
		for _, v := range vv {
			dst.Add(k, v)
		}
	}
}

func (p *proxy) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	// convert the original request for proxying
	req.Host = p.host
	req.URL.Host = p.host
	req.URL.Scheme = p.scheme
	// empty RequestURI for client request
	req.RequestURI = ""

	resp, err := (*p).client.Do(req)
	if err != nil {
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		log.Println("Proxy request failed with:", err)
		return
	}
	defer resp.Body.Close()
	// copy client response as the response for the client request
	w.WriteHeader(resp.StatusCode)
	copyHeaders(w.Header(), resp.Header)
	io.Copy(w, resp.Body)
}

func main() {
	// Configure clients, most values are not critical for this test except MaxIdleConnsPerHost
	var transport = &http.Transport{
		Dial: (&net.Dialer{
			Timeout: 5 * time.Second,
		}).Dial,
		TLSHandshakeTimeout: 5 * time.Second,
		// MaxIdleConnsPerHost: using the default 2 leaves a lot of TIME_WAIT connections and hurts performance
		MaxIdleConnsPerHost: 100,
	}
	var client = &http.Client{
		Timeout:   time.Second * 10,
		Transport: transport,
	}
	handler := &proxy{
		client: client,
		host:   "localhost",
		scheme: "http",
	}
	log.Fatal(http.ListenAndServe(":8080", handler))
}
