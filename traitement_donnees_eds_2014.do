cd "C:\Users\ALIDOU\OneDrive\Bureau\article_analyse\MICS\Base\nouvo_2110"
use wm_2014, replace
numlabel, add

***  Age des enfant lors de l'enquete
* Dernière naissance dans les 36 derniers mois
gen recent_last = (v008 - b3_01 <= 36) if b3_01 < .

* (Optionnel) statut du dernier enfant
gen last_alive  = (b5_01 == 1) if b5_01 < .

* Restreindre l’analyse SBA (pas besoin de filtrer sur vivant pour SBA)
keep if recent_last == 1 & last_alive==1

*** Construction des variable accouchement assisté
gen sba = .
replace sba = 1 if m3a_1==1 | m3b_1==1 | m3c_1==1 | m3d_1==1 | m3h_1==1
replace sba = 0 if m3e_1==1 | m3f_1==1 |m3g_1==1 | m3i_1==1 | m3j_1==1 | m3k_1==1 | m3n_1==1
label def sba 1 "Oui" 0 "Non"
label var sba "skilled birth attendance"
label val sba sba
tab sba

****** Retenir seulement des sba sans variable manquante
keep if sba !=.

**  Tranche d'âge
gen mage = .
replace mage = 1 if v013==1  // 15–19
replace mage = 2 if inlist(v013,2,3,4) // 20–24, 25–29, 30–34
replace mage = 3 if inlist(v013,5,6,7) // 35–49
label var mage "mather_age"
label define mage 1 "15-19" 2 "20-34" 3 "35-49"
label values mage mage


*** Quintile
gen quintile=v190
label var quintile "Economic status"
label def quintile 1 "Quintile 1 (Poorest)" 2 "Quintile 2" 3 "Quintile 3" 4 "Quintile 4" 5 "Quintile 5 (Richest)"
label val quintile quintile

**** Education
gen educatt=. 
replace educatt=1 if v106==0
replace educatt=2 if  v106==1
replace educatt=3 if  v106==2|v106==3
label var educatt "Education"
label def educatt 1 "No education" 2 "Primaire" 3 "Secondary or high"
label val educatt educatt

*******

***** Milieu de residence
gen urban=1 if v102==1
replace urban=0 if v102==2
label var urban "place of residence"
label def urban 0 "rural" 1 "urban"
label val urban urban
tab urban

*****varibale region
gen region=.
replace region=1 if v101==6
replace region=2 if v101==4
replace region=3 if v101==5
replace region=4 if v101==3
replace region=5 if v101==2
replace region=6 if v101==1
label var region "Region administractif" 
label def region 1 "Savane" 2 "Centrale" 3 "Kara" 4 "Plateaux" 5 "Maritime" 6 "Lomé_commune"
label val region region
tab region

    
**** poids
gen weight=(v005/1000 000)
label var weight "Poid d'echantillon"

**** sauver la nouvelle base
keep v001 v005 weight v022 sba region quintile urban mage educatt
save base_mics_2014, replace


                  **************Calcul des estimation et préparation du fichier excel............

*** Calcule des estimation pour preparer la fiche exce
*** declaration d'une enquete
use base_mics_2014, replace
svyset v001 [pweight=weight], strata (v022)


**** poids non manquant


*** description de l'echantillon
svydescribe

**** Calcule des estimation au niveau national
svy linearize: prop sba, percent
svy linearize: tab sba
svy linearize: mean sba

**** Estimation desagreger
*** indice economique
svy linearize: mean sba, over (quintile)

**Education
svy linearize: mean sba, over (educatt)

*** milieu
svy linearize: mean sba, over (urban)

*** Region 
svy linearize: mean sba, over (region)

**** tail totale
gen size=1
total size

***** tal par quintile
total size, over (quintile)

*** population avec poid
svy linearize: total size

************************* Créer des variables binaires factices pour chaque dimension de l'inégalité**************
	qui tab urban, gen(urban_)
	qui tab educatt, gen(educatt_)
	qui tab quintile, gen(quintile_)
	qui tab mage, gen(mage_)
	qui tab region, gen(region_)


