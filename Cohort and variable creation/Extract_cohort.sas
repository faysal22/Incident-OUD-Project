
/*	--------------------------------------------------------------------------
	[Objective] Extract Cohort from One FL data (2017-2019)
	--------------------------------------------------------------------------	*/
/*	--------------------------------------------------------------------------
	Setup
	- Setup Library
	- Import useful Macro
	- Import NDC/RXCUI
	--------------------------------------------------------------------------	*/

/*	Setup Library	--------------------------------------------------------------------------*/
	%put Notice: Start of the program. %sysfunc(date(),date9.) %sysfunc(time(),time.);

	libname FL 		"/data/Project/IRB202101897-DEMONSTRATE/rawdata/ONE FL - 2023-02-16";
	libname TEMP 	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/Dataset4";
	libname OUT 	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/Output4";
	
/*	Useful Macro	--------------------------------------------------------------------------*/
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/utilities.sas";
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/macros.sas";
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/Elxihauser Format.sas";
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/format_OneFL.sas";

/*	Import NDC/RXCUI	--------------------------------------------------------------------------*/
	
	proc import out=RXCUI_OPIOID_NONIVOUD datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Opioids.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final_OPIOIDS_NONIVOUD"; run;
	proc import out=RXCUI_OPIOID_IV datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Opioids.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final_OPIOIDS_IV"; run;
	proc import out=RXCUI_BUPRENORPHINE_OUD datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Opioids.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final_BUP_OUD"; run;
	proc import out=RXCUI_OPIOIDS_ANTITUSSIVES datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Opioids.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final_ANTITUSSIVE"; run; 

	%undupSortNew(RXCUI_OPIOID_NONIVOUD,			RXCUI_OPIOID_NONIVOUD,		RXCUI);
	%undupSortNew(RXCUI_OPIOID_IV,					RXCUI_OPIOID_IV,			RXCUI);
	%undupSortNew(RXCUI_BUPRENORPHINE_OUD,			RXCUI_BUPRENORPHINE_OUD,	RXCUI);
	%undupSortNew(RXCUI_OPIOIDS_ANTITUSSIVES,		RXCUI_OPIOIDS_ANTITUSSIVES,	RXCUI);

	proc import out=RXCUI_ANTIDEPRESSANTS datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Antidepressants.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final"; run;
	proc import out=RXCUI_BZD datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Benzodiazepines.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final"; run;
	proc import out=RXCUI_GABAPENTINOIDS datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Gabapentinoids.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final"; run;
	proc import out=RXCUI_MUSCLE_RELAXANT datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Muscle Relaxants.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final"; run;
	proc import out=RXCUI_NALOXONE datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Naloxone.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final"; run;
	proc import out=RXCUI_NALTREXONE datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/RXCUI_NDC_202208/RXCUI_Naltrexone.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Final"; run;

	%undupSortNew(RXCUI_ANTIDEPRESSANTS,			RXCUI_ANTIDEPRESSANTS,		RXCUI);
	%undupSortNew(RXCUI_BZD,						RXCUI_BZD,					RXCUI);
	%undupSortNew(RXCUI_GABAPENTINOIDS,				RXCUI_GABAPENTINOIDS,		RXCUI);
	%undupSortNew(RXCUI_MUSCLE_RELAXANT,			RXCUI_MUSCLE_RELAXANT,		RXCUI);
	%undupSortNew(RXCUI_NALOXONE,					RXCUI_NALOXONE,				RXCUI);
	%undupSortNew(RXCUI_NALTREXONE,					RXCUI_NALTREXONE,			RXCUI);
	
	data RXCUI_ALL;
	set	RXCUI_OPIOID_NONIVOUD			(in=nonivoud	keep=RXCUI DEA: LA_SA MME_CONVERSION_FACTOR STRENGTH_PER_UNIT MASTER_FORM DRUG ABUSE_DETERRENT RENAME=(LA_SA=SA_LA MASTER_FORM=DOSAGE_FORM))
		RXCUI_BZD						(in=bzd			keep=RXCUI)
		RXCUI_opioids_antitussives		(in=antitussive keep=RXCUI)
		RXCUI_naloxone					(in=naloxone	keep=RXCUI)
		RXCUI_naltrexone				(in=naltrexone	keep=RXCUI)
		RXCUI_buprenorphine_oud			(in=bupre		keep=RXCUI)
		RXCUI_gabapentinoids			(in=gabapen		keep=RXCUI)
		RXCUI_antidepressants			(in=antidepress keep=RXCUI)
		RXCUI_muscle_relaxant			(in=musclerelax	keep=RXCUI)
		RXCUI_OPIOID_IV					(in=iv			keep=RXCUI)
		;
	length RXCUI_SOURCE $ 12; 
	if nonivoud 	then RXCUI_SOURCE = 'NONIVOUD';
	if bzd 			then RXCUI_SOURCE = 'BZD';
	if antitussive 	then RXCUI_SOURCE = 'OUD';
	if naloxone 	then RXCUI_SOURCE = 'NALOXONE';
	if naltrexone 	then RXCUI_SOURCE = 'NALTREXONE';
	if bupre 		then RXCUI_SOURCE = 'BUPRE';
	if gabapen 		then RXCUI_SOURCE = 'GABAPEN';
	if antidepress 	then RXCUI_SOURCE = 'ANTIDEPRESS';
	if musclerelax 	then RXCUI_SOURCE = 'MUSCLERELAX';
	if iv		 	then RXCUI_SOURCE = 'IV';
	run;
	data temp.RXCUI_ALL(drop=RXCUI_);
	length RXCUI $7;
	set RXCUI_ALL(rename=(RXCUI=RXCUI_));
	if ^missing(RXCUI_);
	if length(RXCUI_)<7 then RXCUI=cats(repeat('0',7-length(RXCUI_)-1),RXCUI_);
	else RXCUI=RXCUI_;
	run;
	%undupSortNew(temp.RXCUI_ALL,temp.RXCUI_ALL,RXCUI);
	%nrows(temp.RXCUI_ALL);
	%distinctid(temp.RXCUI_ALL,RXCUI); /* Number of distinct RXCUI: 1403 */

/*	Total bene in OneFL: 2,115,218 > 4,939,327*/
	%distinctid(FL.EMR_DEMOGRAPHIC,ID);/*2,115,218 > 4,939,327*/

