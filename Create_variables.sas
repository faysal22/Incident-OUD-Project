
/*	--------------------------------------------------------------------------------------------------------------------------------
	[Objective] Create variables(2017-2022)
	
	- Patient-level
		- Demographics: AGE(current), DISABLED, RACE, ETHNIC
		- Comorbidities: Including Elixhauser Index
		- Service utilization: N_ED N_IP N_OP 
		- Orders pattern: N_MONTHLY_NONOPI_RX NRX_: DAYS_SUPPLY_:
		- Lab pattern: ANY_LAB_CONFIR/SCREEN: N_LAB_ANY_CONFIR/SCREEN:

	- Patterns of opioid use 
		- MME per day: QUANTITY*STRENGTH_PER_UNIT*MME_CONVERSION_FACTOR/DAYS_SUPLY
		- CDAYS_EARLY_REFILL
		- NRX_: Number of orders for ____
		- CONT_DUR_: Duration of longest continuous use of ____
		- CUM_DUR_: Duration of cumulative use of ____
		- CUM_DUR30D_: Duration of cumulative 30-day use of ____
		- DAYS_OPI_BZD: Total cumulative overlapping days of concurrent use of opioids, benzodiazepines
		- N_OPI_PRESCRIBERS: Number of opioid prescribers
		- N30DRX_OPIOID Total number of 30-day prescription for any opioids
		- TYPE_OPIOIDS: Drug Enforcement Administration’s Controlled Substance Schedule (Schedule I to IV) and duration of action (long- vs. short-acting)

	- Provider-level
		- MME_PER_PT_PERIOD_AVRG: Average monthly opioid prescribing dose (MME)
		- N_CLAIMS_AVRG: Average monthly opioid prescribing volume
		- N_PT: Average monthly patients receiving opioids
		- PROVIDER_SEX: Gender of primary prescriber for opioids 
		- PRVDR_CATEGORY: Specialty of primary prescriber for opioids 

	- Health-system-level/regional-level
		- ADI: Area Deprevation Index
		- CHR: County Health Rankings 
		- AHRF: Area Health Resources Files
	--------------------------------------------------------------------------------------------------------------------------------*/
 
/*	--------------------------------------------------------------------------------------------------------------------------------
	Import Library etc.
	--------------------------------------------------------------------------------------------------------------------------------*/
	%put Notice: Start of the program. %sysfunc(date(),date9.) %sysfunc(time(),time.);

	libname FL 		"/data/Project/IRB202101897-DEMONSTRATE/rawdata/ONE FL - 2023-02-16";
	libname TEMP 	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/Dataset4/3M";
	libname OUT 	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/Output4";
	libname NDC 	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/NDC";
	libname NDC2021 "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/NDC_Upload_202111";

	libname Primary	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/Dataset4";
	*libname NPI		"E:\resources\NPI\NPPES_2020_05";

	libname AHRF	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/File/AHRF/2017_2018";
	libname ADI 	"/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/ADI/";


	/*	Useful Macro	-------------------------------------------------------------------------*/
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/utilities.sas";
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/macros.sas";
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/Elxihauser Format.sas";
	%include "/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/format_OneFL.sas";


	/*	Import Dataset	--------------------------------------------------------------------------*/

	proc import out=NPI_SPECIALTY 		datafile="/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/DEMONSTRATE_Data Dictionary_20221212.xlsx"	dbms=xlsx replace; getnames=yes; sheet="PROVIDER_SPECIALTY_PRIMARY"; run;
	proc import out=NPI_CATEGORY 		datafile="/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/DEMONSTRATE_Data Dictionary_20221212.xlsx"	dbms=xlsx replace; getnames=yes; sheet="PRVDR_Category";run;
	proc import out=NPI_CATEGORY_FORMAT datafile="/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/DEMONSTRATE_Data Dictionary_20221212.xlsx"	dbms=xlsx replace; getnames=yes; sheet="PRVDR_Category_Format";run;

/*	--------------------------------------------------------------------------------------------------------------------------------
	Prepare dataset
	--------------------------------------------------------------------------------------------------------------------------------*/
	%put Prepare dataset;
	proc sql;
	create table temp.BENE_ENC as 
	select b.*, a.index_date as OPIOID_START_DT format=DATE9., floor((b.ADMIT_DATE-a.index_date)/91.25)+1 as CLAIM_PERIOD 
	from primary.bene as a 
	inner join fl.emr_enc (drop=ADMIT_TIME DISCHARGE_TIME where=(2016<=year(admit_date)<=2022 & SOURCE not in ('CHP','FLM'))) as b on a.ID=B.ID
	where a.index_date<=b.ADMIT_DATE
	order by id, admit_date, enc_type
	;
	quit;

	proc sql;
	create table temp.BENE_DX as
	select b.ID, a.index_date as OPIOID_START_DT format=DATE9., floor((b.ADMIT_DATE-a.index_date)/91.25)+1 as CLAIM_PERIOD, 
			b.ADMIT_DATE, b.ENC_TYPE, b.PDX, b.DX, b.SOURCE 
	from primary.bene as a 
	inner join primary.dx_16to19 (drop=ENCOUNTERID where =(SOURCE not in ('CHP','FLM'))) as b on a.ID=b.ID
	where a.index_date<=b.ADMIT_DATE
	order by b.ID, b.ADMIT_DATE, b.pdx, b.dx 
	;
	quit;

	proc sql;
	create table temp.BENE_DX_comorb as
	select b.*, a.index_date as OPIOID_START_DT format=DATE9., floor((b.ADMIT_DATE-a.index_date)/91.25)+1 as CLAIM_PERIOD 
	from primary.bene as a 
	inner join primary.dx_comorb (drop=ENCOUNTERID WHERE=(SOURCE not in ('CHP','FLM'))) as b on a.ID=b.ID
	where a.index_date<=b.ADMIT_DATE
	order by b.ID, b.ADMIT_DATE, b.pdx, b.dx 
	;
	quit;

	proc sql;
	create table temp.bene_RX_merge_RXCUI as
	select b.encounterid, b.ID, b.DATE, 
	a.index_date as OPIOID_START_DT,
	floor((b.DATE-a.index_date)/91.25)+1 					as CLAIM_PERIOD ,
	a.index_date+floor((calculated CLAIM_PERIOD-1)*91.25) 	as CLAIM_PERIOD_STR_DT format=DATE9.,
	a.index_date+floor(calculated CLAIM_PERIOD*91.25)-1 	as CLAIM_PERIOD_END_DT format=DATE9.,
	b.RX_START_DATE, b.RX_END_DATE,(case when ^missing(b.RX_START_DATE)&^missing(b.RX_END_DATE) then (b.RX_END_DATE-b.RX_START_DATE) else . end) as RX_DAYS, 
	b.RXCUI, b.QUANTITY, b.SUPPLY, 
	(case when ^missing(supply) then supply when missing(supply)& calculated RX_DAYS>0 then calculated RX_DAYS else . end) as SUPPLY_NEW,
	b.REFILLS, b.rx_providerid, 
	b.DRUG, b.DOSAGE_FORM, b.ABUSE_DETERRENT, b.SA_LA, b.RXCUI_SOURCE, b.SOURCE, b.RX_BASIS,b.FREQUENCY,	
	(case when b.RXCUI_SOURCE = 'NONIVOUD' & b.MME_CONVERSION_FACTOR  =. then 0 else b.MME_CONVERSION_FACTOR end) as MME_CONVERSION_FACTOR,
	(case when b.RXCUI_SOURCE = 'NONIVOUD' & b.drug='Hydrocodone-Acetaminophen' & b.DOSAGE_FORM = 'SOLN' then b.STRENGTH_PER_UNIT/15 else b.STRENGTH_PER_UNIT end) as STRENGTH_PER_UNIT,
	(case when year(b.DATE) = 2016 then DEA_2016 when year(b.DATE) = 2017 then DEA_2017 when year(b.DATE) = 2018 then DEA_2018 when year(b.DATE) = 2019 then DEA_2019 when year(b.DATE) = 2020 then DEA_2019 end )as DEACLASS,
	(case when c.ENC_TYPE in ('IP') then "IP" when c.ENC_TYPE in ('ED', 'EI') then "ED" when c.ENC_TYPE in ('AV', 'OA') then "OP" end ) as ENC_TYPE
	from primary.bene as a
	inner join primary.RX_merge_RXCUI (where=(2016<=year(date)<=2022 & SOURCE not in ('CHP','FLM'))) as b on a.ID=B.ID
	left join FL.EMR_ENC (keep=ENCOUNTERID ENC_TYPE) as c on b.encounterid=c.encounterid
	where a.index_date<=b.DATE & b.RXCUI_SOURCE not in ("Dihydrocodein","Dihydrocodeine","Opium","Propoxyphene")
	order by ID, DATE, RXCUI, QUANTITY desc, SUPPLY desc, REFILLS desc
	;
	quit;
	%distinctid(temp.bene_RX_merge_RXCUI,ID);*109914>183433;
	%distinctid(temp.bene_RX_merge_RXCUI(WHERE=(RXCUI_SOURCE='NONIVOUD')),ID);*109914>183433;
	%distinctid(temp.bene_RX_merge_RXCUI(WHERE=(RXCUI_SOURCE='NONIVOUD'&2017<=year(date))),ID);*109914>183433;
	%procfreq(primary.RX_merge_RXCUI,ENC_TYPE);
	%procfreq(primary.RX_merge_RXCUI,ENC_TYPE*SOURCE);
	%checkmissing(temp.bene_RX_merge_RXCUI);*[Missing] Quantity 50.87%>53.43% Supply 80.55%>76.88%  Refills 48.55%>52.70% ;

	proc sql;
	create table temp.bene_PX as 
	select b.ID, a.index_date as OPIOID_START_DT, floor((b.PX_DATE-a.index_date)/91.25)+1 as CLAIM_PERIOD, 
			b.ADMIT_DATE, b.PX_DATE, b.PX_TYPE, b.PX_SOURCE, b.PROCEDURESID, b.PROVIDERID, b.ENCOUNTERID, b.SOURCE
	from primary.bene as a
	inner join FL.EMR_PX (where=(2016<=year(PX_DATE)<=2022 & SOURCE not in ('CHP','FLM'))) as b on a.ID=b.ID
	where a.index_date<=b.PX_DATE /*& ^missing(b.LAB_LOINC)*/
	order by ID, PX_DATE, PX
	;
	quit;

	proc sql;
	create table temp.bene_px_hcpcs as 
	select b.ID, a.index_date as OPIOID_START_DT, floor((b.admit_date-a.index_date)/91.25)+1 as CLAIM_PERIOD, 
		b.admit_date, b.px, b.px_date, b.source
	from primary.bene as a
	inner join primary.PX_HCPCS_16to19 (where=(SOURCE not in ('CHP','FLM'))) as b on a.ID=b.ID
	where a.index_date<=b.admit_date 
	order by ID, admit_date, px
	;
	quit;

	proc sql;
	create table temp.OD_EPISODE_7DGAP_3M as 
	select distinct b.ID, floor((b.admit_date-a.index_date)/91.25)+1 as CLAIM_PERIOD, 
		b.ADMIT_DATE, max(b.OVD_DEF) as OVD_DEF
	from primary.bene as a
	inner join primary.od_episode_7dgap as b on a.ID=b.ID
	where a.index_date<=b.admit_date 
	group by b.ID, b.CLAIM_PERIOD
	order by b.ID, b.CLAIM_PERIOD
	;
	quit;
	%procfreq(temp.OD_EPISODE_7DGAP_3M,OVD_DEF);
	/*OVD_DEF   Frequency     Percent      Cumulative_Frequency    Cumulative_Percent  */
	/*0 		89>212 		20.84>26.53 	89 						20.84>26.53 
	  1 		338>587 	79.16>73.47 	427 					100.00 */

/*	--------------------------------------------------------------------------------------------------------------------------------
	Comorbidity and Elixhauser variables
	--------------------------------------------------------------------------------------------------------------------------------	*/
/*	Comorbidity from diagnosis	*/
	%undupsortNew(primary.DX_COMORB,,ID ADMIT_DATE);
	data temp.COHORT_DX_COMORB;
	merge	primary.bene (in=a rename=(INDEX_DATE=OPIOID_START_DT))
			primary.DX_COMORB	(in=b drop=ENCOUNTERID DX ENC_TYPE PDX);
	by ID;
	if a & b;
	run;
	data temp.COHORT_DX_COMORB;
	retain  ID OPIOID_START_DT CLAIM_PERIOD;
	format  OPIOID_START_DT yymmdd10.;
	set temp.COHORT_DX_COMORB;
	CLAIM_PERIOD = floor((ADMIT_DATE-OPIOID_START_DT)/91.25)+1;
	if CLAIM_PERIOD>=0;
	drop ADMIT_DATE SOURCE;
	run;
	%undupsortNew(temp.COHORT_DX_COMORB,,ID OPIOID_START_DT CLAIM_PERIOD);
	%anyGrpBy(temp.COHORT_DX_COMORB, temp.COHORT_DX_COMORB_3M, ID CLAIM_PERIOD OPIOID_START_DT);
	data temp.COHORT_DX_COMORB_3M;
	set temp.COHORT_DX_COMORB_3M;
	ELIX_INDEX = 0;
	ELIX_INDEX = sum(of ELIX_CHF--ELIX_HTN_C); 
	run;

/*	Comorbidity from procedure (CPT/HCPCS)	*/
	%undupsortNew(PRIMARY.PX_COMORB,,ID ADMIT_DATE PX_DATE);
	data temp.COHORT_PX_COMORB;
	retain  ID OPIOID_START_DT CLAIM_PERIOD;
	merge	primary.BENE (rename=(INDEX_DATE=OPIOID_START_DT) in=a)
			primary.PX_COMORB	 (in=b)
			;
	by ID;
	if DATE=. then CLAIM_PERIOD = floor((ADMIT_DATE-OPIOID_START_DT)/91.25)+1;
	else CLAIM_PERIOD = floor((DATE-OPIOID_START_DT)/91.25)+1;
	format DATE OPIOID_START_DT yymmdd10.;
	if a & b;
	if CLAIM_PERIOD>=0 ;
	drop ADMIT_DATE DATE PX SOURCE;
	run;
	%undupsortNew(temp.COHORT_PX_COMORB,,ID CLAIM_PERIOD OPIOID_START_DT);
	%anyGrpBy(temp.COHORT_PX_COMORB, temp.COHORT_PX_COMORB_3M,ID CLAIM_PERIOD OPIOID_START_DT);
	data temp.COHORT_PX_COMORB_3M;
	set temp.COHORT_PX_COMORB_3M;
	ANY_CPT = 0;
	ANY_CPT = max(of PX_:);
	run;


/*	--------------------------------------------------------------------------------------------------------------------------------
	Calculate # IP and OP claims
	--------------------------------------------------------------------------------------------------------------------------------*/
	%undupsortNew(FL.EMR_ENC(keep=ID ADMIT_DATE ENC_TYPE FACILITYID),temp.ENCOUNTERS_NODUP,ID ADMIT_DATE ENC_TYPE FACILITYID);
	
	proc sql;
	create table IP_ED as 
	select 	distinct a.ID, a.INDEX_DATE, b.ADMIT_DATE format=yymmdd10., floor((ADMIT_DATE-a.INDEX_DATE)/91.25)+1 as CLAIM_PERIOD, b.ENC_TYPE
	from primary.BENE as a 
	inner join temp.ENCOUNTERS_NODUP as b on a.ID=b.ID 
	order by a.ID, b.ADMIT_DATE
	;
	quit;
	proc sql;
	create table N_IP_ED as 
	select 	distinct ID, ADMIT_DATE, CLAIM_PERIOD,
			max(case when ENC_TYPE in ('IP','EI') then 1 else 0 end) as IP, 
			max(case when ENC_TYPE in ('ED') then 1 else 0 end) as ED, 
			max(case when ENC_TYPE in ('AV','OA') then 1 else 0 end) as OP
	from IP_ED
	group by ID, ADMIT_DATE
	order by ID, ADMIT_DATE
	;
	quit;
	proc sql;
	create table temp.N_IP_ED_3m as 
	select 	ID, CLAIM_PERIOD, 
			sum(IP) as N_IP, sum(ED) as N_ED, sum(OP) as N_OP
	from N_IP_ED
	where CLAIM_PERIOD>=0
	group by ID, CLAIM_PERIOD
	order by ID, CLAIM_PERIOD
	;
	quit;

	/*	--------------------------------------------------------------------------------------------------------------------------------
	Calculate usage pattern of opioid and other drugs for study cohort
	--------------------------------------------------------------------------------------------------------------------------------*/

/*	Calculate # non-opioid orders	----------------------------------------------------------------------------------------*/

	proc sql;
	create table NONOPIOID as
	select a.ID, a.INDEX_DATE, b.DATE, floor((b.DATE-a.INDEX_DATE)/91.25)+1 as CLAIM_PERIOD, RXCUI_SOURCE
	from primary.bene as a
	left join  primary.RX_MERGE_RXCUI (where=(RXCUI_SOURCE^='NONIVOUD'& IP_OP="OP")) as b on a.ID=b.ID
	order by a.ID, b.DATE
	;
	quit;
	proc sql;
	create table temp.N_NONOPIOID_3M as
	select distinct ID, CLAIM_PERIOD, count(*)*30/91 as N_MONTHLY_NONOPI_RX
	from NONOPIOID
	where CLAIM_PERIOD>=0
	group by ID, CLAIM_PERIOD
	order by ID, CLAIM_PERIOD
	;
	quit;

/*	Opioid overlap pattern	------------------------------------------------------------------------------------------------------------*/
/*	--------------------------------------------------------------------------------------------------------------------------------
	Create "Overlap_OPI_BZD_3d" : Opioid and benzodizapine prescription order overlap within 3 days
	Flag if had BZD order within +- 3 days of OPI order. (Cap if the observation window cover next following period)
	--------------------------------------------------------------------------------------------------------------------------------*/
	%macro identify_overlap_order (dsIn, dsOut, RXCUI_NDC, DrugA, DrugB, Gap, VarName);
	data temp_&DrugA temp_&DrugB;
	set &dsIn. (keep=ID DATE &RXCUI_NDC._SOURCE);
	if &RXCUI_NDC._SOURCE="&DrugA." then output temp_&DrugA;
	if &RXCUI_NDC._SOURCE="&DrugB." then output temp_&DrugB;
	run;
	proc sort data=temp_&DrugA; by ID DATE &RXCUI_NDC._SOURCE; run;
	proc sort data=temp_&DrugB; by ID DATE &RXCUI_NDC._SOURCE; run;
	proc sql;
	create table temp_&DrugA._1 as 
	select distinct b.ID, a.INDEX_DATE, (floor((b.DATE-a.INDEX_DATE)/91.25)+1) as CLAIM_PERIOD, b.DATE
	from primary.bene as a 
	inner join temp_&DrugA. as b on a.ID=b.ID 
	where calculated CLAIM_PERIOD>=0
	order by b.ID, b.DATE
	;
	quit;
	proc sql;
	create table temp_&DrugB._1 as 
	select distinct b.ID, (floor((b.DATE-a.INDEX_DATE)/91.25)+1) as CLAIM_PERIOD, b.DATE
	from primary.bene as a 
	inner join temp_&DrugB as b on a.ID=b.ID 
	where calculated CLAIM_PERIOD>=0
	order by b.ID, b.DATE
	;
	quit;
	proc sql;
	create table temp_&&DrugA._&DrugB. as
	select 	a.ID, a.claim_period as period_&DrugA, b.claim_period as period_&DrugB,
			a.INDEX_DATE+floor((a.CLAIM_PERIOD-1)*91.25) 		as CLAIM_PERIOD_STR_DT format=yymmdd10.,
			a.INDEX_DATE+floor((a.CLAIM_PERIOD  )*91.25) 		as CLAIM_PERIOD_END_DT format=yymmdd10.,
			a.date as DATE_&DrugA format=yymmdd10., b.date as date_&DrugB format=yymmdd10.
	from temp_&DrugA._1 as a
	inner join temp_&DrugB._1 as b on a.ID=b.ID & (a.claim_period=b.claim_period | a.claim_period-1=b.claim_period)
	order by a.ID, a.date, b.date
	;
	quit;
	proc sql;
	create table temp_&&DrugA._&DrugB._1 as 
	select ID , period_&DrugA, period_&DrugB, CLAIM_PERIOD_STR_DT, CLAIM_PERIOD_END_DT,  DATE_&DrugA , DATE_&DrugB, abs(DATE_&DrugB-DATE_&DrugA) as DIFF, 
			(case when calculated DIFF<=&GAP. then 1 else 0 end) as FLAG
	from temp_&&DrugA._&DrugB.
	order by ID , DATE_&DrugA
	;
	quit;
	proc sql;
	create table temp_&&DrugA._&DrugB._2 as 
	select distinct ID, period_&DrugA as CLAIM_PERIOD , max(FLAG) as &VarName.
	from temp_&&DrugA._&DrugB._1
	group by ID , CLAIM_PERIOD
	order by ID , CLAIM_PERIOD
	;
	quit;
	proc sort data=temp_&&DrugA._&DrugB._2 (keep=ID CLAIM_PERIOD &VarName.) out=&dsout. nodupkey; 
	by ID CLAIM_PERIOD &VarName. ;
	run;
	proc delete data=temp_&DrugA temp_&DrugB temp_&DrugA._1 temp_&DrugB._1  temp_&&DrugA._&DrugB. temp_&&DrugA._&DrugB._1 temp_&&DrugA._&DrugB._2; run;
	%mend;
