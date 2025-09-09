
//==============================================================================
						// STATA Coding Sample
//==============================================================================

 /* In this script, we replicate certain figures and tables from
	
	"Jensen, Robert, and Nolan H. Miller. 2018. "Market Integration, Demand, and 
	the Growth of Firms: Evidence from a Natural Experiment in India." American 
	Economic Review 108 (12): 3583–3625.
	DOI: 10.1257/aer.20161965"
	 
	The figures and tables are:
	 
	1) Table 2 - Regression Results: Exit, Market Share, and Employment - Panel A
	2) Figure 2 - Mobile Phones and Fishermen's Behavior and Information
	3) Table 5 - Pooled Treatment Regressions: Consumers
	
	Additonally, we also investigate the data to look for the boat quality of 90th percentile firm at baseline 
	and	mean market share at baseline.
	
	NOTE: This script was originally written for a replication assignemnt in ECON_442 (Issues in Economic
	Development) at UBC. To run the script, one needs to download the replication data from the above 
	mentioned paper's replication which is publicly available.
	
	By: Akshat Kumar
	Last Updated: 08/09/2025
*/


 **************** SET MAIN DO-FILE ARGUMENTS ****************
 
	// Clear all and set large data arguments.
	clear all
	set memory 1500m
	set maxvar 10000
	set more off 
	set seed 2929

*********************************** HEADER ***********************************/

************************ Define user-specific project paths  *******************

	local system_string `c(username)' // Get Stata dir.
	display "Current user, `c(username)' `c(machine_type)' `c(os)'."
		
	* Akshat Kumar
	if inlist( "`c(username)'" , "aksha") {

		local workingdir "C:\Users\aksha\Dropbox\Personal\ECON_442"
		}
		
	* Computer Lab	
	else if inlist( "`c(username)'" , "User") {

		local workingdir "C:\Users\User\Downloads"
		}
		
	else {
	  noisily display as error _newline "{phang}Your username [`c(username)'] could not be matched with a profile. Check do-file header and try again.{p_end}"
	  error 2222
	}

	di "This project is working from `workingdir'"
*==============================================================================*

************************** Set Up Directories **********************************

	// Directory with input data
	local inputdir "`workingdir'\replication_data"
	
	// Directory for output files
	local outputdir "`workingdir'\results"

//============================== END HEADER =====================================
	

	/******************************************************************/		
/*                             TABLE 2                            */
/*        REGRESSION RESULTS: EXIT, MARKET SHARE AND EMPLOYMENT   */
/******************************************************************/	
	
		//Load in Dataset
		use "`inputdir'\BuilderDataSetFinal.dta"	

		//Generate New Variables
		egen total_boats_built_year_all=sum(boats_built), by(round)
		gen market_share=boats_built/total_boats_built_year_all
			
		sort round district		
		
		//Quality at Baseline		
		gen b_l_e=life_expectancy_boat if round==2				
		egen baseline_life_expectancy=max(b_l_e), by(town_id)
				
		//Interaction Term
		gen has_phone_life_expectancy=has_phone*baseline_life_expectancy

		
		//Add lables
		label variable has_phone_life_expectanc "Phone × baseline quality"
		label variable has_phone "Phone"
		label variable baseline_life_expectancy "Baseline quality"
		label variable exit "Exit"
		label variable market_share "Market Share"
		label variable n_workers "Workers"
		label variable boats_built "Boats Built"
		

		//Define locals for output variabls
		local outcomes "exit market_share n_workers boats_built"
		local replace_append "replace"
		
		//Run the loop over each outcome
		foreach y of local outcomes{
			//Regress
			reg `y' has_phone_life_expectanc has_phone baseline_life_expectancy i.district i.round, robust cluster(town_id)
			//Save Result
			outreg2 using `outputdir'\table_2.tex, tex `replace_append' keep(has_phone_life_expectanc has_phone baseline_life_expectancy) nocons stat(coef se blank) nor2 label 

			local replace_append "append"
	
}