/*	------------------------------------------------------------------------------------------
	Prepare data (Extract cohort from 2017-2022, plus 1yr lookback. so need data from 2016-2022)

	- For encounters, consider the records with same patient ID, admit date or date of service, provider ID, and ENC_TYPE as one visit. 
	- Similarly, a DX or PX that occurred for the same patient ID, admit date, provider ID, and ENC_TYPE can be counted as one occurrence.
	- For Outcome use both Claims and EHR
	- For Variables use EHR only where=(SOURCE not in ('CHP','FLM'))
	------------------------------------------------------------------------------------------*/
    /*previous run*/
	/*
	data temp.DEMO (keep= ID BIRTH_DATE SEX RACE SOURCE);
    format SEX $SEX. RACE RACE.;
    set FL.EMR_DEMOGRAPHIC(rename=(RACE=RACE_CHAR));
	/*if SEX="M" then GENDER=1;
	else if SEX="F" then GENDER=2;
	else GENDER=0;*/
	/*if RACE_CHAR="05" then RACE=1;
	else if RACE_CHAR="03" then RACE=2;
	/* else if HISPANIC="Y" then RACE=3;*/
	/*else RACE=3;
	/*if HISPANIC="N" then ETHNIC=1;
	else if HISPANIC="Y" then ETHNIC=2; 
	else ETHNIC=0; */
	/*run;
	*/

	/*new run*/
	data temp.DEMO (keep= ID BIRTH_DATE GENDER RACE ETHNIC SOURCE);
    format SEX $SEX.;
    set FL.EMR_DEMOGRAPHIC;
	if SEX="M" then GENDER=1;
	else if SEX="F" then GENDER=2;
	else GENDER=0;
	/*else if HISPANIC="Y" then RACE=3;*/
	if HISPANIC="N" then ETHNIC=1;
	else if HISPANIC="Y" then ETHNIC=2; 
	else ETHNIC=0;
	run;

	data temp.demo;
	set temp.demo;
	if race=05 then RACE=1;
	else if race=03 then RACE=2;
	else RACE=3;
	run;

	proc sql;
	create table temp.DX_16to19 as
	select distinct a.ID, a.ENCOUNTERID, a.ADMIT_DATE, b.DISCHARGE_DATE, a.PDX, compress(a.DX,".") as DX, b.ENC_TYPE, a.SOURCE
	from FL.EMR_DX (where=('31Dec2015'd<ADMIT_DATE<'01Jan2023'd)) as a
	left join FL.EMR_ENC(keep=ENCOUNTERID DISCHARGE_DATE ENC_TYPE) as b on a.ENCOUNTERID=B.ENCOUNTERID
	order by ID, ADMIT_DATE, PDX, DX 
	;
	quit;

	proc sort data=FL.EMR_PX (keep=ID ADMIT_DATE PX_DATE PX PX_TYPE PROVIDERID source
	where=(PX_TYPE='CH' & '31Dec2015'd<ADMIT_DATE<'01Jan2023'd & SOURCE not in ('CHP','FLM'))) nodupkey 
	out=temp.PX_HCPCS_16to19;
	by ID ADMIT_DATE PX_DATE PX PROVIDERID ;
	run;


	proc sort data=FL.EMR_RX (keep=ENCOUNTERID ID RXNORM_CUI RX_BASIS RX_DAYS_SUPPLY RX_DOSE_ORDERED RX_FREQUENCY RX_ORDER_DATE RX_PROVIDERID RX_QUANTITY RX_REFILLS SOURCE RX_BASIS RX_START_DATE RX_END_DATE RX_ORDER_DATE
 	where=(RXNORM_CUI^=''& '31Dec2015'd<RX_ORDER_DATE<'01Jan2023'd )) nodupkey 
	out=temp.RX_16to19 (RENAME=(RXNORM_CUI=RXCUI RX_ORDER_DATE=DATE RX_DAYS_SUPPLY=SUPPLY RX_QUANTITY=QUANTITY RX_REFILLS=REFILLS RX_DOSE_ORDERED=DOSE RX_FREQUENCY=FREQUENCY));
	by ID RX_ORDER_DATE RXNORM_CUI DESCENDING RX_QUANTITY DESCENDING RX_DAYS_SUPPLY DESCENDING RX_REFILLS RX_PROVIDERID;
	run;

	data TEMP.RX_16to19(drop=RXCUI_);
	length RXCUI $7;
	set TEMP.RX_16to19(rename=(RXCUI=RXCUI_));
	RXCUI=cats(repeat('0',7-length(RXCUI_)-1),RXCUI_);
	run;

	%undupSortNew(TEMP.RX_16to19,,RXCUI);
	%undupSortNew(TEMP.RXCUI_all,,RXCUI);

	data RX_merge_RXCUI;
	merge	TEMP.RX_16to19					(in=a)
			TEMP.RXCUI_all					(in=b)
			;
	by RXCUI;
	if a & b;
	run;

	proc sql;
	create table temp.RX_MERGE_RXCUI as 
	select a.*, b.ENC_TYPE, (case when b.ENC_TYPE in ('IP', 'EI') then 'IP' when b.ENC_TYPE='ED' then 'ED' when b.ENC_TYPE in ('AV', 'OA') then 'OP' else 'OT' end) as IP_OP
	from rx_merge_rxcui as a 
	left join FL.emr_enc (keep=ENCOUNTERID ENC_TYPE) as b on a.ENCOUNTERID=b.ENCOUNTERID
	;
	quit;

	%procfreq(temp.RX_merge_RXCUI,RXCUI_SOURCE*IP_OP/ norow nocum nocol nopercent);
 
	/* Its old */

	/*				ED		IP		OP		OT		Total*/
	/*ANTIDEPRESS	33710	242193	535482	167868	979253*/
	/*				3.44	24.73	54.68	17.14	*/
	/*BUPRE			705		6203	3708	423		11039*/
	/*				6.39	56.19	33.59	3.83	*/
	/*BZD			70457	290552	343148	89898	794055*/
	/*				8.87	36.59	43.21	11.32	*/
	/*GABAPEN		23455	170554	225843	70199	490051*/
	/*				4.79	34.8	46.09	14.32	*/
	/*IV			73305	674694	570271	93746	1412016*/
	/*				5.19	47.78	40.39	6.64	*/
	/*MUSCLERELAX	85761	102991	203720	61846	454318*/
	/*				18.88	22.67	44.84	13.61	*/
	/*NALOXONE		1726	23974	18232	2390	46322*/
	/*				3.73	51.76	39.36	5.16	*/
	/*NALTREXONE	128		1320	4533	891		6872*/
	/*				1.86	19.21	65.96	12.97	*/
	/*NONIVOUD		349013	909839	937166	211466	2407484*/
	/*				14.5	37.79	38.93	8.78	*/
	/*OUD			6755	5624	22528	2605	37512*/
	/*				18.01	14.99	60.06	6.94	*/
	/*Total			645015	2427944	2864631	701332	6638922*/

