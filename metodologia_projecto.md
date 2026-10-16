# Metodologia — "Do Barril ao Banco Central: Choques do Brent na Economia Angolana"

*Documento de trabalho, actualizado ao longo do projecto. Serve de base para o resumo executivo final.*

**Dashboard:** [Power BI](https://app.powerbi.com/view?r=eyJrIjoiMmQzZmQ5OWItNWIxOC00N2Y2LThmZGYtZjUzYTQ3NjZiNWM0IiwidCI6IjgyNWI5NmI2LTdhMDAtNDI4Ny05ZmRhLWQ4MWM4ZTJkZmNhYiJ9) · **Repositório:** [GitHub](https://github.com/julianasac/do-barril-ao-banco-central)

## 1. Objectivo e Perguntas de Negócio

Projecto de portfólio com **dados reais**, sucessor do projecto fictício de logística petrolífera. Analisa a relação entre o preço do petróleo Brent e a economia angolana (câmbio, reservas, política monetária), 2014-2025.

**Perguntas de negócio:**
1. Existe correlação entre o preço do Brent e a taxa de câmbio Kwanza/USD? Com que desfasamento temporal?
2. As reservas internacionais (ou a cobertura de importações) seguem o preço do petróleo de perto, ou o BNA consegue amortecer quedas de preço por algum tempo?
3. As decisões de taxa de juro do BNA reagem mais à inflação doméstica ou aos choques no preço do petróleo?

## 2. Fontes de Dados

| Série | Fonte | Frequência | Período | Notas |
|---|---|---|---|---|
| Preço do Brent | EIA (API oficial, series RBRTE) | Mensal | 2014-2025 | Sem falhas |
| Câmbio Kwanza/USD | BNA (Excel diário, agregado à média mensal) | Diário→Mensal | 2014-2025 | Sem falhas |
| Inflação (IPC, var. homóloga) | INE Angola | Mensal | Índice desde Dez/2014; homóloga só a partir de Dez/2015 | Ver secção 3 |
| Reservas Internacionais | BNA (milhões USD) + FMI via FRED (`AGOBRASSMIMH`, reservas líquidas em meses de importações de bens e serviços) | Mensal / Anual | BNA: Dez/2021-2025. FRED: 2014-2020 (anual, repetido nos 12 meses) | Fonte mista — ver secção 3 |
| Taxa de juro directora BNA | Decisões do CPM (tabela compilada manualmente, 30 registos, incluindo reuniões sem alteração) | Eventos (degraus), "esticada" para mensal (último valor em vigor em cada mês) | 2014-2025 | Todas as linhas confirmadas nos comunicados do CPM; ver secção 10 |

## 3. Decisões Metodológicas e Limitações Assumidas

- **Reservas Internacionais é uma fonte mista**: BNA (valor absoluto, milhões USD) para 2021-2025; FMI via FRED (reservas líquidas em meses de importações — métrica e definição diferentes das do BNA; não comparável em unidades) para 2014-2020. Há ainda um hiato de Jan-Nov/2021, sem dados em nenhuma das duas fontes (a série do BNA só começa em Dez/2021). Documentado como limitação, não erro.
- **Inflação**: usa-se a variação homóloga (não mensal nem acumulada) do IPC **nacional** do INE (não o índice provincial de Luanda, frequentemente citado em notícias — os dois divergem ligeiramente, o que é esperado).
- **Câmbio**: agregado de diário para mensal por **média do mês** (não último dia útil), para consistência com as restantes séries mensais.
- **Taxa de juro**: compilada de comunicados/notícias e depois confirmada com dados oficiais directos do BNA quando o portal voltou a funcionar. Corrigido um erro de datação (9,25% em Jan/2014, um corte para 8,75% algures antes de Jul/2014, sem data exacta encontrada nas fontes).

## 4. Problemas Técnicos Encontrados e Resolvidos

- **Tradução automática do browser** corrompeu um JSON copiado da API da EIA (chaves e valores traduzidos/misturados PT-EN) — resolvido desligando a tradução automática.
- **Datas ambíguas dia/mês** (formato DD/MM sem indicação clara) — resolvido forçando sempre localidade explícita no Power Query em vez de deixar detecção automática.
- **Separador decimal**: várias fontes exigiram atenção ao ponto (EUA/API) vs. vírgula (PT-PT) — resolvido com "Alterar Tipo Usando Localidade" no Power Query, e com `REPLACE(coluna, ',', '.')` no SQL.
- **"Cabeçalhos Promovidos" acidental** no Power Query causou perda de uma linha (Brent Dez/2025) — identificado e removido do passo da consulta.
- **BULK INSERT do SQL Server falhava silenciosamente (0 linhas, sem erro)** apesar de múltiplas tentativas de ROWTERMINATOR — causa raiz: permissões da pasta Downloads do utilizador, inacessível ao serviço do SQL Server. Resolvido movendo o ficheiro para `C:\SQLImport` e, por fim, usando o Assistente de Importação e Exportação de Dados do SSMS em vez de BULK INSERT.
- **Portais públicos do BNA (reservas internacionais) devolviam "0 registos"** de forma persistente — resolvido mais tarde quando o portal voltou a funcionar; entretanto usada fonte alternativa (FRED) para os anos não cobertos.

## 5. Nota Metodológica — Como se mediu a relação

- **Variações, não níveis.** A correlação de Pearson foi calculada em SQL Server (sem função `CORR()` nativa) sobre **variações mensais** (percentuais para Brent, câmbio e reservas; em pontos percentuais para a taxa de juro e a inflação). Em nível, séries com tendência partilhada dão correlações enganadoras: o Brent e o câmbio têm correlação de 0,16 no mesmo mês na amostra toda e de 0,02 em 2018–2025, o que mostra que o resultado depende do período e não de uma relação estável.
- **Desfasamento k** = correlação entre a variação do Brent no mês *t−k* e a variação da variável de resposta no mês *t*. (A primeira versão desta análise tinha o sentido invertido; foi corrigida em 15 Out 2026 e está registada na secção 10.)
- **Limiares** de significância a 5%, bilateral, calculados para o N de cada correlação (n ≈ 130: 0,17; n entre 42 e 48: 0,28–0,30). Não há ajuste para testes múltiplos.

## 6. Resultado — Pergunta 1 (Brent × Câmbio)

Correlação das variações mensais, com o regime atribuído pelo mês do câmbio (Administrada: até Dez/2017; Banda: Jan/2018–Out/2019; Livre: desde Nov/2019).

| Grupo | N | Desfasamentos 0 / 3 / 6 / 9 / 12 meses | Limiar (5%) |
|---|---|---|---|
| Amostra completa | 131–143 | −0,130 / −0,010 / −0,141 / −0,067 / −0,026 | ≈ 0,17 |
| Administrada (2014–17) | 35–47 | −0,192 / −0,089 / −0,296 / −0,110 / −0,248 | 0,29–0,33 |
| Banda (2018–19) | 22 | −0,005 / 0,183 / 0,273 / 0,110 / 0,049 | ≈ 0,42 |
| Livre (2019–25) | 74 | −0,138 / −0,025 / −0,195 / −0,091 / −0,004 | ≈ 0,23 |

**Resultado:** nenhuma correlação é estatisticamente significativa. A mais próxima do limiar é −0,296 (regime administrado, 6 meses; limiar ≈ 0,31). O sinal é quase sempre negativo (Brent a subir, dólar a descer), coerente com a teoria, mas fraco.

**Contexto verificado:** até 9 de Janeiro de 2018 a taxa era fixada directamente pelo BNA, indexada ao dólar (fixa em 166 Kz/USD desde o 1.º trimestre de 2016); a partir daí passou a flutuar dentro de uma banda, com leilões de divisas, e foi liberalizada em Outubro de 2019 (fontes: Jornal Económico, 3 Jan 2018; Ver Angola, Jan 2019 e Nov 2019).

**Hipótese do regime cambial.** Se o regime administrado escondesse uma relação, o período livre devia mostrá-la, e mostra correlações do mesmo nível da amostra completa (−0,14 e −0,20), por isso a hipótese não é apoiada **para o período livre**. Para o período administrado, o teste tem pouco poder: o câmbio oficial esteve quase constante em 2016–2017 (166 Kz/USD desde o 1.º trimestre de 2016), pelo que, dos 47 meses do regime, cerca de 24 têm variação quase nula, e a taxa oficial não é o canal por onde o choque se manifestava (o ajuste fez-se depois, por degraus, e o mercado paralelo, que não está nos dados, é onde a pressão se via).

**Ao nível anual há coincidências** que a análise mensal não capta: em 2014–2016 (Brent a cair, reservas a cair, câmbio a degraus) e em 2021–2022 (Brent a subir e kwanza a apreciar-se, como mostra a página 2 do dashboard e como o BNA reportou: apreciação de 18,24% em 2021). Com 11 pontos anuais, é uma observação, não um teste.

**Verificações de robustez** (desfasamento 0, Brent × câmbio): sem Abril e Maio de 2020 (meses em que as variações do Brent, de cerca de ±40%, dominam a dispersão) a correlação é −0,097 (N = 141); por postos (Spearman) é −0,109 (N = 143); na amostra completa é −0,130 (N = 143). Os limiares a 5% são ≈ 0,165, por isso nenhuma é significativa, e o resultado não depende dos outliers. A correlação por postos usa `RANK`, que trata os empates de forma aproximada (há muitos meses de câmbio parado em 2016–2017).

## 7. Resultado — Pergunta 2 (Brent × Reservas Internacionais)

**Parte A (2014–2020, FMI via FRED, anual, reservas líquidas em meses de importações):** só 7 pontos anuais, por isso a leitura é visual. Em 2015, com o Brent a cair de ~99 para ~52 USD, a série subiu de 8,77 para 11,42 meses. É um rácio, e o movimento é coerente com a queda das importações calculada abaixo.

**Reservas totais em USD, 2014–2020 (FMI, International Financial Statistics, via Banco Mundial: *Total reserves, includes gold, current US$*; anual):**

| Ano | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 |
|---|---|---|---|---|---|---|---|
| Reservas totais (mil milhões USD) | 27,03 | 23,79 | 23,67 | 17,46 | 15,41 | 16,33 | 13,78 |
| Meses de importações (mesma fonte) | 5,15 | 6,48 | 9,08 | 5,82 | 5,41 | 6,43 | 8,03 |

Entre 2014 e 2020 as reservas totais caíram 49%. Em 2015 caíram 12% (23,79 ÷ 27,03) enquanto o indicador em meses de importações subiu 26% (6,48 ÷ 5,15). Como meses = reservas ÷ (importações ÷ 12), isto implica que as importações caíram cerca de 30% (0,88 ÷ 1,26 = 0,70). Esta passagem é aritmética, dentro da série do FMI, e não foi confirmada com dados directos de importações. O BNA reportava reservas de 31,2 mil milhões USD no início de 2014 (Ver Angola, Jun 2018). As definições do FMI (total, incluindo ouro) e do BNA (reservas internacionais) diferem: para 2021 o FMI dá 14,5 e o BNA 15,5 mil milhões USD, e para 2025 o FMI dá 13,5 (fim de ano) contra 15,4 do BNA, por isso as séries não se juntam. Na série do FMI, os valores de 2021 a 2025 são 14,47 · 13,65 · 13,94 · 14,24 · 13,54 mil milhões USD (variação de −6%), e na do BNA −0,5% entre Dez/2021 e Dez/2025: níveis diferentes por definição, e em ambas as séries a variação é pequena.

**Parte B (Dez/2021–2025, BNA, milhões USD, mensal):** correlação das variações mensais.

| Desfasamento | Correlação | N | Limiar (5%) |
|---|---|---|---|
| 0 meses | −0,113 | 48 | 0,28 |
| 3 meses | 0,125 | 45 | 0,29 |
| 6 meses | 0,170 | 42 | 0,30 |

**Resultado:** nenhuma é significativa, e o sinal muda entre desfasamentos, o que é típico de ruído. Desde Dezembro de 2021, as reservas do BNA estiveram estáveis (15.508 M USD em Dez/2021 e 15.434 em Dez/2025, −0,5%), enquanto o Brent caiu e oscilou. Esta estabilidade só vale para 2021–2025: no choque de 2014–2016, as reservas caíram. Verificação cruzada: a FocusEconomics indica 15,5 mil milhões USD em 2021 e 15,9 em 2025.

## 8. Resultado — Pergunta 3 (Taxa de Juro × Inflação e Brent)

Correlação das variações mensais (pontos percentuais para a taxa e a inflação; percentagem para o Brent), na janela Jan/2016–Dez/2025, com a taxa de Novembro de 2025 já corrigida (18,5%). Limiar a 5% para n = 120: ≈ 0,18.

| Variável explicativa | Desfasamento | N | Correlação | Significativa? |
|---|---|---|---|---|
| Inflação | 0 meses | 120 | 0,237 | Sim |
| Inflação | 3 meses | 117 | 0,126 | Não |
| Brent | 0 meses | 120 | 0,093 | Não |
| Brent | 3 meses | 120 | −0,033 | Não |

**Resultado:** a taxa directora acompanha a inflação do mesmo mês (r = 0,237, o que explica cerca de 6% da variação mensal da taxa) e não acompanha o Brent. A associação com a inflação é fraca, e a taxa só muda por degraus (poucas decisões em 12 anos), pelo que as observações não são independentes e o resultado é uma indicação, não uma prova.

**Leitura descritiva (não depende da correlação):** a taxa directora ficou abaixo da inflação homóloga em 100 dos 121 meses com inflação disponível (21 meses com a taxa igual ou superior); a taxa de juro real foi, por isso, negativa na maior parte do período, com o ponto mais baixo em 2016 (−25,1 pp). Nos dois episódios de subida forte da inflação (2015–16 e 2023–24) a taxa subiu, mas sempre muito menos do que a inflação.

## 9. Síntese

Nos dados mensais não aparece uma relação linear directa entre o Brent e o câmbio nem entre o Brent e as reservas, e a taxa de juro acompanha a inflação do mesmo mês (de forma fraca) e não o Brent. Ao nível anual, o choque de 2014–2016 é seguido de uma queda de 49% das reservas até 2020 e de ajustamentos cambiais por degraus, e em 2021–2022 o kwanza apreciou-se com o Brent a subir. A leitura que os dados suportam é a de uma transmissão diferida e mediada pelo regime cambial e pelas reservas, e não contínua e mensal. É uma leitura, não uma prova: os dados não separam o efeito do preço do de outros factores, e a produção caiu de cerca de 1,7–1,8 para cerca de 1,1 milhões de barris/dia entre 2015 e 2021, pelo que usar só o Brent omite o efeito do volume.

## 10. Registo de correcções

| Data | Correcção | Estado |
|---|---|---|
| 15 Out 2026 | Desfasamentos das Perguntas 1 e 2 estavam calculados no sentido inverso (câmbio/reservas de meses antes). Recalculados | Feito |
| 15 Out 2026 | Retirado o valor "0,54 com 12 meses" (comparação de níveis), que vinha do mesmo cálculo | Feito |
| 15 Out 2026 | Fórmula `Meses_Taxa_Acima` contava os meses sem inflação (44 em vez de 21) | Feito |
| 15 Out 2026 | Série FRED AGOBRASSMIMH descrita como "cobertura de importações"; é "reservas líquidas em meses de importações" (FMI, Regional Economic Outlook) | Feito (documento e página 3 do dashboard) |
| 15 Out 2026 | Rótulo "Fixa (2014–17)" do regime passa a "Administrada (2014–17)" | Feito |
| 15 Out 2026 | Taxa de juro de Novembro/2025: 18,5% (corte na reunião de 18 Nov), e não 19,0% | Feito (base corrigida; Out 19,00, Nov 18,50, Dez 18,50) |
| 15 Out 2026 | Pergunta 3: desfasamento de 3 meses da inflação com N errado (0,118 com N = 120 passou a 0,126 com N = 117) | Feito |
| 15 Out 2026 | Linhas de 2018–2023 da tabela de taxas (dez-18, jan-19, nov-19, jul-21, set-22, jan-23) confirmadas nos comunicados do CPM | Feito (confirmado em 15 Out 2026) |
| 15 Out 2026 | Script SQL consolidado (`analise_economia_angola.sql`) corrido de ponta a ponta; valores de controlo confirmados (121 meses com inflação, 100 com taxa abaixo, 21 com taxa igual ou acima, mínimo −25,12 pp) | Feito |
| 15 Out 2026 | Título do projecto: "Da Refinaria…" passa a "Do Barril ao Banco Central" (o projecto trata do preço do crude, não da refinação) | Feito nos documentos; pendente no repositório, no título da página 1 do dashboard e no link |
| 15 Out 2026 | Reservas apresentadas como "estáveis" sem o contexto de 2014–2020 (reservas totais −49% entre 2014 e 2020). Corrigido no README, resumo executivo e secção 7 | Feito nos documentos; pendente no dashboard (substituir o gráfico da cobertura pelo das reservas totais em USD) |
| 15 Out 2026 | Frase "isto afasta a hipótese do regime cambial" era demasiado forte: o teste só vale para o período livre | Feito |
| 15 Out 2026 | Omissão do volume exportado (produção caiu de ~1,7–1,8 para ~1,1 mb/d) | Feito (limitação e síntese) |
| 15 Out 2026 | Valores do FMI (IFS) da secção 7 foram recolhidos num agregador (IndexMundi) | Feito: confirmado com o ficheiro do Banco Mundial (FI.RES.TOTL.CD), 16 Out 2026 |
| 16 Out 2026 | Testes de robustez (sem Abr–Mai/2020; Spearman): −0,097 e −0,109, contra −0,130 | Feito |

## 11. Rastreio dos números do dashboard e do README

Estados: **Verificado** = confirmado em fonte primária ou em várias fontes concordantes; **Cálculo** = conta sobre dados primários; **Ressalva** = fonte única, secundária ou por confirmar.

| Número | Origem | Estado |
|---|---|---|
| Brent Dez/2025: 62,54 USD; Jan/2014: 108,12 | EIA, série RBRTE (média mensal) | Verificado |
| Brent −42% (Jan/2014 → Dez/2025) | (62,54 − 108,12) ÷ 108,12 | Cálculo |
| Dólar: ~97,4 Kz (Jan/2014), ~912,2 Kz (Dez/2025); ×9,4 | Média mensal do câmbio do BNA; 912,21 ÷ 97,38 | Cálculo |
| Kwanza −89% face ao dólar (nominal) | 1 − 97,38 ÷ 912,21 | Cálculo |
| Câmbio administrado até 9 Jan 2018; 166 Kz/USD desde o 1.º trim. 2016; liberalização em Out 2019 | Jornal Económico (3 Jan 2018); Ver Angola (Jan 2019 e Nov 2019) | Verificado |
| Reservas BNA: 15.508 M USD (Dez/2021), 15.434 (Dez/2025) | BNA, média mensal dos valores diários | Cálculo; ordem de grandeza confirmada (FocusEconomics: 15,5 mil milhões em 2021 e 15,9 em 2025) |
| Brent anual 2014–2020: 99 · 52 · 44 · 54 · 71 · 64 · 42 | Média das médias mensais da EIA | Cálculo |
| Reservas líquidas em meses de importações: 8,8 · 11,4 · 10,3 · 8,5 · 8,7 · 13,6 · 9,5 | FMI, via FRED, série AGOBRASSMIMH (anual) | Verificado na fonte; definição diferente da do Banco Mundial |
| Taxa directora: mínimo 8,75% (Jul/2014) | Tabela de decisões do CPM; Trading Economics | Verificado |
| Taxa directora: máximo 20% (2021–22) | Tabela de decisões do CPM; reunião de Jan/2022 manteve os 20% | Verificado |
| Taxa directora Dez/2025: 18,5% | Reunião do CPM de Nov/2025 (BPI; Trading Economics) | Verificado em fontes secundárias; confirmar no comunicado do BNA |
| Taxa 17% → 18% (Nov/2023); 19,0% → 19,5% (Mai/2024) | Expansão (notícias dos dias das decisões) | Verificado |
| Inflação Dez/2025: 15,7% | INE; confirmada por notícia de Jan/2026 | Verificado |
| Inflação máxima 41,1% | INE, variação homóloga (máximo da série) | Cálculo sobre dados do INE |
| Taxa abaixo da inflação em 100 de 121 meses | Taxa directora − inflação homóloga, mês a mês | Cálculo (21 meses com taxa ≥ inflação, confirmado no Power BI) |
| Juro real mínimo: −25,1 pp (2016) | Mesma série | Cálculo (valor lido no Power BI: −25,12) |
| Correlações (secções 6, 7 e 8) | SQL Server, sobre as variações mensais | Cálculo, verificado com valores de controlo |
| Linhas dez-18, jan-19, nov-19, jul-21, set-22 e jan-23 da tabela de taxas | Transcrição manual de comunicados do CPM | Verificado (confirmadas nos comunicados) |
| Reservas totais 2014–2020: 27,03 · 23,79 · 23,67 · 17,46 · 15,41 · 16,33 · 13,78 mil milhões USD | FMI, International Financial Statistics, via Banco Mundial | Verificado (Banco Mundial, FI.RES.TOTL.CD; ficheiro `dados/reservas_fmi_anual.csv`; valores exactos: 27.032.344.084 · 23.790.543.425 · 23.672.191.989 · 17.455.327.771 · 15.410.405.365 · 16.334.853.784 · 13.781.988.140 USD) |
| Reservas −49% (2014→2020); −12% em 2015 | 13,78 ÷ 27,03 − 1; 23,79 ÷ 27,03 − 1 | Cálculo |
| Importações −30% em 2015 | 0,88 ÷ 1,26 (reservas ÷ meses de importações, mesma fonte) | Cálculo, aritmético; sem dados directos de importações |
| Reservas de 31,2 mil milhões USD no início de 2014 | BNA, via Ver Angola (Jun 2018) | Verificado (fonte secundária) |
| Produção de petróleo: ~1,7–1,8 mb/d (2015) e ~1,1 mb/d (desde 2021) | GlobalData (1,7 em 2015, ~1,2 em 2021); ANPG via Xinhua (pico de 1,8 em 2015; 1,134 mb/d em 2024) | Verificado em duas fontes, com valores de 2015 ligeiramente diferentes |
| Apreciação do kwanza de 18,24% em 2021 | Banco Nacional de Angola, citado pelo Jornal de Negócios (Jan 2022) | Verificado (fonte secundária) |
| Taxa directora parada em 16% entre Maio/2016 e Nov/2017 | Tabela de decisões do CPM; Ver Angola (Jan 2018, Dez 2017) | Verificado |
| Correlação sem Abr–Mai/2020 (−0,097, N = 141) e de Spearman (−0,109, N = 143) | SQL Server, secção 8.5 do script | Cálculo, verificado (a amostra completa dá −0,130, igual ao controlo) |
| Meses de importações 2014–2020: 5,15 · 6,48 · 9,08 · 5,82 · 5,41 · 6,43 · 8,03 | FMI, International Financial Statistics, via Banco Mundial (*Total reserves in months of imports*; valores lidos no IndexMundi) | Ressalva: confirmar no ficheiro do Banco Mundial |