/*	OVERLAP_OPI_BZD_3/7/14d	*/
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_BZD_3D, RXCUI, NONIVOUD, BZD, 3,OVERLAP_OPI_BZD_3D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_BZD_7D, RXCUI, NONIVOUD, BZD, 7,OVERLAP_OPI_BZD_7D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_BZD_14D, RXCUI, NONIVOUD, BZD, 14,OVERLAP_OPI_BZD_14D);
/*	OVERLAP_OPI_MUS_3D	*/
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_MUS_3D, RXCUI, NONIVOUD, MUSCLERELAX, 3,OVERLAP_OPI_MUS_3D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_MUS_7D, RXCUI, NONIVOUD, MUSCLERELAX, 7,OVERLAP_OPI_MUS_7D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_MUS_14D, RXCUI, NONIVOUD, MUSCLERELAX, 14,OVERLAP_OPI_MUS_14D);
/*	Overlap_OPI_GABA_3D	*/
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_GABA_3D, RXCUI, NONIVOUD, GABAPEN, 3,OVERLAP_OPI_GABA_3D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_GABA_7D, RXCUI, NONIVOUD, GABAPEN, 7,OVERLAP_OPI_GABA_7D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_GABA_14D, RXCUI, NONIVOUD, GABAPEN, 14,OVERLAP_OPI_GABA_14D);
/*	Overlap_BZD_BUP_3D	*/
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_BZD_BUP_3D, RXCUI, BZD, BUPRE, 3,OVERLAP_BZD_BUP_3D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_BZD_BUP_7D, RXCUI, BZD, BUPRE, 7,OVERLAP_BZD_BUP_7D);
	%identify_overlap_order (primary.RX_MERGE_RXCUI, DS_Overlap_BZD_BUP_14D, RXCUI, BZD, BUPRE, 14,OVERLAP_BZD_BUP_14D);

/*	--------------------------------------------------------------------------------------------------------------------------------
	Create "Overlap_OPI_BZD_MUS_3d" : Opioid and benzodizapine & muscle relaxant prescription order overlap within 3 days
	Flag if had BZD AND MUS order within +/- 3 days of OPI order. (Cap if the observation window cover next following 3-month period)
	--------------------------------------------------------------------------------------------------------------------------------*/

	%macro identify_overlap_order_3drug (dsIn, dsOut, RXCUI_NDC, DrugA, DrugB, DrugC, Gap, VarName);
	data temp_&DrugA temp_&DrugB temp_&DrugC;
	set &dsIn. (keep=ID DATE &RXCUI_NDC._SOURCE);
	if &RXCUI_NDC._SOURCE="&DrugA." then output temp_&DrugA;
	if &RXCUI_NDC._SOURCE="&DrugB." then output temp_&DrugB;
	if &RXCUI_NDC._SOURCE="&DrugC." then output temp_&DrugC;
	run;
	proc sort data=temp_&DrugA; by ID DATE &RXCUI_NDC._SOURCE; run;
	proc sort data=temp_&DrugB; by ID DATE &RXCUI_NDC._SOURCE; run;
	proc sort data=temp_&DrugC; by ID DATE &RXCUI_NDC._SOURCE; run;
	proc sql;
	create table temp_&DrugA._1 as 
	select distinct b.ID, a.INDEX_DATE, (floor((b.DATE-a.INDEX_DATE)/91.25)+1) as CLAIM_PERIOD, b.DATE
	from primary.bene as a 
	inner join temp_&DrugA. as b on a.ID=b.ID 
	where calculated CLAIM_PERIOD>=0
	order by b.ID, b.DATE
	;
	quit;
	proc sql;
	create table temp_&DrugB._1 as 
	select distinct b.ID, (floor((b.DATE-a.INDEX_DATE)/91.25)+1) as CLAIM_PERIOD, b.DATE
	from primary.bene as a 
	inner join temp_&DrugB. as b on a.ID=b.ID 
	where calculated CLAIM_PERIOD>=0
	order by b.ID, b.DATE
	;
	quit;
	proc sql;
	create table temp_&DrugC._1 as 
	select distinct b.ID, (floor((b.DATE-a.INDEX_DATE)/91.25)+1) as CLAIM_PERIOD, b.DATE
	from primary.bene as a 
	inner join temp_&DrugC. as b on a.ID=b.ID 
	where calculated CLAIM_PERIOD>=0
	order by b.ID, b.DATE
	;
	quit;
	proc sql;
	create table temp_&&DrugA._&&DrugB._&DrugC. as
	select 	a.ID, a.claim_period as period_&DrugA, b.claim_period as period_&DrugB, c.claim_period as period_&DrugC,
			a.INDEX_DATE+floor((a.CLAIM_PERIOD-1)*91.25) 		as CLAIM_PERIOD_STR_DT format=yymmdd10.,
			a.INDEX_DATE+floor((a.CLAIM_PERIOD  )*91.25) 		as CLAIM_PERIOD_END_DT format=yymmdd10.,
			a.date as DATE_&DrugA format=yymmdd10., b.date as date_&DrugB format=yymmdd10., c.date as date_&DrugC format=yymmdd10.
	from temp_&DrugA._1 as a
	inner join temp_&DrugB._1 as b on a.ID=b.ID & (a.claim_period=b.claim_period | a.claim_period-1=b.claim_period)
	inner join temp_&DrugC._1 as c on a.ID=c.ID & (a.claim_period=c.claim_period | a.claim_period-1=c.claim_period)
	order by a.ID, a.date, b.date, c.date
	;
	quit;
	proc sql;
	create table temp_&&DrugA._&&DrugB._&DrugC._1 as 
	select 	ID , period_&DrugA, period_&DrugB, period_&DrugC, CLAIM_PERIOD_STR_DT, CLAIM_PERIOD_END_DT,  
			DATE_&DrugA , DATE_&DrugB, DATE_&DrugC, abs(DATE_&DrugB-DATE_&DrugA) as DIFF1, abs(DATE_&DrugC-DATE_&DrugA) as DIFF2,
			(case when calculated DIFF1<=&GAP. & calculated DIFF2<=&GAP.  then 1 else 0 end) as FLAG
	from temp_&&DrugA._&&DrugB._&DrugC.
	order by ID , DATE_&DrugA
	;
	quit;
	proc sql;
	create table temp_&&DrugA._&&DrugB._&DrugC._2 as 
	select distinct ID, period_&DrugA as CLAIM_PERIOD , max(FLAG) as &VarName.
	from temp_&&DrugA._&&DrugB._&DrugC._1
	group by ID , CLAIM_PERIOD
	order by ID , CLAIM_PERIOD
	;
	quit;
	proc sort data=temp_&&DrugA._&&DrugB._&DrugC._2 (keep=ID CLAIM_PERIOD &VarName.) out=&dsout. nodupkey; 
	by ID CLAIM_PERIOD &VarName. ;
	run;
	proc delete data=temp_&DrugA temp_&DrugB temp_&DrugC temp_&DrugA._1 temp_&DrugB._1 temp_&DrugC._1  temp_&&DrugA._&&DrugB._&DrugC. temp_&&DrugA._&&DrugB._&DrugC._1 temp_&&DrugA._&&DrugB._&DrugC._2; run;
	%mend;
	%identify_overlap_order_3drug (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_BZD_MUS_3D, RXCUI, NONIVOUD, BZD, MUSCLERELAX, 3,OVERLAP_OPI_BZD_MUS_3D);
	%identify_overlap_order_3drug (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_BZD_MUS_7D, RXCUI, NONIVOUD, BZD, MUSCLERELAX, 7,OVERLAP_OPI_BZD_MUS_7D);
	%identify_overlap_order_3drug (primary.RX_MERGE_RXCUI, DS_Overlap_OPI_BZD_MUS_14D, RXCUI, NONIVOUD, BZD, MUSCLERELAX, 14,OVERLAP_OPI_BZD_MUS_14D);

	data temp.COHORT_OVERLAP;        
	merge 	DS_OVERLAP_OPI_BZD_3D DS_OVERLAP_OPI_BZD_7D DS_OVERLAP_OPI_BZD_14D
			DS_OVERLAP_OPI_MUS_3D DS_OVERLAP_OPI_MUS_7D DS_OVERLAP_OPI_MUS_14D
			DS_OVERLAP_OPI_GABA_3D DS_OVERLAP_OPI_GABA_7D DS_OVERLAP_OPI_GABA_14D
			DS_OVERLAP_BZD_BUP_3D DS_OVERLAP_BZD_BUP_7D DS_OVERLAP_BZD_BUP_14D
			DS_OVERLAP_OPI_BZD_MUS_3D DS_OVERLAP_OPI_BZD_MUS_7D DS_OVERLAP_OPI_BZD_MUS_14D
			;
	by ID CLAIM_PERIOD;
	run;

/*	Opioid use pattern	------------------------------------------------------------------------------------------------------------*/

	proc sql;
	create table OPIPATTERN  as
	select 	a.ID, floor((b.DATE-a.INDEX_DATE)/91.25)+1 as CLAIM_PERIOD, a.INDEX_DATE as OPIOID_START_DT, b.*
	from primary.bene as a
	left join  primary.RX_MERGE_RXCUI 
			(where=(RXCUI_SOURCE in ('NONIVOUD','NALOXONE','NALTREXONE','BZD','GABAPEN',
			'ANTIDEPRESS','BUPRE','MUSCLERELAX','IV','OUD'))) as b on a.ID=b.ID
	where calculated CLAIM_PERIOD>=0
	;
	quit;
	proc sql;
	create table temp.OPIPATTERN_3M  as
	select 	distinct ID, CLAIM_PERIOD, OPIOID_START_DT, 
			sum(SA_LA='SA') 																as NRX_SAO,
			sum(SA_LA='LA') 																as NRX_LAO,
			sum(SA_LA='SA' | SA_LA='LA')												as NRX_OPIOID,
			sum(SUPPLY>30 & SA_LA='SA') 												as N30DRX_SAO,
			sum(SUPPLY>30 & SA_LA='LA') 												as N30DRX_LAO,
			sum(SUPPLY>30)																as N30DRX_OPIOID,
			sum(SUPPLY/30 * (SA_LA='SA'))												as CUM_DUR30D_SAO,
			sum(SUPPLY/30 * (SA_LA='LA'))												as CUM_DUR30D_LAO,
			calculated CUM_DUR30D_SAO + calculated CUM_DUR30D_LAO							as CUM_DUR30D_OPIOID,
			sum(SUPPLY * (SA_LA='SA'))													as DAYS_SUPPLY_SAO,
			sum(SUPPLY * (SA_LA='LA'))													as DAYS_SUPPLY_LAO,
			sum(substr(DRUG,1,8)='fentanyl' & SA_LA='SA')								as NRX_FENTANYL_SA,
			sum(substr(DRUG,1,8)='fentanyl' & SA_LA='LA')								as NRX_FENTANYL_LA,
			calculated NRX_FENTANYL_SA + calculated NRX_FENTANYL_LA							as NRX_FENTANYL,
			sum(substr(DRUG,1,8)='tramadol' & SA_LA='SA')								as NRX_TRAMADOL_SA,
			sum(substr(DRUG,1,8)='tramadol' & SA_LA='LA')								as NRX_TRAMADOL_LA,
			calculated NRX_TRAMADOL_SA + calculated NRX_TRAMADOL_LA							as NRX_TRAMADOL,
			sum(substr(DRUG,1,10)='tapentadol' & SA_LA='SA')							as NRX_TAPENTADOL_SA,
			sum(substr(DRUG,1,10)='tapentadol' & SA_LA='LA')							as NRX_TAPENTADOL_LA,
			calculated NRX_TAPENTADOL_SA + calculated NRX_TAPENTADOL_LA						as NRX_TAPENTADOL,
			sum((substr(DRUG,1,11)='hydrocodone')&(SA_LA='SA'))							as NRX_HYDROCODONE_SA,
			sum((substr(DRUG,1,11)='hydrocodone')&(SA_LA='LA'))							as NRX_HYDROCODONE_LA,
			calculated NRX_HYDROCODONE_SA + calculated NRX_HYDROCODONE_LA					as NRX_HYDROCODONE,
			sum((substr(DRUG,1,13)='hydromorphone') & (SA_LA='SA'))						as NRX_HYDROMORPHONE_SA,
			sum((substr(DRUG,1,13)='hydromorphone') & (SA_LA='LA'))						as NRX_HYDROMORPHONE_LA,
			calculated NRX_HYDROMORPHONE_SA + calculated NRX_HYDROMORPHONE_LA				as NRX_HYDROMORPHONE,
			sum((substr(DRUG,1,8)='morphine') & (SA_LA='LA'))							as NRX_MORPHINE_LA,
			sum((substr(DRUG,1,8)='morphine') & (SA_LA='SA'))							as NRX_MORPHINE_SA,
			calculated NRX_MORPHINE_SA + calculated NRX_MORPHINE_LA							as NRX_MORPHINE,
			sum((substr(DRUG,1,9)='oxycodone') & (SA_LA='LA'))							as NRX_OXYCODONE_LA,
			sum((substr(DRUG,1,9)='oxycodone') & (SA_LA='SA'))							as NRX_OXYCODONE_SA,
			calculated NRX_OXYCODONE_SA + calculated NRX_OXYCODONE_LA						as NRX_OXYCODONE,
			sum((substr(DRUG,1,11)='oxymorphone') & (SA_LA='LA'))						as NRX_OXYMORPHONE_LA,
			sum((substr(DRUG,1,11)='oxymorphone') & (SA_LA='SA'))						as NRX_OXYMORPHONE_SA,
			calculated NRX_OXYMORPHONE_SA + calculated NRX_OXYMORPHONE_LA					as NRX_OXYMORPHONE,
			sum(DRUG='acetaminophen-Codeine')												as NRX_ACET_CODEINE,
			sum(DRUG='hydrocodone-Acetaminophen')											as NRX_ACET_HYDROCODONE,
			sum(DRUG='buprenorphine')														as NRX_BUPRE_PAIN,
			sum(DRUG='butorphanol') 														as NRX_BUTORPHANOL,
			sum(DRUG='codeine')															as NRX_CODEINE,
			sum(DRUG='dihydrocodeine')													as NRX_DIHYDROCODEINE,
			sum(DRUG='levorphanol')														as NRX_LEVOPHANOL,
			sum(substr(DRUG,1,10)='meperidine')											as NRX_MEPERIDINE,
			sum(DRUG='methadone')															as NRX_METHADONE,
			sum((substr(DRUG,1,11)='pentazocine'))										as NRX_PENTAZOCINE,
			sum(DOSAGE_FORM in ('SOLN','solution','LIQD','ELIX','CONC','SUSPS'))			as NRX_OPI_SOLUTION,
			count(distinct RX_PROVIDERID) 											as N_OPI_PRESCRIBERS,
/*			count(distinct DISPENSING_PROVIDER) 											as N_OPI_PHARMACIES,*/
			sum(ABUSE_DETERRENT)															as N_OPI_ABUSE_DETERRENT,
			/*	Add iv and cold/cough opioid use flag (# prescription)	*/
			sum(RXCUI_SOURCE='IV'|RXCUI_SOURCE='OUD'|RXCUI_SOURCE='NONIVOUD')	 		as NRX_NONIV_IV_COLD,
			sum(RXCUI_SOURCE='IV')	 													as NRX_IV,
			sum(RXCUI_SOURCE='OUD')		 												as NRX_COLD,
			sum(RXCUI_SOURCE='NALOXONE') 													as NRX_NALOXONE,
			sum(RXCUI_SOURCE='NALTREXONE') 												as NRX_NALTREXONE,
			sum(RXCUI_SOURCE='BZD') 														as NRX_BZD,
			sum(RXCUI_SOURCE='GABAPEN') 													as NRX_GABA,
			sum(RXCUI_SOURCE='ANTIDEPRESS') 												as NRX_ANTIDEPRESS,
			sum(RXCUI_SOURCE='MUSCLERELAX') 												as NRX_MUS,
			max(RXCUI_SOURCE='BUPRE') 													as MAT_BUP,
			sum(RXCUI_SOURCE='BUPRE') 													as NRX_MAT_BUP,
			sum((RXCUI_SOURCE='BUPRE')*SUPPLY) 											as DAYS_SUPPLY_MAT_BUP,
			sum((RXCUI_SOURCE='GABAPEN')*SUPPLY) 										as DAYS_SUPPLY_GABA,
			sum((RXCUI_SOURCE='ANTIDEPRESS')*SUPPLY) 									as DAYS_SUPPLY_ANTIDEPRESS
	from OPIPATTERN
	group by ID, CLAIM_PERIOD
	order by ID, CLAIM_PERIOD
	;
	quit;

/*	Opioid type		----------------------------------------------------------------------------------------------------------------*/
	proc sql;
	create table temp.COHORT_MERGE_RXCUI as
	select  a.ID, 
			a.INDEX_DATE as OPIOID_START_DT format=yymmdd10., 
			floor((b.DATE-a.INDEX_DATE)/91.25)+1 						as CLAIM_PERIOD ,
			a.INDEX_DATE+floor((calculated CLAIM_PERIOD-1)*91.25) 		as CLAIM_PERIOD_STR_DT format=yymmdd10.,
			a.INDEX_DATE+floor((calculated CLAIM_PERIOD  )*91.25) 		as CLAIM_PERIOD_END_DT format=yymmdd10.,
			b.DATE format=yymmdd10., 
			b.RX_PROVIDERID, B.RXCUI,
			b.RXCUI_SOURCE, b.DRUG,  b.QUANTITY, b.SUPPLY,  b.DOSAGE_FORM,  b.ABUSE_DETERRENT, b.SA_LA, 
			(case when b.RXCUI_SOURCE = 'NONIVOUD' & b.MME_CONVERSION_FACTOR  =. then 0 else b.MME_CONVERSION_FACTOR end) as MME_CONVERSION_FACTOR,
			(case when b.RXCUI_SOURCE = 'NONIVOUD' & b.drug='Hydrocodone-Acetaminophen' & b.DOSAGE_FORM = 'Oral Solution' then b.STRENGTH_PER_UNIT/15 else b.STRENGTH_PER_UNIT end) as STRENGTH_PER_UNIT,
			(case when year(b.DATE) = 2016 then DEA_2016 when year(b.DATE) = 2017 then DEA_2017 when year(b.DATE) = 2018 then DEA_2018 when year(b.DATE) = 2019 then DEA_2019 when year(b.DATE) = 2020 then DEA_2020 else DEA_2020 end )as DEACLASS
	from primary.bene as a
	inner join primary.RX_MERGE_RXCUI as b on a.ID=b.ID
	where calculated CLAIM_PERIOD>=0 & IP_OP="OP"
	order by ID, DATE
	;
	quit;
	

	proc sql;
	create table temp.TYPE_OPIOIDS as
	select a.ID, a.CLAIM_PERIOD,
		(case
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='SA' & DEACLASS=1 	then 1
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='SA' & DEACLASS=2 	then 2
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='SA' & DEACLASS=3 	then 3
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='SA' & DEACLASS=4 	then 4
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='LA' & DEACLASS=1 	then 5
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='LA' & DEACLASS=2 	then 6
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='LA' & DEACLASS=3 	then 7
			when N_SA_LA=1 & N_DEACLASS=1 & SA_LA='LA' & DEACLASS=4 	then 8
			when N_SA_LA=1 & N_DEACLASS>1 & SA_LA='SA' 					then 9
			when N_SA_LA=1 & N_DEACLASS>1 & SA_LA='LA' 					then 10
			when N_SA_LA>1 & N_DEACLASS>1 								then 11
			when (N_SA_LA>1 & N_DEACLASS=1) | (DEACLASS=5) 				then 12	/* Add the 12th opioid prescription pattern type*/
			end) as TYPE_OPIOIDS
	from 	(select distinct SA_LA, ID, CLAIM_PERIOD, count(distinct SA_LA) as N_SA_LA 			from temp.cohort_MERGE_RXCUI (where=(RXCUI_SOURCE='NONIVOUD')) group by ID, CLAIM_PERIOD) as a,
			(select distinct DEACLASS, ID, CLAIM_PERIOD, count(distinct DEACLASS) as N_DEACLASS   from temp.cohort_MERGE_RXCUI (where=(RXCUI_SOURCE='NONIVOUD')) group by ID, CLAIM_PERIOD) as b
	where a.ID = b.ID & a.CLAIM_PERIOD = b.CLAIM_PERIOD & a.SA_LA ^= '' & b.DEACLASS ^= .
	;
	quit;
	%undupsortNew(temp.TYPE_OPIOIDS,,ID CLAIM_PERIOD);

