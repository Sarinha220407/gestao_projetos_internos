bz_projetos_pa_raw:
Load
*
FROM [$(bronze_layer)bz_projetos_pa_f.QVD] (qvd);


sv_projetos_pa:

LOAD
*,

// Separa Data e Hora de Criação
Date(created_date) 																									as data_criacao,  
Time(created_date) 																									as hora_criacao,

// Regra: se activated_date estiver nula ou vazia e closed_date estiver preenchida, atribuir created_date à activated_date, mantendo o formato de data e hora.
Date(
	IF(
    	IsNull(activated_date) and Not IsNull (closed_date),
        created_date,
        activated_date))																								as data_status_active,

Time(
	IF(
    	IsNull(activated_date) and Not IsNull (closed_date),
        created_date,
        activated_date))																								as hora_status_active, 
        
Date(closed_date)																										as data_status_closed,
Time(closed_date)																										as hora_status_closed;


// Load Precedente(carrega primeiro a tabela debaixo e depois a de cima)
Load

// Transformação de Dados
num(ID) 																												as id,
"Work Item Type" 																										as tipo,
Title 																													as titulo,
SubField("Assigned To", '<' ,1 ) 																						as responsavel,
State 																													as status,
"Tags" 																													as tags,

// Limpa os campos que trazem '' e os transformam em NULL
IF(Len(Trim("Activated Date")) = 0, Null(), "Activated Date")															as activated_date,
IF(Len(Trim("Closed Date")) = 0, Null(), "Closed Date")																	as closed_date,
IF(Len(Trim("Created Date")) = 0, Null(), "Created Date")																as created_date,

// Tranformação de Métricas
num("Original Estimate") 																								as horas_estimadas,
num("Remaining Work") 																									as horas_restantes,
num("Completed Work") 																									as horas_concluidas,

// Traz 'Backlog' para os campos que forem PEOPLE ANALYTICS e traz apenas os números de PEOPLE ANALYTICS\Sprint...
if ("Iteration Path" = 'PEOPLE ANALYTICS', 'Backlog', Num(PurgeChar("Iteration Path", 'PEOPLE ANALYTICS\Sprint '))) 	as sprint,

// Transformação de Dados
Priority 																												as prioridade,
Parent 																													as parent

RESIDENT bz_projetos_pa_raw;
Store sv_projetos_pa into [$(silver_layer) sv_projetos_pa.QVD] (qvd);



//Criação de Calendário
Let vDataInicio = '2003-01-01';
Let vDataFim = Date(MakeDate(Year(Today())+1, 12, 31), 'YYYY-MM-DD');
sv_calendario_d:
Load
Date(TempDate, 'DD.MM.YYYY') 																							as date_key,
Date(Floor(MonthEnd(TempDate)), 'DD.MM.YYYY') 																			as load_month,
Date(Floor(MonthEnd(TempDate)), 'MM/YYYY')																				as ano_mes_numero,
If(Date#(Date(Floor(MonthEnd(TempDate)), 'MM/YYYY'),'MM/YYYY') <= MonthStart(Today()),
Date(Floor(MonthEnd(TempDate)), 'MM/YYYY')) 																			as ano_mes_numero_reduzido,
Year(TempDate) 																											as ano,
Num(Month(TempDate)) 																									as mes_numero,
Month(TempDate) 																										as mes_nome,
Day(TempDate) 																											as dia,
'Sem ' & Ceil(Day(TempDate)/7) 																							as semana_mes,
Week(TempDate) 																											as semana_ano,
Num(Weekday(TempDate)) 																									as dia_semana_numero,
Date(TempDate, 'WWW') 																									as dia_semana_nome,
Month(TempDate) & ' - ' & Year(TempDate)																				as ano_mes, //Date(MonthStart(TempDate), 'YYYY-MM')
If(MonthStart(TempDate) = MonthStart(Today()), 'Sim', 'Não') 															as mes_atual,
If(YearStart(TempDate) = YearStart(Today()), 'Sim', 'Não') 																as ano_atual,
Date(TempDate, 'YYYY-Q') 																								as ano_trimestre,
Dual('Sem ' & Week(TempDate) & ' ' & Year(TempDate), WeekStart(TempDate)) 												as ano_semana,
If(TempDate <= Today(), 'Historico', 'Futuro') 																			as periodo_status,
If(TempDate = Today(), 'Sim', 'Não') 																					as hoje,
If(TempDate = Today() - 1, 'Sim', 'Não') 																				as ontem,
If(TempDate = Today() + 1, 'Sim', 'Não') 																				as amanha,
If(WeekDay(TempDate) >= 6, 'Sim', 'Não') 																				as final_semana,
NetworkDays(TempDate, TempDate) 																						as dia_util,
Ceil(Month(TempDate)/3) 																								as trimestre_fiscal,
Ceil(Month(TempDate)/6) 																								as semestre,
'S' & Ceil(Month(TempDate)/6) & ' - ' & Year(TempDate) 																	as ano_semestre;

