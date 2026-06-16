CREATE DATABASE BankLoan_RiskAnalytics;

USE BankLoan_RiskAnalytics;

SELECT * FROM customers;
SELECT * FROM loans;
SELECT * FROM payments;
SELECT * FROM risk;


--Joining Loans and customers

SELECT TOP 50
    l.Loan_ID,l.Loan_Amount,l.Interest_Rate,l.Risk_Grade,l.Loan_Status,l.Loan_Category,
    c.Gender,c.Age,c.City,c.Annual_Income,c.Occupation
FROM loans l
INNER JOIN customers c
    ON l.Customer_ID = c.Customer_ID;

--KPI Summary
SELECT
    COUNT(DISTINCT l.Loan_ID) AS Total_Loans,
    ROUND(SUM(l.Loan_Amount), 2) AS Total_Loan_Amount,
    ROUND(AVG(l.Interest_Rate), 2) AS Avg_Interest_Rate,
    ROUND(AVG(r.DTI_Ratio), 2) AS Avg_DTI_Ratio,
    ROUND(AVG(CAST(r.FICO_Score AS FLOAT)),0) AS Avg_FICO_Score,
    SUM(CASE WHEN l.Loan_Category = 'Bad Loan'
        THEN 1 ELSE 0 END) AS Total_Bad_Loans,
    ROUND(SUM(CASE WHEN l.Loan_Category = 'Bad Loan'
        THEN 1 ELSE 0 END) * 100.0 /
        COUNT(*), 2) AS Bad_Loan_Rate_Pct,
    ROUND(SUM(p.Paid_Amount), 2) AS Total_Payments_Received
FROM loans l
INNER JOIN customers c  ON l.Customer_ID = c.Customer_ID
INNER JOIN risk r       ON l.Loan_ID     = r.Loan_ID
LEFT  JOIN payments p   ON l.Loan_ID     = p.Loan_ID;

--Good loan vs Bad loan Analysis
SELECT
    l.Loan_Category,
    COUNT(*) AS Total_Loans,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER(), 2) AS Percentage,
    ROUND(AVG(l.Loan_Amount), 2) AS Avg_Loan_Amount,
    ROUND(AVG(l.Interest_Rate), 2) AS Avg_Interest_Rate,
    ROUND(AVG(r.FICO_Score), 0) AS Avg_FICO_Score,
    ROUND(AVG(r.DTI_Ratio), 2) AS Avg_DTI_Ratio
FROM loans l
INNER JOIN risk r ON l.Loan_ID = r.Loan_ID
GROUP BY l.Loan_Category;

--Ranks loans by Amount per City

WITH Ranked AS (
SELECT  c.City,
        l.Loan_ID,
        l.Loan_Amount,
        l.Interest_Rate,
        l.Loan_Category,
    RANK() OVER (PARTITION BY c.City ORDER BY l.Loan_Amount DESC) AS Rank_In_City,
    ROUND(AVG(l.Loan_Amount) OVER (PARTITION BY c.City), 2) AS City_Avg_Loan
FROM loans l
INNER JOIN customers c ON l.Customer_ID = c.Customer_ID
)
SELECT * FROM Ranked
WHERE Rank_In_City = 1
ORDER BY Loan_Amount DESC;

--Monthly Trend
WITH Monthly AS (
    SELECT
        Issue_Year,
        Issue_Month,
        Month_Name,
        COUNT(*) AS Total_Loans,
        ROUND(SUM(Loan_Amount), 2) AS Total_Amount,
        SUM(CASE WHEN Loan_Category = 'Bad Loan'
            THEN 1 ELSE 0 END) AS Bad_Loans
    FROM loans
    GROUP BY Issue_Year, Issue_Month, Month_Name
)
SELECT
    Issue_Year,
    Month_Name,
    Total_Loans,
    Total_Amount,
    Bad_Loans,
    LAG(Total_Loans) OVER (ORDER BY Issue_Year, Issue_Month) AS Prev_Month_Loans,
    Total_Loans - LAG(Total_Loans) OVER (ORDER BY Issue_Year, Issue_Month) AS MOM_Change,
    ROUND((Total_Loans - LAG(Total_Loans) OVER (ORDER BY Issue_Year, Issue_Month)) * 100.0 /
        NULLIF(LAG(Total_Loans) OVER (ORDER BY Issue_Year, Issue_Month), 0), 2) AS MOM_Change_Pct
FROM Monthly
ORDER BY Issue_Year, Issue_Month;


--Running Total of Loan Amount
SELECT
    Issue_Year,
    Month_Name,
    Issue_Month,
    ROUND(SUM(Loan_Amount), 2) AS Monthly_Amount,
    ROUND(SUM(SUM(Loan_Amount)) OVER (PARTITION BY Issue_Year ORDER BY Issue_Month
    ROWS UNBOUNDED PRECEDING), 2) AS Running_Total_YTD
FROM loans
GROUP BY Issue_Year, Issue_Month, Month_Name
ORDER BY Issue_Year, Issue_Month;


