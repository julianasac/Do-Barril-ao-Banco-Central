# Resumo Executivo

**Do Barril ao Banco Central: Choques do Brent na Economia Angolana (2014–2025)**

**Dashboard:** [Power BI](https://app.powerbi.com/view?r=eyJrIjoiMmQzZmQ5OWItNWIxOC00N2Y2LThmZGYtZjUzYTQ3NjZiNWM0IiwidCI6IjgyNWI5NmI2LTdhMDAtNDI4Ny05ZmRhLWQ4MWM4ZTJkZmNhYiJ9) · **Repositório:** [GitHub](https://github.com/julianasac/do-barril-ao-banco-central)

## Contexto e objectivo

Angola vive das exportações de petróleo. Este projecto analisa, com dados mensais reais de 2014 a 2025, se o preço do Brent se reflecte no câmbio, nas reservas internacionais e na taxa de juro do BNA.

## Principais conclusões

1. **Câmbio.** O Brent caiu 42% e o dólar passou de cerca de 97 para cerca de 912 Kz (×9,4; em termos nominais, o kwanza perdeu 89% do seu valor face ao dólar). Mês a mês, as variações das duas séries não estão relacionadas de forma consistente, nem sequer depois da liberalização cambial (a taxa foi fixada pelo BNA até Janeiro de 2018 e liberalizada em Outubro de 2019). No período administrado, a taxa oficial não mede o choque: esteve fixa durante 2016–2017 e ajustou-se depois, por degraus.
2. **Reservas.** Entre 2014 e 2020, as reservas totais caíram quase para metade (de cerca de 27,0 para cerca de 13,8 mil milhões USD, −49%), com o Brent a passar de 99 para 42 USD em média anual. Em 2015, as reservas em dólares caíram 12% e o indicador em meses de importações subiu, o que implica que as importações caíram mais depressa. Desde Dezembro de 2021 estabilizaram em torno de 15 mil milhões USD (BNA).
3. **Taxa de juro.** A taxa directora acompanha a inflação do mesmo mês, de forma fraca, e não acompanha o Brent. Ficou abaixo da inflação em 100 dos 121 meses disponíveis: a taxa de juro real foi negativa na maior parte do período, com o mínimo de −25,1 pontos percentuais em 2016.

## O que isto significa

- Não há transmissão contínua e mensal do petróleo para o câmbio nem para as reservas. Ao nível anual, o choque de 2014–2016 é seguido de uma perda de reservas e de ajustamentos cambiais por degraus, o que sugere uma transmissão diferida, mediada pelo regime cambial e pelas reservas. É uma leitura, não uma prova.
- Nos dois episódios de subida forte da inflação (2015–16 e 2023–24), a taxa directora subiu, mas muito menos do que os preços, o que se traduz em juros reais negativos na maior parte do período (leitura *ex post*, com a inflação homóloga).

## Limitações

- A análise mensal é linear, e correlação não é causalidade. As coincidências anuais assentam em 11 pontos.
- A receita em divisas depende do preço e do volume, e a produção caiu de cerca de 1,7–1,8 para cerca de 1,1 milhões de barris/dia entre 2015 e 2021. Usar só o Brent omite metade do choque.
- Em 2016–2017 o câmbio oficial esteve quase constante, e as reservas vêm de fontes com definições diferentes.
- A inflação homóloga só existe desde Dezembro de 2015, e a taxa de juro muda por degraus, com poucas decisões em 12 anos.

## Dados e método

Brent: EIA. Câmbio, reservas (desde 2021) e taxa directora: BNA. Inflação: INE. Reservas totais e em meses de importações (2014–2020): FMI. Pipeline: Excel / Power Query → SQL Server → Power BI. A metodologia detalhada, os testes e o registo de correcções estão em `metodologia_projecto.md`.

## Próximos passos possíveis

1. Juntar a receita petrolífera do Orçamento Geral do Estado e o volume exportado, e testar a transmissão através do orçamento.
2. Passar de correlações a pares a um modelo multivariado (estacionariedade, causalidade de Granger e um VAR).
3. Medir o câmbio de mercado (paralelo) no período administrado, se houver série disponível.
