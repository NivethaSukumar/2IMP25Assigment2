import sys
#import numpy as np
import matplotlib.pyplot as plt

x = []
#y = []
with open(sys.argv[1]) as f:
	f.readline() # header
	for line in f:
		data = line.split(",")
		x.append(float(data[1]))
		#y.append(float(data[2]))

plt.hist(x, 20)
plt.title("Distribution of politeness score")
plt.xlabel("Politeness score")
plt.ylabel("Number of occurrances")
#plt.scatter(x, y)
plt.savefig(sys.argv[2])
