# get_vot.praat
# 
# Comments:
#
# This procedure extracts VOT (and other) values from TextGrid files with certain
# characteristics:
#   1: A tier (default label is "Word") with word-level intervals
#   2: A tier (default label is "Segment") with phoneme-size segments marked
#   3: A tier (default label is "Phone") with acoustic intervals relevant to VOT
#      see below and Abramson & Whalen (submitted) for details
#   (4: The example has a tier "Source", to indicate where the sounds came from:
#       English DHW: speaker: D. H. Whalen
#       ASA, L2 Thai, L2 Sgaw: speaker: Arthur Abramson
#       Thai: UCLA: http://archive.phonetics.ucla.edu/Language/THA/tha.html
#       Malagasy Howe: provided by Penelope Howe from her field recordings
# If requested, a new tier (default name is "VOT") with intervals marking the final
#   value calculated for VOT ("VOT" is positive, "mVOT" is negative).
# If requested, a new tier (default name is "CLO") including closure intervals (labeled as "CLO")
#   will be created
#
#  The segments that are looked for by default are in the Define segments for VOT result:
#	comment Define segments for VOT result (separated by comma without space)
#		word segments b,d,g,p,t,k
#  Edit this line if there are more or fewer segments of interest; the list can be
#    entered on execution as well (for example, if you want to do a separate run
#    for each stop).
# 
# Each Segment can have one VOT labeled.  
#   In this way, VOT values for many words in one file can be associated with the word
#   and the same labels can be used multiple times on the Segment tier.
# The maximal number of relevant Segment labels is 6:
#    V VDCLO VLCLO REL ASP V
# REL, the onset of the release burst, must always be present or no VOT can be computed.
#  If there is no real acoustic release burst, a REL interval of some minimal duration 
#  must still be created.
#  Note that REL is assumed to include the "frication" portion of the release, if any.
#  (cf. Stevens, K. N. (1993). Models for the production and acoustics of stop consonants. 
#     Speech Communication, 13, 367-375.)
# first V, the preceding vocalic segment, is optionally present.  Its offset is the onset 
#   of the closure.  If vowel durations are not of interest, they can simply be omitted.
# VDCLO, the voiced closure, if any, begins at the end of V1, or at the point of closure
#   (if there is a preceding acoustic portion but that is not labeled as V1) or at the
#   beginning of voicing during the closure if there is no preceding context.
# VLCLO, the voiceless closure, if any, begins at the end of VDCLO (if any) or first V (if 
#   not) or at the end of any other (unlabeled) preceding acoustic segment.
# If voicing starts and stops in some other pattern, this procedure cannot handle it. 
#   It would make sense to mark such (presumably rare) cases for special handling.
# ASP, aspiration, is the period from the end of REL to the onset of second V (if present)
#   or simply the end of aspiration if second V is not marked (or not present).
#   Note that the overlap between voicing and aspiration should be marked consistently
#   as either belonging to the vocalic segment or the aspiration.
# second V, the following vocalic segment, is optionally present.  It's onset is the end
#   of ASP or, if there is no ASP, REL.
#
#  The output can select which stop will be reported, using the IPA symbols in Praat.
#  
# ** Operating systems **
# - This script was tested on macOS Sierra
# - For Window OS users, change directory settings in ...
#    line 91, "Create Strings as file list... "
#    line 142, "nowarn Read from file... "
#    line 217, "nowarn Read from file... "
#    line 670, "Save as text file... "
#    (Also, change directory on the GUI prompt)
#
# ** File encoding **
# - Make sure to set "Text writing preferences" as "UTF-8" on Praat.
# - If IPA symbols are not showing properly on the result file (.csv), 
#   use 'import -> CSV file' option and choose UTF-8 encoding on MS Excel program.

#############################################################################
#---- GUI window ----#

