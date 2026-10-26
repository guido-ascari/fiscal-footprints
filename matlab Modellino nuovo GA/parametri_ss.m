function p = parametri_ss()
% PARAMETRI_SS Parametri comuni alle due versioni MATLAB.
% Modificare qui i valori, salvare e premere Run in simulate_ss.m.
% Periodo = un anno. PIL di riferimento = 100 (denominatore fisso).

p.BETA = 0.96;                 % Fattore di sconto
p.SIGMA = 1;                   % Curvatura dell'utilita del consumo
p.NU = 1;                      % Curvatura della disutilita del lavoro
p.THETA = 0.6;                 % Probabilita Calvo di NON cambiare prezzo
p.PHI = 0.8;                   % Risposta monetaria: 0 <= PHI < 1

p.LOWER = 8;                   % Soglia delle riserve, % PIL di riferimento
p.INITIAL_RESERVES = 10.6;      % Riserve alla fine dell'anno -1
p.INITIAL_PUBLIC_DEBT = 60;     % Debito detenuto dal pubblico, anno -1
p.AMPLE_TAU = 0.6;             % Saldo previdenziale: riserve ampie
p.DEPLETION_TAU = -0.7;         % Saldo previdenziale: esaurimento previsto

p.J = 10;                      % Orizzonte della proiezione attuariale
p.REVISION_PER_YEAR = 0.015;    % Peggioramento aggiuntivo del saldo ogni anno
% La revisione e -REVISION_PER_YEAR*k fino a J; poi resta a -REVISION_PER_YEAR*J.
p.H = 800;                     % Orizzonte numerico per i valori attuali
p.SHOW = 25;                   % Ultimo anno mostrato nei grafici
p.P_Y = 12;                    % Contributo per giovane (conversione demografica)
p.V_O = 24;                    % Beneficio per anziano (conversione demografica)
% P_Y e V_O non cambiano tau: i saldi sono impostati direttamente sopra.
end
