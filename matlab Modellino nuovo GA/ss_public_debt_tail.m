function tail = ss_public_debt_tail(x,p,rho)
% SS_PUBLIC_DEBT_TAIL Continuazione analitica dopo H, che deve essere >= J.
% Dopo J tau e il target sono costanti; pi e y continuano con la radice rho.
% Identifichiamo un ramo delle riserve che puo continuare per sempre e ne
% controlliamo condizioni SUFFICIENTI. Se non valgono, la verifica fallisce:
% non si certifica la trasversalita supponendo arbitrariamente costante a.
r=1/p.BETA; L=p.LOWER; b0=x.ref_reserves(end); b=x.reserves(end);
tau0=x.tau_base(end); tau=x.tau_report(end);
tol=1e-10; d=p.SIGMA*(rho-1)*x.output(end); % Rhat[H+1]
ref_floor=abs(b0-L)<=tol && (1-r)*L-tau0>=-tol;
if ref_floor
    a0=(1-r)*L-tau0; U=0; V=L;
    ref_ok=abs(x.ref_correction(end)-a0)<=tol;
else
    a0=0; U=b0+tau0/(r-1); V=-tau0/(r-1);
    ref_ok=abs(x.ref_correction(end))<=tol && b0>=L-tol && U>=-tol;
end
% Riserve di riferimento: b0[H+m-1]=U*r^(m-1)+V.
% I termini di rivalutazione sono quindi due progressioni geometriche.
at_floor=abs(b-L)<=tol && (1-r)*L-tau>=-tol;
if at_floor
    ainf=(1-r)*L-tau;
    % Limite superiore valido per OGNI m>=1 alla rivalutazione positiva.
    positive_U=max(r*d*U,0);
    if rho>p.BETA && positive_U>0, positive_U=Inf; end
    upper=positive_U+max(r*d*V,0);
    actual_ok=ainf>=upper-tol;
    D=(1-r)*L-tau0-a0;
    C1=-r*d*U; C2=-r*d*V;
else
    % Limite alla somma dei rendimenti, espressa in unita scontate a H.
    return_bound=abs(d)*(abs(U)/(1-rho)+abs(V)/(1-p.BETA*rho));
    actual_ok=abs(x.correction(end))<=tol && ...
        b-return_bound>=L-tol && b+tau/(r-1)-return_bound>=-tol;
    D=tau-tau0-a0; C1=0; C2=0;
end
% ds[H+m] = D + C1*(rho/beta)^(m-1) + C2*rho^(m-1).
% Le somme scontate convergono anche se rho/beta>1: beta*(rho/beta)=rho<1.
s0=x.son+tau0+a0;
tail.reference_debt=s0*p.BETA/(1-p.BETA);
tail.debt_deviation=D*p.BETA/(1-p.BETA) + ...
    C1*p.BETA/(1-rho)+C2*p.BETA/(1-p.BETA*rho) + ...
    p.SIGMA*x.output(end)*s0* ...
    (p.BETA/(1-p.BETA)-p.BETA*rho/(1-p.BETA*rho));
tail.reference_floor=ref_floor;
tail.actual_floor=at_floor;
tail.reference_supported=ref_ok;
tail.actual_supported=actual_ok;
tail.supported=ref_ok && actual_ok && p.H>=p.J && rho>0 && rho<1;
tail.surplus_reference=s0;
tail.surplus_delta_constant=D;
tail.surplus_delta_rhor=C1;
tail.surplus_delta_rho=C2;
end