/*	-----------------------------------------------------------------------------------------------------------------------------  
	Determine study cohort
	-----------------------------------------------------------------------------------------------------------------------------	*/

	/* Identify Comorbidity -----------------------------------------------------------------------------------------------------	*/

	%macro identifyComorbidity(dsin, dsout);

	/*Load Outcome*/

	proc import out=ds_outcome datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/DEMONSTRATE_Data Dictionary.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Overdose Outcome";
	run;
	data ds_outcome;	set ds_outcome; if ICD9_SAS^='' | ICD10_SAS^=''; run;
	proc sql noprint; Select distinct(VARIABLE) into :varList_outcome separated by ' ' from ds_outcome; quit;
	%put &varList_outcome.;
	%do k=1 %to %sysfunc(countw(&varList_outcome,' '));
       	%let varTemp = %scan(&varList_outcome, &k,' ');
		%put &k &varTemp;
		data tempList (drop=VARIABLE); retain ID; set ds_outcome (keep=ICD9_SAS ICD10_SAS VARIABLE where=(VARIABLE="&varTemp.")); ID=_n_; run;
		proc transpose data=tempList out=list_OUTCOME_&varTemp.; by ID; var ICD9_SAS ICD10_SAS; run;
		%undupsortNew(list_OUTCOME_&varTemp.(keep=COL1 where=(COL1^='')),list_OUTCOME_&varTemp.,COL1);
		proc sql noprint; Select "'"||compress(compress(COL1,'00090A0DA0'x))||"'" into :str_OUTCOME_&varTemp. separated by ' ' from list_OUTCOME_&varTemp.; quit;
		%put &k &varTemp &&str_OUTCOME_&varTemp..;
	%end;

	/*Load covariates*/
	proc import out=ds_COV datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/DEMONSTRATE_Data Dictionary.xlsx' dbms=xlsx replace;	getnames=yes;
	sheet="Predictors";
	run;
	data ds_COV;	set ds_COV; if ICD9_SAS^='' | ICD10_SAS^=''; run;
	proc sql noprint; Select distinct(VARIABLE) into :varList_COV separated by ' ' from ds_COV;quit;
	%do k=1 %to %sysfunc(countw(&varList_COV,' '));
       	%let varTemp = %scan(&varList_COV, &k,' ');
		%put &k &varTemp;
		data tempList (drop=VARIABLE); retain ID; set ds_COV (keep=ICD9_SAS ICD10_SAS VARIABLE where=(VARIABLE="&varTemp.")); ID=_n_; run;
		proc transpose data=tempList out=list_COV_&varTemp.; by ID; var ICD9_SAS ICD10_SAS; run;
		%undupsortNew(list_COV_&varTemp.(keep=COL1 where=(COL1^='')),list_COV_&varTemp.,COL1);
		proc sql noprint; Select "'"||compress(compress(COL1,'00090A0DA0'x))||"'" into :str_COV_&varTemp. separated by ' ' from list_COV_&varTemp.; quit;
		%put &k &varTemp &&str_COV_&varTemp..;
   	%end;
	data &dsout.(drop= A1--A30 J DXVALUE: ELIX_HTN ELIX_HTNCX );
	set	&dsin.	;
		%do k=1 %to %sysfunc(countw(&varList_outcome,' '));
	       	%let dxTemp = %scan(&varList_outcome, &k,' ');
			length OUTCOME_&dxtemp. 3.;
			OUTCOME_&dxtemp. = 0;
		%end;
		%do k=1 %to %sysfunc(countw(&varList_cov,' '));
	       	%let dxTemp = %scan(&varList_cov, &k,' ');
			length DX_&dxtemp. 3.;
			DX_&dxtemp. = 0;
		%end;

		ARRAY COM1 (30)	ELIX_CHF      ELIX_VALVE    ELIX_PULMCIRC ELIX_PERIVASC
		                ELIX_HTN      ELIX_HTNCX    ELIX_PARA     ELIX_NEURO    ELIX_CHRNLUNG
		                ELIX_DM       ELIX_DMCX     ELIX_HYPOTHY  ELIX_RENLFAIL ELIX_LIVER
		                ELIX_ULCER    ELIX_AIDS     ELIX_LYMPH    ELIX_METS     ELIX_TUMOR
		                ELIX_ARTH     ELIX_COAG     ELIX_OBESE    ELIX_WGHTLOSS ELIX_LYTES
		                ELIX_BLDLOSS  ELIX_ANEMDEF  ELIX_ALCOHOL  ELIX_DRUG     ELIX_PSYCH
		                ELIX_DEPRESS ;
		ARRAY COM2 (30) $ 8 A1-A30
		                ("CHF"     "VALVE"   "PULMCIRC" "PERIVASC"
		                 "HTN"     "HTNCX"   "PARA"     "NEURO"     "CHRNLUNG"
		                 "DM"      "DMCX"    "HYPOTHY"  "RENLFAIL"  "LIVER"
		                 "ULCER"   "AIDS"    "LYMPH"    "METS"      "TUMOR"
		                 "ARTH"    "COAG"    "OBESE"    "WGHTLOSS"  "LYTES"
		                 "BLDLOSS" "ANEMDEF" "ALCOHOL"  "DRUG"      "PSYCH"
		                 "DEPRESS") ;
		LENGTH			ELIX_CHF      ELIX_VALVE    ELIX_PULMCIRC ELIX_PERIVASC
		                ELIX_HTN      ELIX_HTNCX    ELIX_PARA     ELIX_NEURO    ELIX_CHRNLUNG
		                ELIX_DM       ELIX_DMCX     ELIX_HYPOTHY  ELIX_RENLFAIL ELIX_LIVER
		                ELIX_ULCER    ELIX_AIDS     ELIX_LYMPH    ELIX_METS     ELIX_TUMOR
		                ELIX_ARTH     ELIX_COAG     ELIX_OBESE    ELIX_WGHTLOSS ELIX_LYTES
		                ELIX_BLDLOSS  ELIX_ANEMDEF  ELIX_ALCOHOL  ELIX_DRUG     ELIX_PSYCH
		                ELIX_DEPRESS 3 ;


		do J = 1 to 30;	COM1(J) = 0;	end;

			%do lenTemp = 3 %to 7;
				if length(DX)>= &lentemp. then do;
					%do k=1 %to %sysfunc(countw(&varList_outcome,' '));
				       	%let dxTemp = %scan(&varList_outcome, &k,' ');
						if substr(DX,1,&lentemp.) in (&&str_outcome_&dxTemp.) then OUTCOME_&dxtemp.=1;
				   	%end;
					%do k=1 %to %sysfunc(countw(&varList_cov,' '));
				       	%let dxTemp = %scan(&varList_cov, &k,' ');
						if substr(DX,1,&lentemp.) in (&&str_cov_&dxTemp.) then DX_&dxtemp.=1;
				   	%end;
				end;

	        	DXVALUE1 = PUT(DX,$RCOMFMT.);
	        	DXVALUE2 = PUT(DX,$RCOMFMT_new.);
				DXVALUE	= coalescec(DXVALUE1,DXVALUE2);
	         	if DXVALUE NE " " then do;
	            	do J = 1 to 30;
	               		if DXVALUE = COM2(J)  then COM1(J) = 1;
	            	end;

					if DXVALUE in ("HTNPREG","HTNWOCHF","HTNWCHF","HRENWORF","HRENWRF","HRENWORF","HHRWCHF","HHRWRF","HHRWHRF","OHTNPREG") then ELIX_HTNCX = 1;
					if DXVALUE in ("HTNWCHF","HHRWCHF","HHRWHRF") then ELIX_CHF = 1;
					if DXVALUE in ("HRENWRF","HHRWRF","HHRWHRF") then ELIX_RENLFAIL = 1;
				end;
			%end;
		if ELIX_HTNCX = 1 then ELIX_HTN = 0 ;
		if ELIX_METS = 1 then ELIX_TUMOR = 0 ;
		if ELIX_DMCX = 1 then ELIX_DM = 0 ;
		attrib ELIX_HTN_C length=3 label='Hypertension';

		if ELIX_HTN=1 | ELIX_HTNCX=1 then ELIX_HTN_C=1; else ELIX_HTN_C=0;

		label 	OUTCOME_OPI_OVD		= 'Opioid overdose'
				OUTCOME_OPI_ADR 	= 'Opioid-Related Adverse Events'
				OUTCOME_BZD_OVD 	= 'BZD overdose'
				OUTCOME_OTHER_OVD 	= 'Other drug overdose'
				OUTCOME_HEROIN_OVD 	= 'Heroin overdose'
				OUTCOME_SUD 		= 'Other SUD'
				ELIX_CHF        	= 'Congestive heart failure'
				ELIX_VALVE      	= 'Valvular disease'
				ELIX_PULMCIRC   	= 'Pulmonary circulation disease'
				ELIX_PERIVASC   	= 'Peripheral vascular disease'
				ELIX_PARA       	= 'Paralysis'
				ELIX_NEURO     	 	= 'Other neurological disorders'
				ELIX_CHRNLUNG   	= 'Chronic pulmonary disease'
				ELIX_DM         	= 'Diabetes w/o chronic complications'
				ELIX_DMCX      		= 'Diabetes w/ chronic complications'
				ELIX_HYPOTHY   		= 'Hypothyroidism'
				ELIX_RENLFAIL   	= 'Renal failure'
				ELIX_LIVER      	= 'Liver disease'
				ELIX_ULCER     	 	= 'Peptic ulcer Disease x bleeding'
				ELIX_AIDS     	  	= 'Acquired immune deficiency syndrome'
				ELIX_LYMPH    	  	= 'Lymphoma'
				ELIX_METS     	  	= 'Metastatic cancer'
				ELIX_TUMOR    	  	= 'Solid tumor w/out metastasis'
				ELIX_ARTH     	  	= 'Rheumatoid arthritis/collagen vas'
				ELIX_COAG     	  	= 'Coagulopthy'
				ELIX_OBESE    	  	= 'Obesity'
				ELIX_WGHTLOSS 	  	= 'Weight loss'
				ELIX_LYTES     	 	= 'Fluid and electrolyte disorders'
				ELIX_BLDLOSS   	 	= 'Chronic blood loss anemia'
				ELIX_ANEMDEF   	 	= 'Deficiency Anemias'
				ELIX_ALCOHOL    	= 'Alcohol abuse'
				ELIX_DRUG      	 	= 'Drug abuse'
				ELIX_PSYCH      	= 'Psychoses'
				ELIX_DEPRESS   	 	= 'Depression';
	run;
	%mend;
	%identifyComorbidity(temp.DX_16to19, TEMP.DX_comorb);
	data temp.DX_OUTCOME;
	set  temp.DX_COMORB;
	if sum (of OUTCOME_:)>0;/*for outcome creations, use both EHR & claims records*/
	run;
	data temp.DX_COMORB;
	set  temp.DX_COMORB;
	if SOURCE not in ('CHP','FLM'); /*for variable creations, only use EHR records*/
	if sum (of DX_:)>0 | sum (of ELIX_:)>0;
	run;
	

	%macro getHCPCS_diseases(dsin, dsout);
	proc import out=covariateList datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/DEMONSTRATE_Data Dictionary.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Predictors";	run;
	data covariateList_ICD covariateList_HCPCS; set covariateList; if CPT_HCPCS = '' then output covariateList_ICD; else output covariateList_HCPCS; run;
	proc sql noprint; Select distinct(upcase(VARIABLE)) into :dxList_HCPCS separated by ' ' from covariateList_HCPCS;
	%put &dxList_HCPCS.;
	%do k=1 %to %sysfunc(countw(&dxList_HCPCS,' '));
		%let dxTemp = %scan(&dxList_HCPCS, &k,' ');
		data HCPCSList_&dxtemp.(keep=CPT_HCPCS); set covariateList_HCPCS (where=(upcase(VARIABLE)="&dxtemp.")); run;
		%undupsortNew(HCPCSList_&dxtemp.,HCPCSList_&dxtemp.,CPT_HCPCS);
		proc sql noprint; Select "'"||compress(compress(CPT_HCPCS,'00090A0DA0'x))||"'" into :HCPCSList_&dxtemp._STR separated by ' ' from HCPCSList_&dxtemp.;
	%end;

	data &dsout.;
	set	&dsin.;
	if length(PX)>= 5 then do;
		%do k=1 %to %sysfunc(countw(&dxList_HCPCS,' '));
	       	%let dxTemp = %scan(&dxList_HCPCS, &k,' ');
			PX_&dxtemp.=0;
			if substr(PX,1,5) in (&&HCPCSList_&dxtemp._STR) then PX_&dxtemp.=1;
	   	%end;
	end;
	if sum(of PX_:)>0;
	run;
	%mend;
	%getHCPCS_diseases(TEMP.PX_HCPCS_16to19(drop=PROVIDERID PX_TYPE rename=(PX_DATE=DATE) where=(SOURCE not in ('CHP','FLM'))),temp.px_comorb);

	/*	Had 1+ EHR encounter during 2017-2022 	--------------------------------------------------------------------------	*/
	proc sql;
	create table EHR_ENC_17to19 as
	select 		distinct a.ID, a.ADMIT_DATE, 
				floor((intck("month", b.birth_date, a.ADMIT_DATE)-(day(a.ADMIT_DATE)<day(b.birth_date)))/12) as AGE_ENC
	from		FL.EMR_ENC	(keep=ID ADMIT_DATE SOURCE) as a
	left join 	FL.EMR_Demographic as b on a.ID=b.ID
	where 		'31Dec2016'd < a.ADMIT_DATE<='31Dec2022'd and a.SOURCE not in ('CHP','FLM')& calculated AGE_ENC>=18
	;
	quit;
	%nrows(EHR_ENC_17to19)*18112897 > 43603925;
	%distinctid(EHR_ENC_17to19,ID)*1417710 > 2473412;
	%procfreq(EHR_ENC_17to19,AGE_ENC);

	proc sql;
	create table temp.EHR_ENC_17to19 as
	select 		ID, min(ADMIT_DATE) as min_ADMIT_DT format=DATE9., count(*) as N_ENC, AGE_ENC
	from		EHR_ENC_17to19
	group by 	ID
	having 		ADMIT_DATE=min(ADMIT_DATE)
	order by 	ID
	;
	quit;
	%nrows(temp.EHR_ENC_17to19)* 1,417,710 > 2,473,412;
	%distinctid(temp.EHR_ENC_17to19,ID)* 1,417,710 > 2,473,412;

	/*	Index date 2017-2022	--------------------------------------------------------------------------	*/

	data RX_MERGE_RXCUI_OP_17_19;
	set temp.RX_merge_RXCUI	(keep=ID encounterid DATE IP_OP  RXCUI_SOURCE SOURCE);
	if SOURCE not in ('CHP','FLM') & IP_OP="OP" & RXCUI_SOURCE='NONIVOUD' & '31Dec2016'd < DATE<='31Dec2022'd;
	run;

	proc sql;
	create table indexDate as
	select 		a.*, b.*
	from		RX_MERGE_RXCUI_OP_17_19 as a
	inner join 	temp.EHR_ENC_17to19 as b on a.ID=b.ID
	where 		a.date>=b.min_ADMIT_DT
	order by 	a.ID,a.date 
	;
	quit;
	proc sql;
	create table indexDate1 as
	select 		distinct ID, min_ADMIT_DT, N_ENC, AGE_ENC, min(DATE) as INDEX_DATE format=DATE9.
	from		indexDate
	group by 	ID
	order by 	ID
	;
	quit;
	proc sql;
	create table temp.indexDate as
	select a.*, b.birth_date, 
	floor((intck("month", b.birth_date, a.INDEX_DATE)-(day(a.INDEX_DATE)<day(b.birth_date)))/12) as AGE, 
	(case when calculated age>64 then 1 else 0 end) as AGE_OVER_65,
	(case when calculated age<18 then 1 when calculated age>64 then 3 else 2 end) as AGEGRP 
	from indexDate1 as a
	left join FL.EMR_Demographic as b on a.ID=b.ID
	order by AGEGRP
	;
	quit;
	proc freq data=temp.indexDate; table AGEGRP; format AGEGRP AGEGRP.; run;

	