Load
    TempDate
Where
    TempDate >= Date('$(vDataInicio)') and TempDate <= Date('$(vDataFim)');

Load
    MakeDate(2003,1,1) + IterNo() - 1 																					as TempDate
AutoGenerate 1
While IterNo() <= (Date('$(vDataFim)') - Date('$(vDataInicio)') + 1);


// Filtra por Task e faz a contagem das horas, agrupando-as ao seu parent(User Story ou Enhancement)
total_horas_us:
LEFT JOIN (sv_projetos_pa)
Load
    parent 																												as id,
    Sum(horas_estimadas) 																								as total_horas_estimadas,
    Sum(horas_concluidas)  																								as total_horas_concluidas,
    Sum(horas_restantes)																								as total_horas_restantes
RESIDENT sv_projetos_pa
WHERE tipo = 'Task'
GROUP BY parent
;

Positions_Monthly:
LOAD
*,
// Define status por mês com base nas datas 
IF(
    NOT IsNull(data_status_closed) 
    AND MonthStart(ReferenceDate) = MonthStart(data_status_closed),
    'Concluído',
    IF(
        NOT IsNull(data_status_active)
        AND MonthStart(ReferenceDate) >= MonthStart(data_status_active)
        AND (
            IsNull(data_status_closed) 
            OR MonthStart(ReferenceDate) < MonthStart(data_status_closed)
        ),
        'Em Progresso',
        'Não Iniciado'
    )
) 																														as status_mensal
;
LOAD
    *,
    // cálculo quantidade de meses entre data criação e data fechamento (ou hoje)
    (
        Year(Alt(data_status_closed, Today())) * 12 + Month(Alt(data_status_closed, Today()))
    ) -
    (
        Year(data_criacao) * 12 + Month(data_criacao)
    ) 																													as monthcount,
    
    // gera cada mês do intervalo
    MonthEnd(AddMonths(data_criacao, IterNo()-1)) 																		as ReferenceDate
RESIDENT sv_projetos_pa

// Controla quantas linhas serão geradas
WHILE 
    IterNo()-1 <= 
    (
        (Year(Alt(data_status_closed, Today())) * 12 + Month(Alt(data_status_closed, Today()))) -
        (Year(data_criacao) * 12 + Month(data_criacao))
    )
    AND IterNo() <= 150;
 
flag_projeto:
Load
	*,
    
    // Considera como projetos só as User Story e Enhancement com mais de 40 horas estimadas
    IF((tipo = 'Enhancement' or tipo = 'User Story') and total_horas_estimadas >= 40, 'Sim', 'Não')						as flag_projeto
    RESIDENT Positions_Monthly;
 


// Limpeza de Tabelas
DROP TABLE flag_projeto;
DROP TABLE sv_projetos_pa;
DROP TABLE bz_projetos_pa_raw;
DROP TABLE Positions_Monthly;
DROP TABLE sv_calendario_d;