/* ==============================================================================
   Do Barril ao Banco Central: Choques do Brent na Economia Angolana (2014-2025)
   Script SQL Server: esquema, importação, verificações e análises

   Ordem de execução
     1. Base de dados
     2. Tabelas (esquema em estrela: Dim_Calendario + Facto_Indicadores_Economicos)
     3. Calendário (144 meses, Jan/2014 a Dez/2025)
     4. Importação do CSV (passo manual, com o Assistente do SSMS)
     5. Conversão de texto para tipos numéricos
     6. Correcção de dados
     7. Verificações (valores de controlo)
     8. Análises: câmbio, reservas e taxa de juro

   Convenção dos desfasamentos
     Desfasamento k = correlação entre a variação do Brent no mês (t-k) e a
     variação da variável de resposta no mês t.
   ============================================================================== */


/* ------------------------------------------------------------------------------
   1. BASE DE DADOS
   ------------------------------------------------------------------------------ */
IF DB_ID('EconomiaAngola') IS NULL
    CREATE DATABASE EconomiaAngola;
GO

USE EconomiaAngola;
GO


/* ------------------------------------------------------------------------------
   2. TABELAS

   ATENÇÃO: este passo APAGA e recria as duas tabelas. Corre-o só numa base de
   dados nova ou quando quiseres recomeçar do zero. Depois de o correr, a tabela
   de factos fica vazia até concluíres os passos 4 e 5 (importação e conversão).
   Para testar o script sem tocar na base de trabalho, troca o nome da base em
   CREATE DATABASE e USE (passo 1) por outro, por exemplo EconomiaAngola_Teste.
   ------------------------------------------------------------------------------ */
IF OBJECT_ID('Facto_Indicadores_Economicos', 'U') IS NOT NULL DROP TABLE Facto_Indicadores_Economicos;
IF OBJECT_ID('Dim_Calendario', 'U') IS NOT NULL DROP TABLE Dim_Calendario;
GO

CREATE TABLE Dim_Calendario (
    Data DATE NOT NULL PRIMARY KEY,
    Ano  INT  NOT NULL,
    Mes  INT  NOT NULL,
    -- necessária para a chave estrangeira da tabela de factos, que liga por (Ano, Mes)
    CONSTRAINT UQ_Calendario_AnoMes UNIQUE (Ano, Mes)
);
GO

CREATE TABLE Facto_Indicadores_Economicos (
    Ano                          INT           NOT NULL,
    Mes                          INT           NOT NULL,
    Inflacao_Homologa            DECIMAL(6,2)  NULL,      -- INE; só existe a partir de Dez/2015
    Brent_USD_Barril             DECIMAL(6,2)  NOT NULL,  -- EIA, série RBRTE (média mensal)
    Cambio_Medio                 DECIMAL(10,3) NOT NULL,  -- BNA, AOA por USD (média mensal)
    Reservas_BNA_MilhoesUSD      DECIMAL(10,2) NULL,      -- BNA; só a partir de Dez/2021
    Reservas_FRED_MesesCobertura DECIMAL(6,2)  NULL,      -- FMI via FRED, AGOBRASSMIMH; só 2014-2020
    Taxa_Juro_BNA                DECIMAL(5,2)  NOT NULL,  -- taxa directora; último valor em vigor em cada mês
    CONSTRAINT PK_Facto PRIMARY KEY (Ano, Mes),
    CONSTRAINT FK_Facto_Calendario FOREIGN KEY (Ano, Mes)
        REFERENCES Dim_Calendario (Ano, Mes)
);
GO


/* ------------------------------------------------------------------------------
   3. CALENDÁRIO: 144 meses (Jan/2014 a Dez/2025)
   ------------------------------------------------------------------------------ */
DECLARE @DataInicio DATE = '2014-01-01';
DECLARE @Contador INT = 0;

IF NOT EXISTS (SELECT 1 FROM Dim_Calendario)
BEGIN
    WHILE @Contador < 144
    BEGIN
        INSERT INTO Dim_Calendario (Data, Ano, Mes)
        VALUES (
            DATEADD(MONTH, @Contador, @DataInicio),
            YEAR(DATEADD(MONTH, @Contador, @DataInicio)),
            MONTH(DATEADD(MONTH, @Contador, @DataInicio))
        );
        SET @Contador = @Contador + 1;
    END
END
GO

SELECT COUNT(*) AS Meses_No_Calendario FROM Dim_Calendario;   -- esperado: 144
GO


