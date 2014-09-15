REMOTE_HOST = cubieboard2.local
REMOTE_USER = mirage
REMOTE_PORT ?= 22

# RESULTS_TAG should be unique for each run - the name of the results-subdir
RESULTS_TAG?=$(shell date +%d%m%y-%H%M%S)

REMOTE_ROOT_PATH=/home/mirage/mirage-bench/
LOCAL_ROOT_PATH=$(shell pwd)

SSH=ssh -p $(REMOTE_PORT) -o VisualHostKey=no -o BatchMode=yes
SSH_EXEC=$(SSH) $(REMOTE_USER)@$(REMOTE_HOST) -C 
TESTS=$(shell ls -A1d test-*)

.PHONY: all sync_tests sync_results clean clean_remote $(TESTS)

all:
	@echo "Syntax: make [test to run]"
	@echo
	@echo "Available tests:"
	@echo $(TESTS)
	@echo
	@echo "Other targets:"
	@echo "sync_tests     sync test scripts with remote node (automatic before tests)"
	@echo "sync_results   sync results from remote node (automatic after tests)"
	@echo "clean_remote   sync test scripts and result, then delete results from remote node"
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

$(TESTS): sync_tests
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

	# execute before_first_test if it exists
	test -x "$(LOCAL_TEST_ROOT_PATH)/before_first_test" && \
	cd $(LOCAL_RESULTS_ROOT_PATH) && \
	"$(LOCAL_TEST_ROOT_PATH)/before_first_test" >> run_local.log

	./run_test.sh

	# sync results, clean up
	make sync_results 
	
	# execute after_last_test if it exists
	test -x "$(LOCAL_TEST_ROOT_PATH)/after_last_test" && \
	cd $(LOCAL_RESULTS_ROOT_PATH) && \
	"$(LOCAL_TEST_ROOT_PATH)/after_last_test" >> run_local.log

