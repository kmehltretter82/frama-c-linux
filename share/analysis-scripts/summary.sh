#!/bin/bash -u

declare -A stats

function pretty_size()
{
  ([[ $# -lt 1 ]] || ! [[ $1 =~ ^[0-9]+$ ]]) && break
  KB=$1
  [ $KB -lt 4096 ] && echo ${KB} kiB && break
  MB=$(((KB+512)/1024))
  [ $MB -lt 4096 ] && echo ${MB} MiB && break
  GB=$(((MB+512)/1024))
  echo $GB GiB
}

function pretty_coverage()
{
  if [[ $# -gt 1 ]] && [ -n '$1' -a $2 -ne 0 ]
  then
    echo $(bc <<<"scale=1; 100 * $2 / $1")%
  fi
}

function print_results()
{
    local s
    local t

    if [ -z "$quiet" ]
    then
        echo -e '\e\0143'
        printf "%20s %10s %10s %10s %10s %10s\n" 'target' 'coverage' 'alarms' 'warnings' 'time' 'memory'
        printf "%s\n" " ----------------------------------------------------------------------------"
        for t in $targets
        do
            printf "%20s %10s %10s %10s %10s %10s\n" $t \
              "${stats["$t,coverage"]-}" \
              "${stats["$t,alarms"]-}" \
              "${stats["$t,warnings"]-}" \
              "${stats["$t,user_time"]-}" \
              "${stats["$t,memory"]-}"
        done
        printf "\n"
    fi
}

function poll_results()
{
  for t in $targets
  do
      if [ -f "$t/stats.txt" ]
      then
          read stats["$t,syn_reach"] stats["$t,sem_reach"] \
               stats["$t,alarms"]    stats["$t,warnings"] \
               stats["$t,user_time"] stats["$t,mem_bytes"] <<< $(
              source $t/stats.txt
              echo ${syn_reach_stmt:-0} ${sem_reach_stmt:-0} \
                   ${alarms:-x} ${warnings:-x} \
                   ${user_time:-x} ${memory:-'x'}
          )
          stats["$t,coverage"]=$(pretty_coverage ${stats["$t,syn_reach"]} ${stats["$t,sem_reach"]})
          stats["$t,memory"]=$(pretty_size ${stats["$t,mem_bytes"]})
      fi
  done
}


# Parse command Line

run="make"
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

for t in $targets
do
    run="$run $t"
done


# Run and display

{
    $run > /dev/null &
    pid=$!

    poll_results
    print_results

    while ps -p $pid >/dev/null
    do
        sleep 1
        poll_results
        print_results
    done
} 2> summary.log

cat summary.log >&2
rm -f summary.log