/*	Calculate opioid coverage indicator	(Note that DAYS_OF_SUPPLY in ORDERS data is not reliable, which could affect the calculation)	----------------------------------------------------------------------------------------*/
/*	2018-2020 > 2018-2023 Total days: 1096+1095 (for 2021 to 2023)= 2191	*/
	
	%undupsortNew(TEMP.COHORT_MERGE_RXCUI,,ID CLAIM_PERIOD DATE);

	%macro calCvrgDts(dsin);
	data 	dsTemp_OPIOID 		(keep=ID OPIOID_START_DT OPIOID_DATE_:) 
			dsTemp_SAO 			(keep=ID OPIOID_START_DT SAO_DATE_:)
			dsTemp_LAO 			(keep=ID OPIOID_START_DT LAO_DATE_:)
			dsTemp_BUP 			(keep=ID OPIOID_START_DT BUP_DATE_:)
			dsTemp_GABA 		(keep=ID OPIOID_START_DT GABA_DATE_:)
			dsTemp_DPRS 		(keep=ID OPIOID_START_DT DPRS_DATE_:)
			dsTemp_OPI_BZD 		(keep=ID OPIOID_START_DT OPI_BZD_DATE_:)
			dsTemp_OPI_MUS 		(keep=ID OPIOID_START_DT OPI_MUS_DATE_:)
			dsTemp_OPI_BZD_MUS 	(keep=ID OPIOID_START_DT OPI_BZD_MUS_DATE_:);
		set &dsin.;	
		total_MME = 0;
		array dateArray 				(2191) DATE_1 - DATE_2191;
		array dateArray_OPIOID 			(2191) OPIOID_DATE_1 - OPIOID_DATE_2191;
		array dateArray_SAO 			(2191) SAO_DATE_1 - SAO_DATE_2191;
		array dateArray_LAO 			(2191) LAO_DATE_1 - LAO_DATE_2191;
		array dateArray_BUP 			(2191) BUP_DATE_1 - BUP_DATE_2191;
		array dateArray_BZD 			(2191) BZD_DATE_1 - BZD_DATE_2191;
		array dateArray_MUS 			(2191) MUS_DATE_1 - MUS_DATE_2191;
		array dateArray_GABA 			(2191) GABA_DATE_1 - GABA_DATE_2191;
		array dateArray_DPRS			(2191) DPRS_DATE_1 - DPRS_DATE_2191;

		array dateArray_OPI_BZD 		(2191) OPI_BZD_DATE_1 - OPI_BZD_DATE_2191;
		array dateArray_OPI_MUS 		(2191) OPI_MUS_DATE_1 - OPI_MUS_DATE_2191;
		array dateArray_OPI_BZD_MUS 	(2191) OPI_BZD_MUS_DATE_1 - OPI_BZD_MUS_DATE_2191;

		retain OPIOID_DATE_: SAO_DATE_: LAO_DATE_: BUP_DATE_: BZD_DATE_: MUS_DATE_: GABA_DATE_: DPRS_DATE_: ;
		do i = 1 to 2191;
			if (date  <= ('31Dec2017'd + i) <= (date + supply - 1)) then do;
					dateArray(i)=1; 
	/*				if RXCUI_SOURCE = 'NONIVOUD' then total_MME = total_MME + QTY_DSPNSD_NUM*STRENGTH_PER_UNIT*MME_CONVERSION_FACTOR/DAYS_SUPLY_NUM; */
				end;
			else dateArray(i)=0;
			if first.ID then do;
				dateArray_OPIOID(i) = 0; 
				dateArray_SAO(i) = 0;
				dateArray_LAO(i) = 0;
				dateArray_BUP(i) = 0;
				dateArray_BZD(i) = 0;
				dateArray_MUS(i) = 0;
				dateArray_GABA(i) = 0;
				dateArray_DPRS(i) = 0;
				end;
			if RXCUI_SOURCE = 'NONIVOUD' 							then dateArray_OPIOID(i) = dateArray_OPIOID(i) | dateArray(i);
			if RXCUI_SOURCE = 'NONIVOUD' & SA_LA = 'SA' 			then dateArray_SAO(i) = dateArray_SAO(i) | dateArray(i);
			if RXCUI_SOURCE = 'NONIVOUD' & SA_LA = 'LA' 			then dateArray_LAO(i) = dateArray_LAO(i) | dateArray(i);
			if RXCUI_SOURCE = 'BUPRE'	 							then dateArray_BUP(i) = dateArray_BUP(i) | dateArray(i);
			if RXCUI_SOURCE = 'BZD' 								then dateArray_BZD(i) = dateArray_BZD(i) | dateArray(i);
			if RXCUI_SOURCE = 'MUSCLERELAX' 						then dateArray_MUS(i) = dateArray_MUS(i) | dateArray(i);
			if RXCUI_SOURCE = 'GABAPEN' 							then dateArray_GABA(i) = dateArray_GABA(i) | dateArray(i);
			if RXCUI_SOURCE = 'ANTIDEPRESS' 						then dateArray_DPRS(i) = dateArray_DPRS(i) | dateArray(i);
			dateArray_OPI_BZD(i) = dateArray_OPIOID(i) & dateArray_BZD(i);
			dateArray_OPI_MUS(i) = dateArray_OPIOID(i) & dateArray_MUS(i);
			dateArray_OPI_BZD_MUS(i) = dateArray_OPIOID(i) & dateArray_BZD(i) & dateArray_MUS(i);
		end;	
		by ID;
		if last.ID;
	run;	
	%mend;
	%calCvrgDts(TEMP.COHORT_MERGE_RXCUI(where=(RXCUI_SOURCE in ('NONIVOUD','BUPRE','BZD','MUSCLERELAX','GABAPEN','ANTIDEPRESS'))));

	%macro calContCvrgDts(dsin,dsout,prefix);
	data &dsout.;
		set &dsin.;
		array dateArray 		(2191) 	&prefix.1 - &prefix.2191;
		array claimPeriodArray	(50)	CUM_DUR_1 - CUM_DUR_50;
		array contDts_0_Array	(50)	CONT_DATES_0_1 - CONT_DATES_0_50;
		array contDts_1_Array	(50)	CONT_DATES_1_1 - CONT_DATES_1_50;
		array maxContDts_Array	(50)	CONT_DUR_1 - CONT_DUR_50;
		do i = 1 to 50;
			claimPeriodArray(i) = 0;
			contDts_0_Array(i) = 0;
			contDts_1_Array(i) = 0;
			maxContDts_Array(i) = 0;
		end;
		do i = 1 to 2191;
			j = floor(((i + '31Dec2017'd -OPIOID_START_DT)/91.25)+1 + 25);
			claimPeriodArray(j) = claimPeriodArray(j) + (dateArray(i)>0);
			if dateArray(i) = 0 then do;
				contDts_0_Array(j) = contDts_0_Array(j) + 1; 
				if contDts_0_Array(j) > 31 then do;
					contDts_1_Array(j) = 0;
					end;
				end;
			else 
			do;
				contDts_1_Array(j) = contDts_1_Array(j) + 1;
				maxContDts_Array(j) = max(maxContDts_Array(j),contDts_1_Array(j));
				contDts_0_Array(j) = 0; 
			end;
		end;
		drop i j &prefix.:;
	run;
	proc transpose data=&dsout. out=&dsout._cum_dur;	by ID;	var CUM_DUR_:;	run;
	data &dsout._cum_dur (drop=_name_);	set &dsout._cum_dur;	CLAIM_PERIOD=input(substr(_name_, 9), 5.)-25;	if CLAIM_PERIOD>0;	run;
	proc transpose data=&dsout. out=&dsout._cont_dur;	by ID;	var CONT_DUR_:;	run;
	data &dsout._cont_dur (drop=_name_);	set &dsout._cont_dur;	CLAIM_PERIOD=input(substr(_name_, 10), 5.)-25;	if CLAIM_PERIOD>0;	run;
	%mend;
	%calContCvrgDts(dsTemp_OPIOID,OPIOID_cvrg,OPIOID_DATE_);
	%calContCvrgDts(dsTemp_SAO,SAO_cvrg,SAO_DATE_);
	%calContCvrgDts(dsTemp_LAO,LAO_cvrg,LAO_DATE_);
	%calContCvrgDts(dsTemp_BUP,BUP_cvrg,BUP_DATE_);
	%calContCvrgDts(dsTemp_GABA,GABA_cvrg,GABA_DATE_);
	%calContCvrgDts(dsTemp_DPRS,DPRS_cvrg,DPRS_DATE_);
	%calContCvrgDts(dsTemp_OPI_BZD,OPI_BZD_cvrg,OPI_BZD_DATE_);
	%calContCvrgDts(dsTemp_OPI_MUS,OPI_MUS_cvrg,OPI_MUS_DATE_);
	%calContCvrgDts(dsTemp_OPI_BZD_MUS,OPI_BZD_MUS_cvrg,OPI_BZD_MUS_DATE_);
	%procsort(PRIMARY.RX_MERGE_RXCUI,,ID DATE);
	%macro calMME();
	data OPIOID_MME (keep=ID MME_:);
		set temp.cohort_MERGE_RXCUI (where=(RXCUI_SOURCE = 'NONIVOUD'));	
		array Array_MME 	(50) MME_1 - MME_50;
		retain MME_1 - MME_50;
		if first.ID then do;
			do i = 1 to 50;
				Array_MME(i) = 0;
			end;
		end;
		do i = 1 to 2191;
			if (date <= ('31Dec2016'd + i) <= (date + supply - 1)) then do;
				j = floor(((i + '31Dec2016'd -OPIOID_START_DT)/91.25)+1 + 25);
				Array_MME(j)=Array_MME(j)+quantity*STRENGTH_PER_UNIT*MME_CONVERSION_FACTOR/supply;
				end;
		end;	
		by ID;
		if last.ID;
		drop MME_CONVER:
	run;	
	proc transpose data=OPIOID_MME out=OPIOID_MME_long;	by ID;	var MME_:;	run;
	data OPIOID_MME (drop=_name_);	set OPIOID_MME_long;	CLAIM_PERIOD=input(substr(_name_, 5), 5.)-25;	if CLAIM_PERIOD>0;	run;
	%mend;
	%calMME;

/*	Calculate early refill days		------------------------------------------------------------------------------------------------*/

	%macro calEarlyRefill(dsin,dsout);
	proc sql;
	create table dsTemp as
	select ID, CLAIM_PERIOD, DATE, CLAIM_PERIOD_END_DT format=DATE9., max(SUPLY_END_DT) as SUPLY_END_DT format=DATE9.
	from (select ID, CLAIM_PERIOD, DATE , OPIOID_START_DT+floor(CLAIM_PERIOD*91.25)-1 as CLAIM_PERIOD_END_DT, 
			DATE+SUPPLY as SUPLY_END_DT from &dsin. where RXCUI_SOURCE='NONIVOUD')
	group by ID, CLAIM_PERIOD, DATE, CLAIM_PERIOD_END_DT;

	data &dsout.;
		set dsTemp;
		retain PREV_SUPLY_END_DT CDAYS_EARLY_REFILL NRX_EARLY_REFILL;
		by ID CLAIM_PERIOD;
		if first.ID then do;
			OVERLAP_DS = 0;
			EARLYREFILL = 0; end;
		else do;
			if DATE <= PREV_SUPLY_END_DT & (SUPLY_END_DT-DATE>=3) then DATE=DATE+3;
			if DATE <= PREV_SUPLY_END_DT then do;
				OVERLAP_DS = min(PREV_SUPLY_END_DT,SUPLY_END_DT) - DATE + 1;
				EARLYREFILL = 1; end;
			else do;
				OVERLAP_DS = 0;
				EARLYREFILL = 0; end;
		end;
		if SUPLY_END_DT > CLAIM_PERIOD_END_DT then PREV_SUPLY_END_DT = CLAIM_PERIOD_END_DT;
		else do;
			if first.ID then PREV_SUPLY_END_DT = SUPLY_END_DT;
			else PREV_SUPLY_END_DT = max(PREV_SUPLY_END_DT,SUPLY_END_DT);
		end;
		if first.CLAIM_PERIOD then do;
			CDAYS_EARLY_REFILL = OVERLAP_DS;
			NRX_EARLY_REFILL = EARLYREFILL;
		end;
		else do;
			CDAYS_EARLY_REFILL = CDAYS_EARLY_REFILL+OVERLAP_DS;
			NRX_EARLY_REFILL = NRX_EARLY_REFILL+EARLYREFILL;
		end;
		format PREV_SUPLY_END_DT DATE9.;
		if last.CLAIM_PERIOD;
	run;
	%mend;
	%calEarlyRefill(temp.cohort_merge_rxcui ,dsTemp_opioid_earlyRefill(keep=ID CLAIM_PERIOD CDAYS_EARLY_REFILL NRX_EARLY_REFILL ));

	data temp.opipattern2_3m;
		merge	Opioid_cvrg_cum_dur			(rename=(COL1=CUM_DUR_OPIOID) where=(CUM_DUR_OPIOID^=0) in=a)
				Opioid_cvrg_cont_dur		(rename=(COL1=CONT_DUR_OPIOID))
				SAO_cvrg_cum_dur			(rename=(COL1=CUM_DUR_SAO))
				SAO_cvrg_cont_dur			(rename=(COL1=CONT_DUR_SAO))
				LAO_cvrg_cum_dur			(rename=(COL1=CUM_DUR_LAO))
				LAO_cvrg_cont_dur			(rename=(COL1=CONT_DUR_LAO))
				Opioid_mme					(rename=(COL1=TOTAL_MME))
				Bup_cvrg_cum_dur			(rename=(COL1=MAT_BUPRE_DUR) where=(MAT_BUPRE_DUR^=0) in=b)
				GABA_cvrg_cum_dur			(rename=(COL1=CUM_DUR_GABA))
				DPRS_cvrg_cum_dur			(rename=(COL1=CUM_DUR_DPRS))
				Opi_bzd_cvrg_cum_dur		(rename=(COL1=DAYS_OPI_BZD))
				Opi_mus_cvrg_cum_dur		(rename=(COL1=DAYS_OPI_MUSCLE))
				Opi_bzd_mus_cvrg_cum_dur	(rename=(COL1=DAYS_OPI_BZD_MUSCLE))
				Dstemp_opioid_earlyrefill	
		;
		by ID CLAIM_PERIOD;
		AVG_MME = TOTAL_MME/CUM_DUR_OPIOID;
	/*	if AVG_MME ^= . | MAT_BUPRE_DUR ^=0;*/
		if a | b;
	run;

	/*	Get daily MME	*/
	%macro getDailyDose(dsin,dsout,source,daysRange);
	data &dsout. (keep=ID RXCUI_SOURCE INDEX_DT MME_PERDAY SUPPLY DAILY_DOSE_:);
		set &dsin. (where=(RXCUI_SOURCE="&source."));
		array DAILY_DOSE (2191) DAILY_DOSE_1-DAILY_DOSE_2191;
		retain DAILY_DOSE_: INDEX_DT;
		MME_PERDAY = quantity*Strength_Per_Unit*MME_Conversion_Factor/SUPPLY;
		do i=1 to 2191;	
			DATE_TEMP = '01Jan2017'd + i - 1;
			if first.ID then do; DAILY_DOSE(i) = 0; INDEX_DT=DATE; end;
			if (DATE_TEMP >= DATE) & (DATE_TEMP < (DATE+SUPPLY)) then DAILY_DOSE(i)+MME_PERDAY;
		end;
		format INDEX_DT DATE9.;
		if last.ID;
		by ID;
	run;
	%mend;
	%getDailyDose(temp.cohort_MERGE_RXCUI,temp.DAILYDOSE_NONIVOUD,NONIVOUD);
	proc transpose data=temp.DAILYDOSE_NONIVOUD(keep=ID DAILY_DOSE_:) out=temp.DAILYDOSE_NONIVOUD_L; by ID ;	var DAILY_DOSE_:; run;
	data TEMP.DAILYDOSE_NONIVOUD_L(drop=_name_ );retain ID DATE; set temp.DAILYDOSE_NONIVOUD_L(rename=(col1=DAILY_DOSE));format date DATE9.;  DATE='31Dec2016'd+put(substr(_name_,12,4),8.); where DAILY_DOSE^=0; run;
/*	------------------------------------------------------------------------------------------------------
	[Identify comorbidities using EHR lab data]
  	------------------------------------------------------------------------------------------------------*/

	/*Patient reported outcome (PRO)*/
	proc sql;
	create table temp.COHORT_LAB as 
	select b.ID, a.INDEX_DATE as OPIOID_START_DT, floor((b.LAB_ORDER_DATE-a.INDEX_DATE)/91.25)+1 as CLAIM_PERIOD, 
			b.LAB_ORDER_DATE, b.SPECIMEN_DATE, b.RAW_LAB_NAME, b.LAB_LOINC, input(b.NORM_RANGE_low,8.) as NORM_RANGE_low, b.RESULT_NUM, input(b.NORM_RANGE_High,8.) as NORM_RANGE_High, b.RESULT_QUAL, b.ABN_IND, b.RESULT_UNIT,
			b.LAB_RESULT_CM_ID, b.ENCOUNTERID, b.source
	from primary.bene as a
	inner join fl.emr_lab (where=(2016<=year(LAB_ORDER_DATE)<=2022 & SOURCE not in ('CHP','FLM'))) as b on a.ID=b.ID
	order by ID, LAB_ORDER_DATE, LAB_LOINC, RAW_LAB_NAME
	;
	quit;

	data temp.COHORT_LAB; set temp.COHORT_LAB; if CLAIM_PERIOD>=0; run;

	%macro identify_LOINC_comorb(dsin, dsout);
	proc import out=ds_LOINC datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/DEMONSTRATE_Data Dictionary_20221212.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="LOINC_PRO";	run;
	data ds_LOINC; set ds_LOINC; if CODE_SAS ^= ''; run;
	proc sql noprint; Select distinct(upcase(VARIABLE)) into :varList_LOINC separated by ' ' from ds_LOINC;
	%put &varList_LOINC.;
	%do k=1 %to %sysfunc(countw(&varList_LOINC,' '));
		%let dxTemp = %scan(&varList_LOINC, &k,' ');
		data LOINCList_&dxtemp.(keep=CODE_SAS); set ds_LOINC (where=(upcase(VARIABLE)="&dxtemp.")); run;
		%undupsortNew(LOINCList_&dxtemp.,LOINCList_&dxtemp.,CODE_SAS);
		proc sql noprint; Select "'"||CATS(CODE_SAS)||"'" into :STR_LOINC_&dxtemp. separated by ' ' from LOINCList_&dxtemp.;
	%end;

	data &dsout.;
	set	&dsin.;
	%do k=1 %to %sysfunc(countw(&varList_LOINC,' '));
       	%let dxTemp = %scan(&varList_LOINC, &k,' ');
		LAB_&dxtemp.=0;
		if LAB_LOINC in (&&STR_LOINC_&dxtemp.) then LAB_&dxtemp.=1;
   	%end;
	keep ID CLAIM_PERIOD LAB_:;
	drop LAB_ORDER_DATE LAB_LOINC LAB_RESULT_CM_ID RAW_LAB_NAME;
	run;
	%mend;
	%identify_LOINC_comorb(temp.COHORT_LAB,temp.COHORT_LAB_COMORB);
	
	%anyGrpBy(temp.cohort_LAB_COMORB, temp.cohort_LAB_COMORB_3M,ID CLAIM_PERIOD);

