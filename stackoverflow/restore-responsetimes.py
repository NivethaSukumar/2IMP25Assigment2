import xml.sax
import sys
import time
import datetime

def strToTime(timestr):
	return time.mktime(datetime.datetime.strptime(timestr, "%Y-%m-%dT%H:%M:%S.%f").timetuple())

# Actual stuff
class PostHandler(xml.sax.ContentHandler):
	def __init__(self, questions):
		self.questions = questions
		self.rows = 0
	
	def startElement(self, name, attr):
		if name == "row":
			if int(attr["PostTypeId"]) == 2:
				aid = int(attr["ParentId"])
				
				if aid in self.questions:
					if self.questions[aid] == -1 or self.questions[aid] > strToTime(attr["CreationDate"]):
						self.questions[aid] = strToTime(attr["CreationDate"])
			
			self.rows += 1
			if self.rows % 50000 == 0:
				print(
					("(progress: \033[92m{:04.1f}%\033[0m) - "+
					"processed \033[92m{:010,}\033[0m rows, ")
					.format((self.rows/294996.60), self.rows)
				)
	
	def getResp(self, qid):
		return self.questions[qid]

questions = {}
with open(sys.argv[2], "r") as fi:
	fi.readline()
	
	for line in fi:
		qid, pos, score, vcount, fcount, responsetime, timestamp = line.split(",")
		qid = int(qid)
		questions[qid] = -1

handler = PostHandler(questions)
parser = xml.sax.make_parser()
parser.setContentHandler(handler)
parser.parse(open(sys.argv[1], "r"))

with open(sys.argv[2], "r") as fi, open(sys.argv[3], "w") as fo:
	fo.write(fi.readline())
	
	for line in fi:
		qid, pos, score, vcount, fcount, responsetime, timestamp = line.split(",")
		qid = int(qid)
		pos = float(pos)
		#neg = float(neg)
		score = int(score)
		vcount = int(vcount)
		fcount = int(fcount)
		timestamp = int(timestamp)
		responsetime = handler.getResp(qid) - timestamp
		
		fo.write("%i,%f,%i,%i,%i,%i,%i\n" % (qid, pos, score, vcount, fcount, responsetime, timestamp))
