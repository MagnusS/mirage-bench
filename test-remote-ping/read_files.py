#!/usr/bin/env python

import sys,glob,re,os

result = {}

for logfile in glob.glob("wait_x_pinger/remote/*_icmp.log"):
	base=os.path.basename(logfile)

	(host,size,_) = base.split("_")	
	#print host,size

	if not host in result:
		result[host] = {}
	result[host][size] = []

	#520 bytes from 10.0.1.1: icmp_seq=5 ttl=64 time=0.446 ms
	match = re.compile("(\d?\.?\d+) ms$")

	with open(logfile) as f:
		for l in f:
			time=None
			if (" bytes from ") in l:
				r = match.findall(l)
				if len(r) == 1:
					time = float(r[0])
					result[host][size].append(time)
				else:
					print l
					print r
					raise Exception("unable to parse: %s" % l)

#print result

import numpy as np

print "# host size results mean std max min"
for h in result.keys():
	for s in result[h].keys():
		print h,s,len(result[h][s]), np.mean(result[h][s]), np.std(result[h][s]), np.var(result[h][s]), np.max(result[h][s]), np.min(result[h][s])

print "# result read from", os.getcwd(),"@", os.uname()[1]
