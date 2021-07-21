cmd='docker run --rm --name proxytest-envoy -v $(pwd)/envoy.yaml:/etc/envoy/envoy.yaml -p ${port}:${port} -e ENVOY_UID=$(id -u) envoyproxy/envoy:v1.19-latest'
port=10000
stop_cmd='docker stop proxytest-envoy'