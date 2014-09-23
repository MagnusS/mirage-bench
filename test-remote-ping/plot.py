#!/usr/bin/env python

import sys

print "# Creating graphs from stdin (requires matplotlib)"

result = {}
for line in sys.stdin:
	# skip blank lines and comments
	if len(line.strip()) == 0 or line.strip()[0] == '#':
		continue	
	(host,size,count,mean,std,var,max,min) = line.strip().split()

	if not host in result: 
		result[host] = {}
	if not size in result[host]:
		result[host][size] = {}	
		
	result[host][size]["results"] = float(count)
	result[host][size]["mean"] = float(mean)
	result[host][size]["std"] = float(std)
	result[host][size]["var"] = float(var)
	result[host][size]["max"] = float(max)
	result[host][size]["min"] = float(min)
		
import matplotlib.pyplot as plt
import numpy as np

labels = sorted(result[result.keys()[0]].keys(), key=int)
ind = np.arange(len(labels))  # the x locations for the groups
width = 0.15       # the width of the bars

fig, ax = plt.subplots()
ax.set_ylabel('ICMP RTT in milliseconds')
ax.set_title('Average ICMP RTT')
ax.set_xticks(ind+width)
ax.set_xticklabels( labels )

means = {}
std = {}
bars = []
colors = ['r','b','g','y', 'c', 'm']

for test in sorted(result.keys()):
    means[test] = []
    std[test] = []
    for l in labels:
        means[test].append(result[test][l]["mean"])
        std[test].append(result[test][l]["std"])
    bars.append(ax.bar(ind, means[test], width, color=colors.pop(), yerr=std[test]))
    ind = ind + width

ax.legend( bars, sorted(result.keys()), loc="best" )

def autolabel(rects):
    # attach some text labels
    for rect in rects:
        height = rect.get_height()
        ax.text(rect.get_x()+rect.get_width()/2., 1.04*height, '%.2f'%float(height),
                ha='center', va='bottom')

for b in bars:
    autolabel(b)

fig="icmp_rtt.pdf"
print "Saving",fig
plt.savefig(fig)
plt.show()

