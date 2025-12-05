import numpy as np
import matplotlib.pyplot as plt
from numpy import trapz
from sklearn import metrics
from sklearn.metrics import roc_auc_score
from sklearn.linear_model import LogisticRegression
import pickle
import pandas as pd
import copy

def add_prefix(filename, prefix):
    return '/'.join(filename.split('/')[:-1] + [prefix + filename.split('/')[-1]])

def add_suffix(filename, suffix):
    assert '.' in filename
    _ext = filename.split('.')[-1]
    _split_by_dot = '.'.join(filename.split('.')[:-1]) + suffix
    return '.'.join([_split_by_dot, _ext])

def calibration_plot(Y, Y_score, savePath, nbins=20, zoom_range=0.25):

    clf = LogisticRegression(random_state=0).fit(Y_score.reshape(-1, 1), Y)
    pred_prob = clf.predict_proba(Y_score.reshape(-1, 1))[:,1]
    true = np.array(Y)[np.array(pred_prob).argsort()]    
    pred_prob = np.sort(np.array(pred_prob))

    if isinstance(nbins,int):
        cutoffs = np.linspace(0,len(pred_prob),nbins+1)
    else:
        cutoffs = np.concatenate([np.linspace(0,.9,10),[.95, .99, 1]])*len(pred_prob)
    grp_score = []
    grp_true = []
    for i_start, i_stop in zip(cutoffs[:-1],cutoffs[1:]):
        grp_score.append(np.mean(pred_prob[int(i_start):int(i_stop)])*100)
        grp_true.append(np.mean(true[int(i_start):int(i_stop)])*100)
    max_val = max(grp_true+grp_score)
    max_val = np.ceil(max_val/0.1)*0.1
    plt.figure(figsize=(10 ,8), dpi= 100, facecolor='w', edgecolor='k')
    plt.plot(grp_true, grp_score, 'o', linewidth=3.0)
    plt.plot([0,max_val], [0,max_val], ':')
    plt.grid()
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    plt.xlim([0.0, max_val])
    plt.ylim([0.0, max_val])
    plt.savefig(add_prefix(add_suffix(savePath.replace('\\','/'), f'_{nbins}_bins'), 'cal_')[:-4] + '_no_annotation.eps', format='eps', dpi=300)
    plt.xlim([0.0, zoom_range])
    plt.ylim([0.0, zoom_range])
    plt.savefig(add_prefix(add_suffix(savePath.replace('\\','/'), f'_{nbins}_bins_zoom'), 'cal_')[:-4] + '_no_annotation.eps', format='eps', dpi=300)

    plt.xlabel('Observed positive (%)',fontsize=14)
    plt.ylabel('Predicted positive (%)',fontsize=14)
    plt.title('beta_0: %.3g, beta_1: %.3g' %(clf.intercept_[0],clf.coef_[0][0]))

    plt.xlim([0.0, max_val])
    plt.ylim([0.0, max_val])
    plt.savefig(add_prefix(add_suffix(savePath.replace('\\','/'), f'_{nbins}_bins'), 'cal_')[:-4] + '.eps', format='eps', dpi=300)
    plt.savefig(add_prefix(add_suffix(savePath.replace('\\','/'), f'_{nbins}_bins'), 'cal_')[:-4] + '.png', format='png', dpi=300)
    plt.xlim([0.0, zoom_range])
    plt.ylim([0.0, zoom_range])
    plt.savefig(add_prefix(add_suffix(savePath.replace('\\','/'), f'_{nbins}_bins_zoom'), 'cal_')[:-4] + '.eps', format='eps', dpi=300)
    plt.savefig(add_prefix(add_suffix(savePath.replace('\\','/'), f'_{nbins}_bins_zoom'), 'cal_')[:-4] + '.png', format='png', dpi=300)



