clear; clc;

% random seed
rng(42, 'twister');

% load data
op = readtable('storage_and_defint_parameters.csv');
rad = readtable('adaptive_radius.csv');
PV_pre = readtable('pre_data\gpr_PV_coldstart.csv');
Nodefint_pre = readtable('pre_data\gpr_nodefint_coldstart.csv');
defint_pre = readtable('pre_data\gpr_defint_coldstart.csv');

% parameter
T = 24;
PV_pred = PV_pre.Prediction;
Nd_pred = Nodefint_pre.Prediction;
Df_total = sum(op.Defint_pred);

PV_r = rad.tepsilon_PV;
Nd_r = rad.tepsilon_nodefint;
price = op.Price;
cost_deg = 0.06;
SOC_max = 2.5; Pmax = 1.25; eta = 0.95;

% scenairo sampling
num_samples = 100;
samples_PV = zeros(T, num_samples);
samples_Nd = zeros(T, num_samples);

for i = 1:num_samples
    samples_PV(:, i) = PV_pred + (PV_r .* PV_pred / 3) .* randn(T, 1);
    samples_Nd(:, i) = Nd_pred + (Nd_r .* Nd_pred / 3) .* randn(T, 1);
    
    samples_PV(:, i) = max(PV_pred.*(1-PV_r), min(samples_PV(:, i), PV_pred.*(1+PV_r)));
    samples_PV(:, i) = max(0, samples_PV(:, i));
    samples_Nd(:, i) = max(Nd_pred.*(1-Nd_r), min(samples_Nd(:, i), Nd_pred.*(1+Nd_r)));
end

% C&CG 
tic;
max_iter = 30;
scenarios_PV = PV_pred;   
scenarios_Nd = Nd_pred;
LB = -inf; UB = inf;
LB_trace = []; UB_trace = [];

ops = sdpsettings('solver', 'gurobi', 'verbose', 0, 'gurobi.MIPGap', 1e-4);

fprintf('Iter |      LB      |      UB      |    Gap ($)   \n');
fprintf('-----------------------------------------------\n');


for k = 1:max_iter
    % Master Problem
    Df_sch = sdpvar(T, 1);
    b_ch = binvar(T, 1);    
    b_dis = binvar(T, 1);
    theta = sdpvar(1, 1);   
    
    g = sdpvar(T, k);
    c = sdpvar(T, k);
    d = sdpvar(T, k);
    soc = sdpvar(T+1, k);
    
    Constraints = [sum(Df_sch) == Df_total, Df_sch >= 0, Df_sch <= 1.5*max(op.Defint_pred)];
    Constraints = [Constraints, b_ch + b_dis <= 1];
    
    Objective = theta;
    for s = 1:k
        Objective = Objective + (1/k) * cost_deg * sum(c(:,s) + d(:,s));
        Constraints = [Constraints, theta >= price' * g(:,s)];
        Constraints = [Constraints, soc(1,s) == 0];
        for t = 1:T
            Constraints = [Constraints, g(t,s) + d(t,s) + scenarios_PV(t,s) == scenarios_Nd(t,s) + Df_sch(t) + c(t,s)];
            Constraints = [Constraints, soc(t+1,s) == soc(t,s) + c(t,s)*eta - d(t,s)/eta];
            Constraints = [Constraints, 0 <= soc(t+1,s) <= SOC_max];
            Constraints = [Constraints, 0 <= c(t,s) <= Pmax * b_ch(t)];
            Constraints = [Constraints, 0 <= d(t,s) <= Pmax * b_dis(t)];
        end
    end
    
    sol = optimize(Constraints, Objective, ops);
    if sol.problem ~= 0, error('Master Problem Failed'); end
    LB = value(Objective);
    LB_trace = [LB_trace, LB];

    % Sub-problem
    max_sub_cost = -inf;
    temp_worst_PV = [];
    temp_worst_Nd = [];

    curr_Df = value(Df_sch);
    curr_bch = value(b_ch);
    curr_bdis = value(b_dis);

    for i = 1:num_samples
        test_PV = samples_PV(:, i);
        test_Nd = samples_Nd(:, i);
        
        c_t = sdpvar(T, 1); d_t = sdpvar(T, 1); g_t = sdpvar(T, 1); s_t = sdpvar(T+1, 1);
        C_t = [s_t(1) == 0];
        for t = 1:T
            C_t = [C_t, g_t(t) + d_t(t) + test_PV(t) == test_Nd(t) + curr_Df(t) + c_t(t)];
            C_t = [C_t, s_t(t+1) == s_t(t) + c_t(t)*eta - d_t(t)/eta, 0 <= s_t(t+1) <= SOC_max];
            C_t = [C_t, 0 <= c_t(t) <= Pmax * curr_bch(t), 0 <= d_t(t) <= Pmax * curr_bdis(t)];
        end
        optimize(C_t, price' * g_t + cost_deg * sum(c_t + d_t), ops);
        current_sample_cost = value(price' * g_t + cost_deg * sum(c_t + d_t));
        
        if current_sample_cost > max_sub_cost
            max_sub_cost = current_sample_cost;
            temp_worst_PV = test_PV;
            temp_worst_Nd = test_Nd;
        end
    end
    
    UB = min(UB, max_sub_cost);
    UB_trace = [UB_trace, UB];
    gap = abs(UB - LB);
    fprintf('%4d | %10.4f | %10.4f | %10.4e \n', k, LB, UB, gap);
    
    % worst scenario
    final_worst_PV = temp_worst_PV;
    final_worst_Nd = temp_worst_Nd;

    if gap < 1e-3, break; end
    
    scenarios_PV = [scenarios_PV, temp_worst_PV];
    scenarios_Nd = [scenarios_Nd, temp_worst_Nd];
end

elapsed_time = toc;  % solving time
fprintf('solving time: %.4f S\n', elapsed_time);

% optimization result
fprintf('Optimization Complete! Total Cost: $%.4f\n', UB);

% convergence plot)
figure('Color', 'w');
plot(LB_trace, 'b-s', 'LineWidth', 1.5); hold on;
plot(UB_trace, 'r-o', 'LineWidth', 1.5);
grid on; xlabel('Iteration Index'); ylabel('Cost ($)');
legend('Lower Bound (Master Problem)', 'Upper Bound (Sub Problem)');
title('C&CG Convergence Trajectory');