import pandas as pd
import pickle
import numpy as np
import sys
sys.path.insert(0,'G:/James/UPMC/Programs/Tools')
import cal_roc
import cal_perf_tables
# importlib.reload(cal_roc)
from cal_roc import get_ROC_precisionRecall, plot_perf_curves_rev, calibration_plot
from pathlib import Path
from cal_perf_tables import createPerfByRisk_decile

model_dict = pickle.load(open("G:/James/UPMC/Models/GBM/GBM_model_val_c_0.87.pkl", "rb"))

X_training = pd.read_csv('G:/James/UPMC/Data/ML_Training_X_JMIR.csv')
X_testing = pd.read_csv('G:/James/UPMC/Data/ML_Testing_X_JMIR.csv')
X_validation = pd.read_csv('G:/James/UPMC/Data/ML_Validation_X_JMIR.csv')
X = pd.concat([X_training, X_testing, X_validation])

Y_training = pd.read_csv('G:/James/UPMC/Data/ML_Training_Y_JMIR.csv')
Y_testing = pd.read_csv('G:/James/UPMC/Data/ML_Testing_Y_JMIR.csv')
Y_validation = pd.read_csv('G:/James/UPMC/Data/ML_Validation_Y_JMIR.csv')
Y = pd.concat([Y_training, Y_testing, Y_validation])

XY = pd.concat([X, Y[['LEAD_DX_OPI_OUD_1', 'LEAD_DX_OPI_OUD_0']]], axis=1)
XY = XY.sort_values(['ID', 'CLAIM_PERIOD'])
XY['cumsum'] = XY.groupby('ID')['LEAD_DX_OPI_OUD_1'].cumsum()
XY_2 = XY.loc[(XY['cumsum'] == 0) | (XY['LEAD_DX_OPI_OUD_1']==1)].drop(columns=['cumsum'])
XY_2 = XY_2.rename(columns={'RACE_R01': 'RACE'})

varlist_jabed = set(pd.read_csv("G:/James/UPMC/Data/varlist.csv")['var'].to_list())
ss = model_dict['normalization']

Y = XY_2[['LEAD_DX_OPI_OUD_1', 'LEAD_DX_OPI_OUD_0']]
X = XY_2[list(set(XY_2.columns) & set(varlist_jabed))]
for col in set(ss.feature_names_in_):
    if col in X:
        continue
    X[col] = 0
X = X[ss.feature_names_in_]
X = pd.DataFrame(ss.transform(X),columns=X.columns)

Y_score = np.zeros(Y.shape[0])
model_list = model_dict['models']
for model in model_list:
    Y_score += model.predict_proba(X)[:,1]/len(model_list)   

metric_tup = get_ROC_precisionRecall(Y['LEAD_DX_OPI_OUD_1'], Y_score, CI_flag=False)

# Bias analysis

XY_2['RACE_CAT'] = XY_2['RACE'].map({1:'White', 2:'Black', 3:'Unknown/Others', 4:'Unknown/Others'})
XY_2['GENDER_CAT'] = XY_2[['GENDER_1', 'GENDER_2']].idxmax(axis=1).str.replace('GENDER_', '').map({'1':'Male', '2':'Female'})
XY_2['ETHNIC_CAT'] = XY_2[['ETHNIC_0', 'ETHNIC_1', 'ETHNIC_2']].idxmax(axis=1).str.replace('ETHNIC_', '').map({'0':'Unknown/Others', '1':'Non-hispanic', '2':'Hispanic'})
XY_2['AGE_CAT'] = pd.cut(XY_2['AGE'], bins=[0,35,50,65,np.inf], labels=['18-34 years', '35-50 years', '51-64 years', '≥65 years'], right=True)

outcome_var = 'LEAD_DX_OPI_OUD_1'
savePath = str(Path('G:/James/UPMC/Programs/Python') / 'JMIR_bias_analysis_race.png')
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['RACE_CAT'], plot_type='fpr-percentile', fixed_threshold_across_grp=True)
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['RACE_CAT'], plot_type='fnr-percentile', fixed_threshold_across_grp=True)

savePath = str(Path('G:/James/UPMC/Programs/Python') / 'JMIR_bias_analysis_age.png')
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['AGE_CAT'], plot_type='fpr-percentile', fixed_threshold_across_grp=True)
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['AGE_CAT'], plot_type='fnr-percentile', fixed_threshold_across_grp=True)

savePath = str(Path('G:/James/UPMC/Programs/Python') / 'JMIR_bias_analysis_gender.png')
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['GENDER_CAT'], plot_type='fpr-percentile', fixed_threshold_across_grp=True)
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['GENDER_CAT'], plot_type='fnr-percentile', fixed_threshold_across_grp=True)

savePath = str(Path('G:/James/UPMC/Programs/Python') / 'JMIR_bias_analysis_ethnic.png')
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['ETHNIC_CAT'], plot_type='fpr-percentile', fixed_threshold_across_grp=True)
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, group_col=XY_2['ETHNIC_CAT'], plot_type='fnr-percentile', fixed_threshold_across_grp=True)

# ROC, Precision recall
savePath = str(Path('G:/James/UPMC/Programs/Python') / 'JMIR.png')
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, plot_type='roc')
plot_perf_curves_rev(Y[outcome_var], Y_score, savePath, plot_type='precision_recall')

# Risk stratification
filename = str(Path('G:/James/UPMC/Programs/Python') / 'JMIR_PerfbyRisk.txt')
perctBeginVec=[-91,-81,-71,-61,-51,-41,-31,-21,-11,-8, -6,-2,-1],
riskNames=['91th-100th','81th-90th','71th-80th','61th-70th','51th-60th','41th-50th','31th-40th','21th-30th','11th-20th','8th-10th','6th-7th','2th-5th','Top 1th percentile']

createPerfByRisk_decile(metric_tup, metric_tup, filename, 'GBM', perctBeginVec=perctBeginVec, riskNames=riskNames)

filename = str(Path('G:/James/UPMC/Programs/Python') / 'JMIR_calibration_plot.png')
calibration_plot(Y[outcome_var], Y_score, filename, nbins=20)


# ETHNIC_0 - UNKNOWN/OTHER
# ETHNIC_1 - NON-HISPANIC
# ETHNIC_2 - HISPANIC
# GENDER_0 - UNKNOWN/OTHER
# GENDER_1 - MALE
# GENDER_2 - FEMALE



# RACE_R01_1 - WHITE
# RACE_R01_2 - BLACK
# RACE_R01_3 - HISPANIC
# RACE_R01_4 - UNKNOWN/OTHER