def plot_perf_curves_rev(Y, Y_score, savePath, CI_flag=False, plot_type='roc', group_col=None, group_color={}, 
                     add_lines=[], title=None, label_dict_custom={}, 
                     fixed_threshold_across_grp=False, add_overall_perf=True, grp_name_whitelist=[],
                     xticks = np.arange(0,101,10), yticks = np.arange(0,101,10), xlim = [0, 100], ylim = [0, 100]):

    scale_dict = {'fnr':100, 'tpr':100, 'percentile':100, 'fpr':100, 'ppv':100, 'ppr':100}
    
    if plot_type == 'roc':
        X_key = 'fpr'
        Y_key = 'tpr'
        xlabel = '1-Specificity (%)'
        ylabel = 'Sensitivity (%)'
        leg_loc = 'lower right'        
    elif plot_type == 'precision_recall':
        X_key = 'tpr'
        Y_key = 'ppv'
        xlabel = 'Recall (%)'
        ylabel = 'Precision (%)'
        leg_loc = 'upper right'
    elif plot_type == 'nne':
        X_key = 'tpr'
        Y_key = 'nne'
        xlabel = 'Sensitivity (%)'
        ylabel = 'Number needed to evaluate'
        leg_loc = 'upper left'
    elif plot_type == 'predicted_pos_rate':
        X_key = 'tpr'
        Y_key = 'ppr'
        xlabel = 'Sensitivity (%)'
        ylabel = 'Number predicted as positive per 100 cases'
        leg_loc = 'upper left'
    elif plot_type == 'tpr-percentile':
        X_key = 'percentile'
        Y_key = 'tpr'
        xlabel = 'Percentile (%)'
        ylabel = 'Sensitivity (%)'
        leg_loc = 'lower right'
    elif plot_type == 'fpr-percentile':
        X_key = 'percentile'
        Y_key = 'fpr'
        xlabel = 'Percentile (%)'
        ylabel = 'FPR (%)'
        leg_loc = 'lower right'
    elif plot_type == 'fnr-percentile':
        X_key = 'percentile'
        Y_key = 'fnr'
        xlabel = 'Percentile (%)'
        ylabel = 'FNR (%)'
        leg_loc = 'lower right'
    elif plot_type == 'fnr-score':
        xticks = None
        X_key = 'thresholds'
        Y_key = 'fnr'
        xlabel = 'Risk score'
        ylabel = 'FNR (%)'
        leg_loc = 'lower right'
    elif plot_type == 'fpr-score':
        xticks = None
        X_key = 'thresholds'
        Y_key = 'fpr'
        xlabel = 'Risk score'
        ylabel = 'FPR (%)'
        leg_loc = 'lower right'
    elif plot_type == 'nb':
        xlabel = 'Percentile (%)'
        ylabel = 'Net benefit'
        X_key = 'percentile'
        Y_key = 'nb'
        leg_loc = 'upper right'
    else:
        raise NotImplementedError()
    
    plt.figure(figsize=(8 ,6), dpi= 100, facecolor='w', edgecolor='k')

    if add_overall_perf or (group_col is None):
        # for grp_name in group_col.unique():
        metric_dict = get_ROC_precisionRecall(Y, Y_score, None, CI_flag=CI_flag, return_dict=True)
        if metric_dict is None:
            return
        metric_dict['nne'] = 1/metric_dict['ppv']
        _X = metric_dict[X_key]*scale_dict.get(X_key,1)
        _Y = metric_dict[Y_key]*scale_dict.get(Y_key,1)        
        plt.plot(_X, _Y, linewidth=3.0, label=', '.join((['All'] if (group_col is not None) else []) + \
                                                  (['C statistic = %.3f (%.3f, %.3f)' \
                                                    %(metric_dict['roc_auc'],metric_dict['auc_CI_lower'],metric_dict['auc_CI_upper'])] \
                                                   if plot_type == 'roc' else (['AUC = %.3f' %(metric_dict['precision_recall_auc'])] if plot_type == 'precision_recall' else []))))
        Z = metric_dict['thresholds']

    if group_col is not None:
        for grp_name in group_col.unique():
            if len(grp_name_whitelist)>0 and grp_name not in grp_name_whitelist:
                continue
            if fixed_threshold_across_grp:
                metric_dict = get_ROC_precisionRecall(Y[group_col == grp_name], Y_score[group_col == grp_name], \
                                                      None, CI_flag=CI_flag, given_thresholds=Z, return_dict=True)
                if metric_dict is None:
                    return
                _Y = metric_dict[Y_key]*scale_dict.get(Y_key,1)
                plt.plot(_X, _Y, linewidth=3.0, label=', '.join([grp_name] + (['C statistic = %.3f (%.3f, %.3f)' \
                                                    %(metric_dict['roc_auc'],metric_dict['auc_CI_lower'],metric_dict['auc_CI_upper'])] \
                                                   if plot_type == 'roc' else (['AUC = %.3f' %(metric_dict['precision_recall_auc'])] if plot_type == 'precision_recall' else []))))
            else:
                # import pdb; pdb.set_trace()
                if len(np.unique(Y[group_col == grp_name]))==1:
                    unique_label = np.unique(Y[group_col == grp_name])[0]
                    print(f'All {grp_name} has label {unique_label}')
                    return
                else:
                    metric_dict = get_ROC_precisionRecall(Y[group_col == grp_name], Y_score[group_col == grp_name], \
                                                          None, CI_flag=CI_flag, return_dict=True)
                    if metric_dict is None:
                        return
                    _X = metric_dict[X_key]*scale_dict.get(X_key,1)
                    _Y = metric_dict[Y_key]*scale_dict.get(Y_key,1)
                    plt.plot(_X, _Y, linewidth=3.0, label=', '.join([grp_name] + (['C statistic = %.3f (%.3f, %.3f)' \
                                                    %(metric_dict['roc_auc'],metric_dict['auc_CI_lower'],metric_dict['auc_CI_upper'])] \
                                                   if plot_type == 'roc' else (['AUC = %.3f' %(metric_dict['precision_recall_auc'])] if plot_type == 'precision_recall' else []))))
    if plot_type == 'nb':
        Y_key = 'nb_treat_all'
        _X = metric_dict[X_key]*scale_dict.get(X_key,1)
        _Y = metric_dict[Y_key]*scale_dict.get(Y_key,1)
        plt.plot(_X, _Y, linewidth=3.0, label='Treat all')

    if xlim is not None: 
        plt.xlim(xlim)
    if ylim is not None:
        plt.ylim(ylim)
    if xticks is not None:
        plt.xticks(xticks)
    if yticks is not None:
        plt.yticks(yticks)
    plt.grid()
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    plt.savefig(add_suffix(add_suffix(savePath, plot_type), ('_fixed_threshold' if fixed_threshold_across_grp else ''))[:-4] + '_no_annotation.eps', format='eps', dpi=300)

    plt.xlabel(xlabel, fontsize=14)
    plt.ylabel(ylabel, fontsize=14)
    plt.legend(loc=leg_loc, fontsize=12)
    plt.savefig(add_suffix(add_suffix(savePath, plot_type), ('_fixed_threshold' if fixed_threshold_across_grp else '')))
    plt.savefig(add_suffix(add_suffix(savePath, plot_type), ('_fixed_threshold' if fixed_threshold_across_grp else ''))[:-4] + '.eps', format='eps', dpi=300)
       

