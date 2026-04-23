SET ThousandSep='.';
SET DecimalSep=',';
SET MoneyThousandSep='.';
SET MoneyDecimalSep=',';
SET MoneyFormat='R$ #.##0,00;-R$ #.##0,00';
SET TimeFormat='hh:mm:ss';
SET DateFormat='DD/MM/YYYY';
SET TimestampFormat='DD/MM/YYYY hh:mm:ss[.fff]';
SET FirstWeekDay=6;
SET BrokenWeeks=1;
SET ReferenceDay=0;
SET FirstMonthOfYear=1;
SET CollationLocale='pt-BR';
SET CreateSearchIndexOnReload=1;
SET MonthNames='jan.;fev.;mar.;abr.;mai.;jun.;jul.;ago.;set.;out.;nov.;dez.';
SET LongMonthNames='janeiro;fevereiro;março;abril;maio;junho;julho;agosto;setembro;outubro;novembro;dezembro';
SET DayNames='seg.;ter.;qua.;qui.;sex.;sáb.;dom.';
SET LongDayNames='segunda-feira;terça-feira;quarta-feira;quinta-feira;sexta-feira;sábado;domingo';
SET NumericalAbbreviation='3:k;6:M;9:G;12:T;15:P;18:E;21:Z;24:Y;-3:m;-6:μ;-9:n;-12:p;-15:f;-18:a;-21:z;-24:y';


SET bronze_layer = 'lib://Eldorado Data Folder - 3 Recursos Humanos - People Analytics/01. HR Medallion/01. Bronze/';
SET silver_layer = 'lib://Eldorado Data Folder - 3 Recursos Humanos - People Analytics/01. HR Medallion/02. Silver/';
SET gold_layer = 'lib://Eldorado Data Folder - 3 Recursos Humanos - People Analytics/01. HR Medallion/03. Gold/';


bz_projetos_pa_raw:
Load
*
FROM [$(bronze_layer)bz_projetos_pa_f.QVD] (qvd);
sv_projetos_pa_f:
LOAD
*,
// Separa Data e Hora de Criação
Date(created_date, 'DD/MM/YYYY') 															as data_criacao, 
Time(created_date) 																			as hora_criacao,
// Regra: se activated_date estiver nula ou vazia e closed_date estiver preenchida, atribuir created_date à activated_date, mantendo o formato de data e hora.
Date(
IF(
 IsNull(activated_date) and Not IsNull (closed_date),
 created_date,
 activated_date)) 																			as data_status_active,
Time(

IF(
 IsNull(activated_date) and Not IsNull (closed_date),
 created_date,
 activated_date))																			as hora_status_active, 

Date(closed_date)																			as data_status_closed,
Time(closed_date)																			as hora_status_closed;
// Load Precedente(carrega primeiro a tabela debaixo e depois a de cima)
Load
// Transformação de Dados
num(ID) 																					as id,
"Work Item Type" 																			as tipo,
Title 																						as titulo,
SubField("Assigned To", '<' ,1 ) 															as responsavel,
State 																						as status,
"Tags" 																						as tags,
// Limpa os campos que trazem '' e os transformam em NULL
IF(Len(Trim("Activated Date")) = 0, Null(), "Activated Date")								as activated_date,
IF(Len(Trim("Closed Date")) = 0, Null(), "Closed Date")										as closed_date,
IF(Len(Trim("Created Date")) = 0, Null(), "Created Date")									as created_date,
// Tranformação de Métricas
"Original Estimate"																			as horas_estimadas,
"Remaining Work" 																			as horas_restantes,
"Completed Work"																			as horas_concluidas,

// Traz 'Backlog' para os campos que forem PEOPLE ANALYTICS e traz apenas os números de PEOPLE ANALYTICS\Sprint...
if ("Iteration Path" = 'PEOPLE ANALYTICS', 'Backlog', 
Num(PurgeChar("Iteration Path", 'PEOPLE ANALYTICS\Sprint '))) 								as sprint,

// Transformação de Dados
Priority 																					as prioridade,
Parent 																						as parent
RESIDENT bz_projetos_pa_raw;


// Filtra por Task e faz a contagem das horas, agrupando-as ao seu parent(User Story ou Enhancement)
total_horas_us:
LEFT JOIN (sv_projetos_pa_f)
Load
 parent 																					as id,
 Sum( Num#(horas_estimadas, '#.##0,00', '.', ',') )											as total_horas_estimadas,
 Sum( Num#(horas_concluidas, '#.##0,00', '.', ',') )										as total_horas_concluidas,
 Sum(Num#(horas_restantes, '#.##0,00', '.', ',') )											as total_horas_restantes
RESIDENT sv_projetos_pa_f
WHERE tipo = 'Task'
GROUP BY parent
;


titulo_projeto: 
left join(sv_projetos_pa_f)
load Distinct
 id 																						as parent,
 titulo 																					as tituloProjeto
RESIDENT sv_projetos_pa_f
WHERE tipo = 'User Story' or tipo = 'Enhancement';


Positions_Monthly:
LOAD
*,
// Define status por mês com base nas datas 
IF(
 NOT IsNull(data_status_closed) 
 AND MonthStart(referencedate) = MonthStart(data_status_closed),
 'Concluído',
 IF(
 NOT IsNull(data_status_active)
 AND MonthStart(referencedate) >= MonthStart(data_status_active)
 AND (
 IsNull(data_status_closed) 
 OR MonthStart(referencedate) < MonthStart(data_status_closed)
 ),
 'Em Progresso',
 'Não Iniciado'
 )
) 																							as status_mensal,

IF((tipo = 'Enhancement' or tipo = 'User Story') and 
total_horas_estimadas >= 40, 'Sim', 'Não')													as flag_projeto
;

LOAD
 *,
 // cálculo quantidade de meses entre data criação e data fechamento (ou hoje)
 (
 Year(Alt(data_status_closed, Today())) * 12 + 
Month(Alt(data_status_closed, Today()))
 ) -
 (
 Year(data_criacao) * 12 + Month(data_criacao)
 ) 																							as monthcount,
 
 // gera cada mês do intervalo
 Date(MonthEnd(AddMonths(data_criacao, IterNo()-1)) )										as referencedate
RESIDENT sv_projetos_pa_f

// Controla quantas linhas serão geradas
WHILE 
 IterNo()-1 <= 
 (
 (Year(Alt(data_status_closed, Today())) * 12 + 
Month(Alt(data_status_closed, Today()))) -
 (Year(data_criacao) * 12 + Month(data_criacao))
 )
 AND IterNo() <= 150;
store Positions_Monthly into [$(silver_layer) sv_projetos_pa_f.qvd] 
(qvd);

// Limpeza de Tabelas
DROP TABLE Positions_Monthly;
DROP TABLE sv_projetos_pa_f;
DROP TABLE bz_projetos_pa_raw;