form get_vot.praat
	comment << Praat procedure for VOT measurement >>
	comment - In File directory, provide all the TextGrids you want to prepopulate
	comment - New TextGrids will have "_vot" appended to file name
	comment File directory (e.g. /Users/exp/vot )
		text Directory ./example_getvot
	comment Result file name with directory (e.g. /Users/exp/vot/result.csv)
		text Resultfile ./example_getvot/result.csv
	comment Define percentage of closure that must be voiced (VDCLO) 
	comment for VOT to be negative (0-100; default, 50)
		real percent_voicing 50
	comment Define tiers (tier number)
		positive Word_tier 1
		positive Segment_tier 2
		positive Phone_tier 3
		positive Source_tier 4
	comment Define segments for VOT result (separated by comma without space)
		word segments b,d,g,p,t,k
	comment Make VOT output tier?
	comment - VOT tier will be appended at the end with VOT intervals only 
		boolean VOT_output
	comment Make CLO output tier?
	comment - CLO tier will be appended at the end with closure intervals only
		boolean CLO_output
endform

#############################################################################
#---- File preparation ----#

# Create file list
Create Strings as file list... textgrid_list 'directory$'/*.TextGrid

# Check if result file already exists
if fileReadable (resultfile$)
	pause The result file already exists! Do you want to overwrite it?
	printline Result file has been overwritten!
	filedelete 'resultfile$'
endif

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
printline Resultfile: 'resultfile$'
printline
printline Num of TextGrids: 'num_files'
printline

# Prepare header for result file
titleline$ = "Filename,Source,Word,V_pre,V_pre_dur,Segment,V_post,V_post_dur,VOT_beg,VOT_end,VOT,CLO"
fileappend "'resultfile$'" 'titleline$' 'newline$'

#############################################################################
#---- Error checking ----#

# Set possible combinations
sets$[1] = ",VDCLO,VLCLO,REL,ASP"
sets$[2] = ",VDCLO,VLCLO,REL"
sets$[3] = ",VDCLO,REL,ASP"
sets$[4] = ",VDCLO,REL"
sets$[5] = ",VLCLO,REL,ASP"
sets$[6] = ",VLCLO,REL"
sets$[7] = ",REL,ASP"
sets$[8] = ",REL"

# Check files iteratively
for ifile from 1 to num_files

	## Read file
	select Strings textgrid_list
	tgFile$ = Get string... ifile	
	nowarn Read from file... 'directory$'/'tgFile$'
	tgName = selected("TextGrid")
	tgname$ = tgFile$ - ".TextGrid"
	numLab_in_word_tier = Get number of intervals... word_tier
	
	isWordTierIntv = Is interval tier... word_tier
	isSegTierIntv = Is interval tier... segment_tier
	isPhoneTierIntv = Is interval tier... phone_tier

	if isWordTierIntv <> 1
		exitScript: "Word tier (tier number=", word_tier, ") is point tier; it should to be an interval tier."
	elsif isSegTierIntv <> 1
		exitScript: "Segment tier (tier number=", segment_tier, ") is point tier; it should to be an interval tier."
	elsif isPhoneTierIntv <> 1
		exitScript: "Phone tier (tier number=", phone_tier, ") is point tier; it should to be an interval tier."
	endif

	## Go through each word
	wordcnt = 0
	for iWord from 1 to numLab_in_word_tier
		word$ = Get label of interval... word_tier iWord
		if length(word$) <> 0
			wordcnt = wordcnt + 1
			wordBeg = Get starting point... word_tier iWord
			wordEnd = Get end point... word_tier iWord
			
			## Check if segments are within word boundary
			# if initial segment begins earlier than word
			beg_possible = Get interval at time... segment_tier wordBeg
			beg_possible_time = Get starting point... segment_tier beg_possible
			beg_suspect$ = Get label of interval... segment_tier beg_possible
			if (beg_possible_time < wordBeg) and beg_suspect$ <> ""
				printline Error: Initial segment begins earlier than the word: ''word$'' at time: 'wordBeg'
				exitScript: "Error: Initial segment begins earlier than the word: ", "'", word$, "'", " at time:", wordBeg
			endif

			# if final segment ends later than word
			end_possible = Get low interval at time... segment_tier wordEnd
			end_possible_time = Get end point... segment_tier end_possible
			end_suspect$ = Get label of interval... segment_tier end_possible
			if (end_possible_time > wordEnd) and end_suspect$ <> ""
				printline Error: Final segment ends later than the word: ''word$'' at time: 'wordEnd'
				exitScript: "Error: Final segment ends later than the word: ", "'", word$, "'", " at time:", wordEnd
			endif
			
			allLabelBegTime = Get end point... segment_tier beg_possible
			allLabelBegIntNum = beg_possible+1
			allLabelEndTime = Get starting point... segment_tier end_possible
			allLabelEndIntNum = end_possible-1

			## Check if phones are within segment boundary
			# if initial phone begins earlier than segment
			# (Add error message later)

			# if final phone ends later than segment
			# (Add error message later)

		endif
	endfor	
	
	# Clear object window
	select all
	minus Strings textgrid_list
	Remove
endfor


#############################################################################
#---- VOT extraction ----#
# Check files iteratively
for ifile from 1 to num_files

	##### Read file #####
	select Strings textgrid_list
	tgFile$ = Get string... ifile	
	nowarn Read from file... 'directory$'/'tgFile$'
	tgName = selected("TextGrid")	
	tgname$ = tgFile$ - ".TextGrid"

	# Make VOT tier
	if (vOT_output == 1) and (cLO_output <> 1)
		select tgName
		Copy... 'tgname$' VOT
		newTg = selected("TextGrid")
		select tgName
		numTier = Get number of tiers
		votTier = numTier + 1
		select newTg
		Insert interval tier... votTier VOT
		select tgName
	endif

	# Make CLO tier
	if (cLO_output == 1) and (vOT_output <> 1)
		select tgName
		Copy... 'tgname$' CLO
		newTg = selected("TextGrid")
		select tgName
		numTier = Get number of tiers
		cloTier = numTier + 1
		select newTg
		Insert interval tier... cloTier CLO
		select tgName
	endif

	# Make VOT & CLO tier
	if (vOT_output == 1) and (cLO_output == 1)
		select tgName
		Copy... 'tgname$' VOT
		newTg = selected("TextGrid")
		select tgName
		numTier = Get number of tiers
		votTier = numTier + 1
		cloTier = numTier + 2
		select newTg
		Insert interval tier... votTier VOT
		Insert interval tier... cloTier CLO
		select tgName
	endif

	##### Go through each word in Word tier #####
	select tgName
	wordcnt = 0
	for iWord from 1 to numLab_in_word_tier
		select tgName
		word$ = Get label of interval... word_tier iWord

		# For word intervals
		if length(word$) <> 0
			select tgName
			wordcnt = wordcnt + 1
			wordBeg = Get starting point... word_tier iWord
			wordEnd = Get end point... word_tier iWord
			seg_int_beg = Get interval at time... segment_tier wordBeg
			seg_int_end = Get interval at time... segment_tier wordEnd
			phone_int_beg = Get interval at time... phone_tier wordBeg
			phone_int_end = Get interval at time... phone_tier wordEnd

			# Check if the specified segments exist at the current interval
			nonempty_segment = 0
			source_result$ = "NA"
			segment_result$ = "NA"
			# if source_tier is not empty
			if string$(source_tier) <> ""
				for i from seg_int_beg to seg_int_end-1
					seg_lab$ = Get label of interval... segment_tier i
					source_interval = Get interval at time... source_tier (wordEnd-wordBeg)/2+wordBeg
					source_result$ = Get label of interval... source_tier source_interval
					isexist = index_regex(segments$, seg_lab$)
					if isexist <> 0 and seg_lab$ <> ""				
						nonempty_segment = 1
						segment_result$ = seg_lab$
					endif
				endfor
			# if source_tier is empty
			elif string$(source_tier) = ""
				for i from seg_int_beg to seg_int_end-1
					seg_lab$ = Get label of interval... segment_tier i
					isexist = index_regex(segments$, seg_lab$)
					if isexist <> 0 and and seg_lab$ <> ""
						nonempty_segment = 1
						segment_result$ = seg_lab$
					endif
				endfor
			endif

			# For specified phone and nonempty segment
			if (phone_int_beg <> phone_int_end)
				# Find the initial phone in a word
				beg_possible = Get interval at time... phone_tier wordBeg
				beg_possible_time = Get starting point... phone_tier beg_possible
				if beg_possible_time <> wordBeg
					beg_possible = beg_possible + 1 
					beg_possible_time = Get starting point... phone_tier beg_possible
				endif
				beg_suspect$ = Get label of interval... phone_tier beg_possible

				# Find the final phone in a word
				end_possible = Get interval at time... phone_tier wordEnd
				end_possible_time = Get end point... phone_tier end_possible
				if end_possible_time <> wordEnd
					end_possible = end_possible - 1
					end_possible_time = Get end point... phone_tier end_possible
				endif
				end_suspect$ = Get label of interval... phone_tier end_possible

				allLabelBegIntNum = beg_possible
				allLabelEndIntNum = end_possible

				# Make Phone sequence string
				phone_line$ = ""
				for iSeg from allLabelBegIntNum to allLabelEndIntNum
					seg_lab$ = Get label of interval... phone_tier iSeg
					phone_line$ = phone_line$ +","+ seg_lab$
				endfor

				# Only for possible phone sequences 
				possible_phone_sequence = 0
				for i from 1 to 8
					# Check possible phone sequences
					if index_regex(phone_line$, sets$[i]) <> 0
						possible_phone_sequence = 1
					endif
				endfor

				# Check vowel phones
				# Only for cases where phone sequences are provided
				if possible_phone_sequence <> 0
					possible_vowel_cnt = 0
					pre_vowel = 0
					post_vowel = 0
					v_pre$ = "v_pre$"
					v_post$ = "v_post$"
					v_pre_dur = -0.999
					v_post_dur = -0.999
					
					for iSeg from allLabelBegIntNum to allLabelEndIntNum
						seg_lab$ = Get label of interval... phone_tier iSeg
						if seg_lab$ = "V"
							possible_vowel_cnt = possible_vowel_cnt + 1
							if iSeg = allLabelBegIntNum
								pre_vowel = 1
								pre_vowel_idx = iSeg
							elif iSeg = allLabelEndIntNum
								post_vowel = 1
								post_vowel_idx = iSeg
							else
								exitScript: "V(owel) should be the initial or the final segment, not inside the segment sequence"
							endif
						endif
					endfor
					if possible_vowel_cnt = 1 and pre_vowel = 1 and post_vowel = 0
						pre_vowel_beg = Get starting point... phone_tier pre_vowel_idx
						pre_vowel_end = Get end point... phone_tier pre_vowel_idx
						pre_vowel_mid = pre_vowel_beg + (pre_vowel_end - pre_vowel_beg)/2
						pre_vowel_interval = Get interval at time... segment_tier pre_vowel_mid
						v_pre$ = Get label of interval... segment_tier pre_vowel_interval
						v_post$ = "v_post$"
						v_pre_dur = pre_vowel_end - pre_vowel_beg

					elif possible_vowel_cnt = 1 and pre_vowel = 0 and post_vowel = 1
						v_pre$ = "v_pre$"
						post_vowel_beg = Get starting point... phone_tier post_vowel_idx
						post_vowel_end = Get end point... phone_tier post_vowel_idx
						post_vowel_mid = post_vowel_beg + (post_vowel_end - post_vowel_beg)/2
						post_vowel_interval = Get interval at time... segment_tier post_vowel_mid
						v_post$ = Get label of interval... segment_tier post_vowel_interval
						v_post_dur = post_vowel_end - post_vowel_beg

					elif possible_vowel_cnt = 2 and pre_vowel = 1 and post_vowel = 1
						pre_vowel_beg = Get starting point... phone_tier pre_vowel_idx
						pre_vowel_end = Get end point... phone_tier pre_vowel_idx
						pre_vowel_mid = pre_vowel_beg + (pre_vowel_end - pre_vowel_beg)/2
						pre_vowel_interval = Get interval at time... segment_tier pre_vowel_mid
						v_pre$ = Get label of interval... segment_tier pre_vowel_interval
						v_pre_dur = pre_vowel_end - pre_vowel_beg

						post_vowel_beg = Get starting point... phone_tier post_vowel_idx
						post_vowel_end = Get end point... phone_tier post_vowel_idx
						post_vowel_mid = post_vowel_beg + (post_vowel_end - post_vowel_beg)/2
						post_vowel_interval = Get interval at time... segment_tier post_vowel_mid
						v_post$ = Get label of interval... segment_tier post_vowel_interval
						v_post_dur = post_vowel_end - post_vowel_beg
					endif
				endif

				
				#######################################
				####### (1) Get each phone info #######
				#######################################	

				# Search only if Phone tier includes possible sequence of phones
				# and segments match with specified segment intervals
				if possible_phone_sequence == 1 and nonempty_segment == 1

					### --------------- VDCLO --------------- ###
					vdclo_idx = 0
					vdclo_int = 0
					vdclo_beg = 0
					vdclo_end = 0
					vdclo_dur = 0
				
					vdclo_idx = index_regex(phone_line$,"VDCLO")
					if vdclo_idx <> 0
						vdclo_ubound = rindex_regex(phone_line$,"VDCLO")
						vdclo_part$ = left$(phone_line$,vdclo_ubound-1)
					
						comma = 0
						for icom from 1 to length(vdclo_part$)
							extracted$ = mid$(vdclo_part$,icom,1)
							comma_idx = index_regex(extracted$,",")
							if comma_idx <> 0
								comma = comma + 1
							endif
						endfor

						vdclo_int = allLabelBegIntNum + comma - 1
						vdclo_beg = Get starting point... phone_tier vdclo_int
						vdclo_end = Get end point... phone_tier vdclo_int
						vdclo_dur = vdclo_end - vdclo_beg
					endif	

					### --------------- VLCLO --------------- ###
					vlclo_idx = 0
					vlclo_int = 0
					vlclo_beg = 0
					vlclo_end = 0
					vlclo_dur = 0

					vlclo_idx = index_regex(phone_line$,"VLCLO")
					if vlclo_idx <> 0
						vlclo_ubound = index_regex(phone_line$,"VLCLO")
						vlclo_part$ = left$(phone_line$,vlclo_ubound)

						comma = 0
						for icom from 1 to length(vlclo_part$)
							extracted$ = mid$(vlclo_part$,icom,1)
							comma_idx = index_regex(extracted$,",")
							if comma_idx <> 0
								comma = comma + 1
							endif
						endfor

						vlclo_int = allLabelBegIntNum + comma - 1
						vlclo_beg = Get starting point... phone_tier vlclo_int
						vlclo_end = Get end point... phone_tier vlclo_int
						vlclo_dur = vlclo_end - vlclo_beg
					endif

					### --------------- REL --------------- ###
					rel_int = 0
					rel_beg = 0
					rel_end = 0
					rel_dur = 0

					rel_ubound = index_regex(phone_line$,"REL")
					rel_part$ = left$(phone_line$,rel_ubound)

					comma = 0
					for icom from 1 to length(rel_part$)
						extracted$ = mid$(rel_part$,icom,1)
						comma_idx = index_regex(extracted$,",")
						if comma_idx <> 0
							comma = comma + 1
						endif
					endfor

					rel_int = allLabelBegIntNum + comma - 1
					rel_beg = Get starting point... phone_tier rel_int
					rel_end = Get end point... phone_tier rel_int

					### --------------- ASP --------------- ###
					asp_idx = 0
					asp_int = 0
					asp_beg = 0
					asp_end = 0
					asp_dur = 0			

					asp_idx = index_regex(phone_line$,"ASP")
					if asp_idx <> 0
						asp_ubound = index_regex(phone_line$,"ASP")
						if asp_ubound <> 0
							asp_part$ = left$(phone_line$,asp_ubound)

							comma = 0
							for icom from 1 to length(asp_part$)
								extracted$ = mid$(asp_part$,icom,1)
								comma_idx = index_regex(extracted$,",")
								if comma_idx <> 0
									comma = comma + 1
								endif
							endfor

							asp_int = allLabelBegIntNum + comma - 1
							asp_beg = Get starting point... phone_tier asp_int
							asp_end = Get end point... phone_tier asp_int
						endif
					endif


					##############################
					###### (2) VOT Decision ######
					##############################

					vot = 0
					clo = 0
					
					vot_beg = 0
					vot_end = 0
					clo_beg = 0
					clo_end = 0
					vdclo_as_clo = 0

					# << Condition: If VDCLO is within WORD >> 
					if vdclo_idx <> 0

						# << Condition: If VLCLO is too >>
						if vlclo_idx <> 0
							
							# << Condition: If VDCLO > closure*percent_voicing/100, VOT=beg of VDCLO to beg REL >>
							if vdclo_dur > (vlclo_dur + vdclo_dur)*percent_voicing/100
								vot_beg = rel_beg
								vot_end = vdclo_beg
								vdclo_as_clo = 1
							else

								# << Condition: If ASP is within word >>
								if asp_idx <> 0
									vot_beg = rel_beg
									vot_end = asp_end
								else
									vot_beg = rel_beg
									vot_end = rel_end
								endif
							endif
						else

						# << Condition: If VLCLO is not within WORD >>
							vot_beg = rel_beg
							vot_end = vdclo_beg
						endif
					
					# << Condition: If VDCLO is not within WORD >>
					else

						# << Condition: If ASP is within word >>
						if asp_idx <> 0
							vot_beg = rel_beg
							vot_end = asp_end
						else
							vot_beg = rel_beg
							vot_end = rel_end
						endif	
					endif

					# << Condition: If (VDCLO or VLCLO is within WORD) >>
					if (vdclo_idx <> 0) or (vlclo_idx <> 0)
						if vdclo_idx <> 0
							clo_beg = vdclo_beg
							clo_end = rel_beg
						else
							clo_beg = vlclo_beg
							clo_end = rel_beg
						endif
					endif

					# Calculate VOT and CLO
					vot = vot_end - vot_beg
					clo = clo_end - clo_beg

					# Convert sec to msec
					vot = vot*1000
					clo = clo*1000

					# Add VOT tier only
					if (vOT_output == 1) and (cLO_output <> 1)
						select newTg
						Insert boundary... votTier vot_beg
						Insert boundary... votTier vot_end

						if vot < 0 
							votIntNum = Get interval at time... votTier vot_end
							Set interval text... votTier votIntNum mVOT
						else
							votIntNum = Get interval at time... votTier vot_beg
							Set interval text... votTier votIntNum VOT
						endif
					endif

					# Add CLO tier only
					if (cLO_output == 1) and (vOT_output <> 1)
						select newTg
						if clo > 0
							Insert boundary... cloTier clo_beg
							Insert boundary... cloTier clo_end
							cloIntNum = Get interval at time... cloTier clo_beg
							Set interval text... cloTier cloIntNum CLO
						endif
					endif

					# Add VOT & CLO tier
					if (vOT_output == 1) and (cLO_output == 1)
						select newTg
						if clo > 0
							Insert boundary... cloTier clo_beg
							Insert boundary... cloTier clo_end
						endif

						Insert boundary... votTier vot_beg
						Insert boundary... votTier vot_end

						if vot < 0 
							cloIntNum = Get interval at time... cloTier clo_beg
							votIntNum = Get interval at time... votTier vot_end
							Set interval text... votTier votIntNum mVOT
						else
							cloIntNum = Get interval at time... cloTier clo_beg
							votIntNum = Get interval at time... votTier vot_beg
							Set interval text... votTier votIntNum VOT
						endif
		
						if clo > 0
							Set interval text... cloTier cloIntNum CLO
						endif
					endif

					# If the closure duration is not measured,
					# set clo to be -999 instead of 0
					if clo = 0
						clo = -999
					endif

					# Write to result file
					# show one digit after the decimal point
					vot_beg_time$ = fixed$(vot_beg*1000,1)
					vot_end_time$ = fixed$(vot_end*1000,1)
					vot$ = fixed$(vot,1)
					clo$ = fixed$(clo,1)
					v_pre_dur$ = fixed$(v_pre_dur*1000,1)
					v_post_dur$ = fixed$(v_post_dur*1000,1)

					resultline$ = "'tgname$','source_result$','word$','v_pre$','v_pre_dur$','segment_result$','v_post$','v_post_dur$','vot_beg_time$','vot_end_time$','vot$','clo$'"
					fileappend "'resultfile$'" 'resultline$' 'newline$'
				endif
			endif
		endif
	endfor
	
	# Save textgrid
	if (vOT_output == 1) or (cLO_output == 1)
		select newTg
		Save as text file... 'directory$'/'tgname$'_vot.TextGrid
		Remove
	endif

	# Clear object window
	select all
	minus Strings textgrid_list
	Remove
endfor

select all
Remove

printline
printline Finished

################## END OF THE SCRIPT #################

