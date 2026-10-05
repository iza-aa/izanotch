import json

with open('data/FuturesScoutPaperTrades_stage2a.jsonl') as f:
    trades = [json.loads(line) for line in f if line.strip()]

grades = {
    'A_GRADE': {'count': 0, 'wins': 0, 'gross': 0.0, 'net': 0.0, 'mfe_sum': 0.0},
    'B_GRADE': {'count': 0, 'wins': 0, 'gross': 0.0, 'net': 0.0, 'mfe_sum': 0.0}
}

for t in trades:
    g = t.get('grade', 'B_GRADE')
    grades[g]['count'] += 1
    if t.get('grossPnlUsd', 0) > 0:
        grades[g]['wins'] += 1
    grades[g]['gross'] += t.get('grossPnlUsd', 0.0)
    grades[g]['net'] += t.get('netPnlUsd', 0.0)
    grades[g]['mfe_sum'] += t.get('mfeAtrRatio', 0.0)

print("=== DIAGNOSTIK GRADE A (>=80) VS GRADE B (65-79) (STAGE 2A) ===")
for g, s in grades.items():
    cnt = s['count']
    wr = (s['wins'] / cnt * 100) if cnt > 0 else 0.0
    avg_g = (s['gross'] / cnt) if cnt > 0 else 0.0
    avg_net = (s['net'] / cnt) if cnt > 0 else 0.0
    avg_mfe = (s['mfe_sum'] / cnt) if cnt > 0 else 0.0
    print(f"{g:<10} | Count: {cnt:<3} | Gross WR: {wr:5.1f}% | Gross PnL: ${s['gross']:>8.2f} | Net PnL: ${s['net']:>8.2f} | Avg Gross: ${avg_g:>6.2f} | Avg Net: ${avg_net:>6.2f} | Avg MFE/ATR: {avg_mfe:.2f}")
