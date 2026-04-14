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


gd_projetos_pa_f:
Load
*,
Date#(Date(referencedate)) as ReferenceDate
From [$(gold_layer)gd_projetos_pa_f.QVD] (qvd);




gd_calendario_d:
LOAD
*,
   Date#(Date(load_month, 'DD/MM/YYYY'))     as ReferenceDate,
   Date#(Date(ano_mes_numero_reduzido, 'DD/MM/YYYY'))
FROM [lib://Eldorado Data Folder - 3 Recursos Humanos - People Analytics/01. HR Medallion/03. Gold/gd_calendario_d.QVD]
(qvd);