//============================== Question E =====================================
	
	//Look at outcomes in just Round 2
	
	//Baseline
	keep if round == 2 
	
	preserve
	
	// Mean Quality
	collapse (mean) baseline_life_expectancy
	tab baseline_life_expectancy 
	//Result:  4.756913
	
	restore
	
	//90th Percentile Quality
	egen p_90 = pctile(baseline_life_expectancy), p(90)
	tab p_90
	//Result: 6.176556
	
	//Mean 
	collapse (mean) market_share
	tab market_share
	//Result: .006993
	
	clear 

	/******************************************************************/		
/*                             FIGURE 2                            */
/*         */
/******************************************************************/	


//============================== Panel A =====================================
	
	//Load Data
	use "`inputdir'/FishermanDataSetFinal"
	
	//Calculate and scale percentage of people who sell local
	collapse(mean) sell_local, by(round district)
	replace sell_local = sell_local * 100
	
	preserve

*-------------------------- Figure for District 1 --------------------------*
	keep if district==1
	
	twoway (connected sell_local round, lcolor(red) mcolor(red) msymbol(square) lpattern(solid) lwidth(medium) ) (pcarrowi 45 4 65 2.3, lcolor(blue) msize(small)  lwidth(thin) mcolor(blue) ),  ///
    ylab(0(10)100, labsize(3) nogrid) ///
	legend(off) ///
	 xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
    xline(2, lcolor(blue) lwidth(thin)) ///
    text(35 6.5 "Mobile Phones", color(black) size(3)) ///
    text(25 5.7 "Introduced", color(black) size(3)) ///
	text(5 12.9 "Region I", color(black) size(3)) ///
	name(g1, replace) /// 
	
	
	restore
	preserve
	
*-------------------------- Figure for District 2 --------------------------*

	keep if district==2
	
	twoway (connected sell_local round, lcolor(red) mcolor(red) msymbol(square) lpattern(solid) lwidth(medium)) (pcarrowi 38 7 60 5.3, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)),  ///
   ylab(0(10)100, labsize(3) nogrid) ///
	legend(off) ///
	 xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
    xline(5, lcolor(blue) lwidth(thin)) ///
    text(30 8.5 "Mobile Phones", color(black) size(3)) ///
    text(20 7.7 "Introduced", color(black) size(3)) ///
	text(5 12.9 "Region II", color(black) size(3)) /// 
	name(g2, replace) /// 

	restore

*-------------------------- Figure for District 3 --------------------------*
	
	keep if district==3
	
	twoway (connected sell_local round, lcolor(red) mcolor(red) msymbol(square) lpattern(solid) lwidth(medium) title("") xtitle("") ytitle("")),  ///
    ylab(0(10)100, labsize(3) nogrid) ///
	legend(off) ///
	 xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
	text(5 12.9 "Region III", color(black) size(3)) ///
	name(g3, replace) /// 
	

	clear
	

//============================== Panel B =====================================

	//Load Data
	use "`inputdir'/FishermanDataSetFinal"
	
	//Calculate estimation errors in quality
	collapse(mean) abs_error_local_builder abs_error_non_local_builder, by(round district)
	
	preserve
	
*-------------------------- Figure for District 1 --------------------------*
	
	keep if district==1
	
	twoway (connected abs_error_local_builder round, lcolor(red) mcolor(red) msymbol(square_hollow) lpattern(dash) lwidth(medium) title("") xtitle("") ytitle("") ) ///
	(connected abs_error_non_local_builder round, lcolor(red) mcolor(red) msymbol(square)   ) ///
	(pcarrowi 1.5 7 1.25 5.55, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)) /// $ Arrow fo Non-local Builder
	(pcarrowi 0.55 3 1 2.2, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)) /// $ Arrow for Mobile Phones
	(pcarrowi 0.25 7.5 0.58 6.5, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)), /// $ Arrow for Local Builder
	xline(2, lcolor(blue) lwidth(thin)) ///
	text(0.4 2.2 "Mobile Phones", color(black) size(3)) ///
	text(0.23 1.5 "Introduced", color(black) size(3)) ///
	text(1.7 8 "Non-local Builder", color(black) size(3)) /// 
	text(0.3 10 "Local Builder", color(black) size(3)) /// 
	xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
	ylab(0 0.5 1 1.5 2, labsize(3) nogrid) ///
	legend(off) /// 
	text(0.1 12.9 "Region I", color(black) size(3)) ///
 	name(g4, replace) /// 
	
	restore
	preserve