--Risk Grade Performance Analysis
WITH Grade_Base AS (
    SELECT
        l.Risk_Grade,
        l.Loan_Purpose,
        COUNT(*) AS Total_Loans,
        ROUND(AVG(l.Loan_Amount), 2) AS Avg_Loan_Amt,
        ROUND(AVG(l.Interest_Rate), 2) AS Avg_Rate,
        ROUND(AVG(r.FICO_Score), 0) AS Avg_FICO,
        ROUND(AVG(r.DTI_Ratio), 2) AS Avg_DTI,
        SUM(CASE WHEN l.Loan_Category = 'Bad Loan'
            THEN 1 ELSE 0 END) AS Defaults
    FROM loans l
    INNER JOIN risk r ON l.Loan_ID = r.Loan_ID
    GROUP BY l.Risk_Grade, l.Loan_Purpose
),
Grade_Risk AS (
    SELECT *,
        ROUND(Defaults * 100.0 /
            NULLIF(Total_Loans, 0), 2) AS Default_Rate_Pct,
        CASE
            WHEN Defaults * 100.0 /
                NULLIF(Total_Loans,0) > 20  THEN 'High Risk'
            WHEN Defaults * 100.0 /
                NULLIF(Total_Loans,0) > 10  THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS Risk_Band
    FROM Grade_Base
)
SELECT *
FROM Grade_Risk
ORDER BY Default_Rate_Pct DESC;


--Payment Behavior Analysis
SELECT
    l.Loan_Purpose,
    l.Risk_Grade,
    COUNT(DISTINCT l.Loan_ID) AS Total_Loans,
    COUNT(p.Payment_ID) AS Total_Payments,
    SUM(CASE WHEN p.Payment_Status = 'On Time'
        THEN 1 ELSE 0 END) AS On_Time_Payments,
    SUM(CASE WHEN p.Payment_Status = 'Late'
        THEN 1 ELSE 0 END) AS Late_Payments,
    ROUND(SUM(p.Paid_Amount), 2) AS Total_Paid,
    ROUND(AVG(p.Outstanding_Bal), 2) AS Avg_Outstanding_Bal
FROM loans l
LEFT JOIN payments p ON l.Loan_ID = p.Loan_ID
GROUP BY l.Loan_Purpose, l.Risk_Grade
ORDER BY l.Risk_Grade, l.Loan_Purpose;


--Stored Procedure for Monthly Report
CREATE PROCEDURE GetMonthlyLoanReport
    @Year  INT,
    @Month INT
AS
BEGIN
    SELECT
        l.Loan_Purpose,
        COUNT(*)                            AS Total_Loans,
        ROUND(SUM(l.Loan_Amount), 2)        AS Total_Amount,
        ROUND(AVG(l.Interest_Rate), 2)      AS Avg_Rate,
        SUM(CASE WHEN l.Loan_Category = 'Bad Loan'
            THEN 1 ELSE 0 END)             AS Bad_Loans,
        ROUND(AVG(r.FICO_Score), 0)         AS Avg_FICO
    FROM loans l
    INNER JOIN risk r ON l.Loan_ID = r.Loan_ID
    WHERE l.Issue_Year  = @Year
      AND l.Issue_Month = @Month
    GROUP BY l.Loan_Purpose
    ORDER BY Total_Amount DESC;
END;

-- Run it like this for any month:
EXEC GetMonthlyLoanReport @Year = 2023, @Month = 6;



--Final View for Dashboard
IF OBJECT_ID('vw_banking_master', 'V') IS NOT NULL
    DROP VIEW vw_banking_master;
GO

CREATE VIEW vw_banking_master AS
SELECT
    l.Loan_ID,
    l.Customer_ID,
    l.Contract_Type,
    l.Loan_Purpose,
    l.Loan_Amount,
    l.Funded_Amount,
    l.Interest_Rate,
    l.Loan_Term_Months,
    l.Issue_Date,
    l.Issue_Month,
    l.Issue_Year,
    l.Month_Name,
    l.Risk_Grade,
    l.Risk_Label,
    l.Loan_Status,
    l.Loan_Category,
    l.Credit_Policy,
    c.Gender,
    c.Age,
    CASE
        WHEN c.Age BETWEEN 21 AND 30 THEN '21-30'
        WHEN c.Age BETWEEN 31 AND 40 THEN '31-40'
        WHEN c.Age BETWEEN 41 AND 50 THEN '41-50'
        ELSE '51+'
    END AS Age_Group,
    c.City,
    c.Education,
    c.Family_Status,
    c.Occupation,
    c.Income_Type,
    c.Annual_Income,
    c.Own_Car,
    c.Own_Realty,
    r.FICO_Score,
    r.FICO_Band,
    r.DTI_Ratio,
    r.Delinquencies_2Yrs,
    r.Inquiries_6Months,
    r.Revolving_Util_Pct,
    r.Credit_Years,
    r.Risk_Level
FROM loans l
INNER JOIN customers c  ON l.Customer_ID = c.Customer_ID
INNER JOIN risk r       ON l.Loan_ID     = r.Loan_ID;
GO

SELECT TOP 10 * FROM vw_banking_master;