# Copyright 2009 Jure Varlec
# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# COPYING.WTFPL-2 or http://sam.zoy.org/wtfpl/COPYING for more details.

function prll() {
    if [[ -z $1 ]] ; then
	cat <<-EOF
	USAGE:
               prll fun_name fun_arg1 fun_arg2 fun_arg3 ...
               prll -s 'fun_string' fun_arg1 fun_arg2 ...
	
	Shell function 'fun_name' will be run for each 'fun_arg'.
        Alternatively, shell code 'fun_string' will be executed.
	The number of processes to be run in parallel can be set with
	the PRLL_NR_CPUS environment variable. If it is unset, prll will
	attempt to read the number of CPUs from /proc/cpuinfo.
	EOF
	return 1
    fi
    /usr/bin/which awk sed egrep ipcs ipcrm ipcmk prll_jobserver > /dev/null
    if [[ $? -ne 0 ]] ; then
	echo "PRLL: Missing some utilities." 1>&2
	return 1
    fi
    if [[ -n $ZSH_VERSION ]] ; then
	setopt | grep -x ksharrays > /dev/null
	if [[ $? -ne 0 ]] ; then
	    local prll_ksharrays_set=1
	    setopt ksharrays
	fi
    fi
    if [[ -z $PRLL_NR_CPUS ]] ; then
	local PRLL_NR_CPUS=$(grep "processor	:" < /proc/cpuinfo | wc -l)
    fi

    local prll_funname=$1
    shift
    # Do we have a function handle or a string?
    if [[ $prll_funname == "-s" ]] ; then
	local prll_fun_str=$1
	shift
	function prll_str2func() {
	    eval $prll_fun_str
	}
	prll_funname=prll_str2func
	local prll_str2func_on=1
    fi
    # Put all arguments into an array
    local -a prll_params
    prll_params=("$@")
    local prll_nr_args=${#prll_params[@]}
    if [[ $prll_nr_args -lt $PRLL_NR_CPUS ]] ; then
	PRLL_NR_CPUS=$prll_nr_args
    fi
    local prll_progress=0
    echo "PRLL: Using $PRLL_NR_CPUS CPUs" 1>&2
    local prll_Qkey
    local prll_Q="$(ipcmk -Q | sed -r 's/.+ ([0-9]+)$/\1/' | egrep -x '[0-9]+')"
    if [[ $? -ne 0 ]] ; then
	echo "PRLL: Failed to create message queue." 1>&2
	return 1
    else
	prll_Qkey=$(ipcs -q | awk "\$2 == $prll_Q { print \$1 }")
	echo "PRLL: created message queue with id $prll_Q and key $prll_Qkey" \
	    1>&2
    fi

    function prll_cleanup() {
	trap - SIGINT
	ipcs -q -i $prll_Q > /dev/null 2>&1
	[[ $? -ne 0 ]] && return 130
	echo "PRLL: Cleaning up." 1>&2
	ipcrm -q $prll_Q
	[[ -n $prll_ksharrays_set ]] && setopt noksharrays
	unset -f prll_cleanup
	[[ -n $prll_str2func_on ]] && unset -f prll_str2func
    }
    trap prll_cleanup SIGINT

    echo "PRLL: Starting jobserver." 1>&2
    ( # run in a subshell so this code can be suspended as a unit
	local prll_jarg
	prll_jobserver s $prll_Qkey $PRLL_NR_CPUS $prll_nr_args | \
	    while read prll_jarg; do
	    echo "PRLL: Starting job ${prll_jarg}." \
		"Progress: $((prll_progress*100/prll_nr_args))%" \
		"Arg: ${prll_params[$prll_jarg]}" 1>&2
	    (
		$prll_funname "${prll_params[$prll_jarg]}"
		echo "PRLL: Job number $prll_jarg finished." 1>&2
		prll_jobserver c $prll_Qkey $prll_jarg
	    ) &
	    let prll_progress+=1
	done
    )
    prll_cleanup
}
