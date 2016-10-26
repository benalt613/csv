#! /usr/bin/bash

# Script: csv.bash
# Author: Ben Altman (csv.feedback.benalt@xoxy.net)
# Description: Convert csv files from Excel in to a format using a different separators.
#
# Usage: csv.bash [options] csv_file
#        -i csv_file_field_separator (default is comma)
#        -o output_field_separator (default is pipe)
#        -l -m -n multiline_field_separator (default is "\n")

usage() {
	[[ -n $1 ]] && echo "$1\n" >&2
	cat <<-xx >&2
	Usage: ${0##*/} [options] [csv_file(s)]
	       -i csv_file_field_separator (default is comma)
	       -l, -m, -n multiline_field_separator (default is "\n")
	       -o output_field_separator (default is pipe)
	xx

	exit 1
}

ifs=, ofs=\|  nl='\\n' # defaults
while getopts :i:o:m:n:l: opt; do
	case $opt in
		i) ifs=$OPTARG;;
		o) ofs=$OPTARG;;
		[mnl]) nl=$OPTARG;;
		*) usage;;
	esac
done
shift $((OPTIND-1))

awk -F"$ifs" -vOFS="$ofs" -vnl="$nl" '
# does the field end in an even number of double quotes?
function evenqq(field) {
	# return ! ((length(field) - length(gensub("\"*$","",1,field))) % 2)  # gawk only
	f2=field; gsub("\"*$","",f2)
	return ! ((length(field) - length(f2)) % 2)
}

BEGIN {
	fs = FS # for rejoining fields containing FS for case when it`s a pipe, don`t join with [|]
	gsub("[|]","[|]",FS)  # Input separator containing a pipe replace "|" with "[|]"
}

{
	# i points to the field we are joining to. j points to the field that may need to join to i.
	# n: number of fields in the current line being processed. 
	# nf: tally of the number of fields including lines read for multi-line fields that have
	#     more fields on those lines to complete the record.
	i=1; j=2
	n = nf = split($0, field)

	while (j <= n+1) {
		# 1. A field with no DQs is a simple field and we can move straight to the next field.
		# 2. A field starting with a DQ can contain DQs, FS or multiple lines which we need to join.

		# If the field is not a simple field with no DQs at all
		if (substr($i,1,1) == "\"") {
			# while the field ENDS in even or no DQs it is joined to the next field, until odd quotes are joined ending the field...
			while (evenqq($i)) 
			{
				if (j <= n) { 			# join with this line (fs)
					$i = $i fs field[j++]
					nf--
				} else {				# join with next line (nl)
					getline line
					n = split(line, field)
					nf += n - 1

					$i = $i nl field[1]
					j = 2
				}
			}

			# Remove surrounding DQs and remove escape DQ character from DQs.
			gsub("^\"|\"$","",$i); gsub("\"\"","\"",$i)
		}

		# Next field[i] is overwritten by current field[j] and move j pointer to next field that might need to be joined
		$(++i) = field[j++]
	}

	NF = nf
 
   	print
}' "$@"

