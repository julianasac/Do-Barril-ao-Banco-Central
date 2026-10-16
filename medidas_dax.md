# Medidas DAX do dashboard

Este documento reúne as medidas e colunas calculadas do dashboard em Power BI. Cada medida traz o seu **valor de controlo**, calculado a partir da tabela mensal, para qualquer pessoa poder confirmar que o modelo funciona.

## Modelo de dados

| Tabela | Conteúdo |
|---|---|
| `Dim_Calendario` | 144 meses (Jan/2014 a Dez/2025): `Data`, `Ano`, `Mes` |
| `Facto_Indicadores_Economicos` | uma linha por mês, com os indicadores (ver `README.md`) |
| `Reservas_FMI_Anual` | tabela autónoma, sem relação com as outras (reservas totais do FMI, 2014–2020) |

`Dim_Calendario` liga a `Facto_Indicadores_Economicos` por mês e ano (relação um para muitos). Todas as medidas abaixo estão escritas na tabela de factos, salvo indicação em contrário.

## Convenções

- **Base fixa com `ALL(Dim_Calendario)`:** os índices e as variações anuais calculam a base (Jan/2014 ou o ano anterior) ignorando o filtro de datas, para o segmentador não mudar a referência.
- **`REMOVEFILTERS` no regime cambial:** nas variações anuais, o ano corrente ignora o filtro de regime, para a barra de cada ano ser sempre a variação do ano inteiro.
- **`ISBLANK` antes de subtrair:** antes de Dez/2015 não há inflação, e sem esta protecção o vazio seria tratado como zero.
- **`DATATABLE` em vez de "Introduzir dados":** os tipos ficam definidos e o separador decimal é sempre o ponto, o que evita problemas com a vírgula.

---

## Página 1: Resumo

**Medidas de base**

```dax
Brent_Medio =
AVERAGE(Facto_Indicadores_Economicos[Brent_USD_Barril])
```

**Índices com base 100 em Jan/2014** (gráfico principal)

```dax
Brent_Indice =
VAR Base = CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Brent_USD_Barril]),
    ALL(Dim_Calendario), Dim_Calendario[Ano] = 2014, Dim_Calendario[Mes] = 1)
RETURN DIVIDE(AVERAGE(Facto_Indicadores_Economicos[Brent_USD_Barril]), Base) * 100
```

```dax
Kwanza_Indice =
VAR Base = CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Cambio_Medio]),
    ALL(Dim_Calendario), Dim_Calendario[Ano] = 2014, Dim_Calendario[Mes] = 1)
RETURN DIVIDE(Base, AVERAGE(Facto_Indicadores_Economicos[Cambio_Medio])) * 100
```

O `Kwanza_Indice` é o inverso do câmbio (kwanzas por dólar), por isso "mais alto" significa kwanza mais forte, e as duas séries ficam na mesma escala. **Controlo (Dez/2025):** Brent 57,8 e kwanza 10,7.

**Cartões (valores em Dez/2025)**

```dax
Brent_Dez2025 =
CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Brent_USD_Barril]),
    Facto_Indicadores_Economicos[Ano] = 2025, Facto_Indicadores_Economicos[Mes] = 12)
```

```dax
Cambio_Mais_Recente =
CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Cambio_Medio]),
    Facto_Indicadores_Economicos[Ano] = 2025, Facto_Indicadores_Economicos[Mes] = 12)
```

```dax
Taxa_Juro_Mais_Recente =
CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Taxa_Juro_BNA]),
    Facto_Indicadores_Economicos[Ano] = 2025, Facto_Indicadores_Economicos[Mes] = 12)
```

```dax
Inflacao_Mais_Recente =
CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Inflacao_Homologa]),
    Facto_Indicadores_Economicos[Ano] = 2025, Facto_Indicadores_Economicos[Mes] = 12)
```

**Controlo:** 62,54 USD; 912,21 Kz; 18,5%; 15,7%.

---

## Página 2: Câmbio

```dax
Cambio_Inicio =
CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Cambio_Medio]),
    Facto_Indicadores_Economicos[Ano] = 2014, Facto_Indicadores_Economicos[Mes] = 1)
```

**Controlo:** 97,38 Kz.

**Regime cambial** (colunas calculadas em `Dim_Calendario`, alimentam o segmentador)

```dax
Regime =
SWITCH(
    TRUE(),
    Dim_Calendario[Data] < DATE(2018, 1, 1), "Administrada (2014–17)",
    Dim_Calendario[Data] < DATE(2019, 11, 1), "Banda (2018–19)",
    "Livre (2019–25)"
)
```

```dax
Regime_Ordem =
SWITCH(TRUE(), Dim_Calendario[Data] < DATE(2018, 1, 1), 1,
               Dim_Calendario[Data] < DATE(2019, 11, 1), 2, 3)
```

`Regime` ordena-se por `Regime_Ordem`, para os botões aparecerem pela ordem cronológica. **Controlo:** 48, 22 e 74 meses.

**Variações mensais** (colunas calculadas em `Facto_Indicadores_Economicos`, alimentam o gráfico de dispersão)