/*	Identify cancer diagnosis	---------------------------------------*/

	proc sql;
	create table temp.cancer as
	select distinct a.ID, 1 as cancer
	from temp.indexdate as a
	inner join temp.dx_comorb (where=(DX_CANCER=1)) as b on a.ID=b.id
	;
	quit;

/*	Identify Hospice	---------------------------------------*/
/*	FACILITY_TYPE: (NOT AVAILABLE)
	ADMITTING_SOURCE: HS=Hospice; 
	DISCHARGE_STATUS: HS=Hospice; 
	ENC_TYPE: IS=Non-Acute Institutional Stay ; 
	PAYER_TYPE_PRIMARY: 13 Medicare Hospice / 98 Other specified but not otherwise classifiable (include Hospice - Unspecified Plan)
	PAYER_TYPE_SECONDARY: 13 Medicare Hospice / 98 Other specified but not otherwise classifiable (include Hospice - Unspecified Plan)*/

	%procfreq(FL.EMR_ENC(keep=FACILITY_TYPE), FACILITY_TYPE:/missing);

	data temp.HOSPICE(keep=ID HOSPICE);
	set FL.EMR_ENC (keep=ID ADMITTING_SOURCE DISCHARGE_STATUS ENC_TYPE PAYER_TYPE_PRIMARY PAYER_TYPE_SECONDARY);
	if (ADMITTING_SOURCE='HS' or DISCHARGE_STATUS='HS' or ENC_TYPE='IS' or PAYER_TYPE_PRIMARY in ("13","98") or PAYER_TYPE_SECONDARY in ("13","98"));
	HOSPICE=1;
	run;
	%procsort(temp.HOSPICE,temp.HOSPICE nodup,ID);
	
	/* J */
	proc sort data=temp.HOSPICE nodupkey;
	by ID;
	run;

	proc sql;
	create table temp.DX_B4_IDX as
	select distinct ID, DX, DX_OPI_OUD, DX_SUD, 1 as DXOUD, 1 as DXSUD
	from temp.dx_comorb (where=(DX_OPI_OUD=1 | DX_SUD=1));
	quit;
	/* J */ 

	/*Medicaid enrollee (On index date)*/
	proc sql;
	create table temp.MDCAID_bene as
	select distinct a.ID, 1 as MDCAID
	from temp.indexdate as a
	inner join FL.emr_mth as b on a.id=b.id & year(a.INDEX_DATE)=b.year & month(a.INDEX_DATE)=b.month
	order by a.ID
	;
	quit;

/*	Identify dual eligible for Medicare on the index date	
	ENR_MTH	AIDCATG (Q/SL)
	MEMBER	MEDICAREINDICATOR
	MEMBER	STATASST(02)	*/

	proc sql;
    create table  temp.DUAL_DISABLED as
	select a.ID, b.YEAR, b.MONTH, (b.YEAR-2011)*12+b.MONTH as MTH_IDX,
	a.MEDICAREINDICATOR, a.STATASST, b.AIDCATG, (case when b.program='FFS' then 0 else 1 end) as MCO
	from	   FL.member  as a 
	left join  FL.eMr_mth as b on a.ID = b.ID 
	order by ID, calculated MTH_IDX
	;
	quit;

	%macro identifyaidcatg(dsin,dsout);
		data &dsout.;
		set &dsin. ;
		AID_DISABLED=0;
		AID_DUAL=0;
		%do i=1 %to %sysfunc(countw(&AIDCATG_DISABLED_STR,''));
			%let dxTemp=%scan(&AIDCATG_DISABLED_STR, &i,'');
			%put &dxTemp;
			if find(aidcatg,"&dxTemp")>0 then AID_DISABLED=1;
		%end;
		%do j=1 %to %sysfunc(countw(&AIDCATG_DUAL_STR,''));
			%let dxTemp=%scan(&AIDCATG_DUAL_STR, &j,'');
			%put &dxTemp;
			if find(aidcatg,"&dxTemp")>0 then AID_DUAL=1;
		%end;
		run;
	%mend;
	%identifyaidcatg(temp.DUAL_DISABLED, temp.DUAL_DISABLED);


	data temp.DUAL_DISABLED;
	set temp.DUAL_DISABLED;
	DISABLED=0; DUAL=0; ELIG_GP=4; 
	if AID_DISABLED=1 or STATASST="01" 							then DISABLED=1;
	if AID_DUAL=1	  or STATASST="02" or MEDICAREINDICATOR="Y" then DUAL=1;
	if DISABLED=1 then ELIG_GP=1;
	if DUAL=1 then ELIG_GP=2;
	run;

	proc sql;
	create table temp.DUAL_INDEX as
	select distinct a.*, b.DUAL
	from temp.indexdate as a
	inner join temp.DUAL_DISABLED as b on a.ID=b.ID & year(a.INDEX_DATE)=b.year & month(a.INDEX_DATE)=b.month
	order by a.ID
	;
	quit;
	%nrows(temp.DUAL_INDEX); 
	%procfreq(temp.DUAL_INDEX,DUAL);*29120 > 38579; 


/*	Identify Outcome	--------------------------------------------------------------------------------------------------
	- Definite Overdose
	- OUD
	AV=Ambulatory Visit
	ED=Emergency Department
	EI=Emergency Department Admit to Inpatient Hospital Stay (permissible substitution)
	IP=Inpatient Hospital Stay
	IS=Non-Acute Institutional Stay
	IC=Institutional Professional Consult (permissible substitution)
	OA=Other Ambulatory Visit
	OS=Observation Stay
	NI=No information
	OT=Other
	UN=Unknown

	Use definite overdose	
	Def:  		1. Inpatient visit with any opioid overdose dx / Outpatient visit with any opioid overdose dx "from ED"
		  		2. Opioid overdose at primary dx 
		  		3. Opioid overdose not at primary dx & other drug/substance overdose or disorder at primary dx
	Prob: 		1. Inpatient visit with any opioid overdose dx / Outpatient visit with any opioid overdose dx "from ED"
		  		2. Opioid overdose not at primary dx & other drug/substance overdose or disorder not at primary dx
		  		3. With opioid-related adverse events
	Uncertain: 	1. Inpatient visit with any opioid overdose dx / Outpatient visit with any opioid overdose dx "from ED"
		  		2. Opioid overdose not at primary dx & other drug/substance overdose or disorder not at primary dx
		  		3. Without opioid-related adverse events	*/
	%procfreq(temp.DX_COMORB,outcome_:);
