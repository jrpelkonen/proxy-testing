#!/usr/bin/env bash

here=$(dirname $0)
base=$here/..
results=$base/results

nginx_docker_id=$(docker run --rm -d -p 80:80 nginx)
read -r -d '' plotscript <<'EOF'
set terminal png
set xlabel "distribution"
set ylabel "latency"
set format y "%s%cs"
set logscale y

plot
EOF

function record_server() {
    dir="$1"
    kind="$2"
    cmd="$3"
    port=$4
    mkdir -p $results
    (cd $dir; exec $cmd) &
    cmd_pid=$!
    echo pid is $cmd_pid
    until nc -z localhost $port; do
        sleep 1;
    done
    echo $kind is up, starting the test
    ~/work/wrk2/wrk -t2 -c100 -d30s -R2000 --latency http://localhost:$port/index.html | grep -A8 HdrHistogram | tail -8 | sed -re 's/us$/E-6/g;s/ms$/E-3/g;s/\.?\0+%/%/g' > $results/$kind
    kill $cmd_pid
    plotscript="$plotscript \"$kind\" using 0:2:xticlabel(1) title \"$kind\" with lines,"
}

record_server "." "baseline" "tail -f /dev/null" 80;
for profile in $(find $base -name run.profile); do
    source $profile;
    dir=$(dirname $profile)
    kind=$(basename $dir);
    record_server "$dir" "$kind" "$cmd" $port;
done
(cd $results; echo "$plotscript" | gnuplot > plot.png)
docker stop $nginx_docker_id