/* ------------------------------------------------------------------------------
   4. IMPORTAÇÃO DO CSV (passo manual)

   O ficheiro dados/indicadores_mensais.csv usa ';' como separador de colunas e
   ',' como separador decimal. O BULK INSERT pode falhar por permissões da pasta
   (o serviço do SQL Server não vê pastas do perfil do utilizador), por isso a
   importação faz-se com o Assistente:

     SSMS > botão direito na base EconomiaAngola > Tarefas > Importar Ficheiro Simples
       - ficheiro: dados/indicadores_mensais.csv
       - nome da tabela: Staging_Indicadores
       - todas as colunas como NVARCHAR(50), com nulos permitidos
         (a conversão para números faz-se no passo 5, para evitar problemas
          com a vírgula decimal)

   O assistente usa o nome do ficheiro por defeito. Confirma o nome real da tabela
   e das colunas com:
   ------------------------------------------------------------------------------ */
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Staging_Indicadores'
ORDER BY ORDINAL_POSITION;
-- esperado: Data, Ano, Mes, Inflacao_Homologa, Brent_USD_Barril, Cambio_Medio,
--           Reservas_BNA_MilhoesUSD, Reservas_FRED_MesesCobertura, Taxa_Juro_BNA

SELECT COUNT(*) AS Linhas_Na_Staging FROM Staging_Indicadores;   -- esperado: 144
GO


/* ------------------------------------------------------------------------------
   5. CONVERSÃO: texto com vírgula decimal -> tipos numéricos
      - REPLACE troca a vírgula por ponto
      - os valores em branco ou 'NULL' passam a NULL (as 3 colunas com lacunas
        esperadas: inflação, reservas BNA e reservas FRED)
      - TRY_CONVERT devolve NULL se um valor não converter; nas colunas NOT NULL
        isso provoca erro, o que é o comportamento desejado
   ------------------------------------------------------------------------------ */
INSERT INTO Facto_Indicadores_Economicos (
    Ano, Mes, Inflacao_Homologa, Brent_USD_Barril, Cambio_Medio,
    Reservas_BNA_MilhoesUSD, Reservas_FRED_MesesCobertura, Taxa_Juro_BNA
)
SELECT
    CAST(Ano AS INT),
    CAST(Mes AS INT),
    TRY_CONVERT(DECIMAL(6,2),  REPLACE(NULLIF(NULLIF(LTRIM(RTRIM(Inflacao_Homologa)), ''), 'NULL'), ',', '.')),
    TRY_CONVERT(DECIMAL(6,2),  REPLACE(Brent_USD_Barril, ',', '.')),
    TRY_CONVERT(DECIMAL(10,3), REPLACE(Cambio_Medio, ',', '.')),
    TRY_CONVERT(DECIMAL(10,2), REPLACE(NULLIF(NULLIF(LTRIM(RTRIM(Reservas_BNA_MilhoesUSD)), ''), 'NULL'), ',', '.')),
    TRY_CONVERT(DECIMAL(6,2),  REPLACE(NULLIF(NULLIF(LTRIM(RTRIM(Reservas_FRED_MesesCobertura)), ''), 'NULL'), ',', '.')),
    TRY_CONVERT(DECIMAL(5,2),  REPLACE(Taxa_Juro_BNA, ',', '.'))
FROM Staging_Indicadores;
GO

SELECT COUNT(*) AS Linhas_Na_Facto FROM Facto_Indicadores_Economicos;   -- esperado: 144
GO

-- Depois de confirmada a conversão, a tabela temporária já não é necessária:
-- DROP TABLE Staging_Indicadores;


/* ------------------------------------------------------------------------------
   6. CORRECÇÃO DE DADOS (idempotente)
      O Comité de Política Monetária do BNA reduziu a taxa directora para 18,5%
      na reunião de Novembro de 2025. Como cada mês usa o último valor em vigor,
      Novembro de 2025 tem de estar a 18,50 (e não a 19,00).
   ------------------------------------------------------------------------------ */
UPDATE Facto_Indicadores_Economicos
SET Taxa_Juro_BNA = 18.50
WHERE Ano = 2025 AND Mes = 11;
GO


/* ------------------------------------------------------------------------------
   7. VERIFICAÇÕES (valores de controlo)
   ------------------------------------------------------------------------------ */