/*	Select records in inpatient or emergency with overdose or OUD or opioid-related adverse event (to downsize the data.)*/
	proc sql;
	create table temp_OD as 
	select b.ID,  floor((b.ADMIT_DATE-a.INDEX_DATE)/91.25)+1 as CLAIM_PERIOD, b.ADMIT_DATE, b.DISCHARGE_DATE, b.ENCOUNTERID, b.DX, b.PDX, b.ENC_TYPE,
			b.OUTCOME_OPI_OVD, b.OUTCOME_OTHER_OVD, b.OUTCOME_SUD, b.OUTCOME_OPI_ADR
	from temp.INDEXDATE as a
	inner join temp.DX_OUTCOME as b on a.ID=b.ID
	where calculated CLAIM_PERIOD>=0 & ENC_TYPE in ("IP","EI","ED","AV","OT") & (b.OUTCOME_OPI_OVD | b.OUTCOME_OTHER_OVD | b.OUTCOME_SUD | b.OUTCOME_OPI_ADR)
	order by b.ID, b.PDX desc, b.DX
	;
	quit;
/*	Select encounters/visits with at least 1 overdose regardless of the position*/
	proc sql;
	create table temp_OD_ENC as 
	select *
	from temp_OD 
	where ENCOUNTERID in (select ENCOUNTERID from temp_OD (where=(OUTCOME_OPI_OVD=1)))
	;
	quit;
/*	Categorize the encounter/visit into definite, probable or uncertain overdose episode:*/
	proc sql;
		create table temp_OD_EPISODE as
		select *, min(case 
					when PDX="P" & OUTCOME_OPI_OVD=1 						then 1 
					when PDX="P" & (OUTCOME_OTHER_OVD=1 | OUTCOME_SUD=1) 	then 1 
					when OUTCOME_OPI_ADR=1 												then 2
					else  																     3
					end) as OD_epi
		from temp_OD_ENC
		group by ENCOUNTERID
		order by ID, ADMIT_DATE, ENCOUNTERID, PDX desc
		;
	quit;
	proc freq data=temp_OD_EPISODE; table OD_epi; format OD_epi OD_epi.; run; 
	%undupsortNew(temp_OD_EPISODE(keep=ID ADMIT_DATE ENCOUNTERID OD_epi), temp_OD_EPISODE_BYENC, ID ADMIT_DATE ENCOUNTERID OD_epi);

/*	Remove if the gap between episodes less than 7 days	*/	
	data temp_OD_EPISODE_BYENC;
	format LAG_DATE date9.;
	set temp_OD_EPISODE_BYENC;
	by ID;
	LAG_DATE=LAG(ADMIT_DATE);
	if first.ID then LAG_DATE=.; 
	DIFF=ADMIT_DATE-LAG_DATE;
	run;
	data temp_OD_EPISODE_BYENC;
	set temp_OD_EPISODE_BYENC;
	where DIFF=. or DIFF=0 or DIFF>7;
	run;
	proc sql;
	create table temp.OD_EPISODE_7dGAP as 
	select *, (case when OD_epi=1 then 1 else 0 end) as OVD_DEF
	from temp_OD_EPISODE
	where ENCOUNTERID in (select ENCOUNTERID from temp_OD_EPISODE_BYENC)
	;
	quit;
	proc freq data=temp.OD_EPISODE_7dGAP; tableS OD_epi OVD_DEF; format OD_epi OD_epi.; run; 
	
/*	OUD Outcome -------------------------------------------------------------------
	Including DX_OUD, BUP ORDER, DX_SUD, METH (Methadone) Procedures
	Also Opioid Overdose	
	*/
	/* J */
	data temp.OUD (keep=ID DATE OUD_SOURCE DX);
	length OUD_SOURCE $16;
	set temp.DX_COMORB		 	(in=DX_OUD_FLAG   	 	keep=ID ADMIT_DATE DX DX_OPI_OUD rename=(ADMIT_DATE=DATE) 		where=(DX_OPI_OUD=1))
	    temp.DX_COMORB		 	(in=DX_SUD_FLAG   	 	keep=ID ADMIT_DATE DX DX_SUD rename=(ADMIT_DATE=DATE) 		    where=(DX_SUD=1))
		temp.DX_COMORB		 	(in=DX_METHADONE_OD_FLAG   	 	keep=ID ADMIT_DATE DX DX_METHADONE_OD rename=(ADMIT_DATE=DATE) 		    where=(DX_METHADONE_OD=1))
		temp.DX_COMORB		 	(in=DX_HEROIN_OVD_FLAG   	 	keep=ID ADMIT_DATE DX DX_HEROIN_OVD rename=(ADMIT_DATE=DATE) 		    where=(DX_HEROIN_OVD=1))
		temp.DX_COMORB		 	(in=DX_OTHER_OPI_OD_FLAG   	 	keep=ID ADMIT_DATE DX DX_OTHER_OPI_OD rename=(ADMIT_DATE=DATE) 		    where=(DX_OTHER_OPI_OD=1))
		temp.DX_COMORB		 	(in=ELIX_DRUG_FLAG   	 	keep=ID ADMIT_DATE DX ELIX_DRUG rename=(ADMIT_DATE=DATE) 		    where=(ELIX_DRUG=1))
		temp.RX_MERGE_RXCUI 	(in=BUP_OUD_FLAG 	 	keep=ID DATE RXCUI_SOURCE 								 	where=(RXCUI_SOURCE='BUPRE'))
		temp.PX_COMORB 		 	(in=METH_OUD_FLAG  		keep=ID DATE PX_MAT_METHADONE								where=(PX_MAT_METHADONE=1))
		/*temp.OD_EPISODE_7dGAP	(in=OVERDOSE_DEF_FLAG 	keep=ID ADMIT_DATE OD_EPI rename=(ADMIT_DATE=DATE) 			where=(OD_EPI=1))*/;
	if DX_OUD_FLAG 		then OUD_SOURCE='DX_OUD';
    if DX_SUD_FLAG 		then OUD_SOURCE='DX_SUD';
	if BUP_OUD_FLAG 	then OUD_SOURCE='BUP_OUD';
	if METH_OUD_FLAG 	then OUD_SOURCE='METH_OUD';
	if DX_METHADONE_OD_FLAG 		then OUD_SOURCE='DX_METH_OD';
	if DX_HEROIN_OVD_FLAG 		then OUD_SOURCE='DX_HEROIN_OVD';
	if DX_OTHER_OPI_OD_FLAG 		then OUD_SOURCE='DX_OTHER_OPI_OD';
	if ELIX_DRUG_FLAG 		then OUD_SOURCE='ELIX_DRUG';
	/*if OVERDOSE_DEF_FLAG then OUD_SOURCE='OVERDOSE_DEF';*/
	run;
	%procfreq(temp.OUD,OUD_SOURCE);/* BUP_OUD 11039 DX_OUD 211676 DX_SUD 448560 METH_OUD 0 OVERDOSE_DEF 3042 
	                                  > BUP_OUD 19039 DX_OUD 332860 DX_SUD 769512 METH_OUD 19275 OVERDOSE_DEF 6910 > 7036*/
	%procsort(temp.OUD,,ID);
	%procsort(temp.INDEXDATE,,ID);

	data temp.OUD;
	merge 	temp.OUD 		(in=a)
			temp.INDEXDATE	(in=b);
	by ID;
	if a & b;
	CLAIM_PERIOD = floor((DATE-INDEX_DATE)/91.25)+1;
	run;
	%procfreq(temp.OUD,OUD_SOURCE);
	%undupsortNew(temp.OUD(keep=ID INDEX_DATE DATE OUD_SOURCE where=(DATE < INDEX_DATE)), temp.OUD_OVD_BEFORE_IDX,ID); /* prev: %undupsortNew(temp.OUD(keep=ID INDEX_DATE DATE OUD_SOURCE where=(DATE <= INDEX_DATE)), temp.OUD_OVD_BEFORE_IDX,ID); */
	%undupsortNew(temp.OUD_OVD_BEFORE_IDX (keep=ID), temp.OUD_OVD_BEFORE_IDX_ID,ID);

	data temp.DX_B4IDX;
	set temp.OUD_OVD_BEFORE_IDX_ID;
    DXB4IDX=1;
	run;
    /* J */

	/* J (Cross check, no need to run) */
	data temp.OUD2 (keep=ID DATE OUD_SOURCE);
	length OUD_SOURCE $16;
	set temp.DX_COMORB		 	(in=DX_OUD_FLAG   	 	keep=ID ADMIT_DATE DX_OPI_OUD rename=(ADMIT_DATE=DATE) 		where=(DX_OPI_OUD=1))
	    temp.DX_COMORB		 	(in=DX_SUD_FLAG   	 	keep=ID ADMIT_DATE DX_SUD rename=(ADMIT_DATE=DATE) 		    where=(DX_SUD=1))
		temp.RX_MERGE_RXCUI 	(in=BUP_OUD_FLAG 	 	keep=ID DATE RXCUI_SOURCE 								 	where=(RXCUI_SOURCE='BUPRE'))
		temp.PX_COMORB 		 	(in=METH_OUD_FLAG  		keep=ID DATE PX_MAT_METHADONE								where=(PX_MAT_METHADONE=1))
		temp.DX_COMORB	        (in=OVERDOSE_DEF_FLAG 	keep=ID ADMIT_DATE OUTCOME_OPI_OVD rename=(ADMIT_DATE=DATE) where=(OUTCOME_OPI_OVD=1));
	if DX_OUD_FLAG 		then OUD_SOURCE='DX_OUD';
    if DX_SUD_FLAG 		then OUD_SOURCE='DX_SUD';
	if BUP_OUD_FLAG 	then OUD_SOURCE='BUP_OUD';
	if METH_OUD_FLAG 	then OUD_SOURCE='METH_OUD';
	if OVERDOSE_DEF_FLAG then OUD_SOURCE='OVERDOSE_DEF';
	run;
	%procfreq(temp.OUD2,OUD_SOURCE);/* BUP_OUD 11039 DX_OUD 211676 DX_SUD 448560 METH_OUD 0 OVERDOSE_DEF 3042 */
	%procsort(temp.OUD2,,ID);
	%procsort(temp.INDEXDATE,,ID);
	data temp.OUD2;
	merge 	temp.OUD2		(in=a)
			temp.INDEXDATE	(in=b);
	by ID;
	if a & b;
	CLAIM_PERIOD = floor((DATE-INDEX_DATE)/91.25)+1;
	run;
	%procfreq(temp.OUD2,OUD_SOURCE);
	%undupsortNew(temp.OUD2(keep=ID INDEX_DATE DATE OUD_SOURCE where=(DATE <= INDEX_DATE)), temp.OUD_OVD_BEFORE_IDX2,ID);
	%undupsortNew(temp.OUD_OVD_BEFORE_IDX2 (keep=ID), temp.OUD_OVD_BEFORE_IDX_ID2,ID);
	data temp.DX_B4IDX2;
	set temp.OUD_OVD_BEFORE_IDX_ID2;
    DXB4IDX2=1;
	run;
	/* J */

