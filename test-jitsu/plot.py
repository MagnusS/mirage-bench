#!/usr/bin/env python

import sys

print "# Creating graphs from stdin (requires matplotlib)"

results = {}
for filename in sys.argv[1:]:
	results[filename] = []
	with open(filename) as f:
		for l in f:
			line = l.strip()
			if len(line) == 0:
				continue
			if l[0] == "#":
				print "Warning: Some results are invalid:"
				print l
				continue
			results[filename].append(float(l))




print results
import matplotlib.pyplot as plt
import numpy as np

#fig,ax = plt.subplots()
name = {}
name["processed_results_warm.dat"] = "Jitsu warm start"
name["processed_results_cold.dat"] = "Unikernel: Jitsu cold start wo/synjitsu"
name["processed_results_coldsynjitsu.dat"] = "Unikernel: Jitsu cold start w/synjitsu"
name["processed_results_coldlinux.dat"] = "Linux: Jitsu cold start"

for t in results:
	title = t
	if t in name:
		title = name[t]
	r = results[t]
	print "Plotting",r
	plt.hist(r, bins=20, label=title)

plt.legend(loc="best")
plt.ylabel("Results")
plt.xlabel("Time from DNS query to final ACK in milliseconds")

plt.show()


"""
		
import matplotlib.pyplot as plt
import numpy as np

labels = sorted(result[result.keys()[0]].keys(), key=int)
ind = np.arange(len(labels))  # the x locations for the groups
width = 0.20       # the width of the bars

fig, ax = plt.subplots()
ax.set_ylabel('ICMP RTT in milliseconds')
ax.set_xlabel('Payload size in bytes')
ax.set_title('Average ICMP RTT')
ax.set_xticks(ind+(width * len(keys))/2)
ax.set_xticklabels( labels )

means = {}
std = {}
bars = []
colors = ['r','b','g','y', 'c', 'm']

for test in keys:
    means[test] = []
    std[test] = []
    for l in labels:
        means[test].append(result[test][l]["mean"])
        std[test].append(result[test][l]["std"])
    bars.append(ax.bar(ind, means[test], width, color=colors.pop(), yerr=std[test]))
    ind = ind + width

ax.legend( bars, keys, loc="best" )

def autolabel(rects):
    # attach some text labels
    for rect in rects:
        height = rect.get_height()
        ax.text(rect.get_x()+rect.get_width()/2, 1.04*height, '%.2f'%float(height),
                ha='center', va='bottom')

for b in bars:
    autolabel(b)

fig="icmp_rtt.pdf"
print "Saving",fig
plt.savefig(fig)
plt.show()

"""