-- 7.1 Lacunas esperadas: 23 meses sem inflação (Jan/2014 a Nov/2015), 95 sem
--     reservas BNA (2014 a Nov/2021), 60 sem reservas FRED (2021 a 2025).
--     As restantes colunas não têm nulos.
SELECT
    SUM(CASE WHEN Inflacao_Homologa IS NULL THEN 1 ELSE 0 END)            AS Nulos_Inflacao,            -- 23
    SUM(CASE WHEN Reservas_BNA_MilhoesUSD IS NULL THEN 1 ELSE 0 END)      AS Nulos_Reservas_BNA,        -- 95
    SUM(CASE WHEN Reservas_FRED_MesesCobertura IS NULL THEN 1 ELSE 0 END) AS Nulos_Reservas_FRED,       -- 60
    SUM(CASE WHEN Brent_USD_Barril IS NULL THEN 1 ELSE 0 END)             AS Nulos_Brent,               -- 0
    SUM(CASE WHEN Cambio_Medio IS NULL THEN 1 ELSE 0 END)                 AS Nulos_Cambio,              -- 0
    SUM(CASE WHEN Taxa_Juro_BNA IS NULL THEN 1 ELSE 0 END)                AS Nulos_Taxa_Juro            -- 0
FROM Facto_Indicadores_Economicos;

-- 7.2 Pontos de controlo, comparados com as fontes
SELECT Ano, Mes, Inflacao_Homologa, Brent_USD_Barril, Taxa_Juro_BNA
FROM Facto_Indicadores_Economicos
WHERE (Ano = 2018 AND Mes = 4)     -- inflação homóloga 20,22
   OR (Ano = 2025 AND Mes = 12)    -- Brent 62,54; taxa 18,50
   OR (Ano = 2025 AND Mes = 11)    -- taxa 18,50 (após a correcção do passo 6)
   OR (Ano = 2014 AND Mes = 10)    -- taxa 9,00
ORDER BY Ano, Mes;
GO


/* ==============================================================================
   8. ANÁLISES
   ============================================================================== */

/* ------------------------------------------------------------------------------
   8.1 PERGUNTA 1: Brent x câmbio, por desfasamento e por regime cambial
       Variações percentuais mensais. O regime é o do mês do câmbio:
         Administrada: até Dez/2017 (taxa fixada pelo BNA; fixa em 166 Kz/USD desde o 1.º trim. 2016)
         Banda:        Jan/2018 a Out/2019 (flutuação dentro de uma banda)
         Livre:        desde Nov/2019
       Valores de controlo: Amostra completa, desfasamento 0 = -0,130 (N = 143);
       desfasamentos 3/6/9/12 = -0,010 / -0,141 / -0,067 / -0,026.
   ------------------------------------------------------------------------------ */
WITH Mensal AS (
    SELECT Ano, Mes,
        CAST((Brent_USD_Barril - LAG(Brent_USD_Barril) OVER (ORDER BY Ano, Mes))
             / LAG(Brent_USD_Barril) OVER (ORDER BY Ano, Mes) AS FLOAT) AS B_Var,
        CAST((Cambio_Medio - LAG(Cambio_Medio) OVER (ORDER BY Ano, Mes))
             / LAG(Cambio_Medio) OVER (ORDER BY Ano, Mes) AS FLOAT) AS C_Var
    FROM Facto_Indicadores_Economicos
),
ComLags AS (
    SELECT Ano, Mes, C_Var AS Y,
        B_Var AS X0,
        LAG(B_Var, 3)  OVER (ORDER BY Ano, Mes) AS X3,
        LAG(B_Var, 6)  OVER (ORDER BY Ano, Mes) AS X6,
        LAG(B_Var, 9)  OVER (ORDER BY Ano, Mes) AS X9,
        LAG(B_Var, 12) OVER (ORDER BY Ano, Mes) AS X12,
        CASE WHEN Ano * 100 + Mes < 201801 THEN '1. Administrada (2014-17)'
             WHEN Ano * 100 + Mes < 201911 THEN '2. Banda (2018-19)'
             ELSE '3. Livre (2019-25)' END AS Regime
    FROM Mensal
),
Pares AS (
    SELECT c.Regime, l.Lag, l.X, c.Y
    FROM ComLags c
    CROSS APPLY (VALUES (0, c.X0), (3, c.X3), (6, c.X6), (9, c.X9), (12, c.X12)) AS l(Lag, X)
    WHERE l.X IS NOT NULL AND c.Y IS NOT NULL
)
SELECT
    CASE WHEN GROUPING(Regime) = 1 THEN 'Amostra completa' ELSE Regime END AS Grupo,
    Lag AS Desfasamento_Meses,
    COUNT(*) AS N,
    ROUND(
        (COUNT(*) * SUM(X * Y) - SUM(X) * SUM(Y)) /
        NULLIF(SQRT(COUNT(*) * SUM(X * X) - SUM(X) * SUM(X)) *
               SQRT(COUNT(*) * SUM(Y * Y) - SUM(Y) * SUM(Y)), 0)
    , 3) AS Correlacao
