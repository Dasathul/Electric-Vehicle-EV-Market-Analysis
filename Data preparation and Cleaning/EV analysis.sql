CREATE DATABASE internship3

CREATE TABLE dbo.VehicleClassAll (
    [Vehicle Class] NVARCHAR(255),
    [Total Registration] NVARCHAR(50)
);

SELECT* FROM [Vehicle Class - All]

UPDATE [Vehicle Class - All]
SET Total_Registration = REPLACE(Total_Registration, ',', '');

ALTER TABLE [Vehicle Class - All]
ALTER COLUMN Total_Registration BIGINT;


------------------------------------category mapping --------------------------------------


CREATE TABLE CategoryMap (
    RawCategory NVARCHAR(200) NOT NULL PRIMARY KEY,
    CategoryGroup NVARCHAR(50) NOT NULL
);

INSERT INTO CategoryMap (RawCategory, CategoryGroup) VALUES
(N'FOUR WHEELER (INVALID CARRIAGE)', '4W'),
(N'LIGHT MOTOR VEHICLE', '4W'),
(N'LIGHT PASSENGER VEHICLE', '4W'),
(N'LIGHT GOODS VEHICLE', '4W'),
(N'TWO WHEELER (INVALID CARRIAGE)', '2W'),
(N'TWO WHEELER(NT)', '2W'),
(N'TWO WHEELER(T)', '2W'),
(N'THREE WHEELER(NT)', '3W'),
(N'THREE WHEELER(T)', '3W'),
(N'HEAVY GOODS VEHICLE', 'Commercial'),
(N'HEAVY MOTOR VEHICLE', 'Commercial'),
(N'MEDIUM GOODS VEHICLE', 'Commercial'),
(N'MEDIUM MOTOR VEHICLE', 'Commercial'),
(N'OTHER THAN MENTIONED ABOVE', 'Other');

SELECT* FROM CategoryMap

--------------------------------Fact_Category (unpivot of ev_cat_01-24)----------------------------


CREATE TABLE Fact_Category (
    FactCategoryID INT IDENTITY(1,1) PRIMARY KEY,
    [Date] DATE NULL,
    [Year] INT NULL,
    RawCategory NVARCHAR(200) NULL,
    Registrations BIGINT NULL,
    CategoryGroup NVARCHAR(50) NULL
);

INSERT INTO Fact_Category ([Date],[Year], RawCategory, Registrations)
SELECT
  TRY_CAST([Date] AS DATE) AS [Date],
  CASE WHEN TRY_CAST([Date] AS DATE) IS NULL THEN NULL ELSE YEAR(TRY_CAST([Date] AS DATE)) END AS [Year],
  v.Category AS RawCategory,
  TRY_CAST(REPLACE(v.Registrations,',','') AS BIGINT) AS Registrations
FROM
(
  SELECT [Date],
       [FOUR_WHEELER_INVALID_CARRIAGE],
       [HEAVY_GOODS_VEHICLE],
       [HEAVY_MOTOR_VEHICLE],
       [HEAVY_PASSENGER_VEHICLE],
       [LIGHT_GOODS_VEHICLE],
       [LIGHT_MOTOR_VEHICLE],
       [LIGHT_PASSENGER_VEHICLE],
       [MEDIUM_GOODS_VEHICLE],
       [MEDIUM_PASSENGER_VEHICLE],
       [MEDIUM_MOTOR_VEHICLE],
       [OTHER_THAN_MENTIONED_ABOVE],
       [THREE_WHEELER_NT],
       [TWO_WHEELER_INVALID_CARRIAGE],
       [THREE_WHEELER_T],
       [TWO_WHEELER_NT],
       [TWO_WHEELER_T]
  FROM [ev_cat_01-24]
) src
UNPIVOT
(
  Registrations FOR Category IN (
       [FOUR_WHEELER_INVALID_CARRIAGE],
       [HEAVY_GOODS_VEHICLE],
       [HEAVY_MOTOR_VEHICLE],
       [HEAVY_PASSENGER_VEHICLE],
       [LIGHT_GOODS_VEHICLE],
       [LIGHT_MOTOR_VEHICLE],
       [LIGHT_PASSENGER_VEHICLE],
       [MEDIUM_GOODS_VEHICLE],
       [MEDIUM_PASSENGER_VEHICLE],
       [MEDIUM_MOTOR_VEHICLE],
       [OTHER_THAN_MENTIONED_ABOVE],
       [THREE_WHEELER_NT],
       [TWO_WHEELER_INVALID_CARRIAGE],
       [THREE_WHEELER_T],
       [TWO_WHEELER_NT],
       [TWO_WHEELER_T]
  )
) v;
-- map category groups
UPDATE fc
SET CategoryGroup = COALESCE(cm.CategoryGroup,
    CASE 
      WHEN fc.RawCategory LIKE '%TWO WHEELER%' THEN '2W'
      WHEN fc.RawCategory LIKE '%THREE WHEELER%' THEN '3W'
      WHEN fc.RawCategory LIKE '%FOUR WHEELER%' OR fc.RawCategory LIKE '%LIGHT MOTOR%' OR fc.RawCategory LIKE '%LIGHT PASSENGER%' THEN '4W'
      WHEN fc.RawCategory LIKE '%HEAVY%' OR fc.RawCategory LIKE '%MEDIUM%' THEN 'Commercial'
      ELSE 'Other'
    END)
