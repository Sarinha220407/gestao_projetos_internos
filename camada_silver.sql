bz_projetos_pa_f:
Load
*
FROM [$(bronze_layer)bz_projetos_pa_f.QVD] (qvd);
sv_projetos_pa:
LOAD
num(ID) 																												as id,
"Work Item Type" 																										as tipo,
Title 																													as titulo,
SubField("Assigned To", '<' ,1 ) 																						as responsavel,
State 																													as status,
"Tags" 																													as tags,
Date("Created Date") 																									as data_criacao, // nao ha necessidade da formatacao 'DD/MM/YYYY' e 'hh:mm' pois o dado ja vem formatado 
Time("Created Date") 																									as hora_criacao,
Date(if(isnull("Activated Date"), "Created Date", "Activated Date" ))				 									as data_status_active,
Time("Activated Date")												 													as hora_status_active, 
Date("Closed Date")																										as data_status_closed,
Time("Closed Date")																										as hora_status_closed,
num("Original Estimate") 																								as horas_estimadas,
num("Remaining Work") 																									as horas_restantes,
num("Completed Work") 																									as horas_concluidas,
if ("Iteration Path" = 'PEOPLE ANALYTICS', 'Backlog', Num(PurgeChar("Iteration Path", 'PEOPLE ANALYTICS\Sprint '))) 	as sprint,
//SubField("Iteration Path" , '\' ,2 )
Priority 																												as prioridade,
Parent 																													as parent
RESIDENT bz_projetos_pa_f;

Store sv_projetos_pa into [$(silver_layer) sv_projetos_pa.QVD] (qvd);
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

Positions_Monthly:
LOAD
*,
// STATUS baseado em intervalo real de datas
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
    // cálculo correto de meses (multi-ano)
    (
        Year(Alt(data_status_closed, Today())) * 12 + Month(Alt(data_status_closed, Today()))
    ) -
    (
        Year(data_criacao) * 12 + Month(data_criacao)
    ) 																													as monthcount,
    MonthEnd(AddMonths(data_criacao, IterNo()-1)) 																		as ReferenceDate
RESIDENT sv_projetos_pa
WHILE 
    IterNo()-1 <= 
    (
        (Year(Alt(data_status_closed, Today())) * 12 + Month(Alt(data_status_closed, Today()))) -
        (Year(data_criacao) * 12 + Month(data_criacao))
    )
    AND IterNo() <= 150;

// agrupa e faz a conta apenas do que sao tasks e retorna o total de horas associando o parent ao id
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
// faz a flag projeto, retorna apenas as User Storty e Enhancement com mais de 40 horas - FUNCIONANDO
flag_projeto:
Load
	*,
    IF((tipo = 'Enhancement' or tipo = 'User Story') and total_horas_estimadas >= 40, 'Sim', 'Não')						as flag_projeto
    RESIDENT sv_projetos_pa;



// DROP TABLE total_horas_us
DROP TABLE sv_projetos_pa;
DROP TABLE bz_projetos_pa_f;
DROP TABLE Positions_Monthly;
DROP TABLE sv_calendario_d;