import json
# body poses while running ([p pitch (- = lean forward), y yaw, r roll]); arms solved from hand / claw-tip targets
# (dino at the origin facing -Z, its right = -X; tip y ~0 = on the ground)
O={}
O['A']=dict(body={'RootJoint':[-16,0,0],'Neck':[-24,0,0],'Head':[18,0,0],'Jaw':[-10,0,0],'Tail1':[-6,0,0]},
  arms={'R':[[-8,7,3],[-11,-0.2,11]],'L':[[7,15,-9],[12,19,-17]]})
O['B']=dict(body={'RootJoint':[-24,0,0],'Neck':[-14,0,0],'Head':[12,0,0],'Jaw':[-6,0,0],'Tail1':[-4,0,0]},
  arms={'R':[[-11,7,-2],[-19,-0.2,3]],'L':[[3,12,-7],[6,8,-17]]})
O['C']=dict(body={'RootJoint':[-30,0,0],'Neck':[-6,0,0],'Head':[14,0,0],'Jaw':[-10,0,0],'Tail1':[-2,0,0]},
  arms={'R':[[-4,4,2],[-5,-0.2,11]],'L':[[5,9,-11],[7,6,-21]]})
tests=[]
for k,o in O.items():
    for side,(h,t) in o['arms'].items(): tests.append([k+'|'+side,o['body'],side,h,t,False])
json.dump(tests,open('run_tests.json','w')); json.dump(O,open('runspec.json','w'))