FROM Fact_Category fc
LEFT JOIN CategoryMap cm ON fc.RawCategory = cm.RawCategory;


-- DROP / CREATE target fact table
IF OBJECT_ID('dbo.Fact_Category','U') IS NOT NULL DROP TABLE dbo.Fact_Category;
CREATE TABLE dbo.Fact_Category (
    FactCategoryID INT IDENTITY(1,1) PRIMARY KEY,
    [Date] DATE NULL,
    [Year] INT NULL,
    RawCategory NVARCHAR(200) NULL,
    Registrations BIGINT NULL,
    CategoryGroup NVARCHAR(50) NULL
);

-- Insert using CROSS APPLY (safe unpivot)
INSERT INTO dbo.Fact_Category ([Date],[Year], RawCategory, Registrations)
SELECT
    -- try common date formats: first try direct cast, then try dd/mm/yy (style 103), else NULL
    COALESCE(TRY_CAST(src.[Date] AS DATE), TRY_CONVERT(date, src.[Date], 103)) AS [Date],
    CASE 
      WHEN COALESCE(TRY_CAST(src.[Date] AS DATE), TRY_CONVERT(date, src.[Date], 103)) IS NULL THEN NULL
      ELSE YEAR(COALESCE(TRY_CAST(src.[Date] AS DATE), TRY_CONVERT(date, src.[Date], 103)))
    END AS [Year],
    v.RawCategory,
    TRY_CAST(REPLACE(v.RegistrationsStr, ',', '') AS BIGINT) AS Registrations
