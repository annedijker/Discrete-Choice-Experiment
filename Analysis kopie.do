/*******************************************************************************************
Analysis Mixed Logit Regression
	Input: ShapedSurveyData.csv
*******************************************************************************************/

version 14
clear all
capture log close
set more off

*** 1. Create log file called 'MIXL.log' in the map 'Logfiles'
	*This file logs the results from the analyses 
	
	log using "/Users/annedijker/Desktop/DCE_final/Output/Logfiles/MIXL.log", text replace	

*** 2. Prepare analysis
	
	ssc install mixlogit			// for MIXL
	ssc install estout				// for esttab (estimate coefficient table)
	set seed 1234
	
*** 3. Import shaped dataset 

	import delimited "/Users/annedijker/Desktop/DCE_final/Export_Qualtrics/ShapedSurveyData.csv", case(preserve) encoding(UTF-8) clear
	
*** 4. Check regression models for best model fit
		*AIC = Akaike Information Criterion
			*Estimator of prediction error
			*Has lower punishment for complexity and chooses more complex models than BIC
			*If prediction power is important for the model, than preference for a lower AIC over a lower BIC
		*BIC = Bayesian Information Criterion
			*Estimator of model fit
			*Has higher punishment for complexity and chooses less complex models than AIC
			*If simplicity is important for the model, than preference for a lower BIC over a lower AIC 
			
		*For this regression model, there is a preference for a lower AIC over a lower BIC
		
	*---------------------------------------------------*
	*	1. CONDITIONAL LOGIT (Full model)				*						
	*---------------------------------------------------*
	*Independence of Irrelevant Alternatives (IIA) assumption = does not account for unobserved heterogeneity across individuals (individual-specific preferences)
	*Assumes fixed coefficients across individuals
				
		*CLOGIT
		clogit Y ASC ICER_60 ICER_120 UNCERTAINTY_moderate UNCERTAINTY_severe AGE_adult AGE_elderly COST_20 COST_80 UMN_moderate UMN_low, group(group)
		
		*Create message indicating if clogit worked or not
		if _rc != 0 {											
			di "clogit failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
		
		*Store the estimated model parameters in a new dataset called 'conditional'
		estimate store conditional		
		
	*---------------------------------------------------*
	*	2. MIXED LOGIT (Full model)						*							
	*---------------------------------------------------*
	*Relaxation of IIA assumption = takes into account unobserved heterogeneity across individuals (individual-specific preferences)
	*Allows for random coefficients across individuals 
			
		*Create macro variable that includes the independent variables
		global xvar_full "ICER_60 ICER_120 UNCERTAINTY_moderate UNCERTAINTY_severe AGE_adult AGE_elderly COST_20 COST_80 UMN_moderate UMN_low"

		*MIXL
		mixlogit Y ASC, rand($xvar_full) group(group) id(id) nrep(1000) burn(19) cluster(id) 

		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic								
			
		*Store the estimated model parameters in a new dataset called 'full'
		estimate store full	
		
	*Check for future model
		*AIC and BIC
			*Mixed Logit models typically have more parameters than Conditional Logit models due to the inclusion of random coefficients
			*This can result in higher AIC and BIC values compared to Conditional Logit models, even if the Mixed Logit model fits the data better
				
		*ASC 
			*Since the DCE includes unlabelled alternatives, no prior preference for one of the two alternatives is assumed
			*Yet, there can still be preference for the left alternative in comparison to the right alternative (left-right bias), because the left one is the first you see.
			
			*P>0.05 = no left-right bias
			
			*A constant in an unlabelled DCE has no substantive meaning.
			*Yet, it does contribute to the reduction of the random component in terms of the model as it captures a small part of the unexplained variance. 
			*By omitting the ASC, you normalize the model to zero because the line must pass through the origin.
			*Hence, despite not being significant, ASC is included in the base model.
			
		*Linearity
			*Test linearity for continuous variables to see if variables need to be included as linear variables for the base model
			
			*H0 = the relationship between the two variables is linear
			*H1 = the relationship between the two variables is not linear
			*P>0.05 = we fail to reject H0 = linear
			 
			*Test linearity ICER		P>0.05 = linear 
				*20 - 60 = 40 units
				*20 - 120 = 100 units

				test ICER_60 = (40/100) * ICER_120

			*Test linearity COST		P>0.05 = linear
				*5 - 20 = 15 units
				*5 - 80 = 75 units
					
				test COST_20 = (15/75) * COST_80
			
			*Create linear terms for the linear variables
				*ICER_lin
				gen 		ICER_lin =0
				recode		ICER_lin (0=60) if ICER_60 ==1
				recode		ICER_lin (0=120) if ICER_120 ==1
				
				*COST_lin
				gen 		COST_lin =0
				recode		COST_lin (0=20) if COST_20 ==1
				recode		COST_lin (0=80) if COST_80 ==1		
			
			*ICER_lin and COST_lin are included in next model
			
	*---------------------------------------------------*
	*	3. MIXED LOGIT (Base model + linear)			*						
	*---------------------------------------------------*
	
		*Create macro variable that includes the independent variables
		global xvar_base_lin "ICER_lin UNCERTAINTY_moderate UNCERTAINTY_severe AGE_adult AGE_elderly COST_lin UMN_moderate UMN_low"
		
		*MIXL Linear
		mixlogit Y ASC, rand($xvar_base_lin) group(group) id(id) nrep(1000) burn(19) cluster(id) 
			
		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
			
		*Store the estimated model parameters in a new dataset called 'base_lin'
		estimate store base_lin
	
	*Check for future model			
		*Linearity
			*In model 2 (Full model) the ICER and COST variables showed significant in SD, meaning there is heterogeneity across individuals.
			*Yet, when including COST as linear variable, the variable shows not significant at all in SD, meaning there is no heterogeneity across individuals.
			*To what extent is there really such a linear relationship? And are the differences in preferences not flattened by including it as a linear variable?
			*Therefore, the COST variable was included as a dummy variable in the future models. 
			*The ICER variable was included as a linear variable.
						
	*---------------------------------------------------*
	*	4. MIXED LOGIT (Base model)						*						
	*---------------------------------------------------*
	
		*Create macro variable that includes the independent variables
		global xvar_base "ICER_lin UNCERTAINTY_moderate UNCERTAINTY_severe AGE_adult AGE_elderly COST_20 COST_80 UMN_moderate UMN_low"
		
		*MIXL Linear
		mixlogit Y ASC, rand($xvar_base) group(group) id(id) nrep(1000) burn(19) cluster(id) 
			
		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
			
		*Store the estimated model parameters in a new dataset called 'base'
		estimate store base		
	
	*Check for future model
		*SD
			*Significant
				*The deviation from the population mean is significant = there are random differences within the population with regards to preferences = heterogeneity across individuals
				*Variable is included as random variable
			*Not significant
				*The deviation from the population mean is not significant = there are no random differences within the population with regards to preferences
				*Variable is included as fixed variable
				
			*Highest p-value will be included as fixed variable first = UMN
			*Include both levels of one attribute as a fixed variable, one attribute by one, and see how model fit changes (AIC and BIC)

	*---------------------------------------------------*
	*	5. MIXED LOGIT (UMN fixed) 						*						
	*---------------------------------------------------*
	
		*Create macro variable that includes the independent variables
		global xvar_UMN_fix "ICER_lin UNCERTAINTY_moderate UNCERTAINTY_severe AGE_adult AGE_elderly COST_20 COST_80"
		
		*MIXL Linear
		mixlogit Y ASC UMN_moderate UMN_low, rand($xvar_UMN_fix) group(group) id(id) nrep(1000) burn(19) cluster(id) 
		
		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
		
		*Store the estimated model parameters in a new dataset called 'base_UMN_fix'
		estimate store base_UMN_fix		

	*---------------------------------------------------*
	*	6. MIXED LOGIT (AGE fixed)						*						
	*---------------------------------------------------*
	
		*Create macro variable that includes the independent variables
		global xvar_AGE_fix "ICER_lin UNCERTAINTY_moderate UNCERTAINTY_severe COST_20 COST_80 UMN_moderate UMN_low"
		
		*MIXL Linear
		mixlogit Y ASC AGE_adult AGE_elderly, rand($xvar_AGE_fix) group(group) id(id) nrep(1000) burn(19) cluster(id) 
		
		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
		
		*Store the estimated model parameters in a new dataset called 'base_AGE_fix'
		estimate store base_AGE_fix
		
	*---------------------------------------------------*
	*	7. MIXED LOGIT (UNCERTAINTY fixed)				*						
	*---------------------------------------------------*
	
		*Create macro variable that includes the independent variables
		global xvar_UNCERTAINTY_fix "ICER_lin AGE_adult AGE_elderly COST_20 COST_80 UMN_moderate UMN_low"
		
		*MIXL Linear
		mixlogit Y ASC UNCERTAINTY_moderate UNCERTAINTY_severe, rand($xvar_UNCERTAINTY_fix) group(group) id(id) nrep(1000) burn(19) cluster(id) 
		
		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
		
		*Store the estimated model parameters in a new dataset called 'base_UNCERTAINTY_fix'
		estimate store base_UNCERTAINTY_fix
	
	*Check for future model
		*Compare Model 4 (Base model), Model 5 (UMN fixed), Model 6 (AGE fixed) and Model 7 (UNCERTAINTY fixed)
		*Continue with model with the lowest AIC

	*---------------------------------------------------*
	*	8. MIXED LOGIT (UMN + UNCERTAINTY fixed)		*						
	*---------------------------------------------------*
	
		*Create macro variable that includes the independent variables
		global xvar_UMN_UNCERTAINTY_fix "ICER_lin AGE_adult AGE_elderly COST_20 COST_80"
		
		*MIXL Linear
		mixlogit Y ASC UMN_moderate UMN_low UNCERTAINTY_moderate UNCERTAINTY_severe, rand($xvar_UMN_UNCERTAINTY_fix) group(group) id(id) nrep(1000) burn(19) cluster(id) 
		
		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
		
		*Store the estimated model parameters in a new dataset called 'base_UMN_UNCERTAINTY_fix'
		estimate store base_UMN_UNCERTAINTY_fix
		
	*Check for future model
		*Compare Model 5 (UMN fixed) with Model 8 (UMN + UNCERTAINTY fixed)
		*Continue with model with the lowest AIC
	
	*---------------------------------------------------*
	*	9. MIXED LOGIT (UMN + UNCERTAINTY + AGE fixed)	*						
	*---------------------------------------------------*
	
		*Create macro variable that includes the independent variables
		global xvar_three_fix "ICER_lin COST_20 COST_80"
		
		*MIXL Linear
		mixlogit Y ASC UNCERTAINTY_moderate UNCERTAINTY_severe AGE_adult AGE_elderly UMN_moderate UMN_low, rand($xvar_three_fix) group(group) id(id) nrep(1000) burn(19) cluster(id) 
		
		*Create message indicating if MIXL worked or not
		if _rc != 0 {											
			di "mixl failed to converge or encountered an error."
			exit, clear
			}

		*Calculate the information criteria (AIC and BIC) for the model
		estat ic				
		
		*Store the estimated model parameters in a new dataset called 'base_three_fix'
		estimate store base_three_fix	

*** 5. Create a table for all stored datasets to compare for the best model fit
	*Table explanation
		* Y(1) = conditional logit (full model)
		* Y(2) = mixed logit (full model)
		* Y(3) = mixed logit (base model with 2 linear)
		* Y(4) = mixed logit (base model)
		* Y(5) = mixed logit (base model with fixed UMN)
		* Y(6) = mixed logit (base model with fixed AGE) 
		* Y(7) = mixed logit (base model with fixed UNCERTAINTY)
		* Y(8) = mixed logit (Base model with fixed AGE and UMN)
		* Y(9) = mixed logit (Base model with fixed AGE, UMN and UNCERTAINTY) --> BEST MODEL FIT
	
	*Create labels for table
	label var  ICER_60 "ICER: 60.000"
	label var  ICER_120 "ICER: 120.000"
	label var  UNCERTAINTY_moderate "Uncertainty: moderate"
	label var  UNCERTAINTY_severe "Uncertainty: high"
	label var  AGE_adult "Age: 18-64"
	label var  AGE_elderly "Age: 65+"
	label var  COST_20 "Cost: €20 million"
	label var  COST_80 "Cost: €80 million"
	label var  UMN_moderate "Unmet Medical Need: moderate"
	label var  UMN_low "Unmet Medical Need: low"
	label var  ICER_lin "ICER in €1.000" 
	label var  COST_lin "Cost in €1.000" 					

	*Change to other working directory (DCE_final/Output/Tables)
	cd "/Users/annedijker/Desktop/DCE_final/Output/Tables"	
		
	*Create table and store in file 'DCE_output_all.rtf'
		*wide = one row per variable
		*p p2 = 2 decimals for every value
		*star = p-values format
		*label compress = compress variable lable for concise table
		*nogaps = remove any gaps between rows
		*b(2) p(2) = format of coefficients and standard errors, both set to 2 decimals 

	esttab conditional full base_lin base base_UMN_fix base_AGE_fix base_UNCERTAINTY_fix base_UMN_UNCERTAINTY_fix base_three_fix using DCE_output_all.rtf, replace wide aic bic scalars(ll) p star(* 0.1 ** 0.05 *** 0.01) label compress nogaps b(3) p(3) 
		
	*Change to previous working directory (DCE_final/Output/Logfiles/MIXL.log)
	cd "../"	
	
*** 6. Save and exit 
	capture log close

	exit
