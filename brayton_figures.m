%% brayton_figures.m
% Brayton cycle analysis: FIGURES AND TABLES  (Thermodynamics I level)
%
% This script does no thermodynamics of its own. It reads the CSV files written by
% brayton_numbers.py and turns them into report figures and tables.
%
% Before running:
%   1. Run  python brayton_numbers.py  in this same folder
%   2. Make sure cycle_path.m is in this same folder
%
% Outputs:
%   figures/fig01_simple.png ... fig09_jet.png   (report figures)
%   tables.txt                                   (report tables, also printed below)

clear; clc; close all;

%% 1. LOAD THE PYTHON RESULTS ---------------------------------------------------------
in = readtable('inputs.csv');
cp = in.cp;  R = in.R;  T1 = in.T1;  P1 = in.P1;  T3 = in.T3;  rp = in.rp;

% Text columns are forced to 'char' so state names like "2a" and "x" are not read as numbers
opts = detectImportOptions('state_points.csv');
opts = setvartype(opts, {'config', 'model', 'state'}, 'char');
S = readtable('state_points.csv', opts);

opts = detectImportOptions('results_summary.csv');
opts = setvartype(opts, {'config', 'model'}, 'char');
RS = readtable('results_summary.csv', opts);

W = readtable('rp_sweep.csv');

opts = detectImportOptions('jet_results.csv');
opts = setvartype(opts, {'config'}, 'char');
J = readtable('jet_results.csv', opts);

if ~exist('figures', 'dir'), mkdir('figures'); end

%% 2. SETTINGS -------------------------------------------------------------------------
configs  = {'Simple', 'Regeneration', 'Intercooling', 'Intercooling + Regeneration'};
fileTags = {'simple', 'regen', 'intercool', 'ic_regen'};
% Order the state points go around each cycle
orders = { {'1','2','3','4'}, ...
           {'1','2','x','3','4','y'}, ...
           {'1','2a','2b','2','3','4'}, ...
           {'1','2a','2b','2','x','3','4','y'} };

% Colors (one per configuration, always in this order) and neutral ink
C = [ 42 120 214;      % blue    - Simple         (also "ideal" on single-config plots)
     235 104  52;      % orange  - Regeneration   (also "real"  on single-config plots)
      27 175 122;      % aqua    - Intercooling
     237 161   0]/255; % yellow  - IC + Regen
GRID = [0.75 0.75 0.75];
INK  = [0.25 0.25 0.25];
MK   = {'o', 's', '^', 'd'};              % a marker per config so color is never the only cue
nPts = 80;                                % points drawn per process

% Property helpers (entropy relative to state 1, specific volume from ideal gas law)
s_of = @(T, P) cp*log(T/T1) - R*log(P/P1);      % kJ/kg-K
v_of = @(T, P) R*T./P;                          % m^3/kg

% Look up one state point, or one row of the summary table
getTP = @(cfg, mdl, st) deal( ...
    S.T_K(  strcmp(S.config, cfg) & strcmp(S.model, mdl) & strcmp(S.state, st)), ...
    S.P_kPa(strcmp(S.config, cfg) & strcmp(S.model, mdl) & strcmp(S.state, st)));
rowOf = @(cfg, mdl) find(strcmp(RS.config, cfg) & strcmp(RS.model, mdl));

