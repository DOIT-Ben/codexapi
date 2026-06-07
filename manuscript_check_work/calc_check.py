from decimal import Decimal, ROUND_HALF_UP

def avg(vals):
    return sum(Decimal(str(v)) for v in vals)/Decimal(len(vals))
def r1(x): return x.quantize(Decimal('0.1'), rounding=ROUND_HALF_UP)
def r2(x): return x.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
rows = []
# table, row, values, reported, decimals
for row,vals,rep in [
('ActionFormer I3D',[82.1,77.8,71,59.4,43.9],66.8),('ActionFormer VideoMAE',[84,79.6,73,63.5,47.7],69.6),('TemporalMaxer',[82.8,78.9,71.8,60.5,44.7],67.7),('TriDet',[83.6,80.1,72.9,62.4,47.4],69.3),('TFFormer',[82.1,78.9,72,60.8,44.9],67.8),('ASL',[83.1,79.0,71.7,59.7,45.8],67.9),('TE-TAD',[83.3,78.4,71.3,60.7,45.6],67.9),('DualH',[83.6,79.5,72.2,60,44.9],68.0),('CTAN I3D',[82.9,79.7,72.2,61.2,45.7],68.3),('CTAN VideoMAE',[84.5,80.6,74.6,61.8,48.9],70.1),('DyFADet',[84,80.1,72.7,61.1,47.9],69.2),('GDD-TAD',[83.1,79.2,73.5,63.1,48],69.4),('ADSFormer I3D',[84.4,80.0,73.1,62.9,46.9],69.5),('ADSFormer VideoMAE',[85.3,80.8,73.9,64,49.8],70.8),('BRTAL',[84.2,80.2,73.1,63,47.6],69.6),('SAEFormer I3D',[83.8,80.5,73.4,62.7,48.1],69.7),('SAEFormer VideoMAE',[86.2,81.8,75.4,63.8,49.8],71.4)]: rows.append(('Table 1', row, vals, rep, 1))
for row,vals,rep in [
('ActionFormer Verb',[26.6,25.4,24.2,22.3,19.1],23.5),('TemporalMaxer Verb',[27.8,26.6,25.3,23.1,19.9],24.5),('TriDet Verb',[28.6,27.4,26.1,24.2,20.8],25.4),('TE-TAD Verb',[27.9,26.8,25.4,23.4,20],24.7),('DualH Verb',[28,27.1,25.4,23.1,19.9],24.7),('GDD-TAD Verb',[29.5,28.2,26.9,24.1,20.8],25.9),('BRTAL Verb',[28.4,27.4,25.9,24.7,21],25.4),('SAEFormer Verb',[29.9,29.0,27.4,25.0,21.3],26.5),
('ActionFormer Noun',[25.2,24.1,22.7,20.5,17],21.9),('TemporalMaxer Noun',[26.3,25.2,23.5,21.3,17.6],22.8),('TriDet Noun',[27.4,26.3,24.6,22.2,18.3],23.8),('DualH Noun',[26.1,25,23.1,21.1,18],22.6),('TE-TAD Noun',[26.3,25.2,23.2,21,18.2],22.8),('GDD-TAD Noun',[27.6,27.1,24.1,21,17],23.3),('BRTAL Noun',[27,25.7,23.7,21.5,18.2],23.2),('SAEFormer Noun',[27.7,26.5,24.4,21.8,18.2],23.7)]: rows.append(('Table 3', row, vals, rep, 1))
for row,vals,rep in [('A',[81.89,78.61,72.34,60.60,46.03],67.89),('B',[83.57,80.10,73.53,61.74,46.84],69.16),('C',[83.09,79.08,72.57,62.50,48.64],69.18),('D',[83.80,80.50,73.40,62.70,48.10],69.70)]: rows.append(('Table 4', row, vals, rep, 2))
for row,vals,rep in [('A',[84.03,80.00,72.67,62.73,47.93],69.47),('B',[84.49,80.93,73.38,62.71,49.52],70.13),('C',[85.10,80.60,73.57,62.82,49.12],70.24),('D',[86.19,81.76,75.44,63.83,49.76],71.39)]: rows.append(('Table S1', row, vals, rep, 2))
for row,vals,rep,gain in [('I3D base',[82.10,77.80,71.00,59.40,43.90],66.80,None),('I3D +BAE',[82.50,78.72,71.86,59.65,44.89],67.52,0.72),('VM base',[84.00,79.60,73.00,63.50,47.70],69.60,None),('VM +BAE',[84.28,79.87,73.75,62.96,47.54],69.68,0.08)]: rows.append(('Table S4', row, vals, rep, 2))
issues=[]
for table,row,vals,rep,dec in rows:
    a=avg(vals)
    rr = r1(a) if dec==1 else r2(a)
    ok = Decimal(str(rep)) == rr
    print(f"{table:8} {row:24} calc={a:.4f} rounded={rr} reported={rep} {'OK' if ok else 'MISMATCH'}")
    if not ok: issues.append((table,row,str(a),str(rr),rep))
print('ISSUES', issues)
print('\nGain checks:')
print('S4 I3D gain', Decimal('67.52')-Decimal('66.80'))
print('S4 VM gain', Decimal('69.68')-Decimal('69.60'))
print('Table4 LMSF gain', Decimal('69.16')-Decimal('67.89'))
print('Table4 BAE gain', Decimal('69.18')-Decimal('67.89'))
print('Table4 Full gain', Decimal('69.70')-Decimal('67.89'))
print('S1 LMSF gain', Decimal('70.13')-Decimal('69.47'))
print('S1 BAE gain', Decimal('70.24')-Decimal('69.47'))
print('S1 Full gain', Decimal('71.39')-Decimal('69.47'))
