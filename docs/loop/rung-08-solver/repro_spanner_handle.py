"""Independent replica of the walk-7 A16-A18 handle constraint system (planegcs semantics).
Fixed (already fully defined by earlier rows): ellipse c=(0,0), semi 25 (local x) / 27.5 (local y), rot 17 deg;
construction CL (0,0)-(240,0); ring circle c=(240,0) r=16.5.
Unknowns: upper strip P1(x1,y1)->P2(x2,y2), lower (mirror copy) P3->P4."""
import math, numpy as np
from scipy.optimize import least_squares
A=math.radians(17); a,b=25.0,27.5
def onell(x,y):
    u= x*math.cos(A)+y*math.sin(A); v=-x*math.sin(A)+y*math.cos(A)
    return (u/a)**2+(v/b)**2-1
def eqs(q,which):
    x1,y1,x2,y2,x3,y3,x4,y4=q
    E={"H_up":y1-y2,"D10":y1-10,"ring_up":math.hypot(x2-240,y2)-16.5,
       "sym_s_x":x3-x1,"sym_s_y":y3+y1,"sym_e_x":x4-x2,"sym_e_y":y4+y2,
       "ring_lo":math.hypot(x4-240,y4)-16.5,
       "ell_up":onell(x1,y1),"ell_lo":onell(x3,y3)}
    return np.array([E[k] for k in which])
def jac(f,q,h=1e-7):
    f0=f(q);J=np.zeros((len(f0),len(q)))
    for i in range(len(q)):
        d=np.zeros(len(q));d[i]=h;J[:,i]=(f(q+d)-f0)/h
    return J
base=["H_up","D10","ring_up","sym_s_x","sym_s_y","sym_e_x","sym_e_y"]
cases={"A16+A17 (H, dim10, mirror)":base+[],
 "+ ring coincident up":base,
 "+ ell_up (A18 n2)":base+["ell_up"],
 "+ ring_lo":base+["ell_up","ring_lo"],
 "+ ell_lo (A18 4th)":base+["ell_up","ring_lo","ell_lo"],
 "ell_lo WITHOUT mirror (own H+dim10)":None}
q0=np.array([22.944,10,226.876,10,22.944,-10,226.876,-10.0])
for name,w in cases.items():
    if w is None: continue
    f=lambda q:eqs(q,w)
    r=least_squares(f,q0+np.array([3,0.3,0,0,3,-0.3,0,0]),method="trf",xtol=1e-15,ftol=1e-15,gtol=1e-15)
    J=jac(f,r.x); s=np.linalg.svd(J,compute_uv=False)
    rank=int((s>1e-8*s[0]).sum())
    Jaug_rank=rank  # consistency: residual
    print(f"{name:32s} eq={len(w)} unk=8 rank={rank} dof={8-rank} redundant={len(w)-rank} |res|={np.linalg.norm(r.fun):.3e} x1={r.x[0]:.3f} x3={r.x[4]:.3f}")
# conflict size
print("ellipse hits y=+10:", 22.944, " y=-10:", 23.929, " mirror forces x3=x1 -> gap", round(23.929-22.944,3))
