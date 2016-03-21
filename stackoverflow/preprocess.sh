#!/bin/bash
# USAGE: ./preprocess.sh <path/to/Posts.xml> <comma separated list of keywords>

trap times EXIT

echo "Filtering $1 on $2, calculating preliminary responsetimes"
time python preprocess.py $1 questions prelim-responsetimes.csv $2

#echo "Second pass on $1, correcting preliminary responsetimes"
#time python correctresponsetimes.py $1 prelim-responsetimes.csv responsetimes.csv
# since nothing will be corrected, we can just copy:
cp prelim-responsetimes.csv responsetimes.csv

echo "Merging responsetimes with xml files for each keyword"
find . -iname "*-questions" | xargs -I file bash -c 'time python merge-responsetimes.py responsetimes.csv 'file' 'file'".xml"'

echo "Removing temporary files"
rm prelim-responsetimes.csv
rm responsetimes.csv
find . -iname "*-questions" | xargs rm