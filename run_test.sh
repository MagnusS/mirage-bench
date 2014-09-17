#!/bin/bash
# 
# Copyright (c) 2014, Magnus Skjegstad <magnus@skjegstad.com>
# 
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# 

#set -eEu

### Functions available for test scripts ###
say_error () {
    echo -e "# FATAL: $@"
    exit -1
}

say_warning () {
    echo -e "# WARNING: $@"
}

say_info () {
    echo -e "# INFO: $@"
}

# Wait for remote port to open
wait_for_remote_port_open () {
    PORT=$1
    echo "Waiting for port ${PORT} to open on remote host"
    ${SSH_EXEC} "while ! sudo lsof -i :${PORT} 2>&1 > /dev/null; do sleep 1; done;" && \
    echo "Remote opened port ${PORT}"
}

# Wait for remote TCP port to close
wait_for_remote_port_close () {
    PORT=$1
    echo "Waiting for port ${PORT} to close on remote host"
    ${SSH_EXEC} "while sudo lsof -i :${PORT} 2>&1 > /dev/null; do sleep 1; done;" && \
    echo "Remote closed port ${PORT}"
}

# Wait for remote test to complete
wait_for_remote () {
    echo "Waiting for remote to exit..."
    while kill -0 $REMOTE_PID 2> /dev/null ; do
        sleep 1
    done
    echo "Remote exited."
}

# Kill remote test
kill_remote () {
    while kill -0 $REMOTE_PID 2> /dev/null ; do
        echo "Remote still running, sending SIGHUP..."
        kill $REMOTE_PID
        sleep 1
    done
}

export -f wait_for_remote say_info say_warning say_error wait_for_remote_port_open wait_for_remote_port_close
### End of test script functions ###

prefix_output () {
    while read line ; do
        # %N (nanonseconds) is not supported on OS X
        echo -e "$1 $(date +%H:%M:%S): ${line}"
    done
}

local_run () {
    dir=${LOCAL_RESULTS_PATH-$LOCAL_RESULTS_ROOT_PATH}
    LOG="${dir}/run_local.log"
    COMMAND="$@"
    date +"# %D, %T" >> ${LOG}
    echo "# Executing $COMMAND" >> ${LOG}
    cd $dir && $COMMAND 2>&1 | while read line ; do echo -e "local $(date +%H:%M:%S): $line"; echo $line >> ${LOG}; done
    unset dir COMMAND LOG
}

remote_run_bg () {
    dir=${REMOTE_RESULTS_PATH-$REMOTE_RESULTS_ROOT_PATH}
    LOG="${dir}/run_remote.log"
    COMMAND="$@"
    ${SSH_EXEC} "date +\"# %D, %T\" >> ${LOG}"
    ${SSH_EXEC} "echo \"# Executing ${COMMAND}\" >> ${LOG}"
    ${SSH_EXEC} "cd $dir && ${COMMAND} 2>&1 | while read line ; do echo -e \"remote \$(date +%H:%M:%S): \$line\"; echo \$line >> ${LOG}; done" &
    REMOTE_PID=$!
    unset dir COMMAND LOG
}


run_tests () {
    local_test_paths=$(find "$LOCAL_TEST_ROOT_PATH/local" -type f -perm +111 -print)
    local_tests_cnt=0
    unset local_tests

    for t in $local_test_paths; do
        local_tests[$local_tests_cnt]="$t"
        say_info "Found local test: "$(basename $t)
        local_tests_cnt=$(($local_tests_cnt+1))
    done

    remote_test_paths=$(${SSH_EXEC} "find \"$REMOTE_TEST_ROOT_PATH/remote\" -type f -perm +111 -print")
    remote_tests_cnt=0
    unset remote_tests

    for t in $remote_test_paths; do
        remote_tests[$remote_tests_cnt]="$t"
        say_info "Found remote test: "$(basename $t)
        remote_tests_cnt=$(($remote_tests_cnt+1))
    done

    say_info "$local_tests_cnt local test(s) found, $remote_tests_cnt remote test(s) found"

    if [ $local_tests_cnt -eq 0 ] || [ $remote_tests_cnt -eq 0 ] ; then
        say_error "At least one remote and one local test is required."
    fi

    say_info "-----------------------------"
    say_info "Test matrix (local / remote):"
    say_info "-----------------------------"
    for i in $(seq 0 $(( $local_tests_cnt-1 )) ); do
        for j in $(seq 0 $(( $remote_tests_cnt-1 )) ); do
            say_info " "$(basename ${local_tests[$i]})"\t\t"$(basename ${remote_tests[$j]})
        done
    done

    say_info "Tests commencing"

    failed_count=0
    success_count=0
    total_count=0

    for i in $(seq 0 $(( $local_tests_cnt-1 )) ); do
        for j in $(seq 0 $(( $remote_tests_cnt-1 )) ); do
            total_count=$((total_count+1))

            local_test_basename=$(basename ${local_tests[$i]})
            remote_test_basename=$(basename ${remote_tests[$j]})
            subtest_name="${local_test_basename}_x_${remote_test_basename}"

            say_info "=============================="
            say_info "LOCAL: $local_test_basename"
            say_info "REMOTE: $remote_test_basename"
            say_info "=============================="
            
            # setup paths
            REMOTE_RESULTS_PATH="$REMOTE_RESULTS_ROOT_PATH/$subtest_name/remote" 
            ${SSH_EXEC} "mkdir -p ${REMOTE_RESULTS_PATH}" || say_error "Unable to create remote path $REMOTE_RESULTS_PATH" 
            LOCAL_RESULTS_PATH="$LOCAL_RESULTS_ROOT_PATH/$subtest_name/local"
            mkdir -p $LOCAL_RESULTS_PATH || say_error "Unable to create local path $LOCAL_RESULTS_PATH"

            # run test
            remote_run_bg ${remote_tests[$j]}
            REMOTE_PID=$REMOTE_PID local_run ${local_tests[$i]} && \
            (say_info "TEST COMPLETE (continuing)"; date > $LOCAL_RESULTS_ROOT_PATH/$subtest_name/SUCCESS; success_count=$((success_count+1)); true) || \
            (say_warning "TEST FAILED (continuing)" ; date > $LOCAL_RESULTS_ROOT_PATH/$subtest_name/FAILED; failed_count=$((failed_count+1)); true)
            # kill remote if still running
            kill_remote

            unset REMOTE_PID
            unset REMOTE_RESULTS_PATH
            unset LOCAL_RESULTS_PATH
        done
    done

    say_info "$total_count tests complete. Success: $success_count, failure: $failed_count"
    if [ $failed_count -gt 0 ]; then
        say_warning "Some tests failed"
    fi
}
cleanup () {
    # kill remote command if still running on exit (e.g. due to ctrl-c being pressed, or unexpected error)
    if [ "${REMOTE_PID-x}" != "x" ]; then
        echo "Terminating background job with pid $REMOTE_PID"
        kill $REMOTE_PID && wait $REMOTE_PID
    fi
}
trap cleanup SIGINT EXIT

### Run tests ###
say_info "Running ${TEST_NAME}... (results tagged with ${RESULTS_TAG}, set RESULTS_TAG to override)"
say_info "Results will be stored in ${LOCAL_RESULTS_ROOT_PATH}"

run_tests && \
say_info "Test(s) completed successfully" || \
say_error "Test(s) failed."