FROM
(
  -- select raw row; we keep Date as-is and cast all category columns to NVARCHAR for safe unpivoting
  SELECT 
     [Date],
     CAST([FOUR_WHEELER_INVALID_CARRIAGE] AS NVARCHAR(100))      AS FOUR_WHEELER_INVALID_CARRIAGE,
     CAST([HEAVY_GOODS_VEHICLE] AS NVARCHAR(100))               AS HEAVY_GOODS_VEHICLE,
     CAST([HEAVY_MOTOR_VEHICLE] AS NVARCHAR(100))               AS HEAVY_MOTOR_VEHICLE,
     CAST([HEAVY_PASSENGER_VEHICLE] AS NVARCHAR(100))           AS HEAVY_PASSENGER_VEHICLE,
     CAST([LIGHT_GOODS_VEHICLE] AS NVARCHAR(100))               AS LIGHT_GOODS_VEHICLE,
     CAST([LIGHT_MOTOR_VEHICLE] AS NVARCHAR(100))               AS LIGHT_MOTOR_VEHICLE,
     CAST([LIGHT_PASSENGER_VEHICLE] AS NVARCHAR(100))           AS LIGHT_PASSENGER_VEHICLE,
     CAST([MEDIUM_GOODS_VEHICLE] AS NVARCHAR(100))              AS MEDIUM_GOODS_VEHICLE,
     CAST([MEDIUM_PASSENGER_VEHICLE] AS NVARCHAR(100))          AS MEDIUM_PASSENGER_VEHICLE,
     CAST([MEDIUM_MOTOR_VEHICLE] AS NVARCHAR(100))              AS MEDIUM_MOTOR_VEHICLE,
     CAST([OTHER_THAN_MENTIONED_ABOVE] AS NVARCHAR(100))        AS OTHER_THAN_MENTIONED_ABOVE,
     CAST([THREE_WHEELER_NT] AS NVARCHAR(100))                  AS THREE_WHEELER_NT,
     CAST([TWO_WHEELER_INVALID_CARRIAGE] AS NVARCHAR(100))      AS TWO_WHEELER_INVALID_CARRIAGE,
     CAST([THREE_WHEELER_T] AS NVARCHAR(100))                   AS THREE_WHEELER_T,
     CAST([TWO_WHEELER_NT] AS NVARCHAR(100))                    AS TWO_WHEELER_NT,
     CAST([TWO_WHEELER_T] AS NVARCHAR(100))                     AS TWO_WHEELER_T
  FROM dbo.[ev_cat_01-24]
) AS src
CROSS APPLY
(
  VALUES
    ('FOUR WHEELER (INVALID CARRIAGE)',     src.FOUR_WHEELER_INVALID_CARRIAGE),
    ('HEAVY GOODS VEHICLE',                 src.HEAVY_GOODS_VEHICLE),
    ('HEAVY MOTOR VEHICLE',                 src.HEAVY_MOTOR_VEHICLE),
    ('HEAVY PASSENGER VEHICLE',             src.HEAVY_PASSENGER_VEHICLE),
    ('LIGHT GOODS VEHICLE',                 src.LIGHT_GOODS_VEHICLE),
    ('LIGHT MOTOR VEHICLE',                 src.LIGHT_MOTOR_VEHICLE),
    ('LIGHT PASSENGER VEHICLE',             src.LIGHT_PASSENGER_VEHICLE),
    ('MEDIUM GOODS VEHICLE',                src.MEDIUM_GOODS_VEHICLE),
    ('MEDIUM PASSENGER VEHICLE',            src.MEDIUM_PASSENGER_VEHICLE),
    ('MEDIUM MOTOR VEHICLE',                src.MEDIUM_MOTOR_VEHICLE),
    ('OTHER THAN MENTIONED ABOVE',          src.OTHER_THAN_MENTIONED_ABOVE),
    ('THREE WHEELER(NT)',                   src.THREE_WHEELER_NT),
    ('TWO WHEELER (INVALID CARRIAGE)',      src.TWO_WHEELER_INVALID_CARRIAGE),
    ('THREE WHEELER(T)',                    src.THREE_WHEELER_T),
    ('TWO WHEELER(NT)',                     src.TWO_WHEELER_NT),
    ('TWO WHEELER(T)',                      src.TWO_WHEELER_T)
) v(RawCategory, RegistrationsStr);

SELECT* FROM Fact_Category

-- normalize RawCategory values in place
UPDATE dbo.Fact_Category
SET RawCategory = LTRIM(RTRIM(REPLACE(REPLACE(RawCategory, CHAR(160), ''), CHAR(9), '')))
WHERE RawCategory IS NOT NULL;


-- All distinct categories in fact table
SELECT DISTINCT RawCategory
FROM dbo.Fact_Category
ORDER BY RawCategory;

-- Which distinct categories are NOT in CategoryMap
SELECT fc.RawCategory, COUNT(*) AS cnt
FROM dbo.Fact_Category fc
LEFT JOIN dbo.CategoryMap cm ON fc.RawCategory = cm.RawCategory
WHERE cm.RawCategory IS NULL
GROUP BY fc.RawCategory
ORDER BY cnt DESC;

-- insert only if not already present
INSERT INTO dbo.CategoryMap (RawCategory, CategoryGroup)
SELECT v.RawCategory, v.CategoryGroup
FROM (VALUES
   ('HEAVY PASSENGER VEHICLE','Commercial'),
   ('MEDIUM PASSENGER VEHICLE','Commercial')
) AS v(RawCategory, CategoryGroup)
WHERE NOT EXISTS (
   SELECT 1 FROM dbo.CategoryMap cm WHERE cm.RawCategory = v.RawCategory
);

UPDATE fc
SET CategoryGroup = cm.CategoryGroup
FROM dbo.Fact_Category fc
JOIN dbo.CategoryMap cm
  ON fc.RawCategory = cm.RawCategory;

SELECT* FROM [ev_sales_by_makers_and_cat_15-24]

---------------------------------------------- fact makersales-----------------------------------------

EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column1', 'Cat', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column2', 'Maker', 'COLUMN';


SELECT TOP 5 * FROM dbo.[ev_sales_by_makers_and_cat_15-24];


EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column3',  '2015', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column4',  '2016', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column5',  '2017', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column6',  '2018', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column7',  '2019', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column8',  '2020', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column9',  '2021', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column10', '2022', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column11', '2023', 'COLUMN';
EXEC sp_rename 'ev_sales_by_makers_and_cat_15-24.column12', '2024', 'COLUMN';

DELETE FROM dbo.[ev_sales_by_makers_and_cat_15-24]
WHERE Cat = 'Cat' AND Maker = 'Maker';



-- 1. create fact table (clean start)
IF OBJECT_ID('dbo.Fact_MakerSales','U') IS NOT NULL DROP TABLE dbo.Fact_MakerSales;
CREATE TABLE dbo.Fact_MakerSales (
  MakerSalesID INT IDENTITY(1,1) PRIMARY KEY,
  Maker NVARCHAR(255),
  RawCategory NVARCHAR(255),
  [Year] INT,
  Sales BIGINT,
  CategoryGroup NVARCHAR(50) NULL
);

-- 2. unpivot years 2015-2024 (source: ev_sales_by_makers_and_cat_15-24)
INSERT INTO dbo.Fact_MakerSales (Maker, RawCategory, [Year], Sales)
SELECT
  TRY_CAST(s.Maker AS NVARCHAR(255))     AS Maker,
  TRY_CAST(s.Cat AS NVARCHAR(255))       AS RawCategory,
  TRY_CAST(y.yr AS INT)                  AS [Year],
  TRY_CAST(REPLACE(COALESCE(y.val, ''), ',', '') AS BIGINT) AS Sales
FROM dbo.[ev_sales_by_makers_and_cat_15-24] s
CROSS APPLY (VALUES
   (2015, s.[2015]), (2016, s.[2016]), (2017, s.[2017]), (2018, s.[2018]),
   (2019, s.[2019]), (2020, s.[2020]), (2021, s.[2021]), (2022, s.[2022]),
   (2023, s.[2023]), (2024, s.[2024])
) y(yr, val)
WHERE LTRIM(RTRIM(COALESCE(y.val, ''))) <> ''; -- skip empty cells

-- 3. map CategoryGroup from CategoryMap (exact) then fallback patterns
UPDATE f
SET CategoryGroup = m.CategoryGroup
FROM dbo.Fact_MakerSales f
JOIN dbo.CategoryMap m ON f.RawCategory = m.RawCategory;

UPDATE dbo.Fact_MakerSales
SET CategoryGroup =
  CASE
    WHEN UPPER(RawCategory) LIKE '%TWO WHEELER%' THEN '2W'
    WHEN UPPER(RawCategory) LIKE '%THREE WHEELER%' THEN '3W'
    WHEN UPPER(RawCategory) LIKE '%FOUR WHEELER%' OR UPPER(RawCategory) LIKE '%LIGHT MOTOR%' OR UPPER(RawCategory) LIKE '%LIGHT PASSENGER%' THEN '4W'
    WHEN UPPER(RawCategory) LIKE '%HEAVY%' OR UPPER(RawCategory) LIKE '%MEDIUM%' OR UPPER(RawCategory) LIKE '%GOODS%' THEN 'Commercial'
    ELSE 'Other'
  END
WHERE CategoryGroup IS NULL OR CategoryGroup = '';

-- 4. quick checks
SELECT COUNT(*) AS RowsInFact FROM dbo.Fact_MakerSales;
SELECT TOP 10 * FROM dbo.Fact_MakerSales ORDER BY [Year] DESC, Sales DESC;








-- 1) See what abbreviation values exist
SELECT DISTINCT RawCategory
FROM dbo.Fact_MakerSales
ORDER BY RawCategory;

-- 2) Insert guessed mappings for abbreviations that are not yet in CategoryMap
-- (non-destructive: only inserts when not exists)
INSERT INTO dbo.CategoryMap (RawCategory, CategoryGroup)
SELECT DISTINCT f.RawCategory,
  CASE
    WHEN UPPER(f.RawCategory) IN ('2W','TWO WHEELER','TWO WHEELER(NT)','TWO WHEELER(T)','TWO WHEELER (INVALID CARRIAGE)') THEN '2W'
    WHEN UPPER(f.RawCategory) IN ('3W','THREE WHEELER','THREE WHEELER(NT)','THREE WHEELER(T)') THEN '3W'
    WHEN UPPER(f.RawCategory) IN ('LMV','LIGHT MOTOR VEHICLE','LIGHT PASSENGER VEHICLE','LIGHT GOODS VEHICLE','FOUR WHEELER','4W') THEN '4W'
    WHEN UPPER(f.RawCategory) LIKE '%HEAVY%' OR UPPER(f.RawCategory) LIKE '%MEDIUM%' OR UPPER(f.RawCategory) LIKE '%GOODS%' THEN 'Commercial'
    ELSE 'Other'
  END