/*	------------------------------------------------------------------------------------------------------
	[Create urine drug test related variable using EHR lab data]
	Selected drug for URINE_DURG_TEST BY LOINC:
		Buprenorphine
		Butorphanol
		Codeine
		Drug
		Dihydrocodeine
		Diphenoxylate
		Fentanyl
		Hydrocodone
		Hydromorphone
		Levorphanol
		Meperidine
		Methardone
		Morphine
		Opiates
		Oxycodone
		Oxymorphone
		Pentazocine
		Propoxyphene
		Tapentadol
		Tramadol
		Narcotic

	(1) create “individual opioid medication flags” as follows:
	0=No test, 1=Yes (with normal results), 2=Yes (with abnormal results), 3=yes (with invalid/missing results or other results) "

	(2) 
	Any_urine_XXX (e.g., any_urinetest_bupre) 
	including any urine tests related to the specific drug, regardless of methods (e.g., screen vs. confirmatory).  "
	"Any_urine_confirm_XXX (e.g., any_urineconfirm_bupre): 
	flag any urine “confirmatory” tests related to the specific drug. "

	"Any_blood_XXX (e.g., any_bloodtest_bupre) 
	including any blood tests related to the specific drug, regardless of methods (e.g., screen vs. confirmatory).  "
	"Any_blood_confirm_XXX (e.g., any_bloodconfirm_bupre): 
	flag any blood “confirmatory” tests related to the specific drug. "

	"Any_other_XXX (e.g., any_bloodtest_bupre) 
	including any non-urine and non-blood tests related to the specific drug, regardless of methods (e.g., screen vs. confirmatory).  "

	(3)
	We will create “an overall opioid medication flags” as follows:
	"Any_urine_opiates 
	including any urine tests related to any opiates or narcotics, regardless of methods (e.g., screen vs. confirmatory).  Any flag =1 for individual drug in the #1 bullet will be included too."
	"Any_urine_confirm_opiates: 
	flag any urine “confirmatory” tests related to any opiates or narcotics. Any flag =1 for individual drug in the #1b, 1d bullets will be included too.  "
	"Any_other_opiates: 
	flag including any non-urine and non-blood tests related to any opiates or narcotics, regardless of methods (e.g., screen vs. confirmatory).  Any flag =1 for individual drug in the #1e bullet will be included too. "

	%procfreq(temp.bene_lab,ABN_IND/missing);
	ABN_IND Frequency 	Percent 
	  		27450 		0.08  
	AB 		428109 		1.24 	AB=Abnormal
	AH 		4712281 	13.68 	AH=Abnormally  high
	AL 		4141408 	12.02 	AL=Abnormally  low
	CH 		26792 		0.08 	CH=Critically  high
	CL 		28615 		0.08 	CL=Critically  low
	CR 		32380 		0.09	CR=Critical
	NI 		23516376 	68.25 	NI=No  information
	NL 		1348021 	3.91 	NL=Normal
	OT 		4703 		0.01	OT=Other
	UN 		191027 		0.55 	UN=Unknown
	IN 							IN=Inconclusive


	--------------------------------------------------------------------------------------------------------------------------------*/




	%macro identifyUrineDrugTest(dsin, dsout);

	/*Buprenorphine -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Buprenorphine_Urine=" "; /*If the macro variables already existed before the query, when SQL selects no rows, the value will remain unchanged.*/
	%let S_Confirm_Buprenorphine_Urine=" "; 
	%let S_Allcode_Buprenorphine_Blood=" "; 
	%let S_Confirm_Buprenorphine_Blood=" "; 
	%let S_Allcode_Buprenorphine_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Buprenorphine_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Buprenorphine_Urine";	run;
	data Loinc_Buprenorphine_Urine; set Loinc_Buprenorphine_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Buprenorphine_Urine separated by ' ' from Loinc_Buprenorphine_Urine ; quit;
	%put &S_Allcode_Buprenorphine_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Buprenorphine_Urine separated by ' ' from Loinc_Buprenorphine_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Buprenorphine_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Buprenorphine_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Buprenorphine_Others";	run;
	data Loinc_Buprenorphine_Others; set Loinc_Buprenorphine_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Buprenorphine_Blood separated by ' ' from Loinc_Buprenorphine_Others where System="Bld"; quit;
	%put &S_Allcode_Buprenorphine_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Buprenorphine_Blood separated by ' ' from Loinc_Buprenorphine_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Buprenorphine_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Buprenorphine_Others separated by ' ' from Loinc_Buprenorphine_Others where System^="Bld"; quit;
	%put &S_Allcode_Buprenorphine_Others.;

	/*Benzodiazepine -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Benzodiazepine_Urine=" "; 
	%let S_Confirm_Benzodiazepine_Urine=" "; 
	%let S_Allcode_Benzodiazepine_Blood=" "; 
	%let S_Confirm_Benzodiazepine_Blood=" "; 
	%let S_Allcode_Benzodiazepine_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Benzodiazepine_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Benzodiazepine_Urine";	run;
	data Loinc_Benzodiazepine_Urine; set Loinc_Benzodiazepine_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Benzodiazepine_Urine separated by ' ' from Loinc_Benzodiazepine_Urine ; quit;
	%put &S_Allcode_Benzodiazepine_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Benzodiazepine_Urine separated by ' ' from Loinc_Benzodiazepine_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Benzodiazepine_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Benzodiazepine_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Benzodiazepine_Others";	run;
	data Loinc_Benzodiazepine_Others; set Loinc_Benzodiazepine_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Benzodiazepine_Blood separated by ' ' from Loinc_Benzodiazepine_Others where System="Bld"; quit;
	%put &S_Allcode_Benzodiazepine_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Benzodiazepine_Blood separated by ' ' from Loinc_Benzodiazepine_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Benzodiazepine_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Benzodiazepine_Others separated by ' ' from Loinc_Benzodiazepine_Others where System^="Bld"; quit;
	%put &S_Allcode_Benzodiazepine_Others.;

	/*Barbiturate -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Barbiturate_Urine=" "; 
	%let S_Confirm_Barbiturate_Urine=" "; 
	%let S_Allcode_Barbiturate_Blood=" "; 
	%let S_Confirm_Barbiturate_Blood=" "; 
	%let S_Allcode_Barbiturate_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Barbiturate_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Barbiturate_Urine";	run;
	data Loinc_Barbiturate_Urine; set Loinc_Barbiturate_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Barbiturate_Urine separated by ' ' from Loinc_Barbiturate_Urine ; quit;
	%put &S_Allcode_Barbiturate_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Barbiturate_Urine separated by ' ' from Loinc_Barbiturate_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Barbiturate_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Barbiturate_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Barbiturate_Others";	run;
	data Loinc_Barbiturate_Others; set Loinc_Barbiturate_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Barbiturate_Blood separated by ' ' from Loinc_Barbiturate_Others where System="Bld"; quit;
	%put &S_Allcode_Barbiturate_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Barbiturate_Blood separated by ' ' from Loinc_Barbiturate_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Barbiturate_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Barbiturate_Others separated by ' ' from Loinc_Barbiturate_Others where System^="Bld"; quit;
	%put &S_Allcode_Barbiturate_Others.;

	/*Opiates -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Opiates_Urine=" "; 
	%let S_Confirm_Opiates_Urine=" "; 
	%let S_Allcode_Opiates_Blood=" "; 
	%let S_Confirm_Opiates_Blood=" "; 
	%let S_Allcode_Opiates_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Opiates_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Opiates_Urine";	run;
	data Loinc_Opiates_Urine; set Loinc_Opiates_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Opiates_Urine separated by ' ' from Loinc_Opiates_Urine ; quit;
	%put &S_Allcode_Opiates_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Opiates_Urine separated by ' ' from Loinc_Opiates_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Opiates_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Opiates_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Opiates_Others";	run;
	data Loinc_Opiates_Others; set Loinc_Opiates_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Opiates_Blood separated by ' ' from Loinc_Opiates_Others where System="Bld"; quit;
	%put &S_Allcode_Opiates_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Opiates_Blood separated by ' ' from Loinc_Opiates_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Opiates_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(loinc_num)||"'" into :S_Allcode_Opiates_Others separated by ' ' from Loinc_Opiates_Others where System^="Bld"; quit;
	%put &S_Allcode_Opiates_Others.;

	/*Drug -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Drug_Urine=" "; 
	%let S_Confirm_Drug_Urine=" "; 
	%let S_Allcode_Drug_Blood=" "; 
	%let S_Confirm_Drug_Blood=" "; 
	%let S_Allcode_Drug_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Drug_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Drug_Urine";	run;
	data Loinc_Drug_Urine; set Loinc_Drug_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Drug_Urine separated by ' ' from Loinc_Drug_Urine ; quit;
	%put &S_Allcode_Drug_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Drug_Urine separated by ' ' from Loinc_Drug_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Drug_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Drug_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Drug_Others";	run;
	data Loinc_Drug_Others; set Loinc_Drug_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Drug_Blood separated by ' ' from Loinc_Drug_Others where System="Bld"; quit;
	%put &S_Allcode_Drug_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Drug_Blood separated by ' ' from Loinc_Drug_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Drug_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Drug_Others separated by ' ' from Loinc_Drug_Others where System^="Bld"; quit;
	%put &S_Allcode_Drug_Others.;

	/*Butorphanol -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Butorphanol_Urine=" "; 
	%let S_Confirm_Butorphanol_Urine=" "; 
	%let S_Allcode_Butorphanol_Blood=" "; 
	%let S_Confirm_Butorphanol_Blood=" "; 
	%let S_Allcode_Butorphanol_Others=" "; 

	/*Any_urine_XXX*/
	proc import out=Loinc_Butorphanol_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Butorphanol_Urine";	run;
	data Loinc_Butorphanol_Urine; set Loinc_Butorphanol_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Butorphanol_Urine separated by ' ' from Loinc_Butorphanol_Urine ; quit;
	%put &S_Allcode_Butorphanol_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Butorphanol_Urine separated by ' ' from Loinc_Butorphanol_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Butorphanol_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Butorphanol_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Butorphanol_Others";	run;
	data Loinc_Butorphanol_Others; set Loinc_Butorphanol_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Butorphanol_Blood separated by ' ' from Loinc_Butorphanol_Others where System="Bld"; quit;
	%put &S_Allcode_Butorphanol_Blood.;
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Butorphanol_Blood separated by ' ' from Loinc_Butorphanol_Others where System="Bld"; quit;
	%put &S_Allcode_Butorphanol_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Butorphanol_Blood separated by ' ' from Loinc_Butorphanol_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Butorphanol_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Butorphanol_Others separated by ' ' from Loinc_Butorphanol_Others where System^="Bld"; quit;
	%put &S_Allcode_Butorphanol_Others.;

	/*Codeine -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Codeine_Urine=" "; 
	%let S_Confirm_Codeine_Urine=" "; 
	%let S_Allcode_Codeine_Blood=" "; 
	%let S_Confirm_Codeine_Blood=" "; 
	%let S_Allcode_Codeine_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Codeine_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Codeine_Urine";	run;
	data Loinc_Codeine_Urine; set Loinc_Codeine_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Codeine_Urine separated by ' ' from Loinc_Codeine_Urine ; quit;
	%put &S_Allcode_Codeine_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Codeine_Urine separated by ' ' from Loinc_Codeine_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Codeine_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Codeine_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Codeine_Others";	run;
	data Loinc_Codeine_Others; set Loinc_Codeine_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Codeine_Blood separated by ' ' from Loinc_Codeine_Others where System="Bld"; quit;
	%put &S_Allcode_Codeine_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Codeine_Blood separated by ' ' from Loinc_Codeine_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Codeine_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Codeine_Others separated by ' ' from Loinc_Codeine_Others where System^="Bld"; quit;
	%put &S_Allcode_Codeine_Others.;

	/*Dihydrocodeine -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Dihydrocodeine_Urine=" "; 
	%let S_Confirm_Dihydrocodeine_Urine=" "; 
	%let S_Allcode_Dihydrocodeine_Blood=" "; 
	%let S_Confirm_Dihydrocodeine_Blood=" "; 
	%let S_Allcode_Dihydrocodeine_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Dihydrocodeine_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Dihydrocodeine_Urine";	run;
	data Loinc_Dihydrocodeine_Urine; set Loinc_Dihydrocodeine_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Dihydrocodeine_Urine separated by ' ' from Loinc_Dihydrocodeine_Urine ; quit;
	%put &S_Allcode_Dihydrocodeine_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Dihydrocodeine_Urine separated by ' ' from Loinc_Dihydrocodeine_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Dihydrocodeine_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Dihydrocodeine_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Dihydrocodeine_Others";	run;
	data Loinc_Dihydrocodeine_Others; set Loinc_Dihydrocodeine_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Dihydrocodeine_Blood separated by ' ' from Loinc_Dihydrocodeine_Others where System="Bld"; quit;
	%put &S_Allcode_Dihydrocodeine_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Dihydrocodeine_Blood separated by ' ' from Loinc_Dihydrocodeine_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Dihydrocodeine_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Dihydrocodeine_Others separated by ' ' from Loinc_Dihydrocodeine_Others where System^="Bld"; quit;
	%put &S_Allcode_Dihydrocodeine_Others.;

	/*Diphenoxylate -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Diphenoxylate_Urine=" "; 
	%let S_Confirm_Diphenoxylate_Urine=" "; 
	%let S_Allcode_Diphenoxylate_Blood=" "; 
	%let S_Confirm_Diphenoxylate_Blood=" "; 
	%let S_Allcode_Diphenoxylate_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Diphenoxylate_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Diphenoxylate_Urine";	run;
	data Loinc_Diphenoxylate_Urine; set Loinc_Diphenoxylate_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Diphenoxylate_Urine separated by ' ' from Loinc_Diphenoxylate_Urine ; quit;
	%put &S_Allcode_Diphenoxylate_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Diphenoxylate_Urine separated by ' ' from Loinc_Diphenoxylate_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Diphenoxylate_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Diphenoxylate_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Diphenoxylate_Others";	run;
	data Loinc_Diphenoxylate_Others; set Loinc_Diphenoxylate_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Diphenoxylate_Blood separated by ' ' from Loinc_Diphenoxylate_Others where System="Bld"; quit;
	%put &S_Allcode_Diphenoxylate_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Diphenoxylate_Blood separated by ' ' from Loinc_Diphenoxylate_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Diphenoxylate_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Diphenoxylate_Others separated by ' ' from Loinc_Diphenoxylate_Others where System^="Bld"; quit;
	%put &S_Allcode_Diphenoxylate_Others.;

	/*Fentanyl -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Fentanyl_Urine=" "; 
	%let S_Confirm_Fentanyl_Urine=" "; 
	%let S_Allcode_Fentanyl_Blood=" "; 
	%let S_Confirm_Fentanyl_Blood=" "; 
	%let S_Allcode_Fentanyl_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Fentanyl_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Fentanyl_Urine";	run;
	data Loinc_Fentanyl_Urine; set Loinc_Fentanyl_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Fentanyl_Urine separated by ' ' from Loinc_Fentanyl_Urine ; quit;
	%put &S_Allcode_Fentanyl_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Fentanyl_Urine separated by ' ' from Loinc_Fentanyl_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Fentanyl_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Fentanyl_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Fentanyl_Others";	run;
	data Loinc_Fentanyl_Others; set Loinc_Fentanyl_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Fentanyl_Blood separated by ' ' from Loinc_Fentanyl_Others where System="Bld"; quit;
	%put &S_Allcode_Fentanyl_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Fentanyl_Blood separated by ' ' from Loinc_Fentanyl_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Fentanyl_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Fentanyl_Others separated by ' ' from Loinc_Fentanyl_Others where System^="Bld"; quit;
	%put &S_Allcode_Fentanyl_Others.;

	/*Hydrocodone -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Hydrocodone_Urine=" "; 
	%let S_Confirm_Hydrocodone_Urine=" "; 
	%let S_Allcode_Hydrocodone_Blood=" "; 
	%let S_Confirm_Hydrocodone_Blood=" "; 
	%let S_Allcode_Hydrocodone_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Hydrocodone_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Hydrocodone_Urine";	run;
	data Loinc_Hydrocodone_Urine; set Loinc_Hydrocodone_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Hydrocodone_Urine separated by ' ' from Loinc_Hydrocodone_Urine ; quit;
	%put &S_Allcode_Hydrocodone_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Hydrocodone_Urine separated by ' ' from Loinc_Hydrocodone_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Hydrocodone_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Hydrocodone_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Hydrocodone_Others";	run;
	data Loinc_Hydrocodone_Others; set Loinc_Hydrocodone_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Hydrocodone_Blood separated by ' ' from Loinc_Hydrocodone_Others where System="Bld"; quit;
	%put &S_Allcode_Hydrocodone_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Hydrocodone_Blood separated by ' ' from Loinc_Hydrocodone_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Hydrocodone_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Hydrocodone_Others separated by ' ' from Loinc_Hydrocodone_Others where System^="Bld"; quit;
	%put &S_Allcode_Hydrocodone_Others.;

	/*Hydromorphone -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Hydromorphone_Urine=" "; 
	%let S_Confirm_Hydromorphone_Urine=" "; 
	%let S_Allcode_Hydromorphone_Blood=" "; 
	%let S_Confirm_Hydromorphone_Blood=" "; 
	%let S_Allcode_Hydromorphone_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Hydromorphone_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Hydromorphone_Urine";	run;
	data Loinc_Hydromorphone_Urine; set Loinc_Hydromorphone_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Hydromorphone_Urine separated by ' ' from Loinc_Hydromorphone_Urine ; quit;
	%put &S_Allcode_Hydromorphone_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Hydromorphone_Urine separated by ' ' from Loinc_Hydromorphone_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Hydromorphone_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Hydromorphone_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Hydromorphone_Others";	run;
	data Loinc_Hydromorphone_Others; set Loinc_Hydromorphone_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Hydromorphone_Blood separated by ' ' from Loinc_Hydromorphone_Others where System="Bld"; quit;
	%put &S_Allcode_Hydromorphone_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Hydromorphone_Blood separated by ' ' from Loinc_Hydromorphone_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Hydromorphone_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Hydromorphone_Others separated by ' ' from Loinc_Hydromorphone_Others where System^="Bld"; quit;
	%put &S_Allcode_Hydromorphone_Others.;

	/*Levorphanol -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Levorphanol_Urine=" "; 
	%let S_Confirm_Levorphanol_Urine=" "; 
	%let S_Allcode_Levorphanol_Blood=" "; 
	%let S_Confirm_Levorphanol_Blood=" "; 
	%let S_Allcode_Levorphanol_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Levorphanol_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Levorphanol_Urine";	run;
	data Loinc_Levorphanol_Urine; set Loinc_Levorphanol_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Levorphanol_Urine separated by ' ' from Loinc_Levorphanol_Urine ; quit;
	%put &S_Allcode_Levorphanol_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Levorphanol_Urine separated by ' ' from Loinc_Levorphanol_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Levorphanol_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Levorphanol_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Levorphanol_Others";	run;
	data Loinc_Levorphanol_Others; set Loinc_Levorphanol_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Levorphanol_Blood separated by ' ' from Loinc_Levorphanol_Others where System="Bld"; quit;
	%put &S_Allcode_Levorphanol_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Levorphanol_Blood separated by ' ' from Loinc_Levorphanol_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Levorphanol_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Levorphanol_Others separated by ' ' from Loinc_Levorphanol_Others where System^="Bld"; quit;
	%put &S_Allcode_Levorphanol_Others.;

	/*Meperidine -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Meperidine_Urine=" "; 
	%let S_Confirm_Meperidine_Urine=" "; 
	%let S_Allcode_Meperidine_Blood=" "; 
	%let S_Confirm_Meperidine_Blood=" "; 
	%let S_Allcode_Meperidine_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Meperidine_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Meperidine_Urine";	run;
	data Loinc_Meperidine_Urine; set Loinc_Meperidine_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Meperidine_Urine separated by ' ' from Loinc_Meperidine_Urine ; quit;
	%put &S_Allcode_Meperidine_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Meperidine_Urine separated by ' ' from Loinc_Meperidine_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Meperidine_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Meperidine_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Meperidine_Others";	run;
	data Loinc_Meperidine_Others; set Loinc_Meperidine_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Meperidine_Blood separated by ' ' from Loinc_Meperidine_Others where System="Bld"; quit;
	%put &S_Allcode_Meperidine_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Meperidine_Blood separated by ' ' from Loinc_Meperidine_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Meperidine_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Meperidine_Others separated by ' ' from Loinc_Meperidine_Others where System^="Bld"; quit;
	%put &S_Allcode_Meperidine_Others.;

	/*Methardone -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Methadone_Urine=" "; 
	%let S_Confirm_Methadone_Urine=" "; 
	%let S_Allcode_Methadone_Blood=" "; 
	%let S_Confirm_Methadone_Blood=" "; 
	%let S_Allcode_Methadone_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Methadone_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Methadone_Urine";	run;
	data Loinc_Methadone_Urine; set Loinc_Methadone_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Methadone_Urine separated by ' ' from Loinc_Methadone_Urine ; quit;
	%put &S_Allcode_Methadone_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Methadone_Urine separated by ' ' from Loinc_Methadone_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Methadone_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Methadone_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Methadone_Others";	run;
	data Loinc_Methadone_Others; set Loinc_Methadone_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Methadone_Blood separated by ' ' from Loinc_Methadone_Others where System="Bld"; quit;
	%put &S_Allcode_Methadone_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Methadone_Blood separated by ' ' from Loinc_Methadone_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Methadone_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Methadone_Others separated by ' ' from Loinc_Methadone_Others where System^="Bld"; quit;
	%put &S_Allcode_Methadone_Others.;

	/*Morphine -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Morphine_Urine=" "; 
	%let S_Confirm_Morphine_Urine=" "; 
	%let S_Allcode_Morphine_Blood=" "; 
	%let S_Confirm_Morphine_Blood=" "; 
	%let S_Allcode_Morphine_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Morphine_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Morphine_Urine";	run;
	data Loinc_Morphine_Urine; set Loinc_Morphine_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Morphine_Urine separated by ' ' from Loinc_Morphine_Urine ; quit;
	%put &S_Allcode_Morphine_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Morphine_Urine separated by ' ' from Loinc_Morphine_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Morphine_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Morphine_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Morphine_Others";	run;
	data Loinc_Morphine_Others; set Loinc_Morphine_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Morphine_Blood separated by ' ' from Loinc_Morphine_Others where System="Bld"; quit;
	%put &S_Allcode_Morphine_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Morphine_Blood separated by ' ' from Loinc_Morphine_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Morphine_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Morphine_Others separated by ' ' from Loinc_Morphine_Others where System^="Bld"; quit;
	%put &S_Allcode_Morphine_Others.;

	/*Noroxycodone -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Noroxycodone_Urine=" "; 
	%let S_Confirm_Noroxycodone_Urine=" "; 
	%let S_Allcode_Noroxycodone_Blood=" "; 
	%let S_Confirm_Noroxycodone_Blood=" "; 
	%let S_Allcode_Noroxycodone_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Noroxycodone_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Noroxycodone_Urine";	run;
	data Loinc_Noroxycodone_Urine; set Loinc_Noroxycodone_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Noroxycodone_Urine separated by ' ' from Loinc_Noroxycodone_Urine ; quit;
	%put &S_Allcode_Noroxycodone_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Noroxycodone_Urine separated by ' ' from Loinc_Noroxycodone_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Noroxycodone_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Noroxycodone_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Noroxycodone_Others";	run;
	data Loinc_Noroxycodone_Others; set Loinc_Noroxycodone_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Noroxycodone_Blood separated by ' ' from Loinc_Noroxycodone_Others where System="Bld"; quit;
	%put &S_Allcode_Noroxycodone_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Noroxycodone_Blood separated by ' ' from Loinc_Noroxycodone_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Noroxycodone_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Noroxycodone_Others separated by ' ' from Loinc_Noroxycodone_Others where System^="Bld"; quit;
	%put &S_Allcode_Noroxycodone_Others.;

	/*Oxycodone -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Oxycodone_Urine=" "; 
	%let S_Confirm_Oxycodone_Urine=" "; 
	%let S_Allcode_Oxycodone_Blood=" "; 
	%let S_Confirm_Oxycodone_Blood=" "; 
	%let S_Allcode_Oxycodone_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Oxycodone_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Oxycodone_Urine";	run;
	data Loinc_Oxycodone_Urine; set Loinc_Oxycodone_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Oxycodone_Urine separated by ' ' from Loinc_Oxycodone_Urine ; quit;
	%put &S_Allcode_Oxycodone_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Oxycodone_Urine separated by ' ' from Loinc_Oxycodone_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Oxycodone_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Oxycodone_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Oxycodone_Others";	run;
	data Loinc_Oxycodone_Others; set Loinc_Oxycodone_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Oxycodone_Blood separated by ' ' from Loinc_Oxycodone_Others where System="Bld"; quit;
	%put &S_Allcode_Oxycodone_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Oxycodone_Blood separated by ' ' from Loinc_Oxycodone_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Oxycodone_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Oxycodone_Others separated by ' ' from Loinc_Oxycodone_Others where System^="Bld"; quit;
	%put &S_Allcode_Oxycodone_Others.;

	/*Oxymorphone -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Oxymorphone_Urine=" "; 
	%let S_Confirm_Oxymorphone_Urine=" "; 
	%let S_Allcode_Oxymorphone_Blood=" "; 
	%let S_Confirm_Oxymorphone_Blood=" "; 
	%let S_Allcode_Oxymorphone_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Oxymorphone_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Oxymorphone_Urine";	run;
	data Loinc_Oxymorphone_Urine; set Loinc_Oxymorphone_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Oxymorphone_Urine separated by ' ' from Loinc_Oxymorphone_Urine ; quit;
	%put &S_Allcode_Oxymorphone_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Oxymorphone_Urine separated by ' ' from Loinc_Oxymorphone_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Oxymorphone_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Oxymorphone_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Oxymorphone_Others";	run;
	data Loinc_Oxymorphone_Others; set Loinc_Oxymorphone_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Oxymorphone_Blood separated by ' ' from Loinc_Oxymorphone_Others where System="Bld"; quit;
	%put &S_Allcode_Oxymorphone_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Oxymorphone_Blood separated by ' ' from Loinc_Oxymorphone_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Oxymorphone_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Oxymorphone_Others separated by ' ' from Loinc_Oxymorphone_Others where System^="Bld"; quit;
	%put &S_Allcode_Oxymorphone_Others.;

	/*Pentazocine -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Pentazocine_Urine=" "; 
	%let S_Confirm_Pentazocine_Urine=" "; 
	%let S_Allcode_Pentazocine_Blood=" "; 
	%let S_Confirm_Pentazocine_Blood=" "; 
	%let S_Allcode_Pentazocine_Others=" "; 

	/*Any_urine_XXX*/
	proc import out=Loinc_Pentazocine_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Pentazocine_Urine";	run;
	data Loinc_Pentazocine_Urine; set Loinc_Pentazocine_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Pentazocine_Urine separated by ' ' from Loinc_Pentazocine_Urine ; quit;
	%put &S_Allcode_Pentazocine_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Pentazocine_Urine separated by ' ' from Loinc_Pentazocine_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Pentazocine_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Pentazocine_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Pentazocine_Others";	run;
	data Loinc_Pentazocine_Others; set Loinc_Pentazocine_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Pentazocine_Blood separated by ' ' from Loinc_Pentazocine_Others where System="Bld"; quit;
	%put &S_Allcode_Pentazocine_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Pentazocine_Blood separated by ' ' from Loinc_Pentazocine_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Pentazocine_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Pentazocine_Others separated by ' ' from Loinc_Pentazocine_Others where System^="Bld"; quit;
	%put &S_Allcode_Pentazocine_Others.;

	/*Propoxyphene -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Propoxyphene_Urine=" "; 
	%let S_Confirm_Propoxyphene_Urine=" "; 
	%let S_Allcode_Propoxyphene_Blood=" "; 
	%let S_Confirm_Propoxyphene_Blood=" "; 
	%let S_Allcode_Propoxyphene_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Propoxyphene_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Propoxyphene_Urine";	run;
	data Loinc_Propoxyphene_Urine; set Loinc_Propoxyphene_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Propoxyphene_Urine separated by ' ' from Loinc_Propoxyphene_Urine ; quit;
	%put &S_Allcode_Propoxyphene_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Propoxyphene_Urine separated by ' ' from Loinc_Propoxyphene_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Propoxyphene_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Propoxyphene_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Propoxyphene_Others";	run;
	data Loinc_Propoxyphene_Others; set Loinc_Propoxyphene_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Propoxyphene_Blood separated by ' ' from Loinc_Propoxyphene_Others where System="Bld"; quit;
	%put &S_Allcode_Propoxyphene_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Propoxyphene_Blood separated by ' ' from Loinc_Propoxyphene_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Propoxyphene_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Propoxyphene_Others separated by ' ' from Loinc_Propoxyphene_Others where System^="Bld"; quit;
	%put &S_Allcode_Propoxyphene_Others.;

	/*Tapentadol -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Tapentadol_Urine=" "; 
	%let S_Confirm_Tapentadol_Urine=" "; 
	%let S_Allcode_Tapentadol_Blood=" "; 
	%let S_Confirm_Tapentadol_Blood=" "; 
	%let S_Allcode_Tapentadol_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Tapentadol_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Tapentadol_Urine";	run;
	data Loinc_Tapentadol_Urine; set Loinc_Tapentadol_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Tapentadol_Urine separated by ' ' from Loinc_Tapentadol_Urine ; quit;
	%put &S_Allcode_Tapentadol_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Tapentadol_Urine separated by ' ' from Loinc_Tapentadol_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Tapentadol_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Tapentadol_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Tapentadol_Others";	run;
	data Loinc_Tapentadol_Others; set Loinc_Tapentadol_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Tapentadol_Blood separated by ' ' from Loinc_Tapentadol_Others where System="Bld"; quit;
	%put &S_Allcode_Tapentadol_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Tapentadol_Blood separated by ' ' from Loinc_Tapentadol_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Tapentadol_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Tapentadol_Others separated by ' ' from Loinc_Tapentadol_Others where System^="Bld"; quit;
	%put &S_Allcode_Tapentadol_Others.;

	/*Tramadol -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Tramadol_Urine=" "; 
	%let S_Confirm_Tramadol_Urine=" "; 
	%let S_Allcode_Tramadol_Blood=" "; 
	%let S_Confirm_Tramadol_Blood=" "; 
	%let S_Allcode_Tramadol_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Tramadol_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Tramadol_Urine";	run;
	data Loinc_Tramadol_Urine; set Loinc_Tramadol_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Tramadol_Urine separated by ' ' from Loinc_Tramadol_Urine ; quit;
	%put &S_Allcode_Tramadol_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Tramadol_Urine separated by ' ' from Loinc_Tramadol_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Tramadol_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Tramadol_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Tramadol_Others";	run;
	data Loinc_Tramadol_Others; set Loinc_Tramadol_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Tramadol_Blood separated by ' ' from Loinc_Tramadol_Others where System="Bld"; quit;
	%put &S_Allcode_Tramadol_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Tramadol_Blood separated by ' ' from Loinc_Tramadol_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Tramadol_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Tramadol_Others separated by ' ' from Loinc_Tramadol_Others where System^="Bld"; quit;
	%put &S_Allcode_Tramadol_Others.;

	/*Narcotic -----------------------------------------------------------------------------------------------*/
	%let S_Allcode_Narcotic_Urine=" "; 
	%let S_Confirm_Narcotic_Urine=" "; 
	%let S_Allcode_Narcotic_Blood=" "; 
	%let S_Confirm_Narcotic_Blood=" "; 
	%let S_Allcode_Narcotic_Others=" "; 
	/*Any_urine_XXX*/
	proc import out=Loinc_Narcotic_Urine datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Narcotic_Urine";	run;
	data Loinc_Narcotic_Urine; set Loinc_Narcotic_Urine(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Narcotic_Urine separated by ' ' from Loinc_Narcotic_Urine ; quit;
	%put &S_Allcode_Narcotic_Urine.;
	/*Any_urine_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Narcotic_Urine separated by ' ' from Loinc_Narcotic_Urine where METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Narcotic_Urine.;
	/*Any_blood_XXX*/
	proc import out=Loinc_Narcotic_Others datafile= '/data/Project/IRB202101897-DEMONSTRATE/faysalj/File/LOINC_UDT.xlsx' dbms=xlsx replace;	getnames=yes;	
	sheet="Loinc_Narcotic_Others";	run;
	data Loinc_Narcotic_Others; set Loinc_Narcotic_Others(keep=loinc_num component METHOD_TYP system LONG_COMMON_NAME); where ^missing(loinc_num); run; 
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Narcotic_Blood separated by ' ' from Loinc_Narcotic_Others where System="Bld"; quit;
	%put &S_Allcode_Narcotic_Blood.;
	/*Any_blood_confirm_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Confirm_Narcotic_Blood separated by ' ' from Loinc_Narcotic_Others where System="Bld" & METHOD_TYP="Confirm"; quit;
	%put &S_Confirm_Narcotic_Blood.;
	/*Any_other_XXX*/
	proc sql noprint; Select "'"||compress(compress(loinc_num,'00090A0DA0'x))||"'" into :S_Allcode_Narcotic_Others separated by ' ' from Loinc_Narcotic_Others where System^="Bld"; quit;
	%put &S_Allcode_Narcotic_Others.;

/*	%let str_ABN_IND_Normal = "NL";*/
/*	%let str_ABN_IND_Abnormal = "NORMAL";*/
/*	%let str_RESULT_QUAL_Normal = "AB" "AH" "AL" "CH" "CL" "CR";*/
/*	%let str_RESULT_QUAL_Abnormal = "BORDERLINE" "ELEVATED" "HIGH" "LOW" "ABNORMAL";*/
/*	%put &str_ABN_IND_Normal.;*/
/*	%put &str_ABN_IND_Abnormal.;*/
/*	%put &str_RESULT_QUAL_Normal.;*/
/*	%put &str_RESULT_QUAL_Abnormal.;*/

	data &dsout.;
	set	&dsin.;
	/*Barbiturate*/
	if 		^missing(lab_loinc) & lab_loinc in (&S_Allcode_Barbiturate_Urine.) 	then L_URI_BARBITURATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Barbiturate_Urine.)    then C_URI_BARBITURATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Barbiturate_Blood.) 	then L_BLO_BARBITURATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Barbiturate_Blood.)  	then C_BLO_BARBITURATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Barbiturate_Others.) 	then L_OTH_BARBITURATE=1;
	if find(LAB_LOINC,"BARBITURATE","i")>0 											then L_OTH_BARBITURATE=1;
	/*Benzodiazepine*/
	if 		^missing(lab_loinc) & lab_loinc in (&S_Allcode_Benzodiazepine_Urine.) 	then L_URI_BENZODIAZEPINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Benzodiazepine_Urine.)    then C_URI_BENZODIAZEPINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Benzodiazepine_Blood.) 	then L_BLO_BENZODIAZEPINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Benzodiazepine_Blood.)  	then C_BLO_BENZODIAZEPINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Benzodiazepine_Others.) 	then L_OTH_BENZODIAZEPINE=1;
	if find(LAB_LOINC,"BENZO","i")>0 											then L_OTH_BENZODIAZEPINE=1;
	/*Buprenorphine*/
	if 		^missing(lab_loinc) & lab_loinc in (&S_Allcode_Buprenorphine_Urine.) 	then L_URI_BUPRENORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Buprenorphine_Urine.)    then C_URI_BUPRENORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Buprenorphine_Blood.) 	then L_BLO_BUPRENORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Buprenorphine_Blood.)  	then C_BLO_BUPRENORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Buprenorphine_Others.) 	then L_OTH_BUPRENORPHINE=1;
	if find(LAB_LOINC,"BUPRE","i")>0 											then L_OTH_BUPRENORPHINE=1;
	/*Opiates*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Opiates_Urine.) 	then L_URI_OPIATES=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Opiates_Urine.)    then C_URI_OPIATES=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Opiates_Blood.) 	then L_BLO_OPIATES=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Opiates_Blood.)  	then C_BLO_OPIATES=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Opiates_Others.) 	then L_OTH_OPIATES=1;
	if find(LAB_LOINC,"OPIATES","i")>0 or find(LAB_LOINC,"OPIOID","i")>0 then L_OTH_OPIATES=1;
	/*Drug*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_DRUG_Urine.) 	then L_URI_DRUG=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_DRUG_Urine.)    then C_URI_DRUG=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_DRUG_Blood.) 	then L_BLO_DRUG=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_DRUG_Blood.)  	then C_BLO_DRUG=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_DRUG_Others.) 	then L_OTH_DRUG=1;
	if find(LAB_LOINC,"DRUG","i")>0 											then L_OTH_DRUG=1;
	/*Butorphanol*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Butorphanol_Urine.) 	then L_URI_BUTORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Butorphanol_Urine.)    then C_URI_BUTORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Butorphanol_Blood.) 	then L_BLO_BUTORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Butorphanol_Blood.)  	then C_BLO_BUTORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Butorphanol_Others.) 	then L_OTH_BUTORPHANOL=1;
	if find(LAB_LOINC,"Butorphanol","i")>0 											then L_OTH_BUTORPHANOL=1;
	/*Codeine*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Codeine_Urine.) 	then L_URI_CODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Codeine_Urine.)    then C_URI_CODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Codeine_Blood.) 	then L_BLO_CODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Codeine_Blood.)  	then C_BLO_CODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Codeine_Others.) 	then L_OTH_CODEINE=1;
	if find(LAB_LOINC,"Codeine","i")>0 											then L_OTH_CODEINE=1;
	/*Dihydrocodeine*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Dihydrocodeine_Urine.) 	then L_URI_DIHYDROCODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Dihydrocodeine_Urine.)    then C_URI_DIHYDROCODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Dihydrocodeine_Blood.) 	then L_BLO_DIHYDROCODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Dihydrocodeine_Blood.)  	then C_BLO_DIHYDROCODEINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Dihydrocodeine_Others.) 	then L_OTH_DIHYDROCODEINE=1;
	if find(LAB_LOINC,"Dihydrocodeine","i")>0 											then L_OTH_DIHYDROCODEINE=1;
	/*Diphenoxylate*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Diphenoxylate_Urine.) 	then L_URI_DIPHENOXYLATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Diphenoxylate_Urine.)    then C_URI_DIPHENOXYLATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Diphenoxylate_Blood.) 	then L_BLO_DIPHENOXYLATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Diphenoxylate_Blood.)  	then C_BLO_DIPHENOXYLATE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Diphenoxylate_Others.) 	then L_OTH_DIPHENOXYLATE=1;
	if find(LAB_LOINC,"Diphenoxylate","i")>0 											then L_OTH_DIPHENOXYLATE=1;
	/*Fentanyl*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Fentanyl_Urine.) 	then L_URI_FENTANYL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Fentanyl_Urine.)    then C_URI_FENTANYL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Fentanyl_Blood.) 	then L_BLO_FENTANYL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Fentanyl_Blood.)  	then C_BLO_FENTANYL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Fentanyl_Others.) 	then L_OTH_FENTANYL=1;
	if find(LAB_LOINC,"Fentanyl","i")>0 											then L_OTH_FENTANYL=1;
	/*Hydrocodone*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Hydrocodone_Urine.) 	then L_URI_HYDROCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Hydrocodone_Urine.)    then C_URI_HYDROCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Hydrocodone_Blood.) 	then L_BLO_HYDROCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Hydrocodone_Blood.)  	then C_BLO_HYDROCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Hydrocodone_Others.) 	then L_OTH_HYDROCODONE=1;
	if find(LAB_LOINC,"Hydrocodone","i")>0 											then L_OTH_HYDROCODONE=1;
	/*Hydromorphone*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Hydromorphone_Urine.) 	then L_URI_HYDROMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Hydromorphone_Urine.)    then C_URI_HYDROMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Hydromorphone_Blood.) 	then L_BLO_HYDROMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Hydromorphone_Blood.)  	then C_BLO_HYDROMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Hydromorphone_Others.) 	then L_OTH_HYDROMORPHONE=1;
	if find(LAB_LOINC,"Hydromorphone","i")>0 											then L_OTH_HYDROMORPHONE=1;
	/*Levorphanol*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Levorphanol_Urine.) 	then L_URI_LEVORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Levorphanol_Urine.)    then C_URI_LEVORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Levorphanol_Blood.) 	then L_BLO_LEVORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Levorphanol_Blood.)  	then C_BLO_LEVORPHANOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Levorphanol_Others.) 	then L_OTH_LEVORPHANOL=1;
	if find(LAB_LOINC,"Levorphanol","i")>0 											then L_OTH_LEVORPHANOL=1;
	/*Meperidine*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Meperidine_Urine.) 	then L_URI_MEPERIDINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Meperidine_Urine.)    then C_URI_MEPERIDINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Meperidine_Blood.) 	then L_BLO_MEPERIDINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Meperidine_Blood.)  	then C_BLO_MEPERIDINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Meperidine_Others.) 	then L_OTH_MEPERIDINE=1;
	if find(LAB_LOINC,"Meperidine","i")>0 											then L_OTH_MEPERIDINE=1;
	/*Methadone*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Methadone_Urine.) 	then L_URI_METHADONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Methadone_Urine.)    then C_URI_METHADONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Methadone_Blood.) 	then L_BLO_METHADONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Methadone_Blood.)  	then C_BLO_METHADONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Methadone_Others.) 	then L_OTH_METHADONE=1;
	if find(LAB_LOINC,"Methadone","i")>0 											then L_OTH_METHADONE=1;
	/*Morphine*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Morphine_Urine.) 	then L_URI_MORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Morphine_Urine.)    then C_URI_MORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Morphine_Blood.) 	then L_BLO_MORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Morphine_Blood.)  	then C_BLO_MORPHINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Morphine_Others.) 	then L_OTH_MORPHINE=1;
	if find(LAB_LOINC,"Morphine","i")>0 											then L_OTH_MORPHINE=1;
	/*Noroxycodone*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Noroxycodone_Urine.) 	then L_URI_NOROXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Noroxycodone_Urine.)    then C_URI_NOROXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Noroxycodone_Blood.) 	then L_BLO_NOROXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Noroxycodone_Blood.)  	then C_BLO_NOROXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Noroxycodone_Others.) 	then L_OTH_NOROXYCODONE=1;
	if find(LAB_LOINC,"Noroxycodone","i")>0 											then L_OTH_NOROXYCODONE=1;
	/*Oxycodone*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Oxycodone_Urine.) 	then L_URI_OXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Oxycodone_Urine.)    then C_URI_OXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Oxycodone_Blood.) 	then L_BLO_OXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Oxycodone_Blood.)  	then C_BLO_OXYCODONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Oxycodone_Others.) 	then L_OTH_OXYCODONE=1;
	if find(LAB_LOINC,"Oxycodone","i")>0 											then L_OTH_OXYCODONE=1;
	/*Oxymorphone*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Oxymorphone_Urine.) 	then L_URI_OXYMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Oxymorphone_Urine.)    then C_URI_OXYMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Oxymorphone_Blood.) 	then L_BLO_OXYMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Oxymorphone_Blood.)  	then C_BLO_OXYMORPHONE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Oxymorphone_Others.) 	then L_OTH_OXYMORPHONE=1;
	if find(LAB_LOINC,"Oxymorphone","i")>0 											then L_OTH_OXYMORPHONE=1;
	/*Pentazocine*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Pentazocine_Urine.) 	then L_URI_PENTAZOCINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Pentazocine_Urine.)    then C_URI_PENTAZOCINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Pentazocine_Blood.) 	then L_BLO_PENTAZOCINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Pentazocine_Blood.)  	then C_BLO_PENTAZOCINE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Pentazocine_Others.) 	then L_OTH_PENTAZOCINE=1;
	if find(LAB_LOINC,"Pentazocine","i")>0 											then L_OTH_PENTAZOCINE=1;
	/*Propoxyphene*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Propoxyphene_Urine.) 	then L_URI_PROPOXYPHENE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Propoxyphene_Urine.)    then C_URI_PROPOXYPHENE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Propoxyphene_Blood.) 	then L_BLO_PROPOXYPHENE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Propoxyphene_Blood.)  	then C_BLO_PROPOXYPHENE=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Propoxyphene_Others.) 	then L_OTH_PROPOXYPHENE=1;
	if find(LAB_LOINC,"Propoxyphene","i")>0 											then L_OTH_PROPOXYPHENE=1;
	/*Tapentadol*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Tapentadol_Urine.) 	then L_URI_TAPENTADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Tapentadol_Urine.)    then C_URI_TAPENTADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Tapentadol_Blood.) 	then L_BLO_TAPENTADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Tapentadol_Blood.)  	then C_BLO_TAPENTADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Tapentadol_Others.) 	then L_OTH_TAPENTADOL=1;
	if find(LAB_LOINC,"Tapentadol","i")>0 											then L_OTH_TAPENTADOL=1;
	/*Tramadol*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Tramadol_Urine.) 	then L_URI_TRAMADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Tramadol_Urine.)    then C_URI_TRAMADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Tramadol_Blood.) 	then L_BLO_TRAMADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Tramadol_Blood.)  	then C_BLO_TRAMADOL=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Tramadol_Others.) 	then L_OTH_TRAMADOL=1;
	if find(LAB_LOINC,"Tramadol","i")>0 											then L_OTH_TRAMADOL=1;
	/*Narcotic*/
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Narcotic_Urine.) 	then L_URI_NARCOTIC=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Narcotic_Urine.)    then C_URI_NARCOTIC=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Narcotic_Blood.) 	then L_BLO_NARCOTIC=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Confirm_Narcotic_Blood.)  	then C_BLO_NARCOTIC=1;
	if ^missing(lab_loinc) & lab_loinc in (&S_Allcode_Narcotic_Others.) 	then L_OTH_NARCOTIC=1;
	if find(LAB_LOINC,"Narcotic","i")>0 											then L_OTH_NARCOTIC=1;
	run;
	%mend;
	%identifyUrineDrugTest(temp.COHORT_LAB, TEMP.COHORT_LAB_UDT);
	data temp.COHORT_LAB_UDT;
	set  temp.COHORT_LAB_UDT;
	ANY_LAB_UDT=max (of L_:);
	if ANY_LAB_UDT>0;
	run;