*****//	Sauver des estimation des parametre de desagragation dans le fichier temporaire
	tempfile urban_1
	svy linearized, subpop(urban_1): mean sba
	parmest, idstr(urban_1) list(,) saving(`urban_1', replace)


****Boucle pour enregistrer les estimations désagrégées pour tous les sous-groupes dans des fichiers temporaires
	foreach var of varlist quintile_* educatt_* urban_* region_* mage_*  { 
		tempfile `var'
		svy linearized, subpop(`var'): mean sba
		qui parmest, idstr(`var') list(,) saving(``var'', replace)
	} 
	
******fusionnon les reslutat dans une base de donnée
	use `quintile_1', clear
	append using `quintile_2'
	append using `quintile_3'
	append using `quintile_4'
	append using `quintile_5'
	append using `educatt_1'
	append using `educatt_2'
	append using `educatt_3'
	append using `urban_1'
	append using `urban_2'
	append using `region_1'
	append using `region_2'
	append using `region_3'
	append using `region_4'
	append using `region_5'
	append using `region_6'
    append using `mage_1'
	append using `mage_2'
	append using `mage_3'

	
save "sample_data_14_disaggregated.dta", replace

**** Exportons les donnée pondérées
************************************************************

// 	utilisons notre base de données
	use base_mics_2014, replace
	
// 	Declarons les données d'enquête 
	svyset v001 [pweight=weight], strata (v022) singleunit(centered)

	
//	Creaon des variable temporaire de dimension d'inagalité 
	qui tab urban, gen(urban_)
	qui tab educatt, gen(educatt_)
	qui tab quintile, gen(quintile_)
	qui tab mage, gen(mage_)
	qui tab region, gen(region_)
	
//	Loop to save weighted population sizes for all subgroups into tempfiles
	gen size=1
	foreach var of varlist quintile_* educatt_* urban_* region_* mage_* { 
		tempfile `var'
		svy linearized, subpop(`var'): total size
		qui parmest, idstr(`var') list(,) saving(``var'', replace)
	} 
	
//	Append the results into a single dataset
	use `quintile_1', clear
	append using `quintile_2'
	append using `quintile_3'
	append using `quintile_4'
	append using `quintile_5'
	append using `educatt_1'
	append using `educatt_2'
	append using `educatt_3'
	append using `urban_1'
	append using `urban_2'
	append using `region_1'
	append using `region_2'
	append using `region_3'
	append using `region_4'
	append using `region_5'
	append using `region_6'
    append using `mage_1'
	append using `mage_2'
	append using `mage_3'

save "sample_data_14_population.dta", replace


***Exportons l'estimation nationale
************************************************************
// utilison la base de donnée 2014
	use base_mics_2014, replace
	
// 	Declaration des données d'enquête
	svyset v001 [pweight=weight], strata (v022) singleunit(centered)

//	Save national average estimates into a tempfile
	svy linearized : mean sba
	parmest, idstr(national) list(,) saving("sample_data_14_national.dta", replace)
	
************************************************************
*	exporetr les donnée non pondérées
************************************************************

// 	Open the sample dataset
	use base_mics_2014, replace

//	Create dummy binary variables for each dimension of inequality
	qui tab urban, gen(urban_)
	qui tab educatt, gen(educatt_)
	qui tab quintile, gen(quintile_)
	qui tab mage, gen(mage_)
	qui tab region, gen(region_)
	
//	Collapse dataset into a dataset of sum of the count of records
	collapse (sum) quintile_* educatt_* urban_* region_* mage_* 

	save "sample_data_14_samplesize.dta", replace
			 

	
// Renommer la variable « estimate » de l'ensemble de données sur la moyenne nationale en « setting average »

    use "sample_data_14_national.dta", clear
	rename estimate setting_average
	tempfile sample_data_14_national
	save `sample_data_14_national', replace
	
//	Rename 'estimate' variable in population dataset to 'population'
// Renommer la variable « estimate » de l'ensemble de données « population » en « population ».
	use "sample_data_14_population.dta", clear
	rename estimate population
	tempfile sample_data_14_population
	save `sample_data_14_population', replace
	
//	Reshape sample size data to long format
// Transformons les données de la taille de l'échantillon en format long
	use "sample_data_14_samplesize.dta", clear
	rename * samplesize*
	gen parm="sba"
	reshape long samplesize, i(parm) j(idstr) string
	tempfile sample_data_14_samplesize
	save `sample_data_14_samplesize', replace

// 	Open the dataset with disaggregated data
	use "sample_data_14_disaggregated.dta", clear
	
//	Merge national average, population size and sample size data
	merge m:1 parm using `sample_data_14_national', nogen
	merge 1:1 idstr using `sample_data_14_population', nogen
	merge 1:1 idstr using `sample_data_14_samplesize', nogen
	
************************************************************

//// Structuré la base des données
************************************************************
	
//	Generate required variables
	gen setting="Sample"
	gen date=2014
	gen source="MICS"
	gen indicator_name="Skilled birth attendance (%)"
	gen iso3=""
	
//	Supprimer les petite taille de données
	gen flag="Suppressed: Estimate based on <25 observations" if samplesize<25
	replace flag="Warning: Estimate based on 25-49 observations" if samplesize>=25 & samplesize<=49
	replace estimate=. if samplesize<25

//	Rommer les variables 
	rename (parm stderr min95 max95) (indicator_abbr se ci_lb ci_ub)
	
//	Multiplier les valeur par  100 
	replace estimate=estimate*100
	replace ci_lb=ci_lb*100
	replace ci_ub=ci_ub*100
	replace setting_average=setting_average*100
	
//	Generate variable with subgroups

//// Generer des variable avec sous groupe
	gen subgroup="Rural" if idstr=="urban_1"
		replace subgroup="Urban" if idstr=="urban_2"
		replace subgroup="15-19 years" if idstr=="mage_1"
		replace subgroup="20-34 years" if idstr=="mage_2"
		replace subgroup="35-49 years" if idstr=="mage_3"
		replace subgroup="Quintile 1 (poorest)" if idstr=="quintile_1"
		replace subgroup="Quintile 2" if idstr=="quintile_2"
		replace subgroup="Quintile 3" if idstr=="quintile_3"
		replace subgroup="Quintile 4" if idstr=="quintile_4"
		replace subgroup="Quintile 5 (richest)" if idstr=="quintile_5"
		replace subgroup="No_education" if idstr=="educatt_1"
		replace subgroup="Primaire" if idstr=="educatt_2"
		replace subgroup="Secondary_high" if idstr=="educatt_3"
		replace subgroup="Savane" if idstr=="region_1"
		replace subgroup="Centrale" if idstr=="region_2"
		replace subgroup="Kara" if idstr=="region_3"
		replace subgroup="Plateaux" if idstr=="region_4"
		replace subgroup="Maritime" if idstr=="region_5"
		replace subgroup="Lomé_commune" if idstr=="region_6"
		
	
//	Generate variable with dimensions of inequality
        gen dimension="Place of residence" if inlist(subgroup,"Rural","Urban")
		replace dimension="mather_age" if inlist(subgroup, "15-19 years","20-34 years", "35-49 years")
		replace dimension="Economic status" if inlist(subgroup,	"Quintile 1 (poorest)","Quintile 2", "Quintile 3","Quintile 4", "Quintile 5 (richest)")
		replace dimension="Education" if inlist(subgroup, "No education", "Primaire", "Secondary or high")
		replace dimension="Region administractif" if inlist(subgroup, "Savanes", "Centrale", "Kara", "Plateaux", "Maritime", "Lomé_commune")
	
//Supprimer les varible non utile
	drop dof t p samplesize idstr
	

/// Creeons la varible specific a HEAT plus
	
	gen favourable_indicator=1
	
	gen indicator_scale=100
	
	gen ordered_dimension=0
		replace ordered_dimension=1 if inlist(dimension,"mather_age","Economic status")
	
	gen subgroup_order=0
		replace subgroup_order=1 if inlist(subgroup,"15-19 years","Quintile 1 (poorest)")
		replace subgroup_order=2 if inlist(subgroup,"20-34 years","Quintile 2")
		replace subgroup_order=3 if inlist(subgroup, "35-49 years","Quintile 3")
		replace subgroup_order=4 if inlist(subgroup,"Quintile 4")
		replace subgroup_order=5 if inlist(subgroup,"Quintile 5 (richest)")

	
	gen reference_subgroup=0
		replace reference_subgroup=1 if inlist(subgroup,"Secondary or high","Urban", "Lomé_commune")

		
//	ordonner les variables  variables
	order setting date source indicator_abbr indicator_name dimension /// 
	subgroup estimate se ci_lb ci_ub population flag setting_average iso3 ///
	favourable_indicator indicator_scale ordered_dimension subgroup_order ///
	reference_subgroup
	
************************************************************
*	Quality checks
************************************************************

//	Verifions, les donner du site sont obligatoire
	assert !mi(setting)
	
//	se, ci_lb and ci_ub must be missing if estimate is missing 
	assert mi(se) if mi(estimate)
	
//	favourable_indicator, ordered_dimension and reference_subgroup must only contain the values of 0 and 1
	assert inlist(favourable_indicator, 0, 1)
	
//	Report duplicate records
	duplicates report
	
//	Tag any duplicate records with the variable 'duplicate'
	duplicates tag, gen(duplicate)
	tab duplicate
	drop duplicate
	
//	Drop duplicated observations
	duplicates drop

************************************************************
*	Exporter les donnée
************************************************************

//	exporetre les donné en excel
	export excel using "dhs_14.xlsx", firstrow(var) replace




