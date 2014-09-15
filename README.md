mirage-bench
============
This is a simple bash/make-based test framework for evaluating client/server applications. It is not ready for use.

### Create a new test
The test scripts are located in sub-directories with the following structure:

```
test-group-name/
                before_first_test
                after_last_test
                local/
                        local-test-A
                        local-test-B
                remote/
                        remote-test-A
                        remote-test-B
```

The local directory contains tests that are executed on the local side and the remote directory contains remote side tests. The local side tests should work with any of the remote side tests, as they are executed pairwise. Any number of tests can be added as executable files in the local and remote directories, and every possible combination of them will be executed. To disable a test, use chmod to set it -x.

In the example above, the executed test pairs will be:
    - local-test-A x remote-test-A
    - local-test-B x remote-test-A
    - local-test-A x remote-test-B
    - local-test-B x remote-test-B


The before_first_test and after_last_test scripts are executed before the first test and after the last test in the group. These scripts can be used install dependencies or to process results and generate graphs. 

When after_last_test is executed, all results should already have been gathered in /result/timestamp/test-group-name/local_test_x_remote_test/[local|remote]. The directories will also include stderr and stdout logs. 

### Test script environment
Each test-script is executed in its result directory. Anything stored in this directory is gathered by the test framework when the test completes.

If the tests are run multiple times within each test script, the script should make sure to create the appropriate directory structure within the directory it is executing in (cwd), e.g., by creating 1,2,3 etc as subdirectories.

Various environment variables from the Makefile will be set. See Makefile for details. In addition, the functions "kill_remote" and "wait_for_remote" are defined for the test scripts that run locally.

The test running locally can kill the remote test by calling "kill_remote". If the remote is running after the local script completes, the test framework will try to terminate remote with SIGHUP and treat it as a success if local returned successfully. The remote test is not able to terminate the local test, but if the remote side exits before the local is ready, the local side should terminate with error. 

The results directory will have a file called FAILED on failure and SUCCESS if the test succeeded.

### Results ###

The results directory has the following structure:

```
results/
    [tag/timestamp]/
        [test-group-name]/
            [local_test_name]_x_[remote_test_name]/
                SUCCESS/FAILED
                remote/
                    [logs]
                local/ 
                    [logs]
```
