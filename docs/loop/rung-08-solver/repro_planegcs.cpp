// Real PlaneGCS (vendored) replica of walk-7 A16..A18 handle system. Build: see solver-diagnosis.md
#include "GCS.h"
#include <cmath>
#include <cstdio>
#include <vector>
using namespace GCS;
struct Case { const char* name; bool ring_up, ell_up, ring_lo, ell_lo, mirror; };
static void run(const Case& k, Algorithm alg, const char* an, bool seed_on_curve) {
  double x1=22.944,y1=10,x2=226.876,y2=10,x3=22.944,y3=-10,x4=226.876,y4=-10;
  if (!k.mirror) { x3=23.9; }            // lower drawn at upper's x (as walk)
  // constants
  double ox=0,oy=0,ax=240,ay=0, cx=240,cy=0,r=16.5;
  double ang=M_PI*107/180, fc=std::sqrt(27.5*27.5-25*25);
  double ecx=0,ecy=0,efx=fc*std::cos(ang),efy=fc*std::sin(ang),erm=25;
  if (seed_on_curve && k.ell_lo) x3=23.929;
  Point P1{&x1,&y1},P2{&x2,&y2},P3{&x3,&y3},P4{&x4,&y4},O{&ox,&oy},Ax{&ax,&ay};
  Line up; up.p1=P1; up.p2=P2; Line lo; lo.p1=P3; lo.p2=P4; Line cl; cl.p1=O; cl.p2=Ax;
  Circle ring; ring.center=Point{&cx,&cy}; ring.rad=&r;
  Ellipse el; el.center=Point{&ecx,&ecy}; el.focus1=Point{&efx,&efy}; el.radmin=&erm;
  double d10=10;
  System s; int t=0;
  s.addConstraintHorizontal(up,++t); s.addConstraintP2LDistance(P1,cl,&d10,++t);
  if(k.ring_up) s.addConstraintPointOnCircle(P2,ring,++t);
  if(k.mirror){ s.addConstraintP2PSymmetric(P1,P3,cl,++t); s.addConstraintP2PSymmetric(P2,P4,cl,++t);} 
  else { s.addConstraintHorizontal(lo,++t); s.addConstraintP2LDistance(P3,cl,&d10,++t);} 
  if(k.ell_up) s.addConstraintPointOnEllipse(P1,el,++t);
  if(k.ring_lo) s.addConstraintPointOnCircle(P4,ring,++t);
  if(k.ell_lo) s.addConstraintPointOnEllipse(P3,el,++t);
  VEC_pD u{&x1,&y1,&x2,&y2,&x3,&y3,&x4,&y4};
  s.declareUnknowns(u); s.initSolution();
  int st=s.solve(true,alg); if(st==Success||st==Converged) s.applySolution();
  int dof=s.diagnose(); VEC_I c,rd; s.getConflicting(c); s.getRedundant(rd);
  printf("%-34s %-4s seed=%d status=%d(%s) dof=%d conflicting=[",k.name,an,seed_on_curve,st,
         (st==Success||st==Converged)?"ok":"FAIL",dof);
  for(int i:c)printf("%d ",i); printf("] redundant=["); for(int i:rd)printf("%d ",i);
  printf("] P1=(%.3f,%.3f) P3=(%.3f,%.3f)\n",x1,y1,x3,y3);
}
int main(){
  Case cs[]={{"A16+A17 H,dim10,mirror",false,false,false,false,true},
    {"+ring_up",true,false,false,false,true},
    {"+ell_up (A18 #2)",true,true,false,false,true},
    {"+ring_lo (A18 #3)",true,true,true,false,true},
    {"+ell_lo (A18 #4)",true,true,true,true,true},
    {"no-mirror: own H+dim10, both ell",true,true,true,true,false}};
  for(auto&k:cs){ run(k,DogLeg,"DL",false); }
  printf("--- alternatives on the conflicting case ---\n");
  run(cs[4],LevenbergMarquardt,"LM",false); run(cs[4],BFGS,"BFGS",false); run(cs[4],DogLeg,"DL",true);
  run(cs[5],LevenbergMarquardt,"LM",false);
}