/*	Create composite outcome > Create incident oud outcome	*/
	data temp.OUD_valid; *Exclude Overdose > Only include incident oud;
	merge	temp.OUD					(where=(DX not in ('F1111','F1121') & OUD_SOURCE^='DX_METH_OD' & OUD_SOURCE^='BUP_OUD' & OUD_SOURCE^='DX_SUD' & OUD_SOURCE^='METH_OUD' & OUD_SOURCE^='DX_HEROIN_OVD' & OUD_SOURCE^='DX_OTHER_OPI_OD' & OUD_SOURCE^='ELIX_DRUG' & DATE>INDEX_DATE))
			temp.OUD_OVD_BEFORE_IDX		(in=b keep=ID);
	by ID;
	if ^b;
	run;
	%undupsortNew(temp.OUD_valid(keep=ID),temp.OUTCOME_OUD_valid_ID,ID);
    %undupsortNew(temp.OUD_valid(keep=ID CLAIM_PERIOD DATE OUD_SOURCE where=(OUD_SOURCE='DX_OUD')),temp.OUTCOME_DX_INC_OUD_valid,ID CLAIM_PERIOD);
    %undupsortNew(temp.OUD_valid(keep=ID OUD_SOURCE where=(OUD_SOURCE='DX_OUD')),temp.OUTCOME_DX_INC_OUD_valid_ID,ID);

	/*
	%undupsortNew(temp.OUD_valid(keep=ID),temp.OUTCOME_ALL_OUD_valid_ID,ID);
	%undupsortNew(temp.OUD_valid(keep=ID OUD_SOURCE where=(OUD_SOURCE='METH_OUD')),temp.OUTCOME_METH_OUD_valid,ID);
	
	%undupsortNew(temp.OUD_valid(keep=ID OUD_SOURCE where=(OUD_SOURCE='BUP_OUD')),temp.OUTCOME_BUP_OUD_valid,ID);
	%undupsortNew(temp.OUD_valid(keep=ID OUD_SOURCE where=(OUD_SOURCE='DX_SUD')),temp.OUTCOME_DX_SUD_valid,ID);
	*/

	/* no need to run 
	data temp.OUD_OVD_valid; *Include Overdose;
	merge	temp.OUD	(where=(DATE>INDEX_DATE))	
			temp.OUD_OVD_BEFORE_IDX	(in=b keep=ID);
	by ID;	
	if ^b;
	run;
	%undupsortNew(temp.OUD_OVD_valid(keep=ID),temp.OUTCOME_OUD_OVD_valid_ID,ID);
	%undupsortNew(temp.OUD_OVD_valid(keep=ID CLAIM_PERIOD DATE OUD_SOURCE where=(OUD_SOURCE='OVERDOSE_DEF')),temp.OUTCOME_OVERDOSE_DEF_valid, ID CLAIM_PERIOD);
	%undupsortNew(temp.OUD_OVD_valid(keep=ID OUD_SOURCE where=(OUD_SOURCE='OVERDOSE_DEF')),temp.OUTCOME_OVERDOSE_DEF_valid_ID,ID);
    */

/*	At least 1 pair after index date -------------------------------------------------------------------*/
	proc sql;
	create table CLAIM_PERIOD as
	select distinct a.ID, floor((a.ADMIT_DATE-b.INDEX_DATE)/91.25)+1 as CLAIM_PERIOD
	from FL.EMR_ENC (where=(SOURCE not in ("CHP","FLM"))) as a
	inner join TEMP.INDEXDATE as b on a.ID=b.ID
	;
	quit;
	%undupsortNew(CLAIM_PERIOD,,ID CLAIM_PERIOD);
	data CLAIM_PERIOD; set CLAIM_PERIOD; if CLAIM_PERIOD>=0; run;
	%undupsortNew(CLAIM_PERIOD,,ID descending CLAIM_PERIOD );

	data CLAIM_PERIOD;
	set CLAIM_PERIOD;
	by ID;
	LEAD_CLAIM_PERIOD=LAG(CLAIM_PERIOD);
	if first.ID then LEAD_CLAIM_PERIOD=.; 
	run;
	%undupsortNew(CLAIM_PERIOD,,ID CLAIM_PERIOD);
	data CLAIM_PERIOD;
	set CLAIM_PERIOD;
	if LEAD_CLAIM_PERIOD=CLAIM_PERIOD+1 /*Only use period with next consecutive paired period*/ & CLAIM_PERIOD>0 /*select pair after index date*/ ; 
	AT_LEAST_1_PAIR=1;
	run;
	%undupsortNew(CLAIM_PERIOD(keep=ID AT_LEAST_1_PAIR),temp.CLAIM_PERIOD,ID);

/*	Adding flag to identify patients who have Substance Use Disorder / Drug Abuse before index date	*/
	proc sql;
	create table temp.Hx_SUD_DRUG_ABUSE_ID as 
	select distinct a.ID 
	/*from temp.dx_comorb (where=(DX_SUD = 1 | ELIX_DRUG = 1)) as a */ /* not used in 9/19 */
	from temp.dx_comorb (where=(ELIX_DRUG = 1)) as a 
	inner join temp.INDEXDATE as b on a.ID=b.ID 
	where a.ADMIT_DATE <= b.INDEX_DATE;
	quit;

	data temp.Hx_SUD_DRUG_ABUSE;
	set temp.Hx_SUD_DRUG_ABUSE_ID;
    ELIX_DRUG=1;
	run;