/*	Code based on different test results: 1=Yes (with normal results), 2=Yes (with abnormal results), 3=yes (with invalid/missing results or other results), 4=no test;
		0=No test;
		1=Had test (with invalid/missing results or other results)
			- ABN_IND = "IN","NI","UN","OT","";
			- RESULT_QUAL_Normal =  "UNDETEMINED","UNDETECTABLE","";
		2=Had test (with normal results)
			- ABN_IND = "NL";
			- RESULT_QUAL_Normal = "NORMAL","NEGATIVE","POSITIVE"
		3=Had test (with abnormal results)
			- ABN_IND = "AB","AH","AL","CH","CL","CR";
			- RESULT_QUAL_Normal =  "BORDERLINE","ELEVATED","HIGH","LOW","ABNORMAL";
		999=XXX */
	data  temp.COHORT_LAB_UDT ; 	
	set  temp.COHORT_LAB_UDT;
	array var(*) L_: C_:;
	do i=1 to dim(var);
		if ABN_IND in ("AB","AH","AL","CH","CL","CR") | RESULT_QUAL in ("BORDERLINE","ELEVATED","HIGH","LOW","ABNORMAL") then var(i)=var(i)+2;/*3=Had test (with abnormal results)*/
		else if ABN_IND in ("NL") | RESULT_QUAL in ("NORMAL","NEGATIVE","POSITIVE") then var(i)=var(i)+1;/*2=Had test (with normal results)*/
		else if ABN_IND in ("IN","NI","UN","OT","") | RESULT_QUAL in ("UNDETEMINED","UNDETECTABLE","") then var(i)=var(i)+0;/*1=Had test (with invalid/missing results or other results)*/
	end;
	keep ID CLAIM_PERIOD L_: C_: ANY_LAB_UDT;
	run;

	proc summary data=temp.COHORT_LAB_UDT;
	by ID CLAIM_PERIOD;
	output out=temp.COHORT_LAB_UDT_3M(drop=_:) max(L_: C_: ANY_LAB_UDT)=;
	run;


