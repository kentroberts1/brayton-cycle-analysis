"""
brayton_numbers.py
------------------
Brayton cycle analysis of a gas turbine / turbojet  (Thermodynamics I level)

What it does
  1. Solves four cycle configurations, each as an ideal and a real cycle:
        Simple, Regeneration, Intercooling, Intercooling + Regeneration
  2. Solves the turbojet version (sea-level static) for thrust and fuel use
  3. Sweeps the pressure ratio from 2 to 40
  4. Prints the results and writes four CSV files for the MATLAB plotting program

Assumptions (cold-air-standard)
  - Air is an ideal gas with constant cp and k (room-temperature values)
  - Combustion is modeled as constant-pressure heat addition; fuel mass is ignored
  - No pressure drops in the combustor, intercooler or regenerator
  - Kinetic and potential energy changes are neglected (except in the nozzle)
  - Two-stage intercooling uses equal pressure ratios and cools back to T1

Run:  python brayton_numbers.py
Out:  results_summary.csv, state_points.csv, rp_sweep.csv, jet_results.csv
"""
import csv
import math

# =============================================================================
# 1. INPUTS  (change these to run your own case)
# =============================================================================
cp = 1.005          # kJ/kg-K, specific heat of air at constant pressure
k = 1.4             # -, specific heat ratio of air
R = cp * (k - 1) / k   # kJ/kg-K, gas constant (= 0.287 for air)

T1 = 288.0          # K, compressor inlet temperature (sea-level standard day)
P1 = 101.325        # kPa, compressor inlet pressure
T3 = 1400.0         # K, turbine inlet temperature (limited by blade materials)
rp = 12.0           # -, overall compressor pressure ratio P2/P1

eta_c = 0.85        # -, compressor isentropic efficiency  (real cycle)
eta_t = 0.88        # -, turbine isentropic efficiency     (real cycle)
eps = 0.80          # -, regenerator effectiveness         (real cycle)

eta_n = 0.95        # -, nozzle isentropic efficiency (jet mode)
LHV = 43000.0       # kJ/kg, lower heating value of jet fuel (jet mode)

EXP = (k - 1) / k   # the exponent that shows up in every isentropic relation


# =============================================================================
# 2. COMPONENT FUNCTIONS  (one function per piece of hardware)
# =============================================================================
def compressor(T_in, pr, eff):
    """Adiabatic compressor.  Returns exit temperature (K) and work in (kJ/kg).
    Isentropic:  T_out,s = T_in * pr^((k-1)/k)
    Efficiency:  eta_c = (T_out,s - T_in) / (T_out - T_in)"""
    T_out_s = T_in * pr ** EXP
    T_out = T_in + (T_out_s - T_in) / eff
    w_in = cp * (T_out - T_in)
    return T_out, w_in


def turbine(T_in, pr, eff):
    """Adiabatic turbine.  Returns exit temperature (K) and work out (kJ/kg).
    Isentropic:  T_out,s = T_in / pr^((k-1)/k)
    Efficiency:  eta_t = (T_in - T_out) / (T_in - T_out,s)"""
    T_out_s = T_in / pr ** EXP
    T_out = T_in - eff * (T_in - T_out_s)
    w_out = cp * (T_in - T_out)
    return T_out, w_out


def regenerator(T_cold_in, T_hot_in, effectiveness):
    """Counter-flow regenerator (both streams have the same m-dot and cp).
    effectiveness = (Tx - T2) / (T4 - T2)
    Returns cold-side exit Tx and hot-side exit Ty.
    If the exhaust is colder than the compressor exit, a regenerator would heat
    the exhaust instead, so it is bypassed (Tx = T2)."""
    if T_hot_in <= T_cold_in:
        return T_cold_in, T_hot_in
    Tx = T_cold_in + effectiveness * (T_hot_in - T_cold_in)
    Ty = T_hot_in - (Tx - T_cold_in)      # energy balance: heat lost by hot = heat gained by cold
    return Tx, Ty


def entropy(T, P):
    """Entropy relative to state 1 (kJ/kg-K), ideal gas with constant cp:
    s - s1 = cp ln(T/T1) - R ln(P/P1)"""
    return cp * math.log(T / T1) - R * math.log(P / P1)


def spec_volume(T, P):
    """Ideal-gas specific volume (m^3/kg):  v = RT/P  (R in kJ/kg-K, P in kPa)"""
    return R * T / P


