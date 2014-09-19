#!/usr/bin/env python

import sys,glob,re

name_map = {}
name_map["wait_x_xl_create"] = "xl_create"
name_map["wait_x_xl_fast_bridge_create"] = "xl_create_fb"
name_map["wait_x_xl_no_net"] = "xl_create_no_net"

findnum = re.compile(r'\d+')

results = {}
found_keys = []
found_tests = []
for test in glob.glob("wait_x_*"):
    if test in name_map:
        name = name_map[test]
    else:
        name = test

    results[name] = {}

    if name not in found_tests:
        found_tests.append(name)

    for result in glob.glob(test + "/remote/create_*.log"):
        memsize=int(findnum.findall(result.rpartition("/")[2]).pop())
        results[name][memsize]=[]

        with open(result) as f:
            for l in f:
                if l.find("real ") >= 0:
                    r = float(l.split(" ")[1]) # get float
                    results[name][memsize].append(r) # add to results
                    if memsize not in found_keys:
                        found_keys.append(memsize)
            
print "# Raw results, time in s"
print results

print "# Creating graphs (requires matplotlib)"
import matplotlib.pyplot as plt
import numpy as np

labels = sorted(found_keys)
ind = np.arange(len(labels))  # the x locations for the groups
width = 0.25       # the width of the bars

fig, ax = plt.subplots()
ax.set_ylabel('Startup time in seconds')
ax.set_title('xl create time in seconds for different mem sizes')
ax.set_xticks(ind+width)
ax.set_xticklabels( labels )

means = {}
std = {}
bars = []
colors = ['r','b','g']

for test in sorted(found_tests):
    means[test] = []
    std[test] = []
    for l in labels:
        means[test].append(np.mean(results[test][l]))
        std[test].append(np.std(results[test][l]))
    bars.append(ax.bar(ind, means[test], width, color=colors.pop(), yerr=std[test]))
    ind = ind + width


ax.legend( bars, sorted(found_tests), loc="best" )

def autolabel(rects):
    # attach some text labels
    for rect in rects:
        height = rect.get_height()
        ax.text(rect.get_x()+rect.get_width()/2., 1.04*height, '%.2f'%float(height),
                ha='center', va='bottom')

for b in bars:
    autolabel(b)

fig="xl_create_graph.pdf"
print "Saving",fig
plt.savefig(fig)
plt.show()
