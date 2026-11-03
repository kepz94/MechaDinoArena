import json
def mir(b):
    o={}
    for k,v in b.items():
        if k=='root': o['root']=dict(v); continue
        n=k[:-1]+('R' if k.endswith('L') else 'L') if k[-1] in 'LR' and k not in ('Tail1',) else k
        o[n]=[v[0],-v[1],-v[2]]
    return o
def mx(p): return [-p[0],p[1],p[2]]
K={}
# body poses: [p pitch (- = lean forward / nod down; arm + = raise forward), y yaw (+ = turn right), r roll]
K['READY']=dict(body={'RootJoint':[-6,0,0],'LegL':[10,0,0],'LegR':[10,0,0],'KneeL':[-16,0,0],'KneeR':[-16,0,0],'AnkleL':[6,0,0],'AnkleR':[6,0,0],'Neck':[-4,0,0]},arms={})
K['R_W']=dict(body={'RootJoint':[6,26,-4],'Neck':[-2,-14,0],'Head':[0,-8,0],'LegR':[12,0,0],'KneeR':[-22,0,0],'LegL':[4,0,0],'KneeL':[-8,0,0],'Tail1':[0,-8,0],'root':{'fwd':-0.5}},arms={'R':[[-9,20,2],[-15,25,6]]})
K['R_S']=dict(body={'RootJoint':[-12,-12,3],'Neck':[-6,10,0],'LegL':[18,0,0],'KneeL':[-26,0,0],'AnkleL':[8,0,0],'LegR':[-4,0,0],'Tail1':[0,6,0],'root':{'fwd':1}},arms={'R':[[-3,14,-13],[3,8,-21]]})
K['R_F']=dict(body={'RootJoint':[-16,-34,5],'Neck':[-6,18,0],'Head':[0,8,0],'LegL':[18,0,0],'KneeL':[-26,0,0],'AnkleL':[8,0,0],'LegR':[-6,0,0],'Tail1':[0,12,0],'root':{'fwd':1.3}},arms={'R':[[5,10,-10],[13,3,-9]]})
for a in ('W','S','F'):
    k=K['R_'+a]; K['L_'+a]=dict(body=mir(k['body']),arms={'L':[mx(k['arms']['R'][0]),mx(k['arms']['R'][1])]})
up_both=lambda h,t:{'R':[h,t],'L':[mx(h),mx(t)]}
K['REAR']=dict(body={'RootJoint':[20,0,0],'Neck':[12,0,0],'Head':[10,0,0],'Jaw':[-30,0,0],'LegL':[-6,0,0],'LegR':[-6,0,0],'KneeL':[4,0,0],'KneeR':[4,0,0],'Tail1':[12,0,0],'Tail2':[6,0,0],'root':{'fwd':-1}},arms=up_both([-6,27,-1],[-9,36,7]))
K['REAR2']=dict(body={'RootJoint':[24,0,0],'Neck':[14,0,0],'Head':[12,0,0],'Jaw':[-34,0,0],'LegL':[-8,0,0],'LegR':[-8,0,0],'KneeL':[4,0,0],'KneeR':[4,0,0],'Tail1':[14,0,0],'Tail2':[8,0,0],'root':{'fwd':-1.4}},arms=up_both([-6,28,1],[-10,37,9]))
K['CHOP']=dict(body={'RootJoint':[-30,0,0],'Neck':[-18,0,0],'Head':[-8,0,0],'Jaw':[-8,0,0],'LegL':[26,0,0],'LegR':[26,0,0],'KneeL':[-40,0,0],'KneeR':[-40,0,0],'AnkleL':[14,0,0],'AnkleR':[14,0,0],'Tail1':[10,0,0],'root':{'fwd':2}},arms=up_both([-5,12,-13],[-4,3,-20]))
K['CHOP_SET']=dict(body={'RootJoint':[-26,0,0],'Neck':[-14,0,0],'Head':[-6,0,0],'LegL':[22,0,0],'LegR':[22,0,0],'KneeL':[-34,0,0],'KneeR':[-34,0,0],'AnkleL':[12,0,0],'AnkleR':[12,0,0],'Tail1':[8,0,0],'root':{'fwd':2}},arms=up_both([-6,12,-12],[-5,3,-19]))
K['J_CROUCH']=dict(body={'RootJoint':[-14,0,0],'Neck':[-8,0,0],'LegL':[32,0,0],'LegR':[32,0,0],'KneeL':[-58,0,0],'KneeR':[-58,0,0],'AnkleL':[26,0,0],'AnkleR':[26,0,0],'Tail1':[-4,0,0]},arms=up_both([-9,9,5],[-12,3,13]))
K['J_AIR']=dict(body={'RootJoint':[12,0,0],'Neck':[8,0,0],'Head':[6,0,0],'Jaw':[-28,0,0],'LegL':[45,0,0],'LegR':[45,0,0],'KneeL':[-72,0,0],'KneeR':[-72,0,0],'AnkleL':[22,0,0],'AnkleR':[22,0,0],'Tail1':[-8,0,0],'Tail2':[-6,0,0]},arms=up_both([-6,27,-1],[-9,36,7]))
K['J_LAND']=dict(body={'RootJoint':[-32,0,0],'Neck':[-20,0,0],'Head':[-8,0,0],'Jaw':[-8,0,0],'LegL':[36,0,0],'LegR':[36,0,0],'KneeL':[-64,0,0],'KneeR':[-64,0,0],'AnkleL':[26,0,0],'AnkleR':[26,0,0],'Tail1':[10,0,0]},arms=up_both([-6,10,-13],[-5,1,-22]))
order=['READY','R_W','R_S','R_F','L_W','L_S','L_F','REAR','REAR2','CHOP','CHOP_SET','J_CROUCH','J_AIR','J_LAND']
tests=[]
chainR=False; chainL=False
for n in order:
    k=K[n]
    for side in ('R','L'):
        if side in k['arms']:
            h,t=k['arms'][side]
            tests.append([n+'|'+side,k['body'],side,h,t,False])
json.dump(tests,open('spec_tests.json','w')); json.dump({'order':order,'K':K},open('spec.json','w'))
print(len(tests))