/*	--------------------------------------------------------------------------------------------------------------------------------
	Step 4: Calculate provider characteristics	
	--------------------------------------------------------------------------------------------------------------------------------*/
/*	Find most common NPI	--------------------------------------------------------------------------------------------------------*/

	%macro calMostCommonNPI(dsin,dsout);
	proc sql;
	create 	table dsTemp as 	
	select 	ID, CLAIM_PERIOD, CLAIM_PERIOD_STR_DT, CLAIM_PERIOD_END_DT, RX_PROVIDERID, count(ID) as N_PRESCRIPTION, 
			sum(SUPPLY) as SUPPLY, sum(QUANTITY) as QUANTITY
	from 	&dsin.
	group by ID, CLAIM_PERIOD, CLAIM_PERIOD_STR_DT, CLAIM_PERIOD_END_DT, RX_PROVIDERID
	order by ID, CLAIM_PERIOD, N_PRESCRIPTION, SUPPLY, QUANTITY
	;
	data &dsout.; set dsTemp (keep=ID CLAIM_PERIOD CLAIM_PERIOD_STR_DT CLAIM_PERIOD_END_DT RX_PROVIDERID);	
	by ID CLAIM_PERIOD;
	if last.CLAIM_PERIOD;
	run;
	%mend;
	%calMostCommonNPI(temp.COHORT_MERGE_RXCUI (keep=ID CLAIM_PERIOD CLAIM_PERIOD_STR_DT CLAIM_PERIOD_END_DT RX_PROVIDERID RXCUI_SOURCE SUPPLY QUANTITY where=(RXCUI_SOURCE='NONIVOUD' & RX_PROVIDERID^='')),
	temp.COHORT_COMMONNPI_3M);
	
/*	Calculate monthly feature for most common NPI	--------------------------------------------------------------------------------*/

	%macro getNPImonthlyFeature(dsout);
	proc sql;
	create table &dsout. as
	select	distinct a.ID, a.RX_PROVIDERID, a.CLAIM_PERIOD, count(b.ID) as N_CLAIMS, count(distinct b.ID) as N_P, 
			sum(b.QUANTITY*b.STRENGTH_PER_UNIT*b.MME_CONVERSION_FACTOR) as MME_PER_PT_PERIOD,
			calculated N_CLAIMS/91.25*30 as N_CLAIMS_AVRG, calculated N_P/91.25*30 as N_PT, calculated MME_PER_PT_PERIOD/91.25*30 as MME_PER_PT_PERIOD_AVRG
	from 	temp.COHORT_COMMONNPI_3M as a, 
			temp.COHORT_MERGE_RXCUI (keep=ID DATE RX_PROVIDERID RXCUI_SOURCE QUANTITY STRENGTH_PER_UNIT MME_CONVERSION_FACTOR 
												where=(RXCUI_SOURCE='NONIVOUD' & RX_PROVIDERID^='')) as b
	where (a.CLAIM_PERIOD_STR_DT <= b.DATE <= a.CLAIM_PERIOD_END_DT) & (a.RX_PROVIDERID=b.RX_PROVIDERID)
	group by a.ID, a.CLAIM_PERIOD, a.RX_PROVIDERID, a.CLAIM_PERIOD_STR_DT, a.CLAIM_PERIOD_END_DT
	order by RX_PROVIDERID;
	quit;
	%mend;
	%getNPImonthlyFeature(temp.COHORT_COMMONNPI_INFO_3M);
%distinctid(temp.COHORT_COMMONNPI_INFO_3M, id);

/*	Get gender and specialties for the most common NPI		------------------------------------------------------------------------*/

	proc sql;
	create table temp.COHORT_COMMONNPI_INFO_3M_2 as 
	select 	a.*, (CASE WHEN ^MISSING(B.PROVIDERID) THEN 1 ELSE 0 END) as FLAG, 
			(case when b.PROVIDER_SEX="F" then 2 when b.PROVIDER_SEX="M" then 1 else 0 end) as PROVIDER_SEX, 
			b.PROVIDER_NPI, 
			(case when b.PROVIDER_SPECIALTY_PRIMARY in ('NI', 'OT') then '' else b.PROVIDER_SPECIALTY_PRIMARY end) as PRVDR_SPCLTY_CD
	from temp.COHORT_COMMONNPI_INFO_3M  as a 
	left join (select distinct PROVIDERID, PROVIDER_SEX, PROVIDER_NPI, PROVIDER_SPECIALTY_PRIMARY from fl.EMR_PROV) as b on a.RX_PROVIDERID=b.PROVIDERID
	;
	quit;	
%distinctid(temp.COHORT_COMMONNPI_INFO_3M_2, id);
	
	proc sql;
	create table temp.COHORT_COMMONNPI_INFO_3M_3 as 
	select a.*, b.DESCRIPTIVE_TEXT as PRVDR_SPCLTY
	from temp.COHORT_COMMONNPI_INFO_3M_2 as a 
	left join npi_specialty as b on (a.PRVDR_SPCLTY_CD=b.CODE)
	;
	quit;
	%distinctid(temp.COHORT_COMMONNPI_INFO_3M_3, id);
	%procfreq(temp.COHORT_COMMONNPI_INFO_3M_3,PROVIDER_NPI PRVDR_SPCLTY_CD PRVDR_SPCLTY PROVIDER_SEX/missing);

	/*Create NPI_CATERGORY_FORMAT*/
	data NPI_CATEGORY_FORMAT;
	retain fmtname 'NPI_CATEGORY_FORMAT' START END LABEL;
	set NPI_CATEGORY_FORMAT;
	run;
	proc format CNTLIN=NPI_CATEGORY_FORMAT; run;

	proc sql;
	create table temp.COHORT_COMMONNPI_INFO_3M_4 as 
	select a.*, (case when ^missing(b.PRVDR_SPCLTY) then b.INDEX else 0 end) as PRVDR_CATEGORY 
	from temp.COHORT_COMMONNPI_INFO_3M_3 as a 
	left join npi_category as b on (a.PRVDR_SPCLTY=b.PRVDR_SPCLTY)
	;
	quit;
	%distinctid(temp.COHORT_COMMONNPI_INFO_3M_4, id);
	proc sort data=temp.COHORT_COMMONNPI_INFO_3M_4  out=temp.COHORT_COMMONNPI_INFO_3M_4; by ID CLAIM_PERIOD; run;
	proc freq data=temp.COHORT_COMMONNPI_INFO_3M_4; tables PRVDR_CATEGORY/missing; format PRVDR_CATEGORY NPI_CATEGORY_FORMAT.; run;

/*	--------------------------------------------------------------------------------------------------------------------------------
	Step 5: Get area level variables
	--------------------------------------------------------------------------------------------------------------------------------*/

/*	Get zip for on index date	----------------------------------------------------------------------------------------------------*/

	%saszip();
	data ALL_ZIP;
	set FL.ZIP_2022 (keep=ID ZIP_CODE IN=a) FL.EMR_DEMOGRAPHIC(keep=ID ZIP_CODE in=b); 
	if a then SOURCE=1; else SOURCE=2; /*Choose zip from most recent source*/
	ZIP=substr(ZIP_CODE,1,5); 
	drop ZIP_CODE; 
	if missing(ZIP) then delete;
	run;
	proc sort data=ALL_ZIP out=all_zip(DROP=SOURCE); by ID SOURCE; run;/*Choose zip from most recent source*/
	proc sort data=ALL_ZIP out=all_zip nodupkey; by ID; run;
	

	proc sql;
	create table temp.cohort_zip as
	select a.ID, a.INDEX_DATE, b.ZIP , c.*
	from primary.bene as a
	inner join ALL_ZIP as b on a.ID=b.ID
	left join saszip as c on b.ZIP=c.ZIP
	where ^missing(b.ZIP);
	;
	quit;

/*	AHRF	------------------------------------------------------------------------------------------------------------------------*/
proc contents data=AHRF.AHRF2018; run;


	data AHRF;
	set AHRF.AHRF2018 (keep= 	f00002
								f1533414 f1316714 f1530715 f0979218 f1249218 f0978718 f1266912 f1397515 f1397615 f1461312
								f1434512 f0885716 f1322116 f1530915 f1555016 f1554916 f1555116 f1528815 f1257316 f1257516
								f1257416 f0886816 f1319216 f0482016 f0482116 f1467716 f1121516 f1526118 f1331716 f1467516
								f1198416 f1067816 f1318516 f1249014 f1387610 f1549816 f1319316 f1440812 f1541912 f1529215
								f1529015 f1529115 f1420816 f1555215 f0002013 f1316614 f0474816 f0506016 f0506116 f0506216
								f0506316 f1205616 f1208716 f0982616 f1075916 f1076016 f1076116 f1076216 f1209016 f1209116
								f0490416 f0490516 f0490616 f0490716 f1201616 f1201716 f1474416 f0510216 f0510316 f0510416
								f0510516 f1210416 f1210516 f0477316 f0509016 f0509116 f0509216 f0509316 f1210016 f1210116 
	RENAME=(
			f00002 =  FIPS_code
			f1533414 =  re_HIGH_PVRTY_TYPO_CD
			f1316714 =  re_HOMICIDES_LGL_INTRVNTN
			f1530715 =  re_HOSP_READMISS_RATE_FFS
			f0979218 =  re_HPSA_DENTIST
			f1249218 =  re_HPSA_MENTAL_HEALTH
			f0978718 =  re_HPSA_PRIMARY_CARE
			f1266912 =  re_INFANT_MRTLTY_RATE
			f1397515 =  re_LOW_EDU_TYPO_CD
			f1397615 =  re_LOW_EMPLYMNT_TYPO_CD
			f1461312 =  re_MED_HOME_VAL
			f1434512 =  re_MED_HOUSEHOLD_INCOME
			f0885716 =  re_N_ACTIVE_MDS
			f1322116 =  re_N_CMMNTY_MNTL_HLTH_CTRS
			f1530915 =  re_N_ED_PER_1K_BENE_FFS
			f1555016 =  re_N_ENRL_AGED
			f1554916 =  re_N_ENRL_AGED_DSBLD
			f1555116 =  re_N_ENRL_DSBLD
			f1528815 =  re_N_FFS
			f1257316 =  re_N_HOSP_ALCDRUG_ABUS_IP_ST_C
			f1257516 =  re_N_HOSP_NURSING_CARE_ST
			f1257416 =  re_N_HOSP_PSYCH_CARE_ST
			f0886816 =  re_N_HOSPITALS
			f1319216 =  re_N_MDCR_ADVNTG
			f0482016 =  re_N_MDS_MALE
			f0482116 =  re_N_MDS_FEMALE
			f1467716 =  re_N_MDS_PRMRY_CARE_PTNT_CARE
			f1121516 =  re_N_MDS_PTNT_CARE
			f1526118 =  re_N_NHSC_FTE_MNTL_HLTH_PRVDR
			f1331716 =  re_N_PAIN_MANAG_PGM_ST
			f1467516 =  re_N_PHYS_PRMRY_CARE_PTNT_CARE
			f1198416 =  re_N_POPULATION
			f1067816 =  re_N_PSYCH_LT_HOSPS
			f1318516 =  re_N_PSYCH_ST_HOSPS
			f1249014 =  re_PERS_PVRTY_TYPO_CD
			f1387610 =  re_POP_DNSTY_PER_SQ_MI
			f1549816 =  re_PRCNT_18_64_WO_HLTH_INS
			f1319316 =  re_PRCNT_ADVNTG_PENETRATION
			f1440812 =  re_PRCNT_BLW_POVERTY_LVL
			f1541912 =  re_PRCNT_DEEP_POVERTY
			f1529215 =  re_PRCNT_ELIG_FFS
			f1529015 =  re_PRCNT_FEMALE_FFS
			f1529115 =  re_PRCNT_MALE_FFS
			f1420816 =  re_PRCNT_PRESC_DRUG_PLAN_PENET
			f1555215 =  re_PRVNT_HOSP_STAYS_RATE_FFS
			f0002013 =  re_RURAL_URBAN_CD
			f1316614 =  re_SUICIDES
			f0474816 =  re_N_CHILD_PSYCH
			f0506016 =  re_N_CHILD_PSYCH_35
			f0506116 =  re_N_CHILD_PSYCH_35_44
			f0506216 =  re_N_CHILD_PSYCH_45_54
			f0506316 =  re_N_CHILD_PSYCH_55_64
			f1205616 =  re_N_CHILD_PSYCH_65_74
			f1208716 =  re_N_CHILD_PSYCH_75
			f0982616 =  re_N_EMRGNCY_MED
			f1075916 =  re_N_EMRGNCY_MED_35
			f1076016 =  re_N_EMRGNCY_MED_35_44
			f1076116 =  re_N_EMRGNCY_MED_45_54
			f1076216 =  re_N_EMRGNCY_MED_55_64
			f1209016 =  re_N_EMRGNCY_MED_65_74
			f1209116 =  re_N_EMRGNCY_MED_75
			f0490416 =  re_N_MDS_35
			f0490516 =  re_N_MDS_35_44
			f0490616 =  re_N_MDS_45_54
			f0490716 =  re_N_MDS_55_64
			f1201616 =  re_N_MDS_65_74
			f1201716 =  re_N_MDS_75
			f1474416 =  re_N_PHYS_MED_REHAB
			f0510216 =  re_N_PHYS_MED_REHAB_35
			f0510316 =  re_N_PHYS_MED_REHAB_35_44
			f0510416 =  re_N_PHYS_MED_REHAB_45_54
			f0510516 =  re_N_PHYS_MED_REHAB_55_64
			f1210416 =  re_N_PHYS_MED_REHAB_65_74
			f1210516 =  re_N_PHYS_MED_REHAB_75
			f0477316 =  re_N_PSYCHIATRY
			f0509016 =  re_N_PSYCHIATRY_35
			f0509116 =  re_N_PSYCHIATRY_35_44
			f0509216 =  re_N_PSYCHIATRY_45_54
			f0509316 =  re_N_PSYCHIATRY_55_64
			f1210016 =  re_N_PSYCHIATRY_65_74
			f1210116 =  re_N_PSYCHIATRY_75
		));
	run;
/*	Get chr&r variables		--------------------------------------------------------------------------------------------------------*/

	%macro getCHRandRvars(dsout);
	%do i = 11 %to 16;
		data CHRandR_&i.(rename=(INDEX=FIPS));
		    infile "E:\resources\Lo-Ciganic_value_sets\CHR_var_&i..csv" dsd delimiter=',' firstobs=2;
			length index $ 5;
		    input 	index ADULT_OBESE_PERC ADULT_SMOKERS_PERC CHILDREN_IN_POVERTY_PERC NOT_PROF_IN_ENG_PERC EXCESSIVE_DRINKING_PERC HIV_RATE
					HOMICIDE_RATE LOW_BIRTHWEIGHT_PERC MAMMOGRAPHY_SCREENING_PERC MEDIAN_HOUSEHOLD_INCOME VEHICLE_CRASH_DEATHS_RATE
					PHYSICAL_INACTIVITY_PERC MENTALLY_UNHEALTHY_DAYS POOR_FAIR_HEALTH_PERC PREMATURE_DEATH_YPLL_RATE PREVENTABLE_HOSP_RATE
					SX_TRNSMT_INFCTNS_RATE TEEN_BIRTH_RATE UNEMPLOYED_PERC UNINSURED_ADULTS_PERC VIOLENT_CRIME_RATE;
			YEAR = 2000+&i.;
		run;
	%end;
	%do i = 17 %to 18;
		proc import out=CHRandR_&i. datafile="E:\resultdata\faysalj\File\CHR\CHR_var_&i..xlsx" dbms=xlsx replace; getnames=yes; run;
		data CHRandR_&i.  (drop=fips rename=fips_char=fips);
		Format fips z5.;
		set CHRandR_&i.;
		YEAR = 2000+&i.;
		fips_char=put(fips,z5.);
		run;
	%end;
	data CHRandR_to18;	
	set CHRandR_1:	(rename=(ADULT_OBESE_PERC=re_ADULT_OBESE_PERC ADULT_SMOKERS_PERC=re_ADULT_SMOKERS_PERC CHILDREN_IN_POVERTY_PERC=re_CHILDREN_IN_POVERTY_PERC 
			NOT_PROF_IN_ENG_PERC=re_NOT_PROF_IN_ENG_PERC EXCESSIVE_DRINKING_PERC=re_EXCESSIVE_DRINKING_PERC HOMICIDE_RATE=re_HOMICIDE_RATE LOW_BIRTHWEIGHT_PERC=re_LOW_BIRTHWEIGHT_PERC
			MAMMOGRAPHY_SCREENING_PERC=re_MAMMOGRAPHY_SCREENING_PERC MEDIAN_HOUSEHOLD_INCOME=re_MEDIAN_HOUSEHOLD_INCOME VEHICLE_CRASH_DEATHS_RATE=re_VEHICLE_CRASH_DEATHS_RATE
			PHYSICAL_INACTIVITY_PERC=re_PHYSICAL_INACTIVITY_PERC MENTALLY_UNHEALTHY_DAYS=re_MENTALLY_UNHEALTHY_DAYS POOR_FAIR_HEALTH_PERC=re_POOR_FAIR_HEALTH_PERC 
			PREMATURE_DEATH_YPLL_RATE=re_PREMATURE_DEATH_YPLL_RATE PREVENTABLE_HOSP_RATE=re_PREVENTABLE_HOSP_RATE SX_TRNSMT_INFCTNS_RATE=re_SX_TRNSMT_INFCTNS_RATE 
			TEEN_BIRTH_RATE=re_TEEN_BIRTH_RATE UNEMPLOYED_PERC=re_UNEMPLOYED_PERC UNINSURED_ADULTS_PERC=re_UNINSURED_ADULTS_PERC VIOLENT_CRIME_RATE=re_VIOLENT_CRIME_RATE));
	run;
	%mend;
	%getCHRandRvars();