/*  patient had an incident OUD diagnosis after the index date during the study period */
    /* No need to run this J portion */
	/* J */ 
    data temp.INC_OUD (keep=ID DATE OUD_SOURCE DX);
	length OUD_SOURCE $16;
	set temp.DX_COMORB		 	(in=DX_OUD_FLG   	 	keep=ID ADMIT_DATE DX DX_OPI_OUD rename=(ADMIT_DATE=DATE) 		where=(DX_OPI_OUD=1 & DX not in ('F1111','F1121')));
	if DX_OUD_FLG 		then OUD_SOURCE='DX_OUD';
	run;

	%procfreq(temp.INC_OUD,OUD_SOURCE);/* DX_INC_OUD 197917 > 305772 */
	%procsort(temp.INC_OUD,,ID);
	%procsort(temp.INDEXDATE,,ID);
	data temp.INC_OUD_AFTER_IDX;
	merge 	temp.INC_OUD 	(in=a)
			temp.INDEXDATE	(in=b);
	by ID;
	if a & b;
	run;
	%procfreq(temp.INC_OUD_AFTER_IDX,OUD_SOURCE);/* DX_INC_OUD 25611 > 60687 */
	%undupsortNew(temp.INC_OUD_AFTER_IDX (keep=ID INDEX_DATE DATE OUD_SOURCE where=(DATE >= INDEX_DATE)), temp.INC_OUD_AFTER_IDX2,ID);
	%undupsortNew(temp.INC_OUD_AFTER_IDX2 (keep=ID), temp.INC_OUD_AFTER_IDX2_ID,ID); /* DX_INC_OUD 3494 > 10113 */

    data temp.INC_OUD_AFTER_IDX2_ID;
	set temp.INC_OUD_AFTER_IDX2_ID;
    DX_INC_OUD_AFTER_IDX=1;
	run;
	/* J */
	
    /* J (Cross check, no need to run) */
	proc sql;
	create table temp.xsample as
	select a.ID, DATE, b.INDEX_DATE, OUD_SOURCE, DX
	from temp.INC_OUD as a
	inner join temp.INDEXDATE as b on a.ID=b.ID
	where a.DATE >= b.INDEX_DATE
	;
	quit;

	proc sort data=temp.xsample nodupkey;
	by ID;
	run;


	proc sql;
	create table temp.xsample2 as
	select ID, DX, OUTCOME_OPI_OVD
	from temp.DX_COMORB as a
	where a.OUTCOME_OPI_OVD=1
	;
	quit;

    proc sort data=temp.xsample2 nodupkey;
	by ID;
	run;
	
    /* J */

	/* J (check index date for step 7 confusion */
	proc sql;
	create table temp.IND_Check as
	select a.ID, a.min_ADMIT_DT, a.INDEX_DATE
	from temp.indexdate as a
	where a.INDEX_DATE>='30Aug2022'd
	;
	quit;
	/* J */
	
/*	------------------------------------------------------------------------------------
	Extract Cohort

	Step1	Eligible beneficiaries aged 18+ , who had =1 prescription fills for non-injectable, non buprenorphine (for opioid use disorder) opioids during 2016-2018 
	Step2	Excluded those who had malignant cancer diagnosis 
	Step3	Excluded those who were in hospice 
	Step4	Among eligible beneficiaries, those who did not have malignant cancer diagnoses or were in hospice care 
	Step5	Excluded those who the first opioid prescription was after Oct 1, 2018
	Step6	Excluded those who were dual eligible for Medicare on the index date
	Step7	Final analytical cohort: Among eligible non-cancer beneficiaries, those who had =1 eligible opioid prescription 
	------------------------------------------------------------------------------------*/
	/*Combine dataset */
	/*%procsort(temp.bene_15to18,,ID);*/
	%procsort(temp.demo,,ID);
	%procsort(temp.EHR_ENC_17to19,,ID);
	%procsort(temp.indexDate,,ID);
	%procsort(temp.MDCAID_bene,,ID);
	%procsort(temp.CANCER,,ID);
	%procsort(temp.HOSPICE,,ID);
	%procsort(temp.dual_index,,ID);
	%procsort(temp.DX_B4IDX,,ID);
	%procsort(temp.Hx_SUD_DRUG_ABUSE,,ID);
	%procsort(temp.CLAIM_PERIOD,,ID);
	/* %procsort(temp.INC_OUD_AFTER_IDX2_ID,,ID); */

	data bene;
		merge
		temp.demo (in=a keep=source id)
		temp.EHR_ENC_17to19		
		temp.indexDate
		temp.MDCAID_bene
		temp.CANCER
		temp.HOSPICE
		temp.dual_index
		temp.DX_B4IDX
		temp.Hx_SUD_DRUG_ABUSE
		temp.CLAIM_PERIOD
		/*temp.INC_OUD_AFTER_IDX2_ID */
		;
		by ID;
		if a;
	run;
	%nrows(bene);
	%distinctid(bene,ID);

/*	Step1   Eligible patients aged >=18 , who had =1 EHR encounter during 2017-2019 */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18)),id);*1,417,710 > 2,473,412;
/*	Step2	Exclude patients without any AV/ED (OP) nonivoud meds*/
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE=.)),id);*1,194,420 > 2,097,470;
/*	Step3	Had =1 AV/ED (OP) prescription fills for non-injectable, non buprenorphine (for opioid use disorder) opioids */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=.)),id);*223,290 > 375,942;
/*	Step4	Excluded those who had malignant cancer diagnosis */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER=1)),id); *45,051 > 81,465;
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1)),id); *178,239 > 294,477;
/*	Step5	Excluded those who were in hospice */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE=1)),id); *2,653 > 5,294;
/*	Step6	Among eligible beneficiaries, those who did not have malignant cancer diagnoses or were in hospice care */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1)),id); *175,586 > 289,183;
/*	Step7	Excluded those who the first opioid prescription was after Oct 1, 2018 > Oct 1, 2021*/
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE>'30Sep2022'd)),id); *7,076 > 0;
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd)),id); *168,510 > 289,183;
/*			Flag those who were dual eligible for Medicare on the index date*/
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd & dual=1)),id); *16,172 > 26098;
/*	Step8	Among eligible non-cancer beneficiaries, those who had =1 eligible opioid prescription */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd)),id); *168,510 > 289,183;
/*  Step9 Excluded those with had a diagnosis of OUD, opioid overdose, other substance use disorder, drug abuse, or received methadone or buprenorphine for OUD
          before initiating opioids */
    %distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd & DXB4IDX=1)),id); *5237 > 10668 > 10620;
/*  Step10 Among eligible patients, those without any history of OUD, having buprenorphine for OUD and methadone for OUD */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd & DXB4IDX^=1)),id); *163273 > 278515;
/*  Step11 Among eligible patients, those who had at least one 3-month prediction window pair */
	%distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd & DXB4IDX^=1 & AT_LEAST_1_PAIR)),id); *105,672 > 183,433 > 183,481;
/*  Step12 Among the study cohort, patient had an incident OUD diagnosis after the index date during the study period */
	/* not run yet */
    %distinctid(bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd & DXB4IDX^=1 & AT_LEAST_1_PAIR & DX_INC_OUD_AFTER_IDX)),id); *1332 > 4380 > ?;

    data temp.bene(keep=ID INDEX_DATE);
	set bene (where=(n_ENC>0 & age_enc>=18 & INDEX_DATE^=. & CANCER^=1 & HOSPICE^=1 & INDEX_DATE<='30Sep2022'd & DXB4IDX^=1 & AT_LEAST_1_PAIR));
	run;
	%distinctid(temp.bene,id);*105,672 > 183,433 > 183,481 > 182083;

	/* End of cohort extraction */

	
/*	Primary outcome: suicide-related outcomes	--------------------------------------------------------------------*/
*Suicide-related outcomes -> OUD after the index date: first opioid prescription date;
	proc sql;
	create table DX_16to19 as 
	select a.*, b.*
	from temp.DX_16to19 (where=(SOURCE not in ('CHP','FLM'))) as a
	right join temp.bene  as b on a.ID=b.ID 
	where a.ADMIT_DATE>b.INDEX_DATE;
	quit;
	%distinctid(DX_16to19,id);  *108105 > 182160 > 182208 > 180820;

	/*
	proc sql;
	create table DX as 
	select a.*, b.*
	from temp.DX_16to19 (where=(SOURCE not in ('CHP','FLM'))) as a 
	right join temp.bene  as b on a.ID=b.ID; 
	quit;
	%distinctid(DX,id); *1619196;
	*/

	%macro incident_oud(dsin, dsout);
	/*Load Suicide Code*/
	proc import out=Oud_List datafile= "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/INCOUD ICD Codes 2023.xlsx" dbms=xlsx replace;	getnames=yes; sheet="Dx_INC_OUD"; run;
	data Oud_List;	set Oud_List (keep=ICD_SAS);	ICD_SAS = compress(ICD_SAS,'.');	run;
	proc sql noprint; Select "'"||STRIP(ICD_SAS)||"'" into :Oud_List_STR separated by ' ' from Oud_List; quit;
	%put &Oud_List_STR;

	data &dsout.;
	set	&dsin.;
	COMORB_OUD=0;
	%do lenTemp = 3 %to 7;
		if length(DX)>= &lenTemp. then do;
			if substr(DX,1,&lenTemp.) in (&Oud_List_STR.)  then COMORB_OUD=1;
		end;
	%end;
	label COMORB_OUD	= 'OUD related event';
	run;
	data &dsout.;
	set &dsout.;
	if sum (of COMORB_:);
	run;
	%mend;
	%incident_oud(DX_16to19, temp.DX_INCOUD);

	%distinctid(temp.DX_INCOUD,id);  *2669 > 5753 > 5802 > 5874;

/*del F1111 & F1121 */
data temp.DX_INCOUD; set temp.DX_INCOUD;
if DX in ('F1111','F1121') then delete;
run; 

/* del other DXs */
data temp.DX_INCOUD; set temp.DX_INCOUD;
where DX like 'F111%' or DX like 'F112%';
run; *15400 > 16554 >17193;