FROM Pares
GROUP BY GROUPING SETS ((Lag), (Regime, Lag))
ORDER BY GROUPING(Regime) DESC, Regime, Lag;
GO


/* ------------------------------------------------------------------------------
   8.2 PERGUNTA 2: Brent x reservas do BNA (Dez/2021 a 2025), desfasamentos 0, 3 e 6
       Valores de controlo: -0,113 (N = 48), 0,125 (N = 45), 0,170 (N = 42).
   ------------------------------------------------------------------------------ */
WITH Base AS (
    SELECT Ano, Mes, Brent_USD_Barril AS B, Reservas_BNA_MilhoesUSD AS R
    FROM Facto_Indicadores_Economicos
    WHERE Reservas_BNA_MilhoesUSD IS NOT NULL
),
Var AS (
    SELECT Ano, Mes,
        CAST((B - LAG(B) OVER (ORDER BY Ano, Mes)) / LAG(B) OVER (ORDER BY Ano, Mes) AS FLOAT) AS B_Var,
        CAST((R - LAG(R) OVER (ORDER BY Ano, Mes)) / LAG(R) OVER (ORDER BY Ano, Mes) AS FLOAT) AS R_Var
    FROM Base
),
ComLags AS (
    SELECT R_Var AS Y, B_Var AS X0,
        LAG(B_Var, 3) OVER (ORDER BY Ano, Mes) AS X3,
        LAG(B_Var, 6) OVER (ORDER BY Ano, Mes) AS X6
    FROM Var
),
Pares AS (
    SELECT l.Lag, l.X, c.Y
    FROM ComLags c
    CROSS APPLY (VALUES (0, c.X0), (3, c.X3), (6, c.X6)) AS l(Lag, X)
    WHERE l.X IS NOT NULL AND c.Y IS NOT NULL
)
SELECT Lag AS Desfasamento_Meses, COUNT(*) AS N,
    ROUND(
        (COUNT(*) * SUM(X * Y) - SUM(X) * SUM(Y)) /
        NULLIF(SQRT(COUNT(*) * SUM(X * X) - SUM(X) * SUM(X)) *
               SQRT(COUNT(*) * SUM(Y * Y) - SUM(Y) * SUM(Y)), 0)
    , 3) AS Correlacao
FROM Pares
GROUP BY Lag
ORDER BY Lag;
GO


/* ------------------------------------------------------------------------------
   8.3 PERGUNTA 3: variação da taxa directora vs. variação da inflação e do Brent
       Janela comum Jan/2016 a Dez/2025 (meses com variação da inflação).
       Taxa e inflação em pontos percentuais; Brent em percentagem.
       Valores de controlo: Brent 0 = 0,093 (N = 120); Brent 3 = -0,033 (N = 120);
       Inflação 0 = 0,237 (N = 120); Inflação 3 = 0,126 (N = 117).
   ------------------------------------------------------------------------------ */
WITH V AS (
    SELECT Ano, Mes,
        CAST(Taxa_Juro_BNA - LAG(Taxa_Juro_BNA) OVER (ORDER BY Ano, Mes) AS FLOAT) AS T,
        CAST(Inflacao_Homologa - LAG(Inflacao_Homologa) OVER (ORDER BY Ano, Mes) AS FLOAT) AS I,
        CAST((Brent_USD_Barril - LAG(Brent_USD_Barril) OVER (ORDER BY Ano, Mes))
             / LAG(Brent_USD_Barril) OVER (ORDER BY Ano, Mes) AS FLOAT) * 100 AS B
    FROM Facto_Indicadores_Economicos
),
L AS (
    SELECT T, I AS I0, B AS B0,
        LAG(I, 3) OVER (ORDER BY Ano, Mes) AS I3,
        LAG(B, 3) OVER (ORDER BY Ano, Mes) AS B3
    FROM V
),
P AS (
    SELECT x.Serie, x.Lag, x.X, L.T AS Y
    FROM L
    CROSS APPLY (VALUES ('Inflacao', 0, L.I0), ('Inflacao', 3, L.I3),
                        ('Brent',    0, L.B0), ('Brent',    3, L.B3)) AS x(Serie, Lag, X)
    WHERE L.I0 IS NOT NULL AND L.T IS NOT NULL AND x.X IS NOT NULL
)
SELECT Serie, Lag AS Desfasamento_Meses, COUNT(*) AS N,
    ROUND((COUNT(*) * SUM(X * Y) - SUM(X) * SUM(Y)) /
      NULLIF(SQRT(COUNT(*) * SUM(X * X) - SUM(X) * SUM(X)) *
             SQRT(COUNT(*) * SUM(Y * Y) - SUM(Y) * SUM(Y)), 0), 3) AS Correlacao
