# About test-jitsu #

Test jitsu startup times.

This test evaluates the time it takes for the client to send a DNS request to Jitsu, connect and receive the first TCP packet with data from a unikernel web server. Variations are with/without Synjitsu (SYN caching while real service boots) and with optimized Xen vif init.

