function fig = plot_ss_results(r)
% PLOT_SS_RESULTS Figura della notizia attuariale nei due regimi fiscali.
% Rosso = riserve ampie; blu = esaurimento previsto; grigio = senza notizia.
% I pannelli inferiori distinguono riserve effettive e proiezioni senza aiuti.

p=r.parameters;
idx=1:p.SHOW+1;                 % Anni 0,...,SHOW
t=r.time(idx);
tr=(-1:p.SHOW)';                % Includiamo lo stock ereditato all'anno -1
red=[186,65,59]/255;
blue=[33,107,145]/255;
gray=[152,162,179]/255;
floorcolor=[71,85,105]/255;
fig=figure('Color','w','Name','Fiscal footprints','Position',[80,80,1200,820]);
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,{'The Paradox of Solvency: Actuarial news and asymmetric fiscal backing'},'FontWeight', 'bold', 'FontSize', 16);
xlabel(layout,'','FontSize',10);
% xlabel(layout,sprintf(['Years after actuarial news. Responses relative to each regime''s own no-news path.\n' ...
%    'Dotted vertical line: end of actuarial horizon J = %d.'],p.J),'FontSize',10);

%% Pannello 1: la notizia cambia subito l'inflazione, prima dei flussi fiscali
ax=nexttile(layout);
plot(ax,t,100*r.ample.inflation(idx),'Color',red,'LineWidth',2.4); hold(ax,'on');
plot(ax,t,100*r.poor.inflation(idx),'--','Color',blue,'LineWidth',2.4);
title(ax,'Inflation response'); ylabel(ax,'Percentage points');
legend(ax,{'Ample reserves: bad actuarial news','Projected depletion: bad actuarial news'}, ...
    'Location','northeast','Box','off','FontSize',8);
decorate(ax,p,0);

%% Pannello 2: output associato al sentiero NK stabile
ax=nexttile(layout);
plot(ax,t,100*r.ample.output(idx),'Color',red,'LineWidth',2.4); hold(ax,'on');
plot(ax,t,100*r.poor.output(idx),'--','Color',blue,'LineWidth',2.4);
title(ax,'Output response'); ylabel(ax,'Percent from own no-news path');
decorate(ax,p,0);

%% Pannello 3: nel caso di riserve ampie confrontiamo con e senza notizia
ax=nexttile(layout);
plot(ax,tr,[p.INITIAL_RESERVES;r.ample_base.ref_reserves(idx)],'--', ...
    'Color',gray,'LineWidth',2); hold(ax,'on');
plot(ax,tr,[p.INITIAL_RESERVES;r.ample.reserves(idx)],'Color',red,'LineWidth',2.4);
yline(ax,p.LOWER,':','Color',floorcolor,'LineWidth',1.5);
title(ax,'Ample reserves: no correction'); ylabel(ax,'Reserves / reference GDP (%)');
legend(ax,{'No actuarial news','Bad actuarial news','Reserve threshold'}, ...
    'Location','northwest','Box','off','FontSize',8);
decorate(ax,p,-1);

%% Pannello 4: effetto della correzione nel caso di esaurimento previsto
% Le riserve effettive incorporano la correzione; quelle senza intervento
% illustrano il deficit di finanziamento. Non proseguiamo il grafico sotto zero.
ax=nexttile(layout);
plot(ax,tr,[p.INITIAL_RESERVES;r.poor_base.ref_reserves(idx)], ...
    'Color',gray,'LineWidth',2); hold(ax,'on');
plot(ax,tr,[p.INITIAL_RESERVES;r.poor.reserves(idx)],'Color',blue,'LineWidth',2.4);
[t0,b0]=truncate_at_zero(tr,[p.INITIAL_RESERVES;r.poor_base.no_adjustment(idx)]);
[t1,b1]=truncate_at_zero(tr,[p.INITIAL_RESERVES;r.poor.no_adjustment(idx)]);
plot(ax,t0,b0,'--','Color',gray,'LineWidth',2);
if strcmp(r.mode,'levels')
    plot(ax,t1,b1,'-.','Color',[180,83,9]/255,'LineWidth',2);
else
    plot(ax,t1,b1,'--','Color',blue,'LineWidth',2);
end
yline(ax,p.LOWER,':','Color',floorcolor,'LineWidth',1.5);
title(ax,'Projected depletion: correction at breach'); ylabel(ax,'Reserves / reference GDP (%)');
legend(ax,{'No actuarial news','Bad actuarial news', ...
    'No actuarial news: no adjustment (a_k=0)', ...
    'Bad actuarial news: no adjustment (a_k=0)','Reserve threshold'}, ...
    'Location','southwest','Box','off','FontSize',8);
decorate(ax,p,-1);
end

function decorate(ax,p,start_year)
% La linea a J e un riferimento temporale; non e una nuova sorpresa.
xline(ax,p.J,':','Color',[0.12, 0.12, 0.13],'LineWidth',1.5, 'HandleVisibility','off');
xlim(ax,[start_year,p.SHOW]);
set(ax,'Box','off','YGrid','on','XGrid','off','FontSize',10,'Layer','top');
end

function [tx,by] = truncate_at_zero(t,b)
% Trova la prima riserva non positiva e interpola l'istante del primo zero.
% Questa operazione modifica soltanto il disegno, non i risultati del modello.
i=find(b<=0,1,'first');
if isempty(i)
    tx=t; by=b;
elseif i==1
    tx=t(1); by=0;
elseif b(i)==0
    tx=t(1:i); by=b(1:i);
else
    tzero=t(i-1)+(t(i)-t(i-1))*(-b(i-1))/(b(i)-b(i-1));
    tx=[t(1:i-1);tzero]; by=[b(1:i-1);0];
end
end