*Suicide-related outcomes;
proc freq data=temp.DX_INCOUD; tables ENC_TYPE PDX; run;
%distinctid(temp.DX_INCOUD (where=(ENC_TYPE in ('ED','EI','IP','AV','IC','OA','OS','OT','TH','UN'))),id); *898 > *2558; *if add AV then 3951 *
* ED: 441
* EI: 709 
* IP: 1681
* AV: 1826;

/* for missing enc_type check, no need to run */
data temp.x; set temp.DX_INCOUD;
where enc_type in ('UN');
run;
%distinctid(temp.x,id);

*suicide outcomes/opioid overdose -> IOUD in each 3-month episode;
data temp.DX_INCOUD; set temp.DX_INCOUD; 
duration=ADMIT_DATE -INDEX_DATE; 
interval=ceil(duration/91.2501);
run;

*ED & IP visits: days gap;
DATA temp.DX_INCOUD; SET temp.DX_INCOUD; 
PDX1=0;
if PDX="P" then PDX1=1;
if PDX="S" then PDX1=2;
if PDX="OT" then PDX1=3;
run;

proc sort data=temp.DX_INCOUD; by id ADMIT_DATE ENC_TYPE PDX1; run;

proc sort data=temp.DX_INCOUD out=temp.DX_INCOUD_nodup nodupkey; by id ADMIT_DATE ENC_TYPE; run;

proc freq data=temp.DX_INCOUD_nodup; tables ENC_TYPE; run;

/*
ENC_TYPE Frequency Percent Cumulative_Frequency Cumulative_Percent 
AV 		 4299 		72.24 	4299 				72.24 
ED 		 567 		9.53 	4866 				81.77 
EI 		 361 		6.07 	5227 				87.83 
IP 		 615 		10.33 	5842 				98.17 
OS 		 16 		0.27 	5858 				98.44 
UN 		 93 		1.56 	5951 				100.00 
Frequency Missing = 59 
*/
/*
ENC_TYPE Frequency Percent 
AV 6748 55.71  
ED 624 5.15  
EI 1127 9.30  
IC 1 0.01  
IP 2519 20.80  
OA 133 1.10  
OS 110 0.91  
OT 133 1.10  
TH 694 5.73  
UN 24 0.20 
*/


proc freq data=temp.DX_INCOUD_nodup; tables interval; run;
proc sql;
select count (distinct id) from temp.DX_INCOUD_nodup
group by interval;
quit;

proc freq data=temp.DX_INCOUD_nodup;
tables PDX; run;

data temp.DX_INCOUD_edip; set temp.DX_INCOUD_nodup; 
where ENC_TYPE="ED" or ENC_TYPE="IP" or ENC_TYPE="EI" or ENC_TYPE="AV" or ENC_TYPE= "OA" or ENC_TYPE="OS" or ENC_TYPE="OT" or ENC_TYPE="TH" or ENC_TYPE="UN"; 
by id ADMIT_DATE; 
*if ENC_TYPE="ED" then type="ED";
*if ENC_TYPE="IP" or ENC_TYPE="EI" then type="IP" ;
gap_days=ADMIT_DATE-lag(DISCHARGE_DATE);
lag_source=lag(ENC_TYPE);
if first.id then do; gap_days=.; lag_source=''; end;
if gap_days ^=. then prior_source=cat(lag_source, '-', ENC_TYPE);
run;

proc freq data=temp.DX_INCOUD_edip; tables prior_source; run;

proc sort data=temp.DX_INCOUD_edip; by prior_source; run;

proc means data=temp.DX_INCOUD_edip n mean STDDEV p10 p25 median p75 p90;
where gap_days ^=.;
by prior_source; 
var gap_days; 
run;

data temp.DX_INCOUD_edip; set temp.DX_INCOUD_edip;
episode=1;
episode7=0;
episode15=0;
episode30=0;

if gap_days >=7 or gap_days =. then episode7=1;
if gap_days >=15 or gap_days =. then episode15=1;
if gap_days >=30 or gap_days =. then episode30=1;
run;

proc sql;
create table episode as
select id,  sum(episode) as sum, sum(episode7) as sum7, sum(episode15) as sum15, sum(episode30) as sum30
from temp.DX_INCOUD_edip
group by id;
quit;

proc means data=episode n sum mean STDDEV median min max; var sum sum7 sum15 sum30; run;

%DISTINCTID(temp.DX_INCOUD_nodup,ID); /*2669 > 4297 > 4345>4460*/
%DISTINCTID(temp.DX_INCOUD_edip,ID); /*898 > 2558 > 4280 > 4328>4443*/


*count # of IP and ED visits for each pt;
data temp.DX_INCOUD_edip; set temp.DX_INCOUD_edip;
ed=0;
ip=0;
if enc_type="ED" then ed=1;
if enc_type="IP" then ip=1;
run;

proc sql;
create table temp.DX_INCOUD_edip as 
select *, sum(ed) as edcount, sum(ip) as ipcount from temp.DX_INCOUD_edip
group by id;
quit;

%DISTINCTID(temp.DX_INCOUD_edip(where=(edcount=1)),ID); /*329 > 360>359*/
%DISTINCTID(temp.DX_INCOUD_edip(where=(edcount>1)),ID); /*74 > 81>83*/
%DISTINCTID(temp.DX_INCOUD_edip(where=(ipcount=1)),ID); /*467 > 1664 >1257>1260*/
%DISTINCTID(temp.DX_INCOUD_edip(where=(ipcount>1)),ID); /*178 > 626>424>419*/

%DISTINCTID(temp.DX_INCOUD_edip(where=((ipcount=1 and edcount=0) or (ipcount=0 and edcount=1))),ID);
*610 > 1808>1479 pts have 1 dx at ED/IP;
%DISTINCTID(temp.DX_INCOUD_edip(where=((ipcount>1) or (edcount>1))),ID);
*218 > 678>491>487 pts have >1 dx at ED/IP;

*diagnosis positions;
proc sort data=temp.DX_INCOUD_edip out=temp.DX_INCOUD_edip; by id ADMIT_DATE; run;

data temp.DX_INCOUD_edip; set temp.DX_INCOUD_edip; 
lag_dx=lag(PDX);
if first.id then do; lag_source=''; end;
if gap_days ^=. then dx_position=cat(lag_dx, '-', PDX);
run;

proc freq data=temp.DX_INCOUD_edip;
where gap_days ^=. ;
tables prior_source*dx_position /nocol; run;

proc freq data=temp.DX_INCOUD_edip;
where gap_days ^=. ;
tables PDX; run;
*there are 85 > ? missing PDX;

*suicide outcomes by race & gender & year;
	proc sql;
	create table incoud_demo as 
	select a.*, b.*
	from temp.DX_incoud_edip as a
	left join temp.demo  as b on a.ID=b.ID; 
	quit;
%DISTINCTID(incoud_demo,ID); /*898 > 2558 > 4328 > 4443 */

proc sql;
create table yr_gender as select
year(admit_date) as year, gender, count(distinct(id)) as count from incoud_demo
group by year, gender;
quit;
*gender: M=1, F=2;

proc sql;
create table yr_race as select
year(admit_date) as year, race, count(distinct(id)) as count from incoud_demo
group by year, race;
quit;
*race: white=1, balck=2, hispanic (any race)=3, native hawaiian or other=4;

	proc sql;
	create table encounter_cohort as 
	select a.*, b.*
	from temp.DX_16to19 as a
	inner join temp.bene  as b on a.ID=b.ID; 
	quit;
%DISTINCTID(encounter_cohort,ID); /*109909 > 183407 > 183455 >182057*/

	proc sql;
	create table encounter_cohort_demo as 
	select a.*, b.*
	from encounter_cohort as a
	left join temp.demo  as b on a.ID=b.ID; 
	quit;
	%DISTINCTID(encounter_cohort_demo,ID); /*109909 > 183407 > 183455 >182057*/


proc sql;
create table yr_gender_all as select
year(admit_date) as year, gender, count(distinct(id)) as count from encounter_cohort_demo
group by year, gender;
quit;
*gender: M=1, F=2;


proc sql;
create table yr_race_all as select
year(admit_date) as year, race, count(distinct(id)) as count from encounter_cohort_demo
group by year, race;
quit;
*race: white=1, balck=2, other=3;

*------------------------------------------------------------------------;
/* Added March 1, 2024 for additional analysis */
/* for ENC_TYPE calculation for 2558 > 4280 patients */

proc sort data=temp.DX_INCOUD_edip out=temp.DX_INCOUD_edip2 nodupkey; by id; run; /* 4443 */
proc freq data=temp.DX_INCOUD_edip2; tables enc_type; run;
proc freq data=temp.DX_INCOUD_edip2; tables pdx; run;
/* Result for this portion */

/* */

	%put Notice: End of the program. %sysfunc(time(),time.);
/* */

/* -------------------------------------------------------------------------------------------------------------------- */



