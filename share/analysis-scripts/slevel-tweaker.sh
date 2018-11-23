#!/bin/bash -u

declare -A alarms
declare -A utimes


function print_results()
{
    local s
    local t

    if [ -z "$quiet" ]
    then
        echo -e '\e\0143'
        printf "%24s" 'file / slevel'
        for s in $slevels
        do
            printf "%8s" $s
        done
        printf "\n"
        for t in $targets
        do
            printf "\n"
            printf "%18s%6s" $t '#alrm'
            for s in $slevels
            do
                printf "%8s" ${alarms["$t,$s"]-}
            done
            printf "\n"
            printf "%18s%6s" '' 'time'
            for s in $slevels
            do
                printf "%8s" ${utimes["$t,$s"]-}
            done
            printf "\n"
        done
        printf "\n"
    fi
}

function poll_results()
{
  for s in $slevels
  do
      for t in $targets
      do
          base=$t.$s.slevel.eva
          if [ -f $base/stats.txt ]
          then
            read alarms["$t,$s"] utimes["$t,$s"] <<< $(
              source $base/stats.txt
              echo ${alarms:-x} ${user_time:- }
            )
          fi
      done
  done
}


# Parse command Line

slevels="0 10 20 50 100 200 500 1000 2000 5000 10000 20000 50000"
run="make --jobs 9"
targets=""
quiet=""

while [[ $# > 0 ]]
do
    case $1 in
        -f|--file|--makefile)
            run="$run $1 $2"
            shift
            ;;

        -B|--always-make)
            run="$run $1"
            ;;

        -q|--quiet)
            quiet="yes"
            ;;

        *)
            targets="$targets $1"
            ;;
    esac
    shift
done


# List make targets

for s in $slevels
do
    for t in $targets
    do
        run="$run $t.$s.slevel.eva"
    done
done


# Run and display

{
    $run > /dev/null &
    pid=$!

    print_results

    while ps -p $pid >/dev/null
    do
        sleep 1
        poll_results
        print_results
    done
} 2> slevel-tweaker.log

cat slevel-tweaker.log >&2