*-------------------------- Figure for District 2 --------------------------*
	
	
	keep if district==2
	
	twoway (connected abs_error_local_builder round, lcolor(red) mcolor(red) msymbol(square_hollow) lpattern(solid) lwidth(medium) title("") xtitle("") ytitle("") ) ///
	(connected abs_error_non_local_builder round, lcolor(red) mcolor(red) msymbol(square)   ) ///
	(pcarrowi 1.7 8 1.5 5.5, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)) ///$ Arrow fo Non-local Builder
	(pcarrowi 1 2.8 0.75 4.9, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)) /// $ Arrow for Mobile Phones
	(pcarrowi 0.35 8 0.6 8.9, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)), /// $ Arrow for Local Builder
	xline(5, lcolor(blue) lwidth(thin)) ///
	text(1.2 1.5 "Mobile Phones", color(black) size(3)) ///
	text(1 0.8 "Introduced", color(black) size(3)) ///
	text(1.8 9.2 "Non-local Builder", color(black) size(3)) /// 
	text(0.35 7 "Local", color(black) size(3)) /// 
	text(0.15 7 "Builder", color(black) size(3)) /// 
	xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
	ylab(0 0.5 1 1.5 2, labsize(3) nogrid) ///
	legend(off) /// 
	text(0.1 12.9 "Region II", color(black) size(3)) ///
	name(g5, replace) /// 

	restore
	
*-------------------------- Figure for District 3 --------------------------*
	
	keep if district==3
	
	twoway (connected abs_error_local_builder round, lcolor(red) mcolor(red) msymbol(square_hollow) lpattern(solid) lwidth(medium) title("") xtitle("") ytitle("") ) ///
	(connected abs_error_non_local_builder round, lcolor(red) msymbol(square) mcolor(red)) ///
	(pcarrowi 1.5 7 1.7 9, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)) /// $ Arrow fo Non-local Builder
	(pcarrowi 1 5.5 0.65 9, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)), /// $ Arrow for Local Builder
	text(1.4 8 "Non-local Builder", color(black) size(3)) /// 
	text(1.2 4 "Local Builder", color(black) size(3)) /// 
	xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
	ylab(0 0.5 1 1.5 2, labsize(3) nogrid) ///
	legend(off) /// 
	text(0.1 12.9 "Region III", color(black) size(3)) ///
 	name(g6, replace) /// 

	clear

	

//============================== Panel  C =====================================
	
	//Load Data
	use "`inputdir'/FishermanDataSetFinal", clear
	
	//Calculate and scale percentage of people who buy local
	collapse(mean) buy_local , by(round district)
	replace buy_local = buy_local * 100
	
	preserve
	
	
*-------------------------- Figure for District 1 --------------------------*
	
	keep if district==1
	
	twoway (connected buy_local round, lcolor(red) mcolor(red) msymbol(square) lpattern(solid) lwidth(medium) title("") xtitle("") ytitle("") ) ///
	(pcarrowi 35 4 50 2.2, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)), /// 
    ylab(0(10)100, labsize(3) nogrid) ///
	legend(off) ///
	 xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
    xline(2, lcolor(blue) lwidth(thin)) ///
    text(30 4.95 "Mobile Phones", color(black) size(3)) ///
    text(21 4.2 "Introduced", color(black) size(3)) ///
	text(5 12.9 "Region I", color(black) size(3)) ///
	name(g7, replace) /// 

	restore
	preserve

