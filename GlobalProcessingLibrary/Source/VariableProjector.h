#ifndef _VARIABLEPROJECTOR_H
#define _VARIABLEPROJECTOR_H

#include "AbstractFitter.h"
//#include "VariableProjection.h"


class VariableProjector : public AbstractFitter
{

public:
   VariableProjector(FitModel* model, int smax, int l, int nl, int nmax, int ndim, int p, double *t, int variable_phi, int n_thread, int* terminate);
   ~VariableProjector();

   int FitFcn(int nl, double *alf, int itmax, int* niter, int* ierr, double* c2);

   int GetFit(int irf_idx, double* alf, double* lin_params, float* adjust, double* fit);

private:

   void Cleanup();

   int varproj(int nsls1, int nls, const double *alf, double *rnorm, double *fjrow, int iflag);   
   void jacb_row(int s, int nls, double *kap, double* r__, int d_idx, double* res, double* derv);
   
   void transform_ab(const double *alf, int irf_idx, int& isel, int thread, int firstca, int firstcb, double* a, double* b, double *u);


   void get_linear_params(int idx, double* a, double* u, double* x = 0);
   int bacsub(int idx, double* a, double* x);

   double d_sign(double *a, double *b);

   double *work; 
   // Buffers used by levmar algorithm
   double *fjac;
   double *diag;
   double *qtf;
   double *wa1, *wa2, *wa3, *wa4;
   int    *ipvt;

   friend int VariableProjectorCallback(void *p, int m, int n, const double *x, double *fnorm, double *fjrow, int iflag);
};


#endif