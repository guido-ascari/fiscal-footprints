function x = reconstruct_ss_public_debt(x,p,rho)
% RECONSTRUCT_SS_PUBLIC_DEBT Debito verso il pubblico al primo ordine.
% Non cambia pi0 o la politica fiscale. Ricostruisce il debito compatibile
% con i surplus futuri e poi lascia al verificatore il controllo del debito
% EREDITATO. Se la valutazione fiscale e errata, il bilancio a data 0 fallisce.
%
% Ricorriamo all'indietro per evitare che errori di arrotondamento crescano
% come r^H (con H=800 una ricorsione in avanti perde molte cifre nei livelli).
% Il debito terminale non e posto a zero: e il VA dei surplus dopo H.
tail=ss_public_debt_tail(x,p,rho);
r=1/p.BETA; n=p.H+1;
b0=zeros(n,1); db=zeros(n,1);
b0(end)=tail.reference_debt; db(end)=tail.debt_deviation;
for i=n:-1:2
    b0(i-1)=(b0(i)+x.reference_surplus(i))/r;
    Rhat=x.nominal_rate_deviation(i-1)-x.inflation(i);
    db(i-1)=(db(i)+x.delta_surplus(i))/r-b0(i-1)*Rhat;
end
x.public_debt_reference=b0;
x.public_debt_deviation=db;
x.public_debt=b0+db;
qhat=p.SIGMA*(x.output(1)-x.output);
x.discounted_public_debt=p.BETA.^(0:p.H)'.*(b0+db+b0.*qhat);
end
