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

SSH=ssh -p $(REMOTE_PORT) -o VisualHostKey=no -o BatchMode=yes
SSH_EXEC=$(SSH) $(REMOTE_USER)@$(REMOTE_HOST)
TESTS=$(shell ls -A1d test-*)

.PHONY: all sync_tests sync_results clean clean_remote sync_time $(TESTS)

all:
	@echo "Syntax: make [test to run]"
	@echo
	@echo "Available tests:"
	@echo $(TESTS)
	@echo
	@echo "Other targets:"
	@echo "clean_remote   			sync test scripts and result, then delete results from remote node"
	@echo "create name=[test-name]  create a new test directory structure in the [test-name] subdirectory (test- prefix required)"
	@echo "sync_tests     			sync test scripts with remote node (automatic before tests)"
	@echo "sync_results   			sync results from remote node (automatic after tests)"
	@echo "sync_time                run ntpdate on remote host to synchronize time"
	@echo

sync_tests:
	# syncing tests with remote host, delete remote diff
	rsync -e "$(SSH)" --delete --progress -qavz $(LOCAL_ROOT_PATH)/ $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_ROOT_PATH) --exclude=results/

sync_results:
	# sync all results _from_ remote host, do not delete anything
	rsync -e "$(SSH)" --progress -qavz $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_ROOT_PATH)/results/ $(LOCAL_ROOT_PATH)/results/

clean_remote: sync_results
	# syncing tests with remote host, delete remote diff, delete results from remote
	rsync -e "$(SSH)" --delete --delete-excluded --progress -qavz $(LOCAL_ROOT_PATH)/ $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_ROOT_PATH) --exclude=results/

create: 
	@echo "Creating test in directory $(name)..."
	@test \! -d $(name) || \
		echo "$(name) already exists. Aborting"
	@mkdir -p $(name)/local $(name)/remote
	@echo "# About $(name) #\n\nThis is an empty example test.\n" > $(name)/README.md
	@echo "#!/bin/bash\n\necho \"This script is executed locally before the tests\"\n" > $(name)/before_first_test_local
	@echo "#!/bin/bash\n\necho \"This script is executed remotely before the tests\"\n" > $(name)/before_first_test_remote
	@echo "#!/bin/bash\n\necho \"This script is executed locally after the tests\"\n" > $(name)/after_last_test_local
	@echo "#!/bin/bash\n\necho \"This script is executed remotely after the tests\"\n" > $(name)/after_last_test_remote
	@echo "#!/bin/bash\n\necho \"Remote test executing\"\nsleep 5\n" >> $(name)/remote/remote_test
	@echo "#!/bin/bash\n\necho \"Local test executing (waiting for remote)\"\nwait_for_remote\n#kill_remote\n" > $(name)/local/local_test
	@chmod +x $(name)/after* $(name)/before* $(name)/local/* $(name)/remote/*

sync_time:
	# synchronize remote time and test internet access
	${SSH_EXEC} "sudo ntpdate fartein.ifi.uio.no"

$(TESTS): sync_time sync_tests
	# export all variables from make
	$(eval export) 

	# set test specific variables
	$(eval TEST_NAME=$@)

	$(eval REMOTE_TEST_ROOT_PATH=$(REMOTE_ROOT_PATH)/$(TEST_NAME))
	$(eval REMOTE_RESULTS_ROOT_PATH=$(REMOTE_ROOT_PATH)/results/$(RESULTS_TAG)/$(TEST_NAME))
	$(SSH_EXEC) "mkdir -p $(REMOTE_RESULTS_ROOT_PATH)"

	$(eval LOCAL_TEST_ROOT_PATH=$(LOCAL_ROOT_PATH)/$(TEST_NAME))
	$(eval LOCAL_RESULTS_ROOT_PATH=$(LOCAL_ROOT_PATH)/results/$(RESULTS_TAG)/$(TEST_NAME))
	mkdir -p $(LOCAL_RESULTS_ROOT_PATH)
	set -o pipefail

	# execute before_first_test if it exists
	test -x "$(LOCAL_TEST_ROOT_PATH)/before_first_test_local" && cd $(LOCAL_RESULTS_ROOT_PATH) && "$(LOCAL_TEST_ROOT_PATH)/before_first_test_local" 2>&1 | tee -a run_local.log

	test -x "$(LOCAL_TEST_ROOT_PATH)/before_first_test_remote" && ${SSH_EXEC} "set -o pipefail ; cd $(REMOTE_RESULTS_ROOT_PATH) && $(REMOTE_TEST_ROOT_PATH)/before_first_test_remote 2>&1 | tee -a run_remote.log"

	./run_test.sh

	# execute after_last_test_remote if it exists (results are still on the remote node so after_last_test_remote can process them)
	test -x "$(LOCAL_TEST_ROOT_PATH)/after_last_test_remote" && ${SSH_EXEC} "set -o pipefail ; cd $(REMOTE_RESULTS_ROOT_PATH) && $(REMOTE_TEST_ROOT_PATH)/after_last_test_remote 2>&1 | tee -a run_remote.log"
	
	# sync results and delete them from remote
	make clean_remote
	
	# execute after_last_test_local if it exists
	test -x "$(LOCAL_TEST_ROOT_PATH)/after_last_test_local" && cd $(LOCAL_RESULTS_ROOT_PATH) && "$(LOCAL_TEST_ROOT_PATH)/after_last_test_local" 2>&1 | tee -a run_local.log

	@echo "Test $(TEST_NAME) complete. Results stored in $(LOCAL_RESULTS_ROOT_PATH)"

