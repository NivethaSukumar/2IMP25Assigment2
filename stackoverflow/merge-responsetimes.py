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
	print("USAGE: python %s <responseTimes> <xmlQuestions> <mergedXML>" % sys.argv[0])
	print("  responseTimes: csv file")
	print("  xmpQuestions: xml file with questions")
	print("  mergedXML: new xml file with questions")
	print("  example: python %s responsetimes-corrected.csv python-q.xml python-questions.xml" % sys.argv[0])
	sys.exit()

# Actual stuff
class PostHandler(xml.sax.ContentHandler):
	def __init__(self, questions, fp):
		self.questions = questions
		self.numQ = len(self.questions)
		self.fp = fp
		self.rows = 0
		self.corrected = 0
	
	def startElement(self, name, attr):
		if name == "row":
			self.rows += 1
			qid = int(attr["Id"])
			timestamp = int(attr["timestamp"])
			score = int(attr["Score"])
			views = int(attr["ViewCount"])
			favs  = int(attr.get("FavoriteCount", 0))
			title = attr["Title"]
			body  = attr["Body"]
			
			if qid in questions:
				resp  = timestamp - questions[qid]
				del questions[qid]
					
				self.fp.write(
					u"  <row Id=\"%i\" Score=\"%i\" ViewCount=\"%i\" FavoriteCount=\"%i\" Title=\"%s\" Body=\"%s\" timestamp=\"%i\" responsetime=\"%i\" />\n"
					% (qid, score, views, favs, title, body, timestamp, resp)
				)
			else:
				self.fp.write(
					u"  <row Id=\"%i\" Score=\"%i\" ViewCount=\"%i\" FavoriteCount=\"%i\" Title=\"%s\" Body=\"%s\" timestamp=\"%i\" />\n"
					% (qid, score, views, favs, title, body, timestamp)
				)
			
			if self.rows % 50000 == 0:
				print(
					("(progress: \033[92m{:04.1f}%\033[0m) - "+
					"processed \033[92m{:010,}\033[0m questions")
					.format(100*(self.rows/float(self.numQ)), self.rows)
				)

# create dict from current responsetimes
questions = {}
with open(sys.argv[1], "r") as f:
	for line in f:
		qid, respTime = line.split(",")
		questions[int(qid)] = int(respTime)

with open(sys.argv[3], "w") as out:
	out.write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
	out.write("<posts>\n")
	
	handler = PostHandler(questions, out)
	parser = xml.sax.make_parser()
	parser.setContentHandler(handler)
	parser.parse(open(sys.argv[2], "r"))
	
	out.write("</posts>\n")
