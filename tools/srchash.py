# srchash.py v1.0 (Mecha Dino Arena): length + hash of a source file, the same numbers the Studio check prints.
# Luau twin: local h=0 for i=1,#s do h=(h*31+s:byte(i))%2147483647 end  (s = Script.Source)
import sys
for p in sys.argv[1:]:
    b=open(p,'rb').read().replace(b'\r\n',b'\n')
    h=0
    for c in b: h=(h*31+c)%2147483647
    print(len(b),h,p)