%% 3. FIGURES 1-4: T-s AND P-v DIAGRAM FOR EACH CONFIGURATION -------------------------
for c = 1:4
    cfg = configs{c};
    ord = orders{c};
    ns  = numel(ord);

    % Pull the state points (ideal and real) in cycle order
    Ti = zeros(1, ns); Pi = Ti; Tr = Ti; Pr = Ti;
    for q = 1:ns
        [Ti(q), Pi(q)] = getTP(cfg, 'ideal', ord{q});
        [Tr(q), Pr(q)] = getTP(cfg, 'real',  ord{q});
    end
    [Tpi, Ppi] = cycle_path(Ti, Pi, nPts);     % smooth curves through the states
    [Tpr, Ppr] = cycle_path(Tr, Pr, nPts);

    iI = rowOf(cfg, 'ideal');
    iR = rowOf(cfg, 'real');

    fig = figure('Color', 'w', 'Position', [50 50 1500 640]);

    axPos = {[0.06 0.10 0.41 0.74], [0.56 0.10 0.41 0.74]};   % leaves room for the figure title
    for panel = 1:2
        ax = axes('Position', axPos{panel}); hold on; box on; grid on;
        set(ax, 'GridColor', GRID, 'FontSize', 11);

        if panel == 1   % ------- T-s -------
            X  = @(T, P) s_of(T, P);   Y = @(T, P) T;
            % Background isobars
            isoP = [P1, rp*P1];
            if any(strcmp(ord, '2a')), isoP = [P1, sqrt(rp)*P1, rp*P1]; end
            Tg = linspace(220, 1600, 200);
            for p = isoP
                plot(s_of(Tg, p), Tg, ':', 'Color', GRID, 'LineWidth', 1, 'HandleVisibility', 'off');
            end
            isoLabelP = isoP;                  % labels are added after the axis limits are set
        else            % ------- P-v -------
            X  = @(T, P) v_of(T, P);   Y = @(T, P) P;
            % Background isotherms at T1 and T3
            vg = linspace(0.05, 2.6, 300);
            for Tk = [T1, T3]
                plot(vg, R*Tk./vg, ':', 'Color', GRID, 'LineWidth', 1, 'HandleVisibility', 'off');
                text(2.45, R*Tk/2.45, sprintf('%.0f K', Tk), 'Color', [0.55 0.55 0.55], ...
                     'FontSize', 9, 'VerticalAlignment', 'bottom');
            end
        end

        % Cycle loops: ideal solid, real dashed
        plot(X(Tpi, Ppi), Y(Tpi, Ppi), '-',  'Color', C(1,:), 'LineWidth', 2.2, 'DisplayName', 'Ideal cycle');
        plot(X(Tpr, Ppr), Y(Tpr, Ppr), '--', 'Color', C(2,:), 'LineWidth', 2.2, 'DisplayName', 'Real cycle');

        % Set the axis box first so the label offsets can be scaled to it
        xAll = [X(Tpi, Ppi), X(Tpr, Ppr)];  yAll = [Y(Tpi, Ppi), Y(Tpr, Ppr)];
        if panel == 1
            xlim([min(xAll) - 0.15, max(xAll) + 0.35]);  ylim([200 1650]);
        else
            xlim([0, 2.6]);  ylim([0, 1.15*rp*P1]);
        end
        xl = xlim; yl = ylim;
        cx = mean(X(Tpi, Ppi)); cy = mean(Y(Tpi, Ppi));        % loop center

        % Isobar labels on the T-s plot: placed where each isobar leaves the plot box
        if panel == 1
            for p = isoLabelP
                sEdge = xl(2) - 0.02;
                Tedge = T1*exp((sEdge + R*log(p/P1))/cp);      % T on this isobar at s = sEdge
                if Tedge > 1560
                    Tedge = 1560; sEdge = s_of(Tedge, p);
                end
                text(sEdge, Tedge + 25, sprintf('%.0f kPa', p), 'Color', [0.55 0.55 0.55], ...
                     'FontSize', 9, 'HorizontalAlignment', 'right');
            end
        end

        % State points and labels. Real state = number; ideal (isentropic) state = number + "s".
        % Each label is pushed outward from the loop center; when the ideal and real points
        % differ, their labels are also pushed apart from each other.
        unit = @(v) v / (norm(v) + eps);
        placed = zeros(0, 2);                  % label positions already used on this plot
        for q = 1:ns
            xr = X(Tr(q), Pr(q));  yr = Y(Tr(q), Pr(q));
            xi = X(Ti(q), Pi(q));  yi = Y(Ti(q), Pi(q));
            outR = unit([(xr - cx)/diff(xl), (yr - cy)/diff(yl)]);
            same = abs(Tr(q) - Ti(q)) < 0.5 && abs(Pr(q) - Pi(q)) < 1e-6;
            if same
                pts = {xr, yr, ord{q}, INK, outR};
            else
                d = unit([(xi - xr)/diff(xl), (yi - yr)/diff(yl)]);
                pts = {xr, yr, ord{q},        C(2,:), unit(0.7*outR - d); ...
                       xi, yi, [ord{q} 's'],  C(1,:), unit(0.7*outR + d)};
            end
            for m = 1:size(pts, 1)
                [x, y, lab, col, dirn] = pts{m, :};
                plot(x, y, 'o', 'MarkerSize', 7, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'w', ...
                     'HandleVisibility', 'off');
                % If the label would land on top of an earlier one, rotate it in 40-degree steps
                a0 = atan2(dirn(2), dirn(1));
                for tries = 0:8
                    a = a0 + ceil(tries/2) * (-1)^tries * 40*pi/180;
                    lx = (x - xl(1))/diff(xl) + 0.04*cos(a);        % label position, axis fraction
                    ly = (y - yl(1))/diff(yl) + 0.04*sin(a);
                    if isempty(placed) || min(hypot(placed(:,1) - lx, placed(:,2) - ly)) > 0.045
                        break
                    end
                end
                placed(end+1, :) = [lx, ly];                        %#ok<SAGROW>
                text(xl(1) + lx*diff(xl), yl(1) + ly*diff(yl), lab, 'Color', col, ...
                     'FontWeight', 'bold', 'FontSize', 11, 'HorizontalAlignment', 'center');
            end
        end

        if panel == 1
            xlabel('Entropy, s - s_1  [kJ/kg-K]');  ylabel('Temperature, T  [K]');
            title('T-s diagram (enclosed area = net work)');
            legend('Location', 'southeast');
            txt = { sprintf('            Ideal     Real'), ...
                    sprintf('w_c     %7.1f  %7.1f', RS.wc_kJkg(iI),   RS.wc_kJkg(iR)), ...
                    sprintf('w_t     %7.1f  %7.1f', RS.wt_kJkg(iI),   RS.wt_kJkg(iR)), ...
                    sprintf('w_{net} %7.1f  %7.1f', RS.wnet_kJkg(iI), RS.wnet_kJkg(iR)), ...
                    sprintf('q_{in}  %7.1f  %7.1f', RS.qin_kJkg(iI),  RS.qin_kJkg(iR)), ...
                    sprintf('\\eta_{th}   %6.1f%%  %6.1f%%', RS.eta_pct(iI), RS.eta_pct(iR)), ...
                    sprintf('BWR     %7.3f  %7.3f', RS.bwr(iI), RS.bwr(iR)), ...
                    '(kJ/kg)' };
            text(xl(1) + 0.02*diff(xl), yl(2) - 0.03*diff(yl), txt, 'FontName', 'Courier', ...
                 'FontSize', 9, 'VerticalAlignment', 'top', 'EdgeColor', GRID, 'BackgroundColor', 'w');
        else
            xlabel('Specific volume, v  [m^3/kg]');  ylabel('Pressure, P  [kPa]');
            title('P-v diagram (enclosed area = net work)');
            legend('Location', 'northeast');
        end
    end

    % Figure title (works in every MATLAB version, no sgtitle needed)
    annotation(fig, 'textbox', [0 0.91 1 0.08], 'String', ...
        sprintf('%s Brayton cycle:  r_p = %g,  T_1 = %g K,  T_3 = %g K,  \\eta_{th} ideal = %.1f%%,  real = %.1f%%', ...
        cfg, rp, T1, T3, RS.eta_pct(iI), RS.eta_pct(iR)), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');

    print(fig, fullfile('figures', sprintf('fig%02d_%s.png', c, fileTags{c})), '-dpng', '-r150');
end

%% 4. FIGURE 5: ALL IDEAL CYCLES OVERLAID ---------------------------------------------
fig = figure('Color', 'w', 'Position', [50 50 1500 620]);
lw = [6 4.5 3 1.6];                    % thick-to-thin so overlapping loops stay visible
for panel = 1:2
    ax = subplot(1, 2, panel); hold on; box on; grid on; set(ax, 'GridColor', GRID, 'FontSize', 11);
    for c = 1:4
        ord = orders{c}; ns = numel(ord); Ti = zeros(1, ns); Pi = Ti;
        for q = 1:ns, [Ti(q), Pi(q)] = getTP(configs{c}, 'ideal', ord{q}); end
        [Tp, Pp] = cycle_path(Ti, Pi, nPts);
        lab = sprintf('%s (%.1f%%)', configs{c}, RS.eta_pct(rowOf(configs{c}, 'ideal')));
        if panel == 1, plot(s_of(Tp, Pp), Tp, 'Color', C(c,:), 'LineWidth', lw(c), 'DisplayName', lab);
        else,          plot(v_of(Tp, Pp), Pp, 'Color', C(c,:), 'LineWidth', lw(c), 'DisplayName', lab); end
    end
    if panel == 1
        xlabel('Entropy, s - s_1  [kJ/kg-K]'); ylabel('Temperature, T  [K]');
        title('T-s, all configurations (ideal)'); legend('Location', 'northwest');
    else
        xlabel('Specific volume, v  [m^3/kg]'); ylabel('Pressure, P  [kPa]');
        title('P-v, all configurations (ideal)');
    end
end
print(fig, fullfile('figures', 'fig05_overlay.png'), '-dpng', '-r150');

%% 5. FIGURE 6: EFFICIENCY BAR CHART --------------------------------------------------
etaI = zeros(1, 4); etaR = etaI;
for c = 1:4
    etaI(c) = RS.eta_pct(rowOf(configs{c}, 'ideal'));
    etaR(c) = RS.eta_pct(rowOf(configs{c}, 'real'));
end
fig = figure('Color', 'w', 'Position', [50 50 1000 600]);
b = bar([etaI' etaR'], 0.8); hold on; box on; grid on;
set(b(1), 'FaceColor', C(1,:), 'EdgeColor', 'w');
set(b(2), 'FaceColor', C(2,:), 'EdgeColor', 'w');
for c = 1:4
    text(c - 0.14, etaI(c) + 1.2, sprintf('%.1f', etaI(c)), 'HorizontalAlignment', 'center', 'Color', INK);
    text(c + 0.14, etaR(c) + 1.2, sprintf('%.1f', etaR(c)), 'HorizontalAlignment', 'center', 'Color', INK);
end
set(gca, 'XTick', 1:4, 'XTickLabel', {'Simple', 'Regen', 'Intercool', 'IC + Regen'}, 'FontSize', 11, 'GridColor', GRID);
ylim([0 75]); ylabel('Thermal efficiency, \eta_{th}  [%]');
legend({'Ideal', 'Real'}, 'Location', 'northwest');
title(sprintf('Thermal efficiency by configuration (r_p = %g, T_3 = %g K)', rp, T3));
print(fig, fullfile('figures', 'fig06_efficiency_bars.png'), '-dpng', '-r150');

%% 6. FIGURE 7: EFFICIENCY vs PRESSURE RATIO ------------------------------------------
tags = {'Simple', 'Regeneration', 'Intercooling', 'Intercooling_Regeneration'};
fig = figure('Color', 'w', 'Position', [50 50 1500 600]);
models = {'ideal', 'real'};
for panel = 1:2
    ax = subplot(1, 2, panel); hold on; box on; grid on; set(ax, 'GridColor', GRID, 'FontSize', 11);
    for c = 1:4
        y = W.(sprintf('eta_%s_%s', tags{c}, models{panel}));
        idx = 1:20:numel(W.rp);                       % a marker every 20th point
        plot(W.rp, y, '-', 'Color', C(c,:), 'LineWidth', 2, 'HandleVisibility', 'off');
        plot(W.rp(idx), y(idx), MK{c}, 'Color', C(c,:), 'MarkerFaceColor', C(c,:), ...
             'MarkerEdgeColor', 'w', 'MarkerSize', 7, 'HandleVisibility', 'off');
        plot(NaN, NaN, ['-' MK{c}], 'Color', C(c,:), 'LineWidth', 2, 'MarkerFaceColor', C(c,:), ...
             'DisplayName', configs{c});              % legend entry showing line + marker
    end
    yl = ylim; plot([rp rp], yl, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    xlabel('Pressure ratio, r_p'); ylabel('Thermal efficiency, \eta_{th}  [%]');
    title(sprintf('%s cycle efficiency vs r_p (T_3 = %g K)', [upper(models{panel}(1)) models{panel}(2:end)], T3));
    legend('Location', 'southeast');
end
print(fig, fullfile('figures', 'fig07_eta_vs_rp.png'), '-dpng', '-r150');

%% 7. FIGURE 8: NET WORK vs PRESSURE RATIO --------------------------------------------
fig = figure('Color', 'w', 'Position', [50 50 1000 600]); hold on; box on; grid on;
set(gca, 'GridColor', GRID, 'FontSize', 11);
for c = [1 3]      % regeneration does not change net work, so only these two are needed
    plot(W.rp, W.(sprintf('wnet_%s_ideal', tags{c})), '-',  'Color', C(c,:), 'LineWidth', 2, ...
         'DisplayName', [configs{c} ' (ideal)']);
    plot(W.rp, W.(sprintf('wnet_%s_real',  tags{c})), '--', 'Color', C(c,:), 'LineWidth', 2, ...
         'DisplayName', [configs{c} ' (real)']);
end
yl = ylim; plot([rp rp], yl, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
xlabel('Pressure ratio, r_p'); ylabel('Net work, w_{net}  [kJ/kg]');
title('Net work vs r_p (regeneration leaves w_{net} unchanged)');
legend('Location', 'southeast');
print(fig, fullfile('figures', 'fig08_wnet_vs_rp.png'), '-dpng', '-r150');

%% 8. FIGURE 9: TURBOJET THRUST AND FUEL CONSUMPTION -----------------------------------
fig = figure('Color', 'w', 'Position', [50 50 1200 520]);
subplot(1, 2, 1);
b = bar(J.spec_thrust_Nperkgs, 0.55); set(b, 'FaceColor', C(1,:), 'EdgeColor', 'w'); grid on;
set(gca, 'XTickLabel', J.config, 'FontSize', 11, 'GridColor', GRID);
for i = 1:numel(J.spec_thrust_Nperkgs)
    text(i, J.spec_thrust_Nperkgs(i) + 20, sprintf('%.0f', J.spec_thrust_Nperkgs(i)), 'HorizontalAlignment', 'center');
end
ylim([0 1.2*max(J.spec_thrust_Nperkgs)]);
ylabel('Specific thrust  [N per kg/s of air]'); title('Specific thrust (sea-level static)');
subplot(1, 2, 2);
b = bar(J.tsfc_mgNs, 0.55); set(b, 'FaceColor', C(2,:), 'EdgeColor', 'w'); grid on;
set(gca, 'XTickLabel', J.config, 'FontSize', 11, 'GridColor', GRID);
for i = 1:numel(J.tsfc_mgNs)
    text(i, J.tsfc_mgNs(i) + 0.6, sprintf('%.1f', J.tsfc_mgNs(i)), 'HorizontalAlignment', 'center');
end
ylim([0 1.2*max(J.tsfc_mgNs)]);
ylabel('TSFC  [mg fuel per N-s]'); title('Thrust-specific fuel consumption (lower is better)');
print(fig, fullfile('figures', 'fig09_jet.png'), '-dpng', '-r150');

%% 9. TABLES (printed to the Command Window AND saved to tables.txt) ------------------
fid = fopen('tables.txt', 'w');
for out = [1 fid]          % 1 = Command Window, fid = file
    fprintf(out, 'TABLE 1. Input parameters\n');
    fprintf(out, '  cp = %.3f kJ/kg-K   k = %.2f   R = %.3f kJ/kg-K\n', cp, in.k, R);
    fprintf(out, '  T1 = %g K   P1 = %.3f kPa   T3 = %g K   rp = %g\n', T1, P1, T3, rp);
    fprintf(out, '  eta_c = %.2f   eta_t = %.2f   regenerator effectiveness = %.2f   eta_nozzle = %.2f\n\n', ...
            in.eta_c, in.eta_t, in.eps, in.eta_n);

    fprintf(out, 'TABLE 2. State points (T in K, P in kPa, s - s1 in kJ/kg-K, v in m^3/kg)\n');
    for c = 1:4
        fprintf(out, '  %s\n', configs{c});
        fprintf(out, '    %-6s %9s %9s %9s %9s | %9s %9s %9s %9s\n', 'State', 'T ideal', 'P', 's', 'v', ...
                'T real', 'P', 's', 'v');
        for q = 1:numel(orders{c})
            st = orders{c}{q};
            mi = strcmp(S.config, configs{c}) & strcmp(S.model, 'ideal') & strcmp(S.state, st);
            mr = strcmp(S.config, configs{c}) & strcmp(S.model, 'real')  & strcmp(S.state, st);
            fprintf(out, '    %-6s %9.1f %9.1f %9.4f %9.4f | %9.1f %9.1f %9.4f %9.4f\n', st, ...
                    S.T_K(mi), S.P_kPa(mi), S.s_kJkgK(mi), S.v_m3kg(mi), ...
                    S.T_K(mr), S.P_kPa(mr), S.s_kJkgK(mr), S.v_m3kg(mr));
        end
    end

    fprintf(out, '\nTABLE 3. Cycle performance (work and heat in kJ/kg)\n');
    fprintf(out, '  %-30s %-6s %8s %8s %8s %8s %8s %8s\n', 'Configuration', 'Model', 'w_c', 'w_t', 'w_net', 'q_in', 'eta %', 'BWR');
    for i = 1:numel(RS.eta_pct)
        fprintf(out, '  %-30s %-6s %8.1f %8.1f %8.1f %8.1f %8.1f %8.3f\n', RS.config{i}, RS.model{i}, ...
                RS.wc_kJkg(i), RS.wt_kJkg(i), RS.wnet_kJkg(i), RS.qin_kJkg(i), RS.eta_pct(i), RS.bwr(i));
    end

    fprintf(out, '\nTABLE 4. Change compared with the simple cycle\n');
    fprintf(out, '  %-30s %-6s %14s %14s %12s\n', 'Configuration', 'Model', 'eta (points)', 'eta (relative)', 'w_net');
    for mdl = {'ideal', 'real'}
        b0 = rowOf('Simple', mdl{1});
        for c = 2:4
            i = rowOf(configs{c}, mdl{1});
            fprintf(out, '  %-30s %-6s %+13.2f  %+13.1f%%  %+10.1f%%\n', configs{c}, mdl{1}, ...
                    RS.eta_pct(i) - RS.eta_pct(b0), 100*(RS.eta_pct(i)/RS.eta_pct(b0) - 1), ...
                    100*(RS.wnet_kJkg(i)/RS.wnet_kJkg(b0) - 1));
        end
    end

    fprintf(out, '\nTABLE 5. Turbojet, sea-level static (real components)\n');
    fprintf(out, '  %-14s %8s %8s %10s %14s %8s %12s\n', 'Config', 'T4 [K]', 'P4 [kPa]', 'Ve [m/s]', 'F/m [N-s/kg]', 'f', 'TSFC [mg/N-s]');
    for i = 1:numel(J.tsfc_mgNs)
        fprintf(out, '  %-14s %8.1f %8.1f %10.0f %14.0f %8.4f %12.1f\n', J.config{i}, J.T4_K(i), J.P4_kPa(i), ...
                J.Ve_ms(i), J.spec_thrust_Nperkgs(i), J.fuel_air(i), J.tsfc_mgNs(i));
    end
    fprintf(out, '\n');
end
fclose(fid);
disp('Saved figures/fig01-fig09 and tables.txt');
