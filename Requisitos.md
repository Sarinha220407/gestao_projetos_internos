# **Requisitos Gestão de Projetos Internos**

*	Parâmetro de data;
*	Serão considerados projetos os itens de trabalho que tiverem mais de 40 horas;
*	Associar as tasks às suas devidas user stories;
*	Considerar o backlog corretamente;
*	Considerar as datas entre a data de criação até a data de fechamento como “Em progresso” e, se possível, criar uma condição que traga o histórico dos status; 
*	Ao selecionar a data, o que vai aparecer? Os projetos que foram abertos naquele mês, os que estão em progresso, ou os que foram fechados; (Irá aparecer todos aqueles que foram criados e que estão em andamento no mês selecionado)
*	Definir uma regra para projetos que tem data de criação e data de fechamento, porém não tem data de ativação. (identificar se o activated date é nulo e se closed date não é nulo, se as afirmativas anteriores forem verdadeiras, duplicar a data de criação para a activated date)


# **RASCUNHO TELAS:**

* Total de projetos (Count({<flag_projeto = {‘Sim’>} id) )
* Status de todos os projetos;
* Tipo dos projetos;
* Quantidade de projetos por pessoa;
* Tabela com quantidade, título e status (tabela rosa);
* Cronograma (grafico de gantt).