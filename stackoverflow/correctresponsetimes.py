from __future__ import print_function
import xml.sax
import sys
import re
import time
import datetime

reload(sys)  
sys.setdefaultencoding('utf8')

# CLI USAGE
if not len(sys.argv) == 4:
	print("USAGE: python %s <xmlfile> <responseTimes> <correctedResponsetimes>" % sys.argv[0])
	print("  xmlfile: xml file")
	print("  responseTimes: csv file")
	print("  outputfileResponseTimes: new csv file")
	print("  example: python %s Posts.xml responsetimes.csv responsetimes2.csv" % sys.argv[0])
	sys.exit()

# GLOBAL
QUESTION = 1
ANSWER = 2

def strToTime(timestr):
	return time.mktime(datetime.datetime.strptime(timestr, "%Y-%m-%dT%H:%M:%S.%f").timetuple())

# Actual stuff
class PostHandler(xml.sax.ContentHandler):
	def __init__(self, questions):
		self.questions = questions
		self.rows = 0
		self.corrected = 0
	
	def startElement(self, name, attr):
		if name == "row":
			self.rows += 1
			aid = int(attr["Id"])
			
			if aid in self.questions:
				if self.questions[aid] > strToTime(attr["CreationDate"]):
					self.questions[aid] = strToTime(attr["CreationDate"])
					self.corrected+=1
			
			if self.rows % 50000 == 0:
				print(
					("(progress: \033[92m{:04.1f}%\033[0m) - "+
					"processed \033[92m{:010,}\033[0m rows, "+
					"corrected \033[92m{:010,}\033[0m response times (\033[92m{:04.01f}%\033[0m)")
					.format((self.rows/294996.60), self.rows, self.corrected, 100*self.corrected/float(self.rows))
				)
	
	def saveCorrectedResponseTimes(self, fp):
		for qid, respTime in questions.iteritems():
			fp.write("%i, %i\n" % (qid, respTime))

# create dict from current responsetimes
questions = {}
with open(sys.argv[2], "r") as f:
	f.readline()
	for line in f:
		qid, respTime = line.split(",")
		questions[int(qid)] = int(respTime)

handler = PostHandler(questions)
parser = xml.sax.make_parser()
parser.setContentHandler(handler)
parser.parse(open(sys.argv[1], "r"))

with open(sys.argv[3], "w") as f:
	handler.saveCorrectedResponseTimes(f)
