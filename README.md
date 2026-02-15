# ADRO_for_REM

#### description:

The core code of the manuscript-"Adaptive Distributionally Robust Optimization for Residential Energy Management Considering Aleatoric and Epistemic Uncertainties in Renewable Generation and Energy Demand" submitted to IEEE ACCESS. 

#### requirement:

Matlab R2021b with YALMIP and Gurobi toolbox. 


#### script:
The main program is adro_experiment.m. 
Running it in MATLAB reproduces all the results presented in this manuscript. 
result_plot.m gives the figures of the optimization results. 

The original data of HOME C is presented in the home_c_data file. 

The prediction of GPR is presented in the pre_data file. 

The adaptive_radius.cvs shows the adaptive radius of the ambiguity set. 

The radius_.cvs shows the radius of the ambiguity set, which is computed as the reference [23]. 


The code will be further enhanced and extended to support community-level energy dispatch in future work.