```dax
Brent_VarPct =
VAR P = Facto_Indicadores_Economicos[Ano] * 12 + Facto_Indicadores_Economicos[Mes]
VAR Ant = CALCULATE(MAX(Facto_Indicadores_Economicos[Brent_USD_Barril]),
    FILTER(ALL(Facto_Indicadores_Economicos),
        Facto_Indicadores_Economicos[Ano] * 12 + Facto_Indicadores_Economicos[Mes] = P - 1))
RETURN DIVIDE(Facto_Indicadores_Economicos[Brent_USD_Barril] - Ant, Ant)
```

```dax
Cambio_VarPct =
VAR P = Facto_Indicadores_Economicos[Ano] * 12 + Facto_Indicadores_Economicos[Mes]
VAR Ant = CALCULATE(MAX(Facto_Indicadores_Economicos[Cambio_Medio]),
    FILTER(ALL(Facto_Indicadores_Economicos),
        Facto_Indicadores_Economicos[Ano] * 12 + Facto_Indicadores_Economicos[Mes] = P - 1))
RETURN DIVIDE(Facto_Indicadores_Economicos[Cambio_Medio] - Ant, Ant)
```

O mês anterior calcula-se pela posição `Ano × 12 + Mês`, e o primeiro mês fica sem valor. **Controlo (Fev/2014):** Brent +0,7% e câmbio −0,0%.

**Variações anuais** (barras "Ano a ano")

```dax
Brent_Var_Anual =
VAR AnoAtual = MAX(Dim_Calendario[Ano])
VAR MediaAtual = CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Brent_USD_Barril]),
    REMOVEFILTERS(Dim_Calendario[Regime]))
VAR MediaAnt = CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Brent_USD_Barril]),
    ALL(Dim_Calendario), Dim_Calendario[Ano] = AnoAtual - 1)
RETURN DIVIDE(MediaAtual - MediaAnt, MediaAnt)
```

```dax
Cambio_Var_Anual =
VAR AnoAtual = MAX(Dim_Calendario[Ano])
VAR MediaAtual = CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Cambio_Medio]),
    REMOVEFILTERS(Dim_Calendario[Regime]))
VAR MediaAnt = CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Cambio_Medio]),
    ALL(Dim_Calendario), Dim_Calendario[Ano] = AnoAtual - 1)
RETURN DIVIDE(MediaAtual - MediaAnt, MediaAnt)
```

**Controlo (Brent):** 2015 = −47% e 2020 = −35%.

---

## Página 3: Reservas

```dax
Reservas_BNA_Medio =
AVERAGE(Facto_Indicadores_Economicos[Reservas_BNA_MilhoesUSD])
```

```dax
Reservas_BNA_Dez2021 =
CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Reservas_BNA_MilhoesUSD]),
    Facto_Indicadores_Economicos[Ano] = 2021, Facto_Indicadores_Economicos[Mes] = 12)
```

```dax
Reservas_BNA_Dez2025 =
CALCULATE(AVERAGE(Facto_Indicadores_Economicos[Reservas_BNA_MilhoesUSD]),
    Facto_Indicadores_Economicos[Ano] = 2025, Facto_Indicadores_Economicos[Mes] = 12)
```

**Controlo:** 15.508 e 15.434 milhões USD.

**Reservas totais do FMI** (tabela autónoma; fonte: Banco Mundial, *Total reserves (includes gold, current US$)*)

```dax
Reservas_FMI_Anual =
DATATABLE(
    "Ano", INTEGER,
    "Reservas_Totais_MilMilhoesUSD", DOUBLE,
    {
        {2014, 27.03}, {2015, 23.79}, {2016, 23.67}, {2017, 17.46},
        {2018, 15.41}, {2019, 16.33}, {2020, 13.78}
    }
)
```

**Controlo:** queda de 49% entre 2014 e 2020.

---

## Página 4: Taxa de juro

```dax
Taxa_Juro_Media =
AVERAGE(Facto_Indicadores_Economicos[Taxa_Juro_BNA])
```

```dax
Inflacao_Media =
AVERAGE(Facto_Indicadores_Economicos[Inflacao_Homologa])
```

**Taxa de juro real (ex post)** = taxa directora menos inflação homóloga

```dax
Taxa_Menos_Inflacao =
IF(ISBLANK([Inflacao_Media]), BLANK(), [Taxa_Juro_Media] - [Inflacao_Media])
```

```dax
Dif_Positiva = IF([Taxa_Menos_Inflacao] >= 0, [Taxa_Menos_Inflacao])
```

```dax
Dif_Negativa = IF([Taxa_Menos_Inflacao] < 0, [Taxa_Menos_Inflacao])
```

As duas últimas separam os meses em que a taxa está acima da inflação (verde) dos que está abaixo (bordô), num gráfico de colunas empilhadas. **Controlo:** o último mês é +2,8 e o mínimo é −25,12 pontos percentuais (2016).

**Contagem de meses** (cartões temporários, usados para o README)

```dax
Meses_Com_Inflacao =
COUNTROWS(FILTER(VALUES(Dim_Calendario[Data]), NOT(ISBLANK([Taxa_Menos_Inflacao]))))
```

```dax
Meses_Taxa_Acima =
COUNTROWS(FILTER(VALUES(Dim_Calendario[Data]),
    NOT(ISBLANK([Taxa_Menos_Inflacao])) && [Taxa_Menos_Inflacao] >= 0))
```

**Controlo:** 121 meses com inflação, dos quais 21 com a taxa igual ou acima da inflação (e 100 abaixo).

---

*Origem de cada número do dashboard e do README: secção 11 de `metodologia_projecto.md`.*
