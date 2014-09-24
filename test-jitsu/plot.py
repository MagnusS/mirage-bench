#!/usr/bin/env python

import sys

print "# Creating graphs from stdin (requires matplotlib)"

results = {}
for filename in sys.argv[1:]:
	results[filename] = []
	with open(filename) as f:
		for l in f:
			line = l.strip()
			if len(line) == 0 or line[0] == '#':
				continue
			if l[0] == "!":
				print "Warning: Some results are invalid:"
				print l
				continue
			results[filename].append(float(l) * 1000)


print results
import matplotlib.pyplot as plt
import numpy as np

#fig,ax = plt.subplots()
name = {}
name["processed_results_warm.dat"] = "Jitsu warm start"
name["processed_results_cold.dat"] = "Jitsu cold start wo/synjitsu"
name["processed_results_http_warm.dat"] = "Jitsu warm start (http)"
name["processed_results_http_cold.dat"] = "Jitsu cold start wo/synjitsu (http)"

plt.title('Time from DNS query to first packet of HTTP response')

for t in results:
	title = t
	if t in name:
		title = name[t]

	r = results[t]

	print "Plotting",r,"==",len(r)

	maxval = 1500
	bins = 20
	binwidth = maxval / bins
	plt.hist(r, bins=range(1, maxval+binwidth, binwidth), label=title)

plt.legend(loc="best")
plt.ylabel("Results")
plt.xlabel("Time in milliseconds")

plt.savefig("jitsu.pdf")

plt.show()

