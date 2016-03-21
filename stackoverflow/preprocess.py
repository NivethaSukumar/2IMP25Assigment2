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
	print("USAGE: python %s <xmlfile> <outputfileQuestions> <outputfileAnswers>" % sys.argv[0])
	print("  outputfileQuestions: xml")
	print("  outputfileAnswers: csv")
	sys.exit()

# GLOBAL
QUESTION = 1
ANSWER = 2

def warning(*objs):
    print("WARNING: ", *objs, file=sys.stderr)

# Actual stuff
class PostHandler(xml.sax.ContentHandler):
	def __init__(self, outputQuestions, outputAnswers):
		self.fq = outputQuestions
		self.fa = outputAnswers
		self.questions = 0
		self.rows = 0
		self.unansweredQuestions = {} # mapping: id --> UNIX timestamp
		self.lastTimestamp = 0 # to check the assumption that input is ordered in increasing time
		
		# matching "<c++>" and "<python>"
		self.pattern = re.compile(r"\<(c\+\+|python)\>", re.IGNORECASE)
		# matching anything in <code> tags, including the tags
		self.bodyCodePattern = re.compile(r"\<code\>.*\</code\>", re.IGNORECASE)
		# matching any html tags
		self.bodyHtmlPattern = re.compile(r"\<[^\<\>]+\>")
	
	def startElement(self, name, attr):
		if name == "row":
			self.rows += 1
			postType = int(attr["PostTypeId"])
			
			if postType == QUESTION:
				self.handleQuestion(name, attr)
			elif postType == ANSWER:
				self.handleAnswer(name, attr)
			#else:
			#	warning("invalid value for PostTypeId: %s" % attr["PostTypeId"])
			
			if self.rows % 10000 == 0:
				print(
					("(progress: \033[92m{:04.1f}%\033[0m) - "+
					"processed \033[92m{:010,}\033[0m questions, "+
					"of which \033[92m{:010,}\033[0m relevant (\033[92m{:04.01f}%\033[0m), "+
					"of which \033[92m{:05,}\033[0m unanswered")
					.format((self.rows/294996.60), self.rows, self.questions, 100*self.questions/float(self.rows), len(self.unansweredQuestions))
				)
	
	def handleQuestion(self, name, attr):
		tags = attr.get("Tags", "No tags")
		if not self.pattern.match(tags):
			return
		
		qid = int(attr["Id"])
		timestamp = self.strToTime(attr["CreationDate"])
		score = int(attr["Score"])
		views = int(attr["ViewCount"])
		favs  = int(attr.get("FavoriteCount", 0))
		title = self.filterTitle(attr["Title"])
		body  = self.filterBody(attr["Body"])
		self.questions+=1
		self.unansweredQuestions[qid] = timestamp
		
		if timestamp < self.lastTimestamp:
			warning("Non incremental time! (QUESTION)")
		self.lastTimestamp = timestamp
			
		self.fq.write(
			u"  <row Id=\"%i\" Score=\"%i\" ViewCount=\"%i\" FavoriteCount=\"%i\" Title=\"%s\" Body=\"%s\" timestamp=\"%i\" />\n"
			% (qid, score, views, favs, title, body, timestamp)
		)
		#print("%i/%i (%.2f)\t: id=%s\ttags=%s\ttime=%i" % (len(self.unansweredQuestions), self.questions, (self.rows/29499660.0), qid, tags, timestamp))
	
	def handleAnswer(self, name, attr):
		if "ParentId" not in attr:
			warning("ParentId not set for answer")
			return
		
		parentId = int(attr["ParentId"])
		if parentId not in self.unansweredQuestions:
			return
		
		answerTime   = self.strToTime(attr["CreationDate"])
		questionTime = self.unansweredQuestions[parentId]
		responseTime = answerTime - questionTime
		
		if answerTime < self.lastTimestamp:
			warning("Non incremental time! (QUESTION)")
		self.lastTimestamp = answerTime
		
		fa.write("%i, %i\n" % (parentId, responseTime))
		
		del self.unansweredQuestions[parentId]
	
	def filterBody(self, body):
		body = body.replace('\n', ' ').replace('\r', '') # replace line feeds with single space
		body = self.bodyCodePattern.sub("", body) # remove code blocks
		body = self.bodyHtmlPattern.sub("", body) # remove html tags
		body = body.replace("\"", "") # drop double quotes
		
		return body
	
	def filterTitle(self, title):
		return title.replace("\"", "")
	
	def strToTime(self, timestr):
		return time.mktime(datetime.datetime.strptime(timestr, "%Y-%m-%dT%H:%M:%S.%f").timetuple())

with open(sys.argv[2], "w") as fq, open(sys.argv[3], "w") as fa:
	fq.write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
	fq.write("<posts>\n")
	
	parser = xml.sax.make_parser()
	parser.setContentHandler(PostHandler(fq, fa))
	parser.parse(open(sys.argv[1], "r"))
	
	fq.write("</posts>\n")