FROM dbo.Fact_MakerSales f
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.CategoryMap cm WHERE cm.RawCategory = f.RawCategory
);

-- 3) Apply exact mapping from CategoryMap to Fact_MakerSales
UPDATE f
SET CategoryGroup = cm.CategoryGroup
FROM dbo.Fact_MakerSales f
JOIN dbo.CategoryMap cm
  ON f.RawCategory = cm.RawCategory;

-- 4) Defensive fallback (pattern based) for any remaining NULLs (should be few or zero)
UPDATE dbo.Fact_MakerSales
SET CategoryGroup =
  CASE
    WHEN UPPER(RawCategory) LIKE '%TWO WHEELER%' OR UPPER(RawCategory) IN ('2W') THEN '2W'
    WHEN UPPER(RawCategory) LIKE '%THREE WHEELER%' OR UPPER(RawCategory) IN ('3W') THEN '3W'
    WHEN UPPER(RawCategory) LIKE '%FOUR WHEELER%' OR UPPER(RawCategory) LIKE '%LIGHT MOTOR%' OR UPPER(RawCategory) IN ('LMV','4W') THEN '4W'
    WHEN UPPER(RawCategory) LIKE '%HEAVY%' OR UPPER(RawCategory) LIKE '%MEDIUM%' OR UPPER(RawCategory) LIKE '%GOODS%' THEN 'Commercial'
    ELSE 'Other'
  END
WHERE CategoryGroup IS NULL OR CategoryGroup = '';

-- 5) Verify results
SELECT CategoryGroup, COUNT(*) AS cnt
FROM dbo.Fact_MakerSales
GROUP BY CategoryGroup
ORDER BY cnt DESC;

-- Show sample rows for each group (optional)
SELECT TOP 20 * FROM dbo.Fact_MakerSales WHERE CategoryGroup = '2W' ORDER BY [Year] DESC;
SELECT TOP 20 * FROM dbo.Fact_MakerSales WHERE CategoryGroup = '3W' ORDER BY [Year] DESC;
SELECT TOP 20 * FROM dbo.Fact_MakerSales WHERE CategoryGroup = '4W' ORDER BY [Year] DESC;
SELECT TOP 20 * FROM dbo.Fact_MakerSales WHERE CategoryGroup = 'Commercial' ORDER BY [Year] DESC;



--------------------------------------------dim makerlocation------------------------------------------

CREATE TABLE Dim_MakerLocation (
    Maker NVARCHAR(255) PRIMARY KEY,
    Place NVARCHAR(255),
    State NVARCHAR(255)
);

INSERT INTO Dim_MakerLocation (Maker, Place, [State])
SELECT [EV_Maker], Place, [State]
FROM [EV Maker by Place];

TRUNCATE TABLE Dim_MakerLocation;  -- clear table first (only if needed)

INSERT INTO Dim_MakerLocation (Maker, Place, State)
SELECT DISTINCT EV_Maker, Place, State
FROM [EV Maker by Place];

SELECT* FROM Dim_MakerLocation


---------------------------------------------maker state presence--------------------------------------

IF OBJECT_ID('dbo.Maker_State_Presence','U') IS NOT NULL DROP TABLE dbo.Maker_State_Presence;
CREATE TABLE dbo.Maker_State_Presence (
    Maker NVARCHAR(255),
    State NVARCHAR(255)
);

INSERT INTO dbo.Maker_State_Presence (Maker, State)
SELECT DISTINCT Maker, State
FROM dbo.Dim_MakerLocation;

SELECT* FROM Maker_State_Presence

-----------------------------------------------------dim state---------------------------------------

IF OBJECT_ID('dbo.Dim_State','U') IS NOT NULL DROP TABLE dbo.Dim_State;
CREATE TABLE dbo.Dim_State (
    StateID INT IDENTITY(1,1) PRIMARY KEY,
    State NVARCHAR(255),
    MakerCount INT,
    MakersList NVARCHAR(MAX),
    NoOfOperationalPCs INT
);

