use hyper::client::HttpConnector;
use hyper::service::{make_service_fn, service_fn};
use hyper::Error;
use hyper::{Body, Client, Request, Response, Server};
use std::convert::Infallible;
use std::net::SocketAddr;
use std::sync::Arc;

async fn proxy(
    client: Client<HttpConnector, Body>,
    host: &str,
    scheme: &str,
    request: Request<Body>,
) -> Result<Response<Body>, Error> {
    // convert the request to a new request for proxying
    let (mut parts, body) = request.into_parts();
    parts.uri = format!("{}://{}/{}", scheme, host, parts.uri.path())
        .parse()
        .unwrap();
    parts.headers.insert("host", host.parse().unwrap());
    let client_req = Request::from_parts(parts, body);
    // respond with proxied response
    client.request(client_req).await
}

#[tokio::main]
async fn main() {
    let addr = SocketAddr::from(([0, 0, 0, 0], 8090));
    let client = Arc::new(Client::new());
    let host = "localhost";
    let scheme = "http";
    let make_svc = make_service_fn(move |_conn| {
        let client = client.clone();
        async move {
            Ok::<_, Infallible>(service_fn(move |req: Request<Body>| {
                let client = client.clone();
                async move { proxy(Client::clone(&client), host, scheme, req).await }
            }))
        }
    });

    let server = Server::bind(&addr).serve(make_svc);

    if let Err(e) = server.await {
        eprintln!("server error: {}", e);
    }
}
