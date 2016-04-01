import sys
import numpy as np
import matplotlib.mlab as mlab
import matplotlib.pyplot as plt

scores = {-1:[], 0:[], 1:[]}
favorites = {-1:[], 0:[], 1:[]}
viewcounts = {-1:[], 0:[], 1:[]}
responsetimes = {-1:[], 0:[], 1:[]}

with open(sys.argv[1]) as f:
	f.readline() # skip header
	#out = {
	#	-1: open(sys.argv[2]+"ngtv.csv","w"),
	#	00: open(sys.argv[2]+"ntrl.csv","w"),
	#	01: open(sys.argv[2]+"pstv.csv","w")
	#}
	
	i=0
	ignored0 = 0
	ignored1 = 0
	for line in f:
		qid, pos, score, vcount, fcount, responsetime, timestamp = line.split(",")
		qid = int(qid)
		pos = float(pos)
		#neg = float(neg)
		score = int(score)
		vcount = int(vcount)
		fcount = int(fcount)
		responsetime = int(responsetime)
		timestamp = int(timestamp)
		
		if pos > 0.7:
			pol = 1
		elif pos > 0.4:
			pol = 0
		else:
			pol = -1
		
		scores[pol].append(score)
		favorites[pol].append(fcount)
		viewcounts[pol].append(vcount)
		outline = "%i,%i,%i," % (score, fcount, vcount)
		if 0 < responsetime < sys.maxint:
			responsetimes[pol].append(responsetime/60./60./24.)
			outline += "%i" % responsetime
		elif responsetime <= 0:
			ignored0 += 1
		else:
			ignored1 += 1
		
		#out[pol].write(outline+"\n")
		
		i+=1
		if i %10000 == 0:
			print "processed %i rows" % i
	
	print "Ignored %i responsetimes <= 0, and %i responsetimes that were not given" % (ignored0, ignored1)
	print "Min viewcount: %i, %i, %i" % (min(viewcounts[-1]), min(viewcounts[0]), min(viewcounts[1]))

# the histogram of the data
bins = np.linspace(0, 10, 50)
plt.hist((favorites[-1], favorites[0], favorites[1]), 20, alpha=0.5, log=True, label=("impolite","neutral","polite"))
#plt.hist(responsetimes[00], bins, alpha=0.5, log=True, label="neutral")
#plt.hist(responsetimes[01], bins, alpha=0.5, log=True, label="polite")
plt.legend(loc="upper right")

#yneg,edges = np.histogram(responsetimes[-1], bins)
#yneu,edges = np.histogram(responsetimes[ 0], bins)
#ypos,edges = np.histogram(responsetimes[ 1], bins)
#bincenters = 0.5*(edges[1:]+edges[:-1])
#plt.plot(bincenters,np.log2(yneg+1),'-')
#plt.plot(bincenters,np.log2(yneu+1),'-')
#plt.plot(bincenters,np.log2(ypos+1),'-')


plt.xlabel('Number of favourites')
plt.ylabel('Number of questions')
plt.title('Number of favourites')
plt.grid(True)

plt.savefig(sys.argv[2]+".png")