% optimization result plot
clear all; 
clc; 


opt_result = readtable('optimization_result.csv');

time = opt_result.Time;
PV   = opt_result.PV;
Nd   = opt_result.Nodefint;
Df   = opt_result.Defint_Original;
Df_sch = opt_result.Defint_Scheduled;
g    = opt_result.Grid_g;
c    = opt_result.Charge;
d    = opt_result.Discharge;
soc  = opt_result.SOC;
SOC_min = min(soc); 
SOC_max = max(soc);


% fig1
figure('Position', [100, 100, 900, 450]); 
bar(time, [Df, Df_sch], 'grouped');
ylabel('Def&int Load (kW)', 'FontSize', 10);

yyaxis right;
plot(time, soc, 'm-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'm', 'DisplayName', 'Battery SOC');
ylim([SOC_min * 0.9, SOC_max * 1.1]);
ylabel('Battery SOC (kWh)', 'FontSize', 10);

ax = gca;
ax.YAxis(2).Color = 'm'; 

lgd = legend('Original Def&int', 'Scheduled Def&int', 'Battery SOC', 'Location', 'northeast');
lgd.Position(1) = lgd.Position(1) - 0.05;
xlabel('Time', 'FontSize', 10);
title('Def&int Load Shifting and Battery SOC', 'FontSize', 10);
grid on; box on;


% fig2
g_buy = max(0, g);      
g_sell = -min(0, g);    


sinks_matrix = [Nd, Df_sch, c, g_sell];   
sources_matrix = [PV, d, g_buy];         

figure('Position', [100, 100, 900, 450]); 
hold on;


b1 = bar(time, sinks_matrix, 'stacked');
b2 = bar(time, -sources_matrix, 'stacked');

yline(0, 'k-', 'LineWidth', 1); 

legend('No-Def&int Load', 'Def&int Load (Scheduled)', 'Battery Charge', 'Grid Export (Sell)', ...
       'PV Generation', 'Battery Discharge', 'Grid Import (Buy)', ...
       'Location', 'southoutside', 'NumColumns', 5, 'Location', 'Northwest');

title('Hourly Energy Scheduling Optimization (Demands vs. Sources)', 'FontSize', 10);
xlabel('Time', 'FontSize', 10);
ylabel('Power (kW)', 'FontSize', 10);
grid on; box on;
set(gca, 'FontSize', 10);

xlim([time(1)-hours(1), time(end)+hours(1)]);
ylim([-2.0, 2.5]);
hold off;