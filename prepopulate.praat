# prepopulate.praat
#
#  This procedure creates a tier in a Praat TextGrid called "Phone" that
#    will mark the components of VOT (see Abramson & Whalen, submitted).
#    The four labels--VDCLO VLCLO REL ASP--are associated with each segment
#     in the Segments list (by default, b,d,g,p,t,k,pʰ,tʰ,kʰ,s,sʰ).
#     The duration of the segment's interval is arbitrarily divided into
#     fourths, each fourth being the duration of one of the four labels.
#     After running this procedure, the boundaries should be adjusted by hand,
#     and unneeded labels removed.  This will allow the second procedure, 
#     get_vot.praat, to be run.
#
# N.B.
# - This script was tested on macOS Sierra
# - For Window OS users, change directory settings in ... 
#    line 35, "Create Strings as file list... "
#    line 61, "nowarn Read from file... "
#    line 114, "Save as text file... "
#    (Also, change directory on the GUI prompt)

#############################################################################
#---- GUI window ----#
form prepopulate.praat
	comment This script prepopulates Phone tier with the following labels
	comment >> VDCLO VLCLO REL ASP
	comment - In File directory, provide all the TextGrids you want to prepopulate
	comment - New TextGrids will have "_new" appended to file name
	comment >> E.g. VOT_examples_phone.TextGrid
	comment File directory (e.g. /Users/exp/vot )
		text Directory ./example_prepopulate
	comment Segment tier number
		positive Segment_tier 2
	comment Output Phone tier number
		positive Phone_tier 3
	comment Define segments to prepopulate (separated by comma, no space)
		word segments b,d,g,p,t,k
endform

#############################################################################
#---- File preparation ----#

# Create file list
Create Strings as file list... textgrid_list 'directory$'/*.TextGrid

# Check textgrid
select Strings textgrid_list
num_files = Get number of strings

# no textgrid files in the directory
if num_files = 0
	exitScript: "No TextGrid files in the directory. Check your directory"
endif

# Prepare info window
clearinfo
file_counting = 0
printline 
printline Directory: 'directory$'
printline
printline Num of TextGrids: 'num_files'
printline

# Check files iteratively
for ifile from 1 to num_files

	## Read file
	select Strings textgrid_list
	tgFile$ = Get string... ifile	
	nowarn Read from file... 'directory$'/'tgFile$'
	tgName = selected("TextGrid")
	tgname$ = tgFile$ - ".TextGrid"
	numLab_in_segment_tier = Get number of intervals... segment_tier
	
	isSegTierIntv = Is interval tier... segment_tier
	if isSegTierIntv <> 1
		exitScript: "Segment tier (tier number=", segment_tier, ") is point tier; it should be an interval tier."
	endif

	# Insert Phone tier
	# - Phone tier is made based on Segment tier
	Insert interval tier... phone_tier Phone

	## Go through each segment
	for iSeg from 1 to numLab_in_segment_tier
		seg$ = Get label of interval... segment_tier iSeg
		isexist = index_regex(segments$, seg$)

		if isexist > 0 and seg$ <> ""
			seg_beg = Get starting point... segment_tier iSeg
			seg_end = Get end point... segment_tier iSeg

			Insert boundary... phone_tier seg_beg
			Insert boundary... phone_tier seg_end
			phone_interval = Get interval at time... phone_tier seg_beg+(seg_end-seg_beg)/2

			seg_dur = seg_end - seg_beg
			seg_add = seg_dur/4
			
			# Insert equidistant labels 
			for i from 1 to 3
				Insert boundary... phone_tier seg_beg+seg_add*i
				if i = 1
					interval_text$ = "VDCLO"
				elif i = 2
					interval_text$ = "VLCLO"
				elif i = 3
					interval_text$ = "REL"
				endif
				Set interval text... phone_tier phone_interval+(i-1) 'interval_text$'
			endfor
			Set interval text... phone_tier phone_interval+3 ASP

		endif
	endfor

	# Save textgrid
	select tgName
	Save as text file... 'directory$'/'tgname$'_phone.TextGrid
	Remove
endfor

select all
Remove

printline
printline Finished

################## END OF THE SCRIPT #################
