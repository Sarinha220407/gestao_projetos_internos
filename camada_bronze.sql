bz_projetos_pa_f:
LOAD
    ID,
    "Work Item Type",
    Title,
    "Assigned To",
    State,
    "Tags",
    "Created Date",
    "Activated Date",
    "Closed Date",
    "Original Estimate",
    "Remaining Work",
    "Completed Work",
    "Iteration Path",
    Priority,
    Parent
FROM [lib://Eldorado Data Folder - 3 Recursos Humanos - People Analytics/02. Manual Source/projetos_historico.csv]
(txt, utf8, embedded labels, delimiter is ',', msq);

Store bz_projetos_pa_f into [$(bronze_layer)bz_projetos_pa_f.QVD]

(qvd);

Drop table bz_projetos_pa_f;