/*	Add Zip code, Combine AHRF & CHR & ADI	----------------------------------------------------------------------------------------*/

	proc contents data=ADI.ADI_avg_by_fips; run;

	data ADI (DROP=FIPS5); length FIPS 5; format FIPS $5.; set ADI.ADI_avg_by_fips; FIPS=COMPRESS(FIPS5,'"'); run;

	proc sql;
		create table temp.COHORT_AHRF_CHR_ADI (DROP=YEAR) as
		select a.ID, 
			(case when c.re_RURAL_URBAN_CD in ('01','02','03') then 1 when c.re_RURAL_URBAN_CD in ('04','05','06','07','08','09') then 0 end) as re_METRO, 
			c.*, d.*, e.avg_ADI_NATIONAL as re_ADI_NATRANK
		from temp.COHORT_ZIP 							as a
		inner join AHRF (rename=(FIPS_code=FIPS))	as c on a.FIPS=c.FIPS
		inner join CHRandR_to18 					as d on a.FIPS=d.FIPS & year(a.INDEX_DATE)=d.year
		inner join ADI 								as e on a.FIPS=put(cats(e.FIPS),$5.)
		ORDER BY a.ID
		;
	quit;

/*	--------------------------------------------------------------------------------------------------------------------------------
	Step 8: Get all variables
	--------------------------------------------------------------------------------------------------------------------------------*/
	%undupsortNew(temp.COHORT_DX_COMORB_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.COHORT_PX_COMORB_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.TYPE_OPIOIDS,,ID CLAIM_PERIOD);
	%undupsortNew(temp.OPIPATTERN_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.OPIPATTERN2_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.N_IP_ED_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.N_NONOPIOID_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.COHORT_COMMONNPI_INFO_3M_4,,ID CLAIM_PERIOD);
	%undupsortNew(temp.COHORT_LAB_COMORB_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.COHORT_LAB_UDT_3M,,ID CLAIM_PERIOD);
	%undupsortNew(temp.COHORT_OVERLAP,,ID CLAIM_PERIOD);
	%closevts;

	*inc_oud outcomes;

	data PRIMARY.OUTCOME_incoud_edip; set PRIMARY.dx_incoud_edip (keep = id admit_date COMORB_OUD pdx1 enc_type interval);
	rename interval=CLAIM_PERIOD; run;

	*data PRIMARY.x ; 
    *set PRIMARY.OUTCOME_incoud_edip (where=(CLAIM_PERIOD=1)); 
    *run;
data temp.COHORT_VARS_CMPST_TEMP_1;
		merge 	
				temp.COHORT_DX_COMORB_3M				    (drop= OPIOID_START_DT)
				temp.COHORT_PX_COMORB_3M 				
				temp.TYPE_OPIOIDS					
				temp.OPIPATTERN_3M					
				temp.OPIPATTERN2_3M
				temp.COHORT_OVERLAP	
				temp.COHORT_COMMONNPI_INFO_3M_4			
				temp.N_IP_ED_3M
				temp.N_NONOPIOID_3M
				temp.cohort_LAB_COMORB_3M 					
				temp.cohort_LAB_UDT_3M 					
/*				temp.COHORT_LAB_ANY_3M*/
/*				temp.COHORT_LAB_COUNT_3M*/
				PRIMARY.OUTCOME_incoud_edip 			(in=incoud_edip)									
		;
		by ID CLAIM_PERIOD;
		if CLAIM_PERIOD>=0;
		if incoud_edip then inc_oud=1; else inc_oud=0;
	run;


    %procfreq(temp.COHORT_VARS_CMPST_TEMP_1,inc_oud);
	%distinctid(temp.COHORT_VARS_CMPST_TEMP_1(where=(claim_period=1)),id);

	%undupsortNew(temp.COHORT_VARS_CMPST_TEMP_1,,ID);
	%undupsortNew(primary.DEMO,,ID );
	%undupsortNew(temp.COHORT_AHRF_CHR_ADI,,ID );
	data temp.COHORT_VARS_CMPST_TEMP_2;
		merge 	
				primary.bene		 (in=a)
				primary.DEMO			(drop= SOURCE)
				temp.cohort_AHRF_CHR_ADI (drop= FIPS)
				temp.COHORT_VARS_CMPST_temp_1 
		;
		by ID ;
		if a;
		AGE = floor ((intck('month',BIRTH_DATE,INDEX_DATE+91.25*(CLAIM_PERIOD-1)) - (day(INDEX_DATE+91.25*(CLAIM_PERIOD-1)) < day(BIRTH_DATE))) / 12);
		if AGE>=65 then AGE_OVER_65=1; else AGE_OVER_65=0;
		drop BIRTH_DATE;
	run;
	%distinctid(temp.COHORT_VARS_CMPST_TEMP_2,ID);
	%distinctid(temp.COHORT_VARS_CMPST_TEMP_2(where=(claim_period=1)),id);
	/* %distinctid(temp.COHORT_VARS_CMPST_TEMP_2(where=(claim_period=1)),id); */

	/*Shift claim_period and overdose_def*/
	
	%procsort(temp.COHORT_VARS_CMPST_TEMP_2,,ID descending CLAIM_PERIOD);
	data temp.COHORT_VARS_CMPST_TEMP_3;
	retain ID CLAIM_PERIOD lead_CLAIM_PERIOD inc_oud lead_inc_oud;
	set temp.COHORT_VARS_CMPST_TEMP_2;
	by ID;
	lead_CLAIM_PERIOD = lag(CLAIM_PERIOD);
	lead_inc_oud = lag(inc_oud);
	run;
	%procsort(temp.COHORT_VARS_CMPST_TEMP_3,,ID CLAIM_PERIOD);
	%distinctid(temp.COHORT_VARS_CMPST_TEMP_3(where=(claim_period=1)),id);

	/* (previously off)
	data temp.COHORT_VARS_CMPST_temp_4;
	retain ID CLAIM_PERIOD LEAD_CLAIM_PERIOD suicide LEAD_suicide claim_pair_flag;
	set temp.COHORT_VARS_CMPST_TEMP_3;
	by ID;
	if last.ID then do; LEAD_CLAIM_PERIOD=.; LEAD_suicide=.; end;
	if LEAD_CLAIM_PERIOD^=. then claim_pair_flag=1; else claim_pair_flag=0;
	if lead_CLAIM_PERIOD=CLAIM_PERIOD+1 then output;
	*Only use period with next consecutive paired period;
	run;
	*/
    
	data temp.COHORT_VARS_CMPST_temp_4;
	retain ID CLAIM_PERIOD LEAD_CLAIM_PERIOD inc_oud LEAD_inc_oud claim_pair_flag;
	set temp.COHORT_VARS_CMPST_TEMP_3;
	by ID;
	if last.ID then do; LEAD_CLAIM_PERIOD=.; LEAD_inc_oud=.; end;
	if LEAD_CLAIM_PERIOD^=. then claim_pair_flag=1; else claim_pair_flag=0;
	run;
	%distinctid(temp.COHORT_VARS_CMPST_TEMP_4(where=(claim_period=1)),id);

	proc sql;
	create table temp.COHORT_VARS_CMPST as 
	select a.*, 
			(case when ^missing(b.ID) then 1 else 0 end) as PT_PAIR_FLAG,
			(case when ^missing(c.ID) then 1 else 0 end) as ANY_inc_oud,
			(case when a.age<18 then 1 when 18<=a.age<=30 then 2 when 30< a.age<=40 then 3 when 40< a.age<=50 then 4 when 50< a.age<=64 then 5 when 64< a.age then 6 else . end) as AGE_GRP 
	from temp.COHORT_VARS_CMPST_temp_4 as a
	left join (select distinct ID from temp.COHORT_VARS_CMPST_temp_4 where claim_pair_flag=1) as b on a.ID=b.ID
	left join (select distinct ID from temp.COHORT_VARS_CMPST_temp_4 where inc_oud=1) as c on a.ID=c.ID
	having calculated PT_PAIR_FLAG=1 & CLAIM_PAIR_FLAG=1
	order by ID, CLAIM_PERIOD
	;
	quit;
	%procfreq(temp.COHORT_VARS_CMPST,Claim_period PT_PAIR_FLAG);
	%procfreq(temp.COHORT_VARS_CMPST,any_inc_oud lead_inc_oud);
	%distinctid(temp.COHORT_VARS_CMPST(where=(claim_period=1)),id);
	%distinctid(temp.COHORT_VARS_CMPST(where=(any_inc_oud=1)),id);


	proc datasets library=temp; delete COHORT_VARS_CMPST_TEMP_:; run;
	%procfreq(temp.COHORT_VARS_CMPST,inc_oud LEAD_inc_oud ANY_inc_oud); /*752572 > 1582592 >1527635*/
	%distinctid(temp.COHORT_VARS_CMPST,ID); /*109914 > 183433 >183481*/
	%distinctid(temp.COHORT_VARS_CMPST(where=(inc_oud=1)),ID); /*746 > 2337 > 4030*/
	%distinctid(primary.Outcome_incoud_edip,ID); /*898 > 2558 > 4328*/ /* 4443*/

proc sort data=primary.Outcome_incoud_edip out=primary.incoud_id (keep= id) nodupkey ; by id; run;
data primary.incoud_id; set primary.incoud_id; any_epid_incoud=1;run;

proc sql;
	create table temp.COHORT_VARS as 
	select a.*, b.*
	from temp.COHORT_VARS_CMPST as a
	left join primary.incoud_id as b on a.id=b.id;
quit;
%distinctid(temp.COHORT_VARS (where=(any_epid_incoud=1)),ID); /*898 > 2558 > 4328*/
%distinctid(temp.COHORT_VARS,ID); /*109914 > 183433 >183481*/
%distinctid(temp.COHORT_VARS (where=(claim_period=1)),ID); /*109914 > 183433 >183481*/
%proccontents(temp.cohort_lab_udt_3m);


	/*Shift claim_period and overdose_def > inc_oud*/
/*
	%procsort(temp.COHORT_VARS_CMPST_TEMP_2,,ID descending CLAIM_PERIOD);
	data temp.COHORT_VARS_CMPST_TEMP_3;
	retain ID CLAIM_PERIOD lead_CLAIM_PERIOD inc_oud lead_inc_oud;
	set temp.COHORT_VARS_CMPST_TEMP_2;
	by ID;
	lead_CLAIM_PERIOD = lag(CLAIM_PERIOD);
	lead_inc_oud = lag(inc_oud);
	run;
	%procsort(temp.COHORT_VARS_CMPST_TEMP_3,,ID CLAIM_PERIOD);
	data temp.COHORT_VARS_CMPST_temp_4;
	retain ID CLAIM_PERIOD LEAD_CLAIM_PERIOD inc_oud LEAD_inc_oud claim_pair_flag;
	set temp.COHORT_VARS_CMPST_TEMP_3;
	by ID;
	if last.ID then do; LEAD_CLAIM_PERIOD=.; LEAD_inc_oud=.; end;
	if LEAD_CLAIM_PERIOD^=. then claim_pair_flag=1; else claim_pair_flag=0;
	if lead_CLAIM_PERIOD=CLAIM_PERIOD+1 then output; /*Only use period with next consecutive paired period*/
	/*
	run;
	proc sql;
	create table temp.COHORT_VARS_CMPST as 
	select a.*, 
			(case when ^missing(b.ID) then 1 else 0 end) as PT_PAIR_FLAG,
			(case when ^missing(c.ID) then 1 else 0 end) as ANY_inc_oud,
			(case when a.age<18 then 1 when 18<=a.age<=30 then 2 when 30< a.age<=40 then 3 when 40< a.age<=50 then 4 when 50< a.age<=64 then 5 when 64< a.age then 6 else . end) as AGE_GRP 
	from temp.COHORT_VARS_CMPST_temp_4 as a
	left join (select distinct ID from temp.COHORT_VARS_CMPST_temp_4 where claim_pair_flag=1) as b on a.ID=b.ID
	left join (select distinct ID from temp.COHORT_VARS_CMPST_temp_4 where inc_oud=1) as c on a.ID=c.ID
	having calculated PT_PAIR_FLAG=1 & CLAIM_PAIR_FLAG=1
	order by ID, CLAIM_PERIOD
	;
	quit;
	%procfreq(temp.COHORT_VARS_CMPST,Claim_period PT_PAIR_FLAG);

	proc datasets library=temp; delete COHORT_VARS_CMPST_TEMP_:; run;
	%procfreq(temp.COHORT_VARS_CMPST,inc_oud LEAD_inc_oud ANY_inc_oud);/*230 260 2230 > 6625 7088 47370;
	%distinctid(temp.COHORT_VARS_CMPST,ID);/*109914 > 183433;
	%distinctid(temp.COHORT_VARS_CMPST(where=(ANY_inc_oud=1)),ID);/*200 > 3746;
%proccontents(temp.cohort_lab_udt_3m);

/*	--------------------------------------------------------------------------------------------------------------------------------
	Step 9: Imputation & filling missing
	--------------------------------------------------------------------------------------------------------------------------------*/
	/*Keep only the variables we need*/
	proc import out=ML_var datafile="E:\resultdata\faysalj\File\DEMONSTRATE_Data Dictionary_20221212.xlsx" dbms=xlsx replace; 
	sheet="DEMONSTRATE"; run;
	data ML_var; set ML_var; if Variable_status="Y"; run;
	proc sql noprint; Select distinct Variable_name into :ML_var_str separated by ' ' from ML_var; quit;
	%put &ML_var_str.;


	data temp.temp_COHORT_VARS_CMPST (keep=&ML_var_str.); 
	set temp.COHORT_VARS_CMPST (RENAME=(ID=ID));
	run;
	%procfreq(temp.COHORT_VARS_CMPST,lead_inc_oud);
	%undupsortNew(temp.COHORT_VARS_CMPST,,ID CLAIM_PERIOD );


	/*Filling missing with mode in categorical variables*/
    
    proc sql noprint; Select distinct Variable_name into :ML_var_mode_str separated by ' ' from ML_var where Imputation='mode' & Category ne "Health-system-level/regional-level"; quit;
	%put &ML_var_mode_str.;
	ods output OneWayFreqs=freqTable;
	proc freq data=temp.temp_COHORT_VARS_CMPST(keep=&ML_var_mode_str.) ;
	tables &ML_var_mode_str. ;
	format _all_;
	run;
	data freqTable;
	length var $32;
	set freqTable;
	format _all_;
	var = scan(table,-1);
	fvalue=strip(vvaluex('F_'||var));
	keep var fvalue frequency percent cumFrequency cumPercent;
	run;	
	%undupsortNew(freqTable,freqTable,var frequency);
	proc sql;
	create table modeTable as select var, fvalue, monotonic() as idx
	from freqTable group by var having idx=max(idx); quit;
	proc sql noprint; Select var into :mode_var_str separated by ' ' from modeTable; quit;
	proc sql noprint; Select fvalue into :mode_fvalue_str separated by ' ' from modeTable; quit;
	%put &mode_var_str. &mode_fvalue_str. ;
	%macro fill_mode(dsin, dsout, var_str, fvalue_str);
	data &dsout.;
	set &dsin.;
	%do k=1 %to %sysfunc(countw(&var_str.,' '));
       	%let varTemp = %scan(&var_str., &k,' ');
       	%let fvalueTemp = %scan(&fvalue_str., &k,' ');
		%put &k. &vartemp.=&fvalueTemp;
		if missing(&vartemp.) then &vartemp.=&fvalueTemp; else &vartemp.=&vartemp.;
	%end;
	run;
	%mend;
	%fill_mode(temp.temp_COHORT_VARS_CMPST,temp.temp_COHORT_VARS_CMPST2,&mode_var_str.,&mode_fvalue_str.);
%distinctid(temp.temp_COHORT_VARS_CMPST2,id); /* 109914 > 183433 >183481;


	/*Filling missing with mean*/
   
	proc sql noprint; Select distinct Variable_name into :ML_var_mean_str separated by ' ' from ML_var where Imputation='mean' & Category ne "Health-system-level/regional-level"; quit;
	%put &ML_var_mean_str.;
	proc means data=temp.temp_COHORT_VARS_CMPST2 noprint;
	var &ML_var_mean_str.;
	output out=meantable(drop=_type_ _freq_) mean=;
	run;
	proc transpose data=meantable out=meantable_long;
	run;
	proc sql noprint; Select _NAME_ into :mean_var_str separated by ' ' from meantable_long order by _name_; quit;
	proc sql noprint; Select  COL1 into :mean_valur_str separated by ' ' from meantable_long order by _name_; quit;
	%put &mean_var_str. &mean_valur_str.;
	%macro fill_mean(dsin, dsout, var_str, value_str);
	data &dsout.;
	set &dsin.;
	%do k=1 %to %sysfunc(countw(&var_str.,' '));
       	%let varTemp = %scan(&var_str., &k,' ');
       	%let valueTemp = %scan(&value_str., &k,' ');
		%put &k. &vartemp.=&valueTemp;
		if missing(&vartemp.) then &vartemp.=&valuetemp.;
	%end;
	run;
	%mend;
	%fill_mean(temp.temp_COHORT_VARS_CMPST2,temp.temp_COHORT_VARS_CMPST3,&mean_var_str.,&mean_valur_str.);
%distinctid(temp.temp_COHORT_VARS_CMPST3,id); /* 109914 > 183433;
 
	/*Filling missing with zero*/
	proc sql noprint; Select distinct Variable_name into :ML_var_fill0_str separated by ' ' from ML_var where Imputation='fill zero' & Category ne "Health-system-level/regional-level"; quit;
	%put &ML_var_fill0_str.;
	%macro fill_zero(dsin, dsout, var_str);
	data &dsout.;
	set &dsin.;
	%do k=1 %to %sysfunc(countw(&var_str.,' '));
       	%let varTemp = %scan(&var_str., &k,' ');
		%put &k. &varTemp;
		if missing(&vartemp.) then &vartemp.=0;
	%end;
	run;
	%mend;
	%fill_zero(temp.temp_COHORT_VARS_CMPST3,temp.temp_COHORT_VARS_CMPST4,&ML_var_fill0_str.);