FROM P
GROUP BY Serie, Lag
ORDER BY Serie, Lag;
GO


/* ------------------------------------------------------------------------------
   8.4 TAXA DE JURO REAL (ex post): taxa directora - inflação homóloga
       Valores de controlo: 121 meses com inflação disponível, 100 com a taxa
       abaixo da inflação e 21 com a taxa igual ou acima; mínimo = -25,12 p.p.
   ------------------------------------------------------------------------------ */
SELECT
    COUNT(*)                                                                AS Meses_Com_Inflacao,        -- 121
    SUM(CASE WHEN Taxa_Juro_BNA <  Inflacao_Homologa THEN 1 ELSE 0 END)     AS Meses_Taxa_Abaixo,         -- 100
    SUM(CASE WHEN Taxa_Juro_BNA >= Inflacao_Homologa THEN 1 ELSE 0 END)     AS Meses_Taxa_Igual_Ou_Acima, -- 21
    MIN(Taxa_Juro_BNA - Inflacao_Homologa)                                  AS Juro_Real_Minimo_pp        -- -25,12
FROM Facto_Indicadores_Economicos
WHERE Inflacao_Homologa IS NOT NULL;
GO

/* ------------------------------------------------------------------------------
   8.5 ROBUSTEZ: Brent x câmbio, desfasamento 0
       a) amostra completa  b) sem Abril e Maio de 2020  c) correlação por postos
       Valores de controlo: -0,130 (N = 143); -0,097 (N = 141); -0,109 (N = 143).
       Nota: RANK trata os empates de forma aproximada.
   ------------------------------------------------------------------------------ */
WITH V AS (
    SELECT Ano, Mes,
        CAST((Brent_USD_Barril - LAG(Brent_USD_Barril) OVER (ORDER BY Ano, Mes))
             / LAG(Brent_USD_Barril) OVER (ORDER BY Ano, Mes) AS FLOAT) AS X,
        CAST((Cambio_Medio - LAG(Cambio_Medio) OVER (ORDER BY Ano, Mes))
             / LAG(Cambio_Medio) OVER (ORDER BY Ano, Mes) AS FLOAT) AS Y
    FROM Facto_Indicadores_Economicos
),
D AS (SELECT * FROM V WHERE X IS NOT NULL AND Y IS NOT NULL)
SELECT 'Amostra completa' AS Teste, COUNT(*) AS N,
    ROUND((COUNT(*)*SUM(X*Y) - SUM(X)*SUM(Y)) /
      NULLIF(SQRT(COUNT(*)*SUM(X*X) - SUM(X)*SUM(X)) *
             SQRT(COUNT(*)*SUM(Y*Y) - SUM(Y)*SUM(Y)), 0), 3) AS Correlacao
FROM D
UNION ALL
SELECT 'Sem Abr-Mai/2020', COUNT(*),
    ROUND((COUNT(*)*SUM(X*Y) - SUM(X)*SUM(Y)) /
      NULLIF(SQRT(COUNT(*)*SUM(X*X) - SUM(X)*SUM(X)) *
             SQRT(COUNT(*)*SUM(Y*Y) - SUM(Y)*SUM(Y)), 0), 3)
FROM D
WHERE NOT (Ano = 2020 AND Mes IN (4, 5))
UNION ALL
SELECT 'Spearman (postos)', COUNT(*),
    ROUND((COUNT(*)*SUM(CAST(RX AS FLOAT)*RY) - SUM(CAST(RX AS FLOAT))*SUM(CAST(RY AS FLOAT))) /
      NULLIF(SQRT(COUNT(*)*SUM(CAST(RX AS FLOAT)*RX) - POWER(SUM(CAST(RX AS FLOAT)), 2)) *
             SQRT(COUNT(*)*SUM(CAST(RY AS FLOAT)*RY) - POWER(SUM(CAST(RY AS FLOAT)), 2)), 0), 3)
FROM (SELECT RANK() OVER (ORDER BY X) AS RX, RANK() OVER (ORDER BY Y) AS RY FROM D) R;
GO