# Calculate ROC AUC PPV 
def calConfIntrvl_auc(Y_score,Y_true,n_bootstraps):
    bootstrapped_scores = []
    rng = np.random.RandomState(1)
    for i in range(n_bootstraps):
        indices = rng.randint(0, len(Y_score)-1, len(Y_score))
        if len(np.unique(Y_true[indices])) < 2:
            continue
        score = roc_auc_score(Y_true[indices], Y_score[indices])
        bootstrapped_scores.append(score)
    sorted_scores = np.array(bootstrapped_scores)
    sorted_scores.sort()
    confidence_lower = sorted_scores[int(0.05 * len(sorted_scores))]
    confidence_upper = sorted_scores[int(0.95 * len(sorted_scores))]
    return confidence_lower, confidence_upper
    
def get_ROC_precisionRecall(Y_true,Y_score,savePath=None,CI_flag=False, given_thresholds=None, return_dict=False):
    
    Y_true = np.array(Y_true)
    if len(np.unique(Y_true)) == 1:
        print('Only one category is provided, TPR does not exist')
        return None
    if CI_flag:
        auc_CI_lower, auc_CI_upper = calConfIntrvl_auc(Y_score,Y_true,500)
    else:
        auc_CI_lower = 0
        auc_CI_upper = 0
    roc_auc = roc_auc_score(Y_true, Y_score)
    if given_thresholds is not None:
        thresholds = given_thresholds
                
        bins = copy.deepcopy(thresholds)
        bins.sort()
        
        _Y_score = Y_score[Y_true==0]        
        hist = np.histogram(_Y_score,bins)[0]
        hist = np.append(np.array(_Y_score.shape[0]-hist.sum()), hist)
        fpr = 1 - np.cumsum(hist)[::-1]/len(_Y_score)
        
        _Y_score = Y_score[Y_true==1]        
        hist = np.histogram(_Y_score,bins)[0]
        hist = np.append(np.array(_Y_score.shape[0]-hist.sum()), hist)
        tpr = 1 - np.cumsum(hist)[::-1]/len(_Y_score)
        
        # fpr = np.array([sum(Y_true[Y_score>x]==0)/sum(Y_true==0) for x in thresholds])
        # tpr = np.array([sum(Y_true[Y_score>x]==1)/sum(Y_true==1) for x in thresholds])
    else:
        fpr, tpr, thresholds = metrics.roc_curve(Y_true, Y_score)
    Pr_positive = sum(Y_true)/Y_score.shape[0]
    Pr_negative = 1-Pr_positive
    ppv = Pr_positive*np.array(tpr)/(Pr_positive*np.array(tpr) + Pr_negative*np.array(fpr))
    npv = Pr_negative*np.array(1-fpr)/(Pr_positive*np.array(1-tpr) + Pr_negative*np.array(1-fpr))
    precision_recall_auc = trapz(x=tpr[~np.isnan(np.array(ppv))], y=ppv[~np.isnan(np.array(ppv))])
    Pr_positive = sum(Y_true)/Y_true.shape[0]
    Pr_negative = 1-Pr_positive
    ppr = Pr_positive*tpr+Pr_negative*fpr
    
    if savePath:
        with open(savePath, 'wb') as fp:
            pickle.dump([roc_auc, fpr, tpr, thresholds, ppv, npv, precision_recall_auc, auc_CI_lower, auc_CI_upper,Y_score,Y_true,Pr_positive,Pr_negative, ppr], fp)    
    if return_dict:
        bins = copy.deepcopy(thresholds)
        bins.sort()
        hist = np.histogram(Y_score,bins)[0]
        hist = np.append(np.array(Y_score.shape[0]-hist.sum()), hist)
        percentile = np.cumsum(hist)[::-1]/len(Y_score)
        # percentile = np.array([sum(Y_score <= x)/len(Y_score) for x in thresholds])
        fnr = 1-tpr
        nb = tpr * sum(Y_true==1)/len(Y_true) - fpr * sum(Y_true==0)/len(Y_true) * percentile / (1-percentile)
        nb_treat_all = sum(Y_true==1)/len(Y_true) - sum(Y_true==0)/len(Y_true) * percentile / (1-percentile)
        return  dict(zip(['roc_auc', 'fpr', 'tpr', 'thresholds', 'ppv', 'npv', 'precision_recall_auc', \
                          'auc_CI_lower', 'auc_CI_upper', 'Y_score', 'Y_true', 'Pr_positive', 'Pr_negative', 'ppr', 'percentile', 'fnr', 'nne', 'nb', 'nb_treat_all'],\
                         [roc_auc, fpr, tpr, thresholds, ppv, npv, precision_recall_auc, \
                          auc_CI_lower, auc_CI_upper, Y_score, Y_true, Pr_positive, Pr_negative, ppr, percentile, fnr, 1/ppv, nb, nb_treat_all]))
    else:
        return roc_auc, fpr, tpr, thresholds, ppv, npv, precision_recall_auc, auc_CI_lower, auc_CI_upper, Y_score,Y_true,Pr_positive,Pr_negative, ppr