INSERT INTO dbo.Dim_State (State, MakerCount, MakersList, NoOfOperationalPCs)
SELECT
    mp.State,
    COUNT(DISTINCT mp.Maker) AS MakerCount,
    STRING_AGG(mp.Maker, ', ') WITHIN GROUP (ORDER BY mp.Maker) AS MakersList,
    ISNULL(op.[No_of_Operational_PCS], 0) AS NoOfOperationalPCs
FROM dbo.Maker_State_Presence mp
LEFT JOIN dbo.OperationalPC op
    ON mp.State = op.State
GROUP BY mp.State, op.[No_of_Operational_PCS];

---------------------------------------------------- dim state ---------------------------------------

IF OBJECT_ID('dbo.StateEVCount','U') IS NOT NULL DROP TABLE dbo.StateEVCount;
CREATE TABLE dbo.StateEVCount (
    State NVARCHAR(255),
    [Year] INT,
    EstimatedEVCount BIGINT
);

INSERT INTO dbo.StateEVCount (State, [Year], EstimatedEVCount)
SELECT
    mp.State,
    ms.[Year],
    SUM( CASE WHEN ms_cnt.cnt_states = 0 THEN 0 ELSE CAST(ROUND(CAST(ms.Sales AS FLOAT)/ms_cnt.cnt_states,0) AS BIGINT) END ) AS EstimatedEVCount
FROM dbo.Fact_MakerSales ms
JOIN (
    SELECT Maker, COUNT(*) AS cnt_states
    FROM dbo.Maker_State_Presence
    GROUP BY Maker
) ms_cnt ON ms_cnt.Maker = ms.Maker
JOIN dbo.Maker_State_Presence mp ON mp.Maker = ms.Maker
GROUP BY mp.State, ms.[Year];

---------------------------------------------------- State ev count ---------------------------------------

IF OBJECT_ID('dbo.StateEVCount','U') IS NOT NULL DROP TABLE dbo.StateEVCount;
CREATE TABLE dbo.StateEVCount (
    State NVARCHAR(255),
    [Year] INT,
    EstimatedEVCount BIGINT
);

INSERT INTO dbo.StateEVCount (State, [Year], EstimatedEVCount)
SELECT
    mp.State,
    ms.[Year],
    SUM( CASE WHEN ms_cnt.cnt_states = 0 THEN 0 ELSE CAST(ROUND(CAST(ms.Sales AS FLOAT)/ms_cnt.cnt_states,0) AS BIGINT) END ) AS EstimatedEVCount
FROM dbo.Fact_MakerSales ms
JOIN (
    SELECT Maker, COUNT(*) AS cnt_states
    FROM dbo.Maker_State_Presence
    GROUP BY Maker
) ms_cnt ON ms_cnt.Maker = ms.Maker
JOIN dbo.Maker_State_Presence mp ON mp.Maker = ms.Maker
GROUP BY mp.State, ms.[Year];

SELECT* FROM StateEVCount


----------------------------------------------------------------------------------------------------------------------
----------------------------------------------- DATA CHECKS ----------------------------------------------------------
----------------------------------------------- Fact category --------------------------------------------------------
SELECT* FROM Fact_Category
---------------------------------------------- Checking for duplicates -----------------------------------------------

SELECT [Date],[Year],RawCategory,Registrations,CategoryGroup,COUNT(*) AS duplicate_count
FROM Fact_Category
GROUP BY [Date],[Year],RawCategory,Registrations,CategoryGroup
HAVING COUNT(*) > 1
------no duplicate records

---------------------------------------------- Checking for missing values -------------------------------------------

SELECT
    SUM(CASE WHEN [Date] IS NULL THEN 1 ELSE 0 END) AS Missing_date,
    SUM(CASE WHEN [Year] IS NULL THEN 1 ELSE 0 END) AS Missing_year,
    SUM(CASE WHEN RawCategory IS NULL THEN 1 ELSE 0 END) AS Missing_rawcategory,
    SUM(CASE WHEN Registrations IS NULL THEN 1 ELSE 0 END) AS Missing_registrations,
    SUM(CASE WHEN CategoryGroup IS NULL THEN 1 ELSE 0 END) AS Missing_categorygroup
FROM Fact_Category
-------no missing values

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH AS MaxLength,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'Fact_Category';

SELECT DISTINCT CategoryGroup
FROM Fact_Category

