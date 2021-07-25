#!/usr/bin/env bash

here=$(realpath $(dirname $0))
base=$here/..
results=$base/results

test_payloads="1K 100K 1M"
test_rps="2000 200 20 5"

read -r -d '' plotscript <<'EOF'
set terminal png
set term png size 1200, 1000
set xlabel "Distribution"
set ylabel "Latency"
set format y "%.0s%cs"
set logscale y

EOF

function generate_tests_data() {
    mkdir -p $here/payloads;
    for payload in $test_payloads; do
        openssl rand -base64 -out $here/payloads/${payload}.txt $(( $(numfmt $payload --from iec) * 3 / 4 ))
    done
}

generate_tests_data

nginx_docker_id=$(docker run --rm -d -v $here/payloads:/usr/share/nginx/html/payloads --network host --name nginx nginx)

function plot() {
    filter=$1
    local plot_statement="plot "
    pushd $results
    for result in *${filter}*; do
        plot_statement="$plot_statement \"${result}\" using 0:2:xticlabel(1) title \"$(echo $result | tr _ ' ')\" with lines,"
    done
    printf "%s\n" "set title \"$filter results\"" "$plotscript" "$plot_statement" | gnuplot > ./plots/plot_${filter}.png
    popd
}


function record_server() {
    dir="$1"
    kind="$2"
    cmd="$3"
    port=$4
    mkdir -p $results/full
    (cd $dir; exec $(eval echo $cmd) 2>&1 > /dev/null) &
    cmd_pid=$!
    echo pid is $cmd_pid
    until nc -z localhost $port; do
        sleep 1;
    done
    echo $kind is up, starting the test
    rps_index=1
    for payload in $test_payloads; do 
        rps=$(echo $test_rps | cut -f$rps_index -d' ')
        ~/work/wrk2/wrk -t2 -c100 -d300s -R$rps --latency http://localhost:$port/payloads/${payload}.txt | tee $results/full/${kind}_${payload}.full | grep -A8 HdrHistogram | tail -8 | sed -re 's/us$/E-6/g;s/ms$/E-3/g;s/\.?\0+%/%/g' > $results/${kind}_${payload}
        rps_index=$(($rps_index + 1))
    done
    plot $kind
    if [ -z "${stop_cmd}" ]; then
        kill $cmd_pid;
    else
        echo $stop_cmd
        $stop_cmd;
        unset stop_cmd;
        echo $stop_cmd
    fi

}

record_server "." "baseline" "tail -f /dev/null" 80;
for profile in $(find $base -name run.profile); do
    source $profile;
    dir=$(dirname $profile)
    kind=$(basename $dir);
    record_server "$dir" "$kind" "$cmd" $port;
done
for payload in $test_payloads; do
    plot $payload
done

docker stop nginx