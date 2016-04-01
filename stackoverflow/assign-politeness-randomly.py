import xml.sax
import sys
import random

reload(sys)  
sys.setdefaultencoding('utf8')

# CLI USAGE
if not len(sys.argv) == 3:
	print "USAGE: python %s <xmlfile> <csvoutput" % sys.argv[0]
	print "  xmlfile: the preprocessed xml file"
	print "  csvoutput: new file"
	sys.exit()

class PostHandler(xml.sax.ContentHandler):
	def __init__(self, fp):
		self.fp = fp
		self.rows = 0
	
	def startElement(self, name, attr):
		if not name == "row":
			return
		
		fp.write("%i,%i,%i,%i,%i,%i,%i\n" % (
				int(attr["Id"]),
				random.random(),
				random.random()
				int(attr["Score"]),
				int(attr["ViewCount"]),
				int(attr["FavoriteCount"]),
				int(attr.get("responsetime", sys.maxint)),
				int(attr["timestamp"])
			)
		)
		
		self.rows+=1
		if self.rows % 10000 == 0:
			print "processed %i rows" % self.rows

with open(sys.argv[2], "w") as fp:
	fp.write("Id,positive,negative,Score,ViewCount,FavoriteCount,responsetime,timestamp\n")
	handler = PostHandler(fp)
	parser = xml.sax.make_parser()
	parser.setContentHandler(handler)
	parser.parse(open(sys.argv[1], "r"))