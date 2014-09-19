# Copyright (c) 2014, Magnus Skjegstad <magnus@skjegstad.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# Copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

REMOTE_HOST = cubieboard2.local
REMOTE_USER = mirage
REMOTE_PORT ?= 22

# RESULTS_TAG should be unique for each run - the name of the results-subdir
RESULTS_TAG?=$(shell date +%d%m%y-%H%M%S)

REMOTE_ROOT_PATH=/home/mirage/mirage-bench/
LOCAL_ROOT_PATH=$(shell pwd)

NTP_SERVER=ntp0.csx.cam.ac.uk
SSH_OPT=-o VisualHostKey=no -o BatchMode=yes
SSH=ssh -p $(REMOTE_PORT) $(SSH_OPT)
SCP=scp -P $(REMOTE_PORT) $(SSH_OPT)
SSH_EXEC=$(SSH) $(REMOTE_USER)@$(REMOTE_HOST)

TESTS=$(shell ls -A1d test-*)

.PHONY: all sync_tests sync_results clean run graphs clean_remote sync_time $(TESTS)

all:
	@echo "Syntax: make [test to run]"
	@echo
	@echo "Available tests:"
	@echo $(TESTS)
	@echo
	@echo "run TEST=[test]                  run the specified test"
	@echo "create TEST=[test] 		 		create a new test directory structure in the [test-name] subdirectory (test- prefix required)"
	@echo "graphs TEST=[test] {RESULT=[tag]} 	run only make_graphs on the given result. Omit result tag for a list of options."
	@echo
	@echo "clean_remote   					sync test scripts and result, then delete results from remote node"
	@echo "sync_tests     					sync test scripts with remote node (automatic before tests, deletes unknown files on remote node)"
	@echo "sync_results   					sync results from remote node (automatic after tests, non-destructive)"
	@echo "sync_time                		run ntpdate on remote host to synchronize time"
	@echo

sync_tests:
	# syncing tests with remote host, delete remote diff
	rsync -e "$(SSH)" --delete --progress -qavz $(LOCAL_ROOT_PATH)/ $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_ROOT_PATH) --exclude=results/

sync_results:
	# sync all results _from_ remote host, do not delete anything
	rsync -e "$(SSH)" --progress -qavz $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_ROOT_PATH)/results/ $(LOCAL_ROOT_PATH)/results/

clean_remote: | sync_results
	# syncing tests with remote host, delete remote diff, delete results from remote
	rsync -e "$(SSH)" --delete --delete-excluded --progress -qavz $(LOCAL_ROOT_PATH)/ $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_ROOT_PATH) --exclude=results/

