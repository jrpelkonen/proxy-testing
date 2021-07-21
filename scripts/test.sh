#!/usr/bin/env bash

here=$(dirname $0)
base=$here/..
results=$base/results

nginx_docker_id=$(docker run --rm -d --network host -p 80:80 --name nginx nginx)
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
    (cd $dir; exec $(eval echo $cmd) 2>&1 > /dev/null) &
    cmd_pid=$!
    echo pid is $cmd_pid
    until nc -z localhost $port; do
        sleep 1;
    done
    echo $kind is up, starting the test
    ~/work/wrk2/wrk -t2 -c100 -d240s -R2000 --latency http://localhost:$port/index.html | tee $results/$kind.full | grep -A8 HdrHistogram | tail -8 | sed -re 's/us$/E-6/g;s/ms$/E-3/g;s/\.?\0+%/%/g' > $results/$kind
    if [ -z "${stop_cmd}" ]; then
        kill $cmd_pid;
    else
        echo $stop_cmd
        $stop_cmd;
        unset stop_cmd;
        echo $stop_cmd
    fi
    plotscript="$plotscript \"$kind\" using 0:2:xticlabel(1) title \"$kind\" with lines,"
}

record_server "." "baseline" "tail -f /dev/null" 80;
for profile in $(find $base -name run.profile); do
    source $profile;
    dir=$(dirname $profile)
    kind=$(basename $dir);
    record_server "$dir" "$kind" "$cmd" $port;
done
(cd $results; echo "$plotscript" | gnuplot > plot_$(date -Iminutes).png)
docker stop nginx