def plotFeatureImportance(df,labelColName,scoreColName,numVars,fullNameSave,xlabel,neg=False):
    if neg:
        df['valTemp'] = np.abs(df[scoreColName])
        df.sort_values(by=['valTemp'],ascending=False,inplace=True)
    else:
        df.sort_values(by=[scoreColName],ascending=False,inplace=True)
    varList = df[labelColName].tolist()
    varScore = np.array(df[scoreColName])
    varList_1_25 = varList[:numVars]
    varScore_1_25 = varScore[:numVars]    
    y_pos = np.arange(len(varList_1_25))
    plt.figure(figsize=(9 ,9), dpi= 100, facecolor='w', edgecolor='k')
    plt.barh(y_pos, varScore_1_25, align='center', color=(0.6,0.6,0.6,0.6), ecolor='black')
    if neg:
        plt.xlim([np.min(varScore_1_25), np.max(varScore_1_25)])
    else:
        plt.xlim([0, np.max(varScore_1_25)])
    plt.ylim([-1, len(varList_1_25)])
    ax = plt.gca()
    plt.gca().xaxis.grid(True)
    ax.set_yticks(y_pos)
    ax.set_yticklabels(varList_1_25, fontsize=12)
    ax.yaxis.labelpad = 100
    ax.invert_yaxis()  # labels read top-to-bottom
    ax.set_xlabel(xlabel)
    plt.tight_layout()
    plt.show()
    plt.savefig(fullNameSave, dpi=600,bbox_inches='tight')
    