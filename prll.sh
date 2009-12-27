# Copyright 2009 Jure Varlec
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# COPYING.WTFPL-2 or http://sam.zoy.org/wtfpl/COPYING for more details.

function prll() {
    which awk sed egrep ipcs ipcrm ipcmk prll_jobserver > /dev/null
    if [[ $? -ne 0 ]] ; then
	echo "PRLL: Missing some utilities. Search results:" 2>&1
	which awk sed egrep ipcs ipcrm ipcmk prll_jobserver 2>&1
	return 1
    fi
    if [[ -n $ZSH_VERSION ]] ; then
	echo "PRLL: ZSH detected. Using KSH-style arrays" \
	    "and disabling job monitoring."
	setopt ksharrays
	setopt nomonitor
    fi
    if [[ -z $PRLL_NR_CPUS ]] ; then
	local PRLL_NR_CPUS=$(grep "processor	:" < /proc/cpuinfo | wc -l)
    fi

    local prll_funname=$1
    shift
    local -a prll_params
    prll_params=("$@")
    local prll_nr_args=${#prll_params[@]}
    if [[ $prll_nr_args -lt $PRLL_NR_CPUS ]] ; then
	PRLL_NR_CPUS=$prll_nr_args
    fi
    local prll_progress=0
    echo "PRLL: Using $PRLL_NR_CPUS CPUs" 2>&1
    local prll_Qkey
    local prll_Q="$(ipcmk -Q | sed -r 's/.+ ([0-9]+)$/\1/' | egrep -x '[0-9]+')"
    if [[ $? -ne 0 ]] ; then
	echo "PRLL: Failed to create message queue." 2>&1
	return 1
    else
	prll_Qkey=$(ipcs -q | awk "\$2 == $prll_Q { print \$1 }")
	echo "PRLL: created message queue with id $prll_Q and key $prll_Qkey" \
	    2>&1
    fi

    echo "PRLL: Starting jobserver." 2>&1
    ( # run in a subshell so this code can be suspended as a unit
	local prll_jarg
	prll_jobserver s $prll_Qkey $PRLL_NR_CPUS $prll_nr_args | \
	    while read prll_jarg; do
	    echo "PRLL: Starting job ${prll_jarg}." \
		"Progress: $((prll_progress*100/prll_nr_args))%" 2>&1
	    (
		$prll_funname "${prll_params[$prll_jarg]}"
		prll_jobserver c $prll_Qkey $prll_jarg
		echo "PRLL: Job number $prll_jarg finished." 2>&1
	    ) &
	    let prll_progress+=1
	done
	echo "PRLL: Jobserver finished, cleaning up."
	wait # TODO: bash doesn't handle this well
	ipcrm -q $prll_Q
    )
}