*-------------------------- Figure for District 2 --------------------------*
	
	keep if district==2
	
	twoway (connected buy_local round, lcolor(red) mcolor(red) msymbol(square) lpattern(solid) lwidth(medium) title("") xtitle("") ytitle("") ) ///
	(pcarrowi 30 2 50 4.8, lcolor(blue)  mcolor(blue) msize(small)  lwidth(thin)), /// 
    ylab(0(10)100, labsize(3) nogrid) ///
	legend(off) ///
	 xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
    xline(5, lcolor(blue) lwidth(thin)) ///
    text(25 2.2 "Mobile Phones", color(black) size(3)) ///
    text(16 1.4 "Introduced", color(black) size(3)) ///
	text(5 12.9 "Region II", color(black) size(3)) ///
	name(g8, replace) /// 

	restore

*-------------------------- Figure for District 3 --------------------------*
	
	keep if district==3
	
	twoway (connected buy_local round, lcolor(red) mcolor(red) msymbol(square) lpattern(solid) lwidth(medium) title("") xtitle("") ytitle("") ), ///
    ylab(0(10)100, labsize(3) nogrid) ///
	legend(off) ///
	 xlabel(-1 "1997" 1 "1998" 3 "1999" 5 "2000" 7 "2001" 9 "2002" 11 "2003" 13 "2004" 15 "2005", angle(45) nogrid) ///
	text(5 12.9 "Region III", color(black) size(3)) ///
	name(g9, replace) /// 

	
//=========================== Combine Graphs =====================================

	graph combine g1 g2 g3, rows(3) title("Panel A. Percent who sell fish" "in their own village", size(small) justification(left)) name(c1, replace)
	
	graph combine g4 g5 g6, rows(3) title("Panel B. Errors in estimating" "boat life-span (yrs.)", size(small) justification(left)) name(c2, replace)
	
	graph combine g7 g8 g9, rows(3) title("Panel C. Percent who buy boats " "in their own village", size(small) justification(left)) 	name(c3, replace)
	
	graph combine c1 c2 c3, rows(1)
	
	//Save Graphs
	graph export "`outputdir'/figure_2.pdf", replace as(pdf)


*/
	/******************************************************************/		
/*                             Table 5                          */
/*         */
/******************************************************************/	

	//Load Data
	use "`inputdir'/BuilderDataSetFinal.dta", clear
	
	//Rename variables for merge
	rename town_id where_buy_id				
	keep round where_buy_id auditor_assessment
	sort round where_buy_id
	
	//Save Data
	save "`inputdir'/temp.dta", replace
	
	//Load Data
	use "`inputdir'/FishermanDataSetFinal.dta"
	
	sort round where_buy_id
	
	//Merge datasets
	merge round where_buy_id using "`inputdir'/temp.dta"
	keep if _m==3
 	drop _m
	
	//Generate Regression variable
	gen price_per_boat_year=price_paid/auditor_assessment
	
	
	//Add lables
	label variable has_phone "Region has phone"
	label variable price_paid "Price"
	label variable auditor_assessment "Assessed life expectancy"
	label variable price_per_boat_year "Price per boat-year"
	
	// Create Locals
	local outcomes_cons "price_paid auditor_assessment price_per_boat_year"
	local replace_append "replace"
	
	foreach y of local outcomes_cons {
		//Regress
		reg `y' has_phone i.round if bought==1, robust cluster(where_buy)
		outreg2 using "`outputdir'/table_5.tex", `replace_append' keep(has_phone) stat(coef se blank) nor2 label addtext(Round FE, No)
		local replace_append "append"
}
	
	foreach y of local outcomes_cons {
		//Regress
		xtreg `y' has_phone i.round if bought==1,  robust cluster(where_buy) fe i(where_buy)
		//Save Results
		outreg2 using "`outputdir'/table_5.tex", append keep(has_phone) stat(coef se blank) nor2  ///
	label addtext(Round FE, Yes)
}




