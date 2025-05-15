-- List all base tables in the database
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

-- View all sales order headers
SELECT *
FROM Sales.SalesOrderHeader;

-- Total Online Orders vs Total Transactions
SELECT COUNT(*) AS OnlineOrders
FROM Sales.SalesOrderHeader
WHERE OnlineOrderFlag = 1;

SELECT COUNT(*) AS TotalTransactions
FROM Sales.SalesOrderHeader;

-- Monthly & Yearly Sales Trend
SELECT 
    CAST(OrderDate AS DATE) AS OrderDate,
    YEAR(OrderDate) AS Year,
    MONTH(OrderDate) AS Month,
    SUM(TotalDue) AS TotalSales
FROM Sales.SalesOrderHeader
GROUP BY OrderDate, YEAR(OrderDate), MONTH(OrderDate)
ORDER BY Year, Month;

-- Top 10 Best-Selling Products by Revenue
SELECT TOP 10
    P.Name AS ProductName,
    SUM(SOD.OrderQty) AS TotalQuantitySold,
    SUM(SOD.LineTotal) AS TotalRevenue
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P ON SOD.ProductID = P.ProductID
GROUP BY P.Name
ORDER BY TotalRevenue DESC;

-- Regional Sales Breakdown
SELECT 
    ST.Name AS Region,
    SUM(SOH.TotalDue) AS TotalSales
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesTerritory ST ON SOH.TerritoryID = ST.TerritoryID
GROUP BY ST.Name
ORDER BY TotalSales DESC;

-- Customer RFM (Recency, Frequency, Monetary) Summary
WITH RFM AS (
    SELECT 
        C.CustomerID,
        MAX(SOH.OrderDate) AS LastPurchaseDate,
        COUNT(SOH.SalesOrderID) AS Frequency,
        SUM(SOH.TotalDue) AS MonetaryValue
    FROM Sales.Customer C
    JOIN Sales.SalesOrderHeader SOH ON C.CustomerID = SOH.CustomerID
    GROUP BY C.CustomerID
)
SELECT 
    CustomerID,
    DATEDIFF(DAY, LastPurchaseDate, GETDATE()) AS Recency,
    Frequency,
    MonetaryValue
FROM RFM
ORDER BY MonetaryValue DESC;

-- Year-over-Year (YoY) Sales Growth
WITH SalesYearly AS (
    SELECT 
        YEAR(OrderDate) AS SalesYear, 
        SUM(TotalDue) AS TotalSales
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate)
)
SELECT 
    SalesYear,
    TotalSales,
    LAG(TotalSales) OVER (ORDER BY SalesYear) AS PreviousYearSales,
    ROUND(((TotalSales - LAG(TotalSales) OVER (ORDER BY SalesYear)) / 
            LAG(TotalSales) OVER (ORDER BY SalesYear)) * 100, 2) AS YoYGrowth
FROM SalesYearly;

-- RFM Segmentation using NTILE
WITH RFM AS (
    SELECT 
        C.CustomerID,
        MAX(SOH.OrderDate) AS LastPurchaseDate,
        COUNT(SOH.SalesOrderID) AS Frequency,
        SUM(SOH.TotalDue) AS MonetaryValue
    FROM Sales.Customer C
    JOIN Sales.SalesOrderHeader SOH ON C.CustomerID = SOH.CustomerID
    GROUP BY C.CustomerID
)
SELECT 
    CustomerID,
    DATEDIFF(DAY, LastPurchaseDate, GETDATE()) AS Recency,
    Frequency,
    MonetaryValue,
    NTILE(4) OVER (ORDER BY DATEDIFF(DAY, LastPurchaseDate, GETDATE()) DESC) AS RecencySegment,
    NTILE(4) OVER (ORDER BY Frequency DESC) AS FrequencySegment,
    NTILE(4) OVER (ORDER BY MonetaryValue DESC) AS MonetarySegment
FROM RFM
ORDER BY MonetaryValue DESC;

-- Monthly Moving Average of Sales
WITH MonthlySales AS (
    SELECT 
        YEAR(OrderDate) AS Year, 
        MONTH(OrderDate) AS Month, 
        SUM(TotalDue) AS TotalSales
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT 
    Year, 
    Month, 
    TotalSales,
    AVG(TotalSales) OVER (ORDER BY Year, Month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAverage
FROM MonthlySales;

-- Churn Analysis (Active vs Churned Customers)
WITH LastPurchase AS (
    SELECT 
        C.CustomerID, 
        MAX(SOH.OrderDate) AS LastPurchaseDate
    FROM Sales.Customer C
    JOIN Sales.SalesOrderHeader SOH ON C.CustomerID = SOH.CustomerID
    GROUP BY C.CustomerID
)
SELECT 
    CustomerID,
    LastPurchaseDate,
    DATEDIFF(DAY, LastPurchaseDate, GETDATE()) AS DaysSinceLastPurchase,
    CASE 
        WHEN DATEDIFF(DAY, LastPurchaseDate, GETDATE()) > 180 THEN 'Churned'
        ELSE 'Active'
    END AS CustomerStatus
FROM LastPurchase
ORDER BY DaysSinceLastPurchase DESC;

-- Salesperson Performance & Ranking
SELECT 
    SP.BusinessEntityID AS SalesPersonID,
    P.FirstName + ' ' + P.LastName AS SalesPersonName,
    SUM(SOH.TotalDue) AS TotalSales,
    RANK() OVER (ORDER BY SUM(SOH.TotalDue) DESC) AS SalesRank
FROM Sales.SalesPerson SP
JOIN HumanResources.Employee E ON SP.BusinessEntityID = E.BusinessEntityID
JOIN Person.Person P ON E.BusinessEntityID = P.BusinessEntityID
JOIN Sales.SalesOrderHeader SOH ON SP.BusinessEntityID = SOH.SalesPersonID
GROUP BY SP.BusinessEntityID, P.FirstName, P.LastName
ORDER BY TotalSales DESC;

-- Product Profitability & Margin
SELECT 
    P.Name AS ProductName,
    SUM(SOD.OrderQty) AS TotalSold,
    SUM(SOD.LineTotal) AS Revenue,
    SUM(SOD.LineTotal - (SOD.OrderQty * P.StandardCost)) AS Profit,
    ROUND(SUM(SOD.LineTotal - (SOD.OrderQty * P.StandardCost)) / SUM(SOD.LineTotal) * 100, 2) AS ProfitMargin
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P ON SOD.ProductID = P.ProductID
GROUP BY P.Name
ORDER BY ProfitMargin DESC;

-- Revenue by Product Category
SELECT 
    PC.Name AS Category, 
    SUM(SOD.LineTotal) AS TotalRevenue
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P ON SOD.ProductID = P.ProductID
JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
JOIN Production.ProductCategory PC ON PSC.ProductCategoryID = PC.ProductCategoryID
GROUP BY PC.Name
ORDER BY TotalRevenue DESC;