from __future__ import print_function
import xml.sax
import sys
import re
import time
import datetime

reload(sys)  
sys.setdefaultencoding('utf8')

# CLI USAGE
if not len(sys.argv) == 5:
	print("USAGE: python %s <xmlfile> <outputfileQuestions> <outputfileResponseTimes> <keywords>" % sys.argv[0])
	print("  outputfileQuestions: xml")
	print("  outputfileResponseTimes: csv")
	print("  keywords: commaseparatedlist")
	print("  example: python %s Posts.xml questions.xml responsetimes.csv c++,python" % sys.argv[0])
	sys.exit()

# GLOBAL
QUESTION = 1
ANSWER = 2

numwarnings = 0
def warning(*objs):
	global numwarnings
	print("\033[93mWARNING:\033[0m ", *objs, file=sys.stderr)
	numwarnings+=1

# Actual stuff
class PostHandler(xml.sax.ContentHandler):
	def __init__(self, outputQuestions, outputAnswers, keywords):
		self.fq = outputQuestions
		self.fa = outputAnswers
		self.questions = 0
		self.rows = 0
		self.unansweredQuestions = {} # mapping: id --> UNIX timestamp
		self.lastTimestampQ = 0 # to check the assumption that input is ordered in increasing time
		self.lastTimestampA = 0 # to check the assumption that input is ordered in increasing time
		
		self.patterns = {}
		for keyword in keywords:
			self.patterns[keyword] = re.compile(r"\<(%s)\>" % re.escape(keyword), re.IGNORECASE)
		
		# matching anything in <code> tags, including the tags
		self.bodyCodePattern = re.compile(r"\<code\>.*\</code\>", re.IGNORECASE)
		# matching any html tags
		self.bodyHtmlPattern = re.compile(r"\<[^\<\>]+\>")
		# matching any &...; html encodings
		self.bodyHtmlSpecialChar = re.compile(r"\&.{2,8}\;")
	
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
					"processed \033[92m{:010,}\033[0m rows, "+
					"of which \033[92m{:010,}\033[0m relevant (\033[92m{:04.01f}%\033[0m), "+
					"of which \033[92m{:05,}\033[0m unanswered questions")
					.format((self.rows/294996.60), self.rows, self.questions, 100*self.questions/float(self.rows), len(self.unansweredQuestions))
				)
	
	def handleQuestion(self, name, attr):
		tags = attr.get("Tags", "No tags")
		
		for keyword, pattern in self.patterns.iteritems():
			if not pattern.match(tags):
				continue
			
			qid = int(attr["Id"])
			timestamp = self.strToTime(attr["CreationDate"])
			score = int(attr["Score"])
			views = int(attr["ViewCount"])
			favs  = int(attr.get("FavoriteCount", 0))
			title = self.filterTitle(attr["Title"])
			body  = self.filterBody(attr["Body"])
			self.questions+=1
			self.unansweredQuestions[qid] = timestamp
			
			if timestamp < self.lastTimestampA:
				warning("Non-incremental time! (question after answer) dt=%i" % (self.lastTimestampA - timestamp))
			else:
				self.lastTimestampQ = timestamp
				
			self.fq[keyword].write(
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
		
		if answerTime < self.lastTimestampA:
			warning("Non-incremental time! (answer out of order) dt=%i" % (self.lastTimestampA - answerTime))
		else:
			self.lastTimestampA = answerTime
		
		fa.write("%i, %i\n" % (parentId, responseTime))
		
		del self.unansweredQuestions[parentId]
	
	def filterBody(self, body):
		body = body.replace('\n', ' ').replace('\r', '') # replace line feeds with single space
		body = self.bodyCodePattern    .sub("", body) # remove code blocks
		body = self.bodyHtmlPattern    .sub("", body) # remove html tags
		body = self.bodyHtmlSpecialChar.sub("", body) # remove html special characters
		body = body.replace("<", "").replace(">","").replace("&","") # remove <, >, &
		body = body.replace("\"", "") # drop double quotes
		
		return body
	
	def filterTitle(self, title):
		return title.replace("\"", "").replace("<", "").replace(">","").replace("&", "")
	
	def strToTime(self, timestr):
		return time.mktime(datetime.datetime.strptime(timestr, "%Y-%m-%dT%H:%M:%S.%f").timetuple())


fq = {}
fa = open(sys.argv[3], "w")

keywords = sys.argv[4].split(",")

for keyword in keywords:
	fq[keyword] = open(keyword+"-"+sys.argv[2], "w")

	fq[keyword].write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
	fq[keyword].write("<posts>\n")

parser = xml.sax.make_parser()
parser.setContentHandler(PostHandler(fq, fa, keywords))
parser.parse(open(sys.argv[1], "r"))

for keyword, filepointer in fq.iteritems():
	filepointer.write("</posts>\n")

if numwarnings > 0:
	print("\033[93m/!\\ %i WARNINGS /!\\\033[0m" % numwarnings)