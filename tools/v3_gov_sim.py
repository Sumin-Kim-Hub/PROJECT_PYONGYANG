import re, random, math, os
# 사용: python3 tools/v3_gov_sim.py  (v3_data.gd 의 정책/건물 표를 읽어 모의 통치를 돌림. Godot 실행이 아님)
_HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(_HERE, '..', 'scripts', 'v3', 'v3_data.gd'), encoding='utf-8').read()

def grab(fn):
    m = re.search(r"static func %s\(\) -> Array:\n\treturn \[(.*?)\n\t\]\n" % fn, src, re.S)
    return m.group(1)

def _p(id,cat,nm,cost,instant,ptick,ticks,cd,desc): return dict(id=id,cat=cat,name=nm,cost=cost,instant=instant,ptick=ptick,ticks=ticks,cd=cd)
def _b(id,nm,cost,w,d,h,col,style,instant,ptick,upkeep,income,desc): return dict(id=id,name=nm,cost=cost,instant=instant,ptick=ptick,upkeep=upkeep,income=income)
Color=lambda *a: a
POL = eval("[" + grab("policies") + "]")
BLD = eval("[" + grab("buildings") + "]")
KEYS=["budget","economy","satisfaction","development","resources","stability"]
ROUTES = {
 "reform": dict(budget=1200,economy=45,satisfaction=68,development=40,resources=45,stability=42, loy=dict(aide=55,econ=50,mil=35,ppl=75,guard=50)),
 "army": dict(budget=1800,economy=52,satisfaction=40,development=42,resources=50,stability=72, loy=dict(aide=50,econ=50,mil=75,ppl=35,guard=60)),
 "deal": dict(budget=3000,economy=55,satisfaction=48,development=45,resources=52,stability=52, loy=dict(aide=70,econ=65,mil=50,ppl=40,guard=50)),
 "will": dict(budget=1500,economy=45,satisfaction=52,development=40,resources=48,stability=55, loy=dict(aide=60,econ=50,mil=50,ppl=50,guard=55)),
}
def clamp(ind):
    for k in KEYS:
        ind[k] = max(-3000,ind[k]) if k=="budget" else min(100,max(0,ind[k]))
class G:
    def __init__(s, route):
        r=ROUTES[route]; s.ind={k:float(r[k]) for k in KEYS}; s.loy=dict(r["loy"]); s.alloc=dict(welfare=1,security=1,invest=1)
        s.active={}; s.cd={}; s.blds=[]; s.t=0; s.emerg=0
    def delta(s,d):
        for k,v in d.items():
            if k!="budget" and v>0 and s.ind[k]>70: v*=min(1,max(0.15,(100-s.ind[k])/30))
            s.ind[k]+=v
        clamp(s.ind)
    def exec(s,pid):
        p=[x for x in POL if x["id"]==pid][0]
        if pid in s.active or pid in s.cd or p["cost"]>s.ind["budget"]: return False
        s.ind["budget"]-=p["cost"]; s.delta(p["instant"])
        if p["ticks"]>0: s.active[pid]=p["ticks"]
        s.cd[pid]=p["cd"]; return True
    def build(s,bid):
        b=[x for x in BLD if x["id"]==bid][0]
        if b["cost"]>s.ind["budget"]: return False
        s.ind["budget"]-=b["cost"]; s.delta(b["instant"]); s.blds.append(b); return True
    def tick(s):
        s.t+=1; i=s.ind
        up=sum(b["upkeep"] for b in s.blds); inc=sum(b["income"] for b in s.blds)
        pt={}
        for b in s.blds:
            for k,v in b["ptick"].items(): pt[k]=pt.get(k,0)+v
        income=60+i["economy"]*1.2+i["development"]*0.6+inc
        expense=70+up+sum(20*v for v in s.alloc.values())+(10 if s.loy["aide"]<30 else 0)
        lw,ls,li=[s.alloc[k]-1 for k in ("welfare","security","invest")]
        i["satisfaction"]+=0.10*lw-0.03*ls; i["resources"]-=0.04*lw; i["stability"]+=0.10*ls
        i["economy"]+=0.08*li; i["development"]+=0.05*li
        done=[]
        for pid in list(s.active):
            p=[x for x in POL if x["id"]==pid][0]; s.delta(p["ptick"]); s.active[pid]-=1
            if s.active[pid]<=0: done.append(pid)
        for pid in done: del s.active[pid]
        for c in list(s.cd):
            s.cd[c]-=1
            if s.cd[c]<=0: del s.cd[c]
        s.delta(pt)
        if s.loy["econ"]<30: i["economy"]-=0.05
        elif s.loy["econ"]>70: i["economy"]+=0.04
        if s.loy["mil"]<30: i["stability"]-=0.08
        elif s.loy["mil"]>70: i["stability"]+=0.05
        if s.loy["ppl"]<30: i["satisfaction"]-=0.06
        elif s.loy["ppl"]>70: i["satisfaction"]+=0.04
        i["resources"]+=-0.10+(i["economy"]-50)*0.002
        mood=0.4*i["resources"]+0.3*i["economy"]+0.3*i["development"]
        i["satisfaction"]+=(mood-50)*0.01
        i["stability"]+=(i["satisfaction"]-50)*0.008
        i["development"]-=0.02
        if i["resources"]<25: i["satisfaction"]-=0.25; i["stability"]-=0.15
        if i["budget"]<0: i["stability"]-=0.4; i["satisfaction"]-=0.1
        if i["stability"]<20: i["satisfaction"]-=0.2
        i["budget"]+=income-expense
        clamp(i)
        if i["stability"]<=0.5:
            i["budget"]-=500; i["satisfaction"]-=10; i["stability"]=25; s.emerg+=1; clamp(i)
        return income,expense
def fmt(g): return " ".join("%s=%d"%(k[:4],g.ind[k]) for k in KEYS)
print("policies",len(POL),"buildings",len(BLD))
for route in ROUTES:
    g=G(route)
    inc,exp=g.tick()
    print(route,"first tick income/expense",round(inc),round(exp))
    for n in range(1,241):
        g.tick()
        if n in (12,60,120,240): print("  idle",n,fmt(g),"emerg",g.emerg)
print("--- active play: one policy/day (12 ticks), tends to weakest indicator; builds when rich")
import itertools
for route in ROUTES:
    g=G(route)
    for day in range(30):
        # pick weakest non-budget ind
        weak=min(["economy","satisfaction","development","resources","stability"], key=lambda k:g.ind[k])
        pref={"economy":["eco_market","eco_industry","inf_transit"],"satisfaction":["life_ration","life_health","dev_housing"],
              "development":["dev_plan","pub_facility","inf_energy"],"resources":["bud_agri","life_ration"],"stability":["bud_security","life_health"]}[weak]
        for pid in pref:
            if g.exec(pid): break
        if g.ind["budget"]>2500 and len(g.blds)<10:
            g.build(["farm","shop","clinic","market","school","station","park","apartment","factory","power"][len(g.blds)])
        for _ in range(12): g.tick()
        if day in (4,9,19,29): print(route,"day",day+1,fmt(g),"blds",len(g.blds),"emerg",g.emerg)