----------------------------------------------- Fact makersales --------------------------------------------------------
SELECT* FROM Fact_MakerSales
---------------------------------------------- Checking for duplicates -----------------------------------------------

SELECT [MakerSalesID],[Maker],RawCategory,[Year],Sales,CategoryGroup,COUNT(*) AS duplicate_count
FROM Fact_MakerSales
GROUP BY [MakerSalesID],[Maker],RawCategory,[Year],Sales,CategoryGroup
HAVING COUNT(*) > 1
------no duplicate records

---------------------------------------------- Checking for missing values -------------------------------------------

SELECT
    SUM(CASE WHEN [Date] IS NULL THEN 1 ELSE 0 END) AS Missing_date,
    SUM(CASE WHEN [Year] IS NULL THEN 1 ELSE 0 END) AS Missing_year,
    SUM(CASE WHEN RawCategory IS NULL THEN 1 ELSE 0 END) AS Missing_rawcategory,
    SUM(CASE WHEN Registrations IS NULL THEN 1 ELSE 0 END) AS Missing_registrations,
    SUM(CASE WHEN CategoryGroup IS NULL THEN 1 ELSE 0 END) AS Missing_categorygroup
FROM Fact_Category
-------no missing values
SELECT DISTINCT [Year]
FROM Fact_MakerSales

----------------------------------------------- Category map --------------------------------------------------------
SELECT* FROM CategoryMap

----------------------------------------------- dim maker location --------------------------------------------------
SELECT* FROM Dim_MakerLocation
---------------------------------------------- Checking for duplicates -----------------------------------------------

SELECT [Maker],place,[State],COUNT(*) AS duplicate_count
FROM Dim_MakerLocation
GROUP BY [Maker],place,[State]
HAVING COUNT(*) > 1
------no duplicate records

---------------------------------------------- Checking for missing values -------------------------------------------

SELECT
    SUM(CASE WHEN Maker IS NULL THEN 1 ELSE 0 END) AS Missing_maker,
    SUM(CASE WHEN [Place] IS NULL THEN 1 ELSE 0 END) AS Missing_place,
    SUM(CASE WHEN [State] IS NULL THEN 1 ELSE 0 END) AS Missing_state
FROM Dim_MakerLocation
-------no missing values
SELECT DISTINCT [State]
FROM Dim_MakerLocation

----------------------------------------------- dim state --------------------------------------------------
SELECT* FROM Dim_State

SELECT AVG(NoOfOperationalPCs)
FROM Dim_State

----------------------------------------------- maker state presence --------------------------------------------------
SELECT* FROM Maker_State_Presence
SELECT DISTINCT Maker
FROM Maker_State_Presence

----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------         EDA         --------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
SELECT* FROM Fact_MakerSales

-- 3.1 Total sales (all years)

SELECT SUM(Sales) AS TotalSales FROM dbo.Fact_MakerSales;

-- 3.2 Top 20 makers by cumulative sales

SELECT TOP 20 Maker, SUM(Sales) AS TotalSales
FROM dbo.Fact_MakerSales
GROUP BY Maker
ORDER BY TotalSales DESC;

-- 3.3 Sales by raw category (cumulative)

SELECT COALESCE(RawCategory,'<NULL>') AS RawCategory, SUM(Sales) AS TotalSales
FROM dbo.Fact_MakerSales
GROUP BY COALESCE(RawCategory,'<NULL>')
ORDER BY TotalSales DESC;

-- 3.4 Yearly total sales (trend)

SELECT Year, SUM(Sales) AS TotalSales
FROM dbo.Fact_MakerSales
GROUP BY Year
ORDER BY Year;


SELECT* FROM Fact_Category
SELECT* FROM Fact_MakerSales
SELECT* FROM CategoryMap
SELECT* FROM Dim_MakerLocation
SELECT* FROM Maker_State_Presence
SELECT* FROM Dim_State

----- best maker per year-----

;WITH maker_year AS (
    SELECT 
        Year,
        Maker,
        SUM(Sales) AS TotalSales,
        ROW_NUMBER() OVER(PARTITION BY Year ORDER BY SUM(Sales) DESC) AS rn
    FROM dbo.Fact_MakerSales
    GROUP BY Year, Maker
)
SELECT 
    Year,
    Maker AS BestMaker,
    TotalSales AS SalesByBestMaker
FROM maker_year
WHERE rn = 1
ORDER BY Year;