# =============================================================================
# 3. CYCLE SOLVER
# =============================================================================
def solve_cycle(intercool, regen, real, pr=rp, T_max=T3):
    """Solve one configuration.  Returns a dict with states and performance."""
    ec, et, ef = (eta_c, eta_t, eps) if real else (1.0, 1.0, 1.0)
    P2 = pr * P1
    states = {"1": (T1, P1)}

    # ---- compression -------------------------------------------------------
    if intercool:
        Pi = math.sqrt(P1 * P2)                       # optimal intermediate pressure
        T2a, w1 = compressor(T1, Pi / P1, ec)         # stage 1
        T2b = T1                                      # intercooler: back to T1
        T2, w2 = compressor(T2b, P2 / Pi, ec)         # stage 2
        w_c = w1 + w2
        q_ic = cp * (T2a - T2b)                       # heat removed in the intercooler
        states["2a"] = (T2a, Pi)
        states["2b"] = (T2b, Pi)
    else:
        T2, w_c = compressor(T1, pr, ec)
        q_ic = 0.0
    states["2"] = (T2, P2)

    # ---- expansion ---------------------------------------------------------
    T4, w_t = turbine(T_max, pr, et)

    # ---- regenerator -------------------------------------------------------
    if regen:
        Tx, Ty = regenerator(T2, T4, ef)
        states["x"] = (Tx, P2)
    else:
        Tx, Ty = T2, T4
    states["3"] = (T_max, P2)
    states["4"] = (T4, P1)
    if regen:
        states["y"] = (Ty, P1)

    # ---- performance -------------------------------------------------------
    q_in = cp * (T_max - Tx)                  # only the combustor burns fuel
    w_net = w_t - w_c
    q_out = q_in - w_net                      # first law for the whole cycle
    return {
        "states": states, "T2": T2, "T4": T4, "Tx": Tx, "Ty": Ty,
        "w_c": w_c, "w_t": w_t, "w_net": w_net, "q_in": q_in, "q_out": q_out, "q_ic": q_ic,
        "eta": w_net / q_in, "bwr": w_c / w_t,
    }


def solve_jet(intercool):
    """Turbojet at sea-level static conditions (V0 = 0), real components.
    The turbine only produces enough work to drive the compressor; the gas
    leaving the turbine still has pressure left, and the nozzle turns that
    into exhaust velocity."""
    c = solve_cycle(intercool, regen=False, real=True)
    w_c, q_in = c["w_c"], c["q_in"]
    T4 = T3 - w_c / cp                            # turbine work = compressor work
    T4s = T3 - (T3 - T4) / eta_t                  # isentropic turbine exit temp
    P4 = rp * P1 * (T4s / T3) ** (1 / EXP)        # turbine exit pressure
    T5s = T4 * (P1 / P4) ** EXP                   # nozzle expands to ambient
    T5 = T4 - eta_n * (T4 - T5s)
    Ve = math.sqrt(2 * cp * 1000 * (T4 - T5))     # m/s  (cp in J/kg-K)
    spec_thrust = Ve                              # N per (kg/s) of air, since V0 = 0
    f = q_in / LHV                                # kg fuel per kg air
    tsfc = f / spec_thrust * 1e6                  # mg of fuel per N-s
    return {"T4": T4, "P4": P4, "T5": T5, "Ve": Ve, "spec_thrust": spec_thrust,
            "fuel_air": f, "tsfc": tsfc, "q_in": q_in}


# =============================================================================
# 4. RUN EVERYTHING
# =============================================================================
CONFIGS = [  # (name, intercool, regen)
    ("Simple", False, False),
    ("Regeneration", False, True),
    ("Intercooling", True, False),
    ("Intercooling + Regeneration", True, True),
]


def main():
    print("=" * 96)
    print(f"BRAYTON CYCLE ANALYSIS   rp = {rp:g}, T1 = {T1:g} K, T3 = {T3:g} K, "
          f"eta_c = {eta_c}, eta_t = {eta_t}, eps = {eps}")
    print("=" * 96)

    # ---- 4a. main results table -------------------------------------------
    rows = []
    hdr = (f"{'Configuration':<30}{'Model':<7}{'T2':>7}{'T4':>7}{'Tx':>7}{'w_c':>8}{'w_t':>8}"
           f"{'w_net':>8}{'q_in':>8}{'eta %':>7}{'BWR':>7}")
    print(hdr)
    print("-" * len(hdr))
    results = {}
    for name, ic, rg in CONFIGS:
        for real in (False, True):
            c = solve_cycle(ic, rg, real)
            model = "real" if real else "ideal"
            results[(name, model)] = c
            print(f"{name:<30}{model:<7}{c['T2']:7.1f}{c['T4']:7.1f}{c['Tx']:7.1f}{c['w_c']:8.1f}"
                  f"{c['w_t']:8.1f}{c['w_net']:8.1f}{c['q_in']:8.1f}{100 * c['eta']:7.1f}{c['bwr']:7.3f}")
            rows.append([name, model, c["T2"], c["T4"], c["Tx"], c["w_c"], c["w_t"], c["w_net"],
                         c["q_in"], c["q_out"], 100 * c["eta"], c["bwr"]])
    print("(temperatures in K, work and heat in kJ/kg)")

    # ---- 4b. change vs the simple cycle -----------------------------------
    print("\nChange vs simple cycle")
    for model in ("ideal", "real"):
        base = results[("Simple", model)]
        for name, _, _ in CONFIGS[1:]:
            c = results[(name, model)]
            d_pts = 100 * (c["eta"] - base["eta"])
            d_rel = 100 * (c["eta"] / base["eta"] - 1)
            d_w = 100 * (c["w_net"] / base["w_net"] - 1)
            print(f"  {model:<6}{name:<30} eta {d_pts:+6.2f} points ({d_rel:+5.1f} % relative)"
                  f"   w_net {d_w:+5.1f} %")

    # ---- 4c. useful limits ------------------------------------------------
    rp_regen_simple = (T3 / T1) ** (1 / (2 * EXP))       # T4 = T2 for the ideal simple cycle
    rp_regen_ic = (T3 / T1) ** (1 / (1.5 * EXP))         # T4 = T2 for the ideal intercooled cycle
    rp_max_work = (T3 / T1) ** (1 / (2 * EXP))           # max w_net, ideal simple cycle
    carnot = 1 - T1 / T3
    print("\nLimits (ideal cycle)")
    print(f"  Carnot efficiency 1 - T1/T3                 = {100 * carnot:.1f} %")
    print(f"  rp for maximum net work (simple)            = {rp_max_work:.1f}")
    print(f"  rp where regeneration stops helping (simple)= {rp_regen_simple:.1f}")
    print(f"  rp where regeneration stops helping (IC)    = {rp_regen_ic:.1f}")

    # ---- 4d. turbojet mode -------------------------------------------------
    print("\nTurbojet, sea-level static, real components")
    jet_rows = []
    for label, ic in (("Simple", False), ("Intercooling", True)):
        j = solve_jet(ic)
        print(f"  {label:<14} T4 = {j['T4']:.1f} K   P4 = {j['P4']:.0f} kPa   Ve = {j['Ve']:.0f} m/s   "
              f"F/m-dot = {j['spec_thrust']:.0f} N/(kg/s)   f = {j['fuel_air']:.4f}   "
              f"TSFC = {j['tsfc']:.1f} mg/(N-s)")
        jet_rows.append([label, j["T4"], j["P4"], j["T5"], j["Ve"], j["spec_thrust"], j["fuel_air"], j["tsfc"]])

    # ---- 4e. write CSV files for MATLAB ----------------------------------
    with open("results_summary.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["config", "model", "T2_K", "T4_K", "Tx_K", "wc_kJkg", "wt_kJkg", "wnet_kJkg",
                    "qin_kJkg", "qout_kJkg", "eta_pct", "bwr"])
        w.writerows([[r[0], r[1]] + [round(v, 4) for v in r[2:]] for r in rows])

    with open("state_points.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["config", "model", "state", "T_K", "P_kPa", "s_kJkgK", "v_m3kg"])
        for (name, model), c in results.items():
            for st, (T, P) in c["states"].items():
                w.writerow([name, model, st, round(T, 4), round(P, 4),
                            round(entropy(T, P), 6), round(spec_volume(T, P), 6)])

    with open("rp_sweep.csv", "w", newline="") as f:
        w = csv.writer(f)
        head = ["rp"]
        for name, _, _ in CONFIGS:
            tag = name.replace(" + ", "_").replace(" ", "_")
            head += [f"eta_{tag}_ideal", f"eta_{tag}_real", f"wnet_{tag}_ideal", f"wnet_{tag}_real"]
        w.writerow(head)
        for i in range(191):                      # rp = 2.0, 2.2, ... 40.0
            r = 2.0 + 0.2 * i
            line = [round(r, 2)]
            for _, ic, rg in CONFIGS:
                ci = solve_cycle(ic, rg, False, pr=r)
                cr = solve_cycle(ic, rg, True, pr=r)
                line += [round(100 * ci["eta"], 4), round(100 * cr["eta"], 4),
                         round(ci["w_net"], 4), round(cr["w_net"], 4)]
            w.writerow(line)

    with open("jet_results.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["config", "T4_K", "P4_kPa", "T5_K", "Ve_ms", "spec_thrust_Nperkgs", "fuel_air", "tsfc_mgNs"])
        w.writerows([[r[0]] + [round(v, 5) for v in r[1:]] for r in jet_rows])

    with open("inputs.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["cp", "k", "R", "T1", "P1", "T3", "rp", "eta_c", "eta_t", "eps", "eta_n", "LHV"])
        w.writerow([cp, k, R, T1, P1, T3, rp, eta_c, eta_t, eps, eta_n, LHV])

    print("\nWrote results_summary.csv, state_points.csv, rp_sweep.csv, jet_results.csv, inputs.csv")


if __name__ == "__main__":
    main()
