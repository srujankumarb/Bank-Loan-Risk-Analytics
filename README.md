# Bank-Loan-Risk-Analytics
# Bank Loan Risk Analytics Dashboard

## Overview
A 2-page advanced banking analytics dashboard built using SQL Server 
and Power BI, analyzing 100,000+ loan applications and 320,000+ 
payment records across 4 relational tables to assess credit risk, 
default rates, and loan portfolio performance.

## Key Insights
- 13.9% overall default rate ("Bad Loan" rate)
- Default rate increases sharply from 8% (Grade A) to 52% (Grade G)
- Poor FICO band (below 580) shows ~14x higher default rate than 
  Exceptional band
- Business loans carry highest risk across all grades

## Tools Used
SQL Server (SSMS) | Power BI | DAX | Data Modelling

## Advanced Techniques
- Star schema data model with Date Table
- Window functions: RANK(), LAG(), running totals
- CTEs for multi-step risk classification
- Stored procedure for reusable monthly reporting
- Time intelligence DAX: MTD, YTD, MOM %
- Drillthrough pages, bookmarks, conditional formatting
- Dynamic dashboard titles using DAX

## Dataset
4 relational tables: Loans, Customers, Risk, Payments (~520K rows total)

![summary Dashboard](summary%20dashboard.png)
![Details Dashboard](details%20dashboard.png)