%distinctid(temp.temp_COHORT_VARS_CMPST4,id); /* 109914 > 183433*/
%procfreq(temp.temp_COHORT_VARS_CMPST4,lead_inc_oud);

	/*Filling missing with mode in categorical variables*/
    /*
    proc sql noprint; Select distinct Variable_name into :ML_var_mode_str separated by ' ' from ML_var where Imputation='mode' ; quit;
	%put &ML_var_mode_str.;
	ods output OneWayFreqs=freqTable;
	proc freq data=temp.temp_COHORT_VARS_CMPST(keep=&ML_var_mode_str.) ;
	tables &ML_var_mode_str. ;
	format _all_;
	run;
	data freqTable;
	length var $32;
	set freqTable;
	format _all_;
	var = scan(table,-1);
	fvalue=strip(vvaluex('F_'||var));
	keep var fvalue frequency percent cumFrequency cumPercent;
	run;	
	%undupsortNew(freqTable,freqTable,var frequency);
	proc sql;
	create table modeTable as select var, fvalue, monotonic() as idx
	from freqTable group by var having idx=max(idx); quit;
	proc sql noprint; Select var into :mode_var_str separated by ' ' from modeTable; quit;
	proc sql noprint; Select fvalue into :mode_fvalue_str separated by ' ' from modeTable; quit;
	%put &mode_var_str. &mode_fvalue_str. ;
	%macro fill_mode(dsin, dsout, var_str, fvalue_str);
	data &dsout.;
	set &dsin.;
	%do k=1 %to %sysfunc(countw(&var_str.,' '));
       	%let varTemp = %scan(&var_str., &k,' ');
       	%let fvalueTemp = %scan(&fvalue_str., &k,' ');
		%put &k. &vartemp.=&fvalueTemp;
		if missing(&vartemp.) then &vartemp.=&fvalueTemp; else &vartemp.=&vartemp.;
	%end;
	run;
	%mend;
	%fill_mode(temp.temp_COHORT_VARS_CMPST,temp.temp_COHORT_VARS_CMPST2,&mode_var_str.,&mode_fvalue_str.);
    
	/*Filling missing with mean */
	/*
	proc sql noprint; Select distinct Variable_name into :ML_var_mean_str separated by ' ' from ML_var where Imputation='mean' ; quit;
	%put &ML_var_mean_str.;
	proc means data=temp.temp_COHORT_VARS_CMPST2 noprint;
	var &ML_var_mean_str.;
	output out=meantable(drop=_type_ _freq_) mean=;
	run;
	proc transpose data=meantable out=meantable_long;
	run;
	proc sql noprint; Select _NAME_ into :mean_var_str separated by ' ' from meantable_long order by _name_; quit;
	proc sql noprint; Select  COL1 into :mean_valur_str separated by ' ' from meantable_long order by _name_; quit;
	%put &mean_var_str. &mean_valur_str.;
	%macro fill_mean(dsin, dsout, var_str, value_str);
	data &dsout.;
	set &dsin.;
	%do k=1 %to %sysfunc(countw(&var_str.,' '));
       	%let varTemp = %scan(&var_str., &k,' ');
       	%let valueTemp = %scan(&value_str., &k,' ');
		%put &k. &vartemp.=&valueTemp;
		if missing(&vartemp.) then &vartemp.=&valuetemp.;
	%end;
	run;
	%mend;
	%fill_mean(temp.temp_COHORT_VARS_CMPST2,temp.temp_COHORT_VARS_CMPST3,&mean_var_str.,&mean_valur_str.);
    */

	/*Filling missing with zero*/
	/*
	proc sql noprint; Select distinct Variable_name into :ML_var_fill0_str separated by ' ' from ML_var where Imputation='fill zero' ; quit;
	%put &ML_var_fill0_str.;
	%macro fill_zero(dsin, dsout, var_str);
	data &dsout.;
	set &dsin.;
	%do k=1 %to %sysfunc(countw(&var_str.,' '));
       	%let varTemp = %scan(&var_str., &k,' ');
		%put &k. &varTemp;
		if missing(&vartemp.) then &vartemp.=0;
	%end;
	run;
	%mend;
	%fill_zero(temp.temp_COHORT_VARS_CMPST3,temp.temp_COHORT_VARS_CMPST4,&ML_var_fill0_str. LEAD_inc_oud);
    */

*episode 1 predictors;
data temp.episode1; set temp.temp_COHORT_VARS_CMPST4; where CLAIM_PERIOD=1; run;
%distinctid(temp.episode1,id); *109914 > 152737;

proc sql; 
create table temp.episode1_complete as
select a.* , b.*
from temp.episode1 as a 
left join primary.incoud_id as b
on a.id=b.id;
quit;

proc sort data=temp.episode1_complete nodupkey; by id CLAIM_PERIOD; run;
data temp.episode1_complete; set temp.episode1_complete;
if any_epid_incoud=. then any_epid_incoud=0;
run;
%distinctid(temp.episode1_complete,id); *109914 > 152737 > 182083;
%PROCFREQ(temp.episode1_complete,any_epid_incoud); *any_epid_incoud=1 :  898 > 2173; *update: 180875 (98.61%), 2558 (1.39%);
%distinctid(temp.episode1_complete (where=(any_epid_incoud=1)),id); *898 > 2173 > 2558;

/* Added for baseline 9/20 */
data temp.episode0; set temp.temp_COHORT_VARS_CMPST4; where CLAIM_PERIOD=0; run;
%distinctid(temp.episode0,id); *109914 > 152737;

proc sql; 
create table temp.episode0_complete as
select a.* , b.*
from temp.episode0 as a 
left join primary.incoud_id as b
on a.id=b.id;
quit;

proc sort data=temp.episode0_complete nodupkey; by id CLAIM_PERIOD; run;
data temp.episode0_complete; set temp.episode0_complete;
if any_epid_incoud=. then any_epid_incoud=0;
run;
%distinctid(temp.episode0_complete,id); *109914 > 157645 >152470;
%PROCFREQ(temp.episode0_complete,any_epid_incoud); *any_epid_incoud=1 :  898 > 2173;
%distinctid(temp.episode0_complete (where=(any_epid_incoud=1)),id); *898 > 2173 > 2558>3637>3723;


/*data utilization;
set temp.episode1_complete (where=(any_epid_incoud=1));
run;
*/

proc sort data=temp.episode0_complete; by any_epid_incoud id; run;
proc summary print mean std data=temp.episode0_complete(where=(any_epid_incoud=1));
by any_epid_incoud;
var _numeric_;
run;

proc freq data=temp.episode1_complete;
tables gender race;
run;

proc means data=temp.episode1_complete;
var age;
run;

proc freq data=temp.episode1_complete;
tables gender * any_epid_incoud;
run;
*gender: M=1, F=2;

proc freq data=temp.episode1_complete;
tables race * any_epid_incoud;
run;
*race: white=1, balck=2, other=3;

proc freq data=temp.episode1_complete;
tables ethnic * any_epid_incoud;
run;
*ethnic: non-hispanic=1 hispanic=2  missing=0;

proc freq data=temp.episode1_complete;
tables PROVIDER_SEX * any_epid_incoud;
run;
*provider sex: M=1, F=2, missing=0;

proc freq data=temp.episode1_complete;
tables PRVDR_CATEGORY * any_epid_incoud /norow nopercent nofreq;
run;

proc means data=temp.episode1_complete stackodsoutput mean P25 P50 P75 P95;
var N_PT N_CLAIMS_AVRG;
ODS OUTPUT summary=longpctls;
run;

proc sgplot data=temp.episode1_complete;
histogram N_PT;
run;

proc sgplot data=temp.episode1_complete;
histogram N_CLAIMS_AVRG;
run;

data n_pt_test;
set temp.COHORT_COMMONNPI_INFO_3M_4 (where=(N_PT>=1000 & CLAIM_PERIOD=1));
run;

proc freq data= n_pt_test;
tables RX_PROVIDERID;run;

/*	--------------------------------------------------------------------------------------------------------------------------------
	Step 6: Create sampling labels
	--------------------------------------------------------------------------------------------------------------------------------*/
/*	 Split into 3group by suicide>inc_oud 	*/
	proc summary data=temp.temp_COHORT_VARS_CMPST4(keep=ID LEAD_inc_oud);
	by ID;
	output out=SAMPLE(drop=_:) max(LEAD_inc_oud)=ANY_inc_oud;
	run;
	%PROCFREQ(SAMPLE,ANY_inc_oud);
	%procsort(sample,,ANY_inc_oud ID);
	proc surveyselect data=sample out=sample1 seed=12345 method=srs samprate=0.33333/*noprint*/;
	strata ANY_inc_oud;
	run;
	%procsort(sample,,id);
	%procsort(sample1,,id);
	%nrows(sample1);*36638>61145;
	data temp1;
	merge sample (in=dsA) sample1(in=dsB);
	by ID;
	if dsA and not dsB;
	run;
	%nrows(sample);*109914>183433;
	%nrows(sample1);*36638>61145;
	%nrows(temp1);*73276>122288;
	%procsort(temp1,,ANY_inc_oud ID);
	%PROCFREQ(SAMPLE1,ANY_inc_oud);
	%PROCFREQ(temp1,ANY_inc_oud);

	proc surveyselect data=temp1 out=sample2 seed=12345 method=srs samprate=0.5/*noprint*/;
	strata ANY_inc_oud;
	run;
	%procsort(temp1,,id);
	%procsort(sample2,,id);
	data sample3;
	merge temp1 (in=dsA) sample2(in=dsB);
	by ID;
	if dsA and not dsB;
	run;
	%nrows(sample2);*36638>61144;
	%nrows(sample3);*36638>61144;
	data sample1; set sample1; CLS_LABEL_3="Training"; run;
	data sample2; set sample2; CLS_LABEL_3="Testing"; run;
	data sample3; set sample3; CLS_LABEL_3="Validation"; run;
	data cohort_sampling; length CLS_LABEL_3 $10; set sample1-sample3; run;
	proc sql;
	create table temp.Final_Episode as
	select a.*, b.CLS_LABEL_3
	from temp.temp_COHORT_VARS_CMPST4 as a 
	left join cohort_sampling as b on a.ID=b.ID
	order by a.ID
	;
	quit;

	%distinctid(temp.Final_Episode,ID);/*109914 > 183433 > 182083*/


/*	--------------------------------------------------------------------------------------------------------------------------------
	Step 7: Transform to dummy variables
	[Categorical Variables]
		HIGH_PVRTY_TYPO_CD				'0'-'1' '999'
		HPSA_DENTIST					'0'-'2' '999' 
		HPSA_MENTAL_HEALTH				'0'-'2' '999'
		HPSA_PRIMARY_CARE				'0'-'2' '999'
		LOW_EDU_TYPO_CD					'0'-'1' '999'
		LOW_EMPLYMNT_TYPO_CD			'0'-'1' '999'
		PERS_PVRTY_TYPO_CD				'0'-'1' '999'
		RURAL_URBAN_CD					'00'-'09'
		ETHNIC							'0'-'2'
		GENDER							'0'-'2'
		RACE_R01						'1'-'3'
		TYPE_OPIOIDS					'0'-'12'
		PROVIDER_SEX					'F' 'M' 'UN'
		PRVDR_CATEGORY					'0'-'14'
		L_: / C_:					'0'-'3'
	--------------------------------------------------------------------------------------------------------------------------------*/

	/*Transform to dummy variables: Binary*/
	%macro binary_dummy(dsin, dsout, varList);
	data temp; set &dsin.; run;
	%put &varList;
	%do k=1 %to %sysfunc(countw(&varList,' '));
		data temp;
		set temp;
		%let varTemp = %scan(&varList, &k,' ');
		%put &k &varTemp;
		if &vartemp.=1 then &vartemp._1=1; else &vartemp._1=0;
		if &vartemp.=0 then &vartemp._0=1; else &vartemp._0=0;
		drop &vartemp.;
		run;
	%end;
	data &dsout.; set temp; run;
	%mend;
	%binary_dummy(temp.Final_Episode,temp_Episode_1,LEAD_inc_oud);

/*	proc sql;*/
/*	create table Binary_var as */
/*	select variable_name*/
/*	from ML_var (where=(variable_type="Binary"))*/
/*	;*/
/*	quit;*/
/*	proc sql noprint; Select distinct variable_name into :Binary_var_str separated by ' ' from Binary_var; quit;*/
/*	%put &Binary_var_str.;*/
/*	%binary_dummy(temp.Final_Episode,temp_Episode_1,&Binary_var_str.);*/

	/*Transform to dummy variables: Categorical
		HIGH_PVRTY_TYPO_CD				'0'-'1' '999'
		HPSA_DENTIST					'0'-'2' '999' 
		HPSA_MENTAL_HEALTH				'0'-'2' '999'
		HPSA_PRIMARY_CARE				'0'-'2' '999'
		LOW_EDU_TYPO_CD					'0'-'1' '999'
		LOW_EMPLYMNT_TYPO_CD			'0'-'1' '999'
		PERS_PVRTY_TYPO_CD				'0'-'1' '999'
		RURAL_URBAN_CD					'00'-'09'
		ETHNIC							'0'-'2'
		GENDER							'0'-'2'
		RACE_R01						'1'-'3'
		TYPE_OPIOIDS					'0'-'12'
		PROVIDER_SEX					'F' 'M' 'UN'
		PRVDR_CATEGORY					'0'-'14'			*/
	%macro categorical_dummy(dsin, dsout, var, codeList);
	data temp; set &dsin.; run;
	%put &codeList;
	data temp (drop=&var.);
	set temp;
	%do k=1 %to %sysfunc(countw(&codeList,' '));
		%let codeTemp = %scan(&codeList, &k,' ');
		%put &k &codeTemp;
		if &var.="&codeTemp" then &var._&codetemp.=1; else &var._&codetemp.=0;
	%end;
	run;
	data &dsout.; set temp; run;
	%mend;
	%categorical_dummy(temp_Episode_1,temp_Episode_2,PRVDR_CATEGORY,		0 1 2 3 4 5 6 7 8 9 10 11 12 13 14);
	%categorical_dummy(temp_Episode_2,temp_Episode_2,re_HPSA_DENTIST,			0 1 2);
	%categorical_dummy(temp_Episode_2,temp_Episode_2,re_HPSA_MENTAL_HEALTH,	0 1 2);
	%categorical_dummy(temp_Episode_2,temp_Episode_2,re_HPSA_PRIMARY_CARE,		0 1 2);
	%categorical_dummy(temp_Episode_2,temp_Episode_2,re_RURAL_URBAN_CD,		1 2 3 4 5 6 7 8 9);
	%categorical_dummy(temp_Episode_2,temp_Episode_2,ETHNIC,				0 1 2);
	%categorical_dummy(temp_Episode_2,temp_Episode_2,GENDER,				0 1 2);

	*%categorical_dummy(temp_Episode_2,temp_Episode_2,TYPE_OPIOIDS,			0 1 2 3 4 5 6 7 8 9 10 11 12);
	*%categorical_dummy(temp_Episode_2,temp_Episode_2,TYPE_OPIOIDS_FILLS,			0 1 2 3 4 5 6 7 8 9 10 11 12);

	%macro lab_dummy(dsin, dsout);
	proc sql noprint; 
	select distinct name into :lab_varnames_str separated by ' '  from dictionary.columns 
	where upcase(libname) = 'WORK' and upcase(MEMNAME)='TEMP_EPISODE_2' and (substr(NAME,1,2)='L_' or substr(NAME,1,2)='C_')
	;
	quit;
	%put &lab_varnames_str.;

	data temp; set &dsin.; run;
	%put 0 1 2 3;
	data temp ;
	set temp;
	%do k=1 %to %sysfunc(countw(&lab_varnames_str,' '));
		%let varTemp = %scan(&lab_varnames_str, &k,' ');
		%put &k &varTemp;
		array &varTemp._(0:3) &varTemp._0-&varTemp._3;
		do i=0 to 3;
			if &varTemp.=i then &varTemp._(i)=1; else &varTemp._(i)=0; 
		end;
		drop i;
/*		drop &varTemp.;*/
	%end;
	run;
	data &dsout.; set temp; run;
	%mend;
	%lab_dummy(temp_Episode_2, temp_Episode_3);

	data temp.Final_Dummy_Episode; set temp_Episode_3; run;

	/*
	data temp.Final_Dummy_Episode; set temp.Final_Dummy_Episode;
	if RACE=4 then RACE=3;
	run;
	*/

	%nrows(temp.Final_Dummy_Episode);
	%nrows(temp.Final_Dummy_Episode(where=(CLS_LABEL_3 in ('Training','Testing'))));
	%nrows(temp.Final_Dummy_Episode(where=(CLS_LABEL_3 ="Validation")));

	%distinctid(temp.Final_Dummy_Episode,ID);
	%distinctid(temp.Final_Dummy_Episode(where=(CLS_LABEL_3 in ('Training','Testing'))),ID); /* 73276 > 122289*/
	%distinctid(temp.Final_Dummy_Episode(where=(CLS_LABEL_3 ="Validation")),ID); /*36638>61144*/

	%procfreq(temp.Final_Dummy_Episode,LEAD_inc_oud_1);

/*	--------------------------------------------------------------------------------------------------------------------------------
	Step 10: Patient-level data (first available 3-month pair after index date) instead of index period
	--------------------------------------------------------------------------------------------------------------------------------*/
	%macro patient_level (dsin, dsout);
	proc sql;
	create table claim_period_pt as
	select * from (select ID, min(CLAIM_PERIOD) as CLAIM_PERIOD from &dsin.(where=(CLAIM_PERIOD>=1)) group by ID) 
	union all
	select * from (select * from (select ID, max(CLAIM_PERIOD) as CLAIM_PERIOD from &dsin. (where=(CLAIM_PERIOD>=0)) group by ID) where CLAIM_PERIOD=0)
	order by ID
	;
	quit;
	proc sql;
	create table &dsout. as 
	select a.* 
	from &dsin. as a 
	inner join claim_period_pt as b on a.ID = b.ID and a.CLAIM_PERIOD = b.CLAIM_PERIOD
	;
	quit;
	%mend;

	%patient_level(temp.Final_Episode,temp.Final_Patient);
	%patient_level(temp.Final_Dummy_Episode,temp.Final_Dummy_Patient);
	%distinctid(temp.Final_Episode,ID);
	%nrows(temp.Final_Patient);

	/* J added for check 7/18/24) */
    data temp.c(where=(lead_inc_oud=1)); set temp.Final_Patient; run; /*460*/

/*	--------------------------------------------------------------------------------------------------------------------------------
	Export Data
	-------------------------------------------------------------------------------------------------------------------------------- */

	data ds_Training(drop=CLS_LABEL_3) ds_Testing(drop=CLS_LABEL_3) ds_Validation (drop=CLS_LABEL_3);
	retain ID LEAD_inc_oud_0 LEAD_inc_oud_1 ;
	set temp.Final_Dummy_Episode (drop=CLAIM_PERIOD );
	if CLS_LABEL_3='Training' 	then output ds_Training;
	if CLS_LABEL_3='Testing' 	then output ds_Testing;
	if CLS_LABEL_3='Validation' then output ds_Validation;
	run;

	proc export data=ds_Training	(drop= LEAD_inc_oud_0 LEAD_inc_oud_1 ) outfile="E:\resultdata\faysalj\Python\ML_Training_X.csv" dbms=csv replace; run;
	proc export data=ds_Testing		(drop= LEAD_inc_oud_0 LEAD_inc_oud_1 ) outfile="E:\resultdata\faysalj\Python\ML_Testing_X.csv" dbms=csv replace; run;
	proc export data=ds_Validation	(drop= LEAD_inc_oud_0 LEAD_inc_oud_1 ) outfile="E:\resultdata\faysalj\Python\ML_Validation_X.csv" dbms=csv replace; run;

	proc export data=ds_Training 	(keep=ID LEAD_inc_oud_0 LEAD_inc_oud_1) outfile="E:\resultdata\faysalj\Python\ML_Training_Y.csv" dbms=csv replace; run;
	proc export data=ds_Testing 	(keep=ID LEAD_inc_oud_0 LEAD_inc_oud_1) outfile="E:\resultdata\faysalj\Python\ML_Testing_Y.csv" dbms=csv replace; run;
	proc export data=ds_Validation 	(keep=ID LEAD_inc_oud_0 LEAD_inc_oud_1) outfile="E:\resultdata\faysalj\Python\ML_Validation_Y.csv" dbms=csv replace; run;

	data pt_Training(drop=CLS_LABEL_3) pt_Testing(drop=CLS_LABEL_3) pt_Validation (drop=CLS_LABEL_3);
	retain ID LEAD_inc_oud_0 LEAD_inc_oud_1 ;
	set temp.Final_Dummy_Patient (drop=CLAIM_PERIOD);
	if CLS_LABEL_3='Training' 	then output pt_Training;
	if CLS_LABEL_3='Testing' 	then output pt_Testing;
	if CLS_LABEL_3='Validation' then output pt_Validation;
	run;

	proc export data=pt_Training	(drop= LEAD_inc_oud_0 LEAD_inc_oud_1 ) outfile="E:\resultdata\faysalj\Python\PT_Training_X.csv" dbms=csv replace; run;
	proc export data=pt_Testing		(drop= LEAD_inc_oud_0 LEAD_inc_oud_1 ) outfile="E:\resultdata\faysalj\Python\PT_Testing_X.csv" dbms=csv replace; run;
	proc export data=pt_Validation	(drop= LEAD_inc_oud_0 LEAD_inc_oud_1 ) outfile="E:\resultdata\faysalj\Python\PT_Validation_X.csv" dbms=csv replace; run;

	proc export data=pt_Training 	(keep=ID LEAD_inc_oud_0 LEAD_inc_oud_1) outfile="E:\resultdata\faysalj\Python\PT_Training_Y.csv" dbms=csv replace; run;
	proc export data=pt_Testing 	(keep=ID LEAD_inc_oud_0 LEAD_inc_oud_1) outfile="E:\resultdata\faysalj\Python\PT_Testing_Y.csv" dbms=csv replace; run;
	proc export data=pt_Validation 	(keep=ID LEAD_inc_oud_0 LEAD_inc_oud_1) outfile="E:\resultdata\faysalj\Python\PT_Validation_Y.csv" dbms=csv replace; run;

	%put Notice: End of the program. %sysfunc(time(),time.);

/*	--------------------------------------------------------------------------------------------------------------------------------
	End of the program	************************************************************************************************************
	--------------------------------------------------------------------------------------------------------------------------------*/









