function [T, P] = cycle_path(Ts, Ps, n)
%CYCLE_PATH  Builds a closed curve through the cycle's state points so it can be plotted.
%   [T, P] = cycle_path(Ts, Ps, n)
%   Ts, Ps : temperatures (K) and pressures (kPa) of the state points, in cycle order
%   n      : number of points drawn along each process
%
%   Two kinds of process are drawn between neighboring states:
%     - same pressure  -> constant-pressure line (combustor, intercooler, regenerator, exhaust)
%     - pressure change -> path T = Ta*(P/Pa)^m through both end states
%       (for an isentropic process m = (k-1)/k, which is a vertical line on the T-s diagram;
%        for a real process it is a smooth curve connecting the actual end states)

T = [];
P = [];
N = numel(Ts);
for i = 1:N
    j = mod(i, N) + 1;                 % next state (the last state connects back to the first)
    Ta = Ts(i);  Pa = Ps(i);
    Tb = Ts(j);  Pb = Ps(j);
    if abs(Pa - Pb) < 1e-6
        Tseg = linspace(Ta, Tb, n);
        Pseg = Pa * ones(1, n);
    else
        Pseg = logspace(log10(Pa), log10(Pb), n);
        m = log(Tb / Ta) / log(Pb / Pa);
        Tseg = Ta * (Pseg / Pa).^m;
    end
    T = [T, Tseg];  %#ok<AGROW>
    P = [P, Pseg];  %#ok<AGROW>
end
end