create: 
	@echo "Creating test in directory $(TEST)..."
	@test \! -d $(TEST) || \
		echo "$(TEST) already exists. Aborting"
	@mkdir -p $(TEST)/local $(TEST)/remote
	@echo "# About $(TEST) #\n\nThis is an empty example test.\n" > $(TEST)/README.md
	@echo "#!/bin/bash\n\necho \"This script is executed locally before the tests\"\n" > $(TEST)/before_first_test_local
	@echo "#!/bin/bash\n\necho \"This script is executed remotely before the tests\"\n" > $(TEST)/before_first_test_remote
	@echo "#!/bin/bash\n\necho \"This script is executed locally after the tests\"\n" > $(TEST)/after_last_test_local
	@echo "#!/bin/bash\n\necho \"This script is executed remotely after the tests\"\n" > $(TEST)/after_last_test_remote
	@echo "#!/bin/bash\n\necho \"This script is executed locally after the results have been gathered\"\n" > $(TEST)/make_graphs
	@echo "#!/bin/bash\n\necho \"Remote test executing\"\nsleep 5\n" >> $(TEST)/remote/remote_test
	@echo "#!/bin/bash\n\necho \"Local test executing (waiting for remote)\"\nwait_for_remote\n#kill_remote\n" > $(TEST)/local/local_test
	@chmod +x $(TEST)/after* $(TEST)/before* $(TEST)/local/* $(TEST)/remote/*

sync_time:
	# synchronize remote time and test internet access
	${SSH_EXEC} "sudo ntpdate $(NTP_SERVER)"

run: | sync_time sync_tests
	# export all variables from make
	$(eval export) 

	# check if test exists
	test -d $(TEST)

	$(eval REMOTE_TEST_ROOT_PATH=$(REMOTE_ROOT_PATH)/$(TEST))
	$(eval REMOTE_RESULTS_ROOT_PATH=$(REMOTE_ROOT_PATH)/results/$(RESULTS_TAG)/$(TEST))
	$(SSH_EXEC) "mkdir -p $(REMOTE_RESULTS_ROOT_PATH)"

	$(eval LOCAL_TEST_ROOT_PATH=$(LOCAL_ROOT_PATH)/$(TEST))
	$(eval LOCAL_RESULTS_ROOT_PATH=$(LOCAL_ROOT_PATH)/results/$(RESULTS_TAG)/$(TEST))
	mkdir -p $(LOCAL_RESULTS_ROOT_PATH)
	set -o pipefail

	# export environment
	rm -f $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export TEST=$(TEST)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export RESULTS_TAG=$(RESULTS_TAG)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export LOCAL_RESULTS_ROOT_PATH=$(LOCAL_RESULTS_ROOT_PATH)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export LOCAL_TEST_ROOT_PATH=$(LOCAL_TEST_ROOT_PATH)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export LOCAL_ROOT_PATH=$(LOCAL_ROOT_PATH)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export REMOTE_RESULTS_ROOT_PATH=$(REMOTE_RESULTS_ROOT_PATH)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export REMOTE_TEST_ROOT_PATH=$(REMOTE_TEST_ROOT_PATH)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment
	echo "export REMOTE_ROOT_PATH=$(REMOTE_ROOT_PATH)" >> $(LOCAL_RESULTS_ROOT_PATH)/local_environment

	# copy environment to remote 
	$(SCP) $(LOCAL_RESULTS_ROOT_PATH)/local_environment $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_RESULTS_ROOT_PATH)/remote_environment
	
	# execute before_first_test if it exists
	test -x "$(LOCAL_TEST_ROOT_PATH)/before_first_test_local" && cd $(LOCAL_RESULTS_ROOT_PATH) && "$(LOCAL_TEST_ROOT_PATH)/before_first_test_local" 2>&1 | tee -a run_local.log

	test -x "$(LOCAL_TEST_ROOT_PATH)/before_first_test_remote" && ${SSH_EXEC} "set -o pipefail ; cd $(REMOTE_RESULTS_ROOT_PATH) && source remote_environment && $(REMOTE_TEST_ROOT_PATH)/before_first_test_remote 2>&1 | tee -a run_remote.log"

	./run_test.sh

	# execute after_last_test_remote if it exists (results are still on the remote node so after_last_test_remote can process them)
	test -x "$(LOCAL_TEST_ROOT_PATH)/after_last_test_remote" && ${SSH_EXEC} "set -o pipefail ; cd $(REMOTE_RESULTS_ROOT_PATH) && source remote_environment && $(REMOTE_TEST_ROOT_PATH)/after_last_test_remote 2>&1 | tee -a run_remote.log"
	
	# sync results and delete them from remote
	make clean_remote
	
	# execute after_last_test_local if it exists
	test -x "$(LOCAL_TEST_ROOT_PATH)/after_last_test_local" && cd $(LOCAL_RESULTS_ROOT_PATH) && "$(LOCAL_TEST_ROOT_PATH)/after_last_test_local" 2>&1 | tee -a run_local.log

	@echo "Test $(TEST) complete. Results stored in $(LOCAL_RESULTS_ROOT_PATH)"
	@echo
	@echo "To make graphs, run"
	@echo "\tmake graphs TEST=$(TEST) RESULT=$(RESULTS_TAG)"

graphs:
	# check if $(TEST)/make_graphs exists and is executable
	@test -x $(LOCAL_ROOT_PATH)/$(TEST)/make_graphs
	@set -o pipefail

	$(eval RESULTS_TAG=$(RESULT))
	$(eval LOCAL_RESULTS_ROOT_PATH=$(LOCAL_ROOT_PATH)/results/$(RESULTS_TAG)/$(TEST))

	@test -f $(LOCAL_RESULTS_ROOT_PATH)/local_environment || (echo "Result not found for test $(TEST). Valid options for RESULT= are:"; \
		find results | grep test-vm-create | grep local_environment | cut -f2 -d"/"; \
		exit -1)

	@echo "Creating graphs for $(LOCAL_RESULTS_ROOT_PATH)..."

	@source $(LOCAL_RESULTS_ROOT_PATH)/local_environment && cd $(LOCAL_RESULTS_ROOT_PATH) && $$LOCAL_TEST_ROOT_PATH/make_graphs