-- For each maker, how sales split across categories (top categories first)
SELECT Maker, RawCategory, SUM(Sales) AS Sales
FROM dbo.Fact_MakerSales
GROUP BY Maker, RawCategory
ORDER BY Maker, SUM(Sales) DESC;

-- Percent split per maker (maker-level share)
;WITH s AS (
  SELECT Maker, RawCategory, SUM(Sales) AS Sales
  FROM dbo.Fact_MakerSales
  GROUP BY Maker, RawCategory
), m AS (
  SELECT Maker, SUM(Sales) AS MakerTotal
  FROM s GROUP BY Maker
)
SELECT s.Maker, s.RawCategory, s.Sales,
       ROUND( (CAST(s.Sales AS DECIMAL(18,2)) / NULLIF(m.MakerTotal,0)) * 100 , 2) AS pct_of_maker
FROM s
JOIN m ON s.Maker = m.Maker
ORDER BY s.Maker, pct_of_maker DESC;

-- 6.3 Yearly registrations (sum across categories)
SELECT Year, SUM(Registrations) AS TotalRegistrations
FROM dbo.Fact_Category
GROUP BY Year
ORDER BY Year;

-- 6.4 Registrations by RawCategory (cumulative)
SELECT RawCategory, SUM(Registrations) AS Registrations,
      ROUND((SUM(Registrations)*100.0)/(SELECT SUM(Registrations) FROM Fact_Category),2) AS perc
FROM dbo.Fact_Category
GROUP BY RawCategory
ORDER BY Registrations DESC;

-- 8.2 Makers per state (top states)
SELECT TOP 30 State, COUNT(*) AS MakerCount
FROM dbo.Dim_MakerLocation
GROUP BY State
ORDER BY MakerCount DESC;

-- 8.3 Top places (cities) by number of makers
SELECT TOP 30 Place, COUNT(*) AS MakerCount
FROM dbo.Dim_MakerLocation
GROUP BY Place
ORDER BY MakerCount DESC;

-- 10.1 State-level sales 
SELECT
  dl.State,
  ms.Year,
  SUM(ms.Sales) AS SalesByState
FROM dbo.Fact_MakerSales ms
JOIN dbo.Dim_MakerLocation dl
  ON UPPER(LTRIM(RTRIM(ms.Maker))) = UPPER(LTRIM(RTRIM(dl.Maker)))
GROUP BY dl.State, ms.Year
ORDER BY dl.State, ms.Year;

SELECT 
    ml.State,
    ms.Year,
    SUM(ms.Sales) AS TotalSales
FROM Fact_MakerSales ms
LEFT JOIN Dim_MakerLocation ml
    ON UPPER(LTRIM(RTRIM(ms.Maker))) = UPPER(LTRIM(RTRIM(ml.Maker)))
GROUP BY ml.State, ms.Year
ORDER BY ml.State, ms.Year;

-------Year-over-Year Growth %-----
WITH yearly AS (
    SELECT Year, SUM(Registrations) AS TotalRegs
    FROM Fact_Category
    WHERE Year >= 2015
    GROUP BY Year
)
SELECT Year,
       TotalRegs,
       LAG(TotalRegs) OVER (ORDER BY Year) AS PrevYear,
       ROUND(
           100.0 * (TotalRegs - LAG(TotalRegs) OVER (ORDER BY Year)) /
           NULLIF(LAG(TotalRegs) OVER (ORDER BY Year), 0),
       2) AS YoY_Growth
FROM yearly
ORDER BY Year;

------Dominant RawCategory Per Year-----
WITH cat AS (
    SELECT Year, RawCategory, SUM(Registrations) AS TotalRegs
    FROM Fact_Category
    WHERE Year >= 2015
    GROUP BY Year, RawCategory
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Year ORDER BY TotalRegs DESC) AS rn
    FROM cat
)
SELECT Year, RawCategory AS DominantCategory, TotalRegs
FROM ranked
WHERE rn = 1
ORDER BY Year;


WITH total AS (
    SELECT SUM(Sales) AS TotalSales
    FROM Fact_MakerSales
),
maker_sales AS (
    SELECT Maker, SUM(Sales) AS TotalSales
    FROM Fact_MakerSales
    GROUP BY Maker
)
SELECT TOP 10 ms.Maker, ms.TotalSales,
       ROUND(100.0 * ms.TotalSales / t.TotalSales, 2) AS MarketShare
FROM maker_sales ms CROSS JOIN total t
ORDER BY ms.TotalSales DESC;