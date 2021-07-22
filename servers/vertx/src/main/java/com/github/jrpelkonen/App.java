package com.github.jrpelkonen;

import io.vertx.core.Future;
import io.vertx.core.Vertx;
import io.vertx.core.http.*;


public class App
{
    static final String host = "localhost";
    static final int port = 80;
    public static void main( String[] args )
    {
        Vertx vertx = Vertx.vertx();
        HttpServer server = vertx.createHttpServer();
        HttpClientOptions clientOptions = new HttpClientOptions();
        HttpClient client  = vertx.createHttpClient(clientOptions);

        server.requestHandler(request -> {
            final HttpServerResponse response = request.response();
            client.request(request.method(), port, host, request.path()).onSuccess(clientRequest -> {
                clientRequest.send().onSuccess(clientResponse -> {
                    response.headers().addAll(clientResponse.headers());
                    response.setStatusCode(clientResponse.statusCode());
                    clientResponse.body().onSuccess(body -> response.send(body));
                }).onFailure(Throwable::printStackTrace);
            }).onFailure(Throwable::printStackTrace);
        });

        server.listen(8070);
        Runtime runtime = Runtime.getRuntime();

        System.out.printf("total heap: %d, max heap: %d, free heap: %d%n", runtime.totalMemory(), runtime.maxMemory(), runtime.freeMemory());
    }
}
