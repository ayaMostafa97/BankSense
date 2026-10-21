CREATE DATABASE BankSense_DB;
GO
USE BankSense_DB;

-- create customers
CREATE TABLE customers (
    id INT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    phone VARCHAR(50) NULL,
    created_at DATETIME2 NOT NULL
)

-- Table: transaction_types
CREATE TABLE transaction_types (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    average_amount DECIMAL(18,2) NOT NULL
)

-- Table: transactions

CREATE TABLE transactions (
    id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    amount DECIMAL(18,2) NULL,
    transaction_type VARCHAR(50) NOT NULL,
    transaction_date DATETIME2 NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
)

-- Table: bill_payments
CREATE TABLE bill_payments (
    id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    amount DECIMAL(18,2) NULL,
    bill_type VARCHAR(50) NOT NULL,
    payment_date DATETIME2 NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
)
-- Table: investments
CREATE TABLE investments (
    id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    amount DECIMAL(18,2) NULL,
    investment_type VARCHAR(50) NOT NULL,
    investment_date DATETIME2 NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
)

-- Table: customer_support
CREATE TABLE customer_support (
    id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    issue_type VARCHAR(100) NOT NULL,
    resolution_status VARCHAR(50) NOT NULL,
    interaction_date DATETIME2 NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
)

-- Database Validation: Check Created Tables

SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME

-- Database Validation: Check Primary and Foreign Keys
SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE CONSTRAINT_TYPE IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY TABLE_NAME, CONSTRAINT_TYPE;

-- Validation: Check Customer Tables
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%customer%'
ORDER BY TABLE_NAME;
-- Validation: Check Transaction Types Data
SELECT COUNT(*) AS transaction_type_count
FROM dbo.transaction_types;

-- Validation: Check Transactions Data

SELECT COUNT(*) AS transaction_count
FROM dbo.transactions;

-- Validation: Customer ID Relationships
SELECT COUNT(*) AS invalid_customer_ids
FROM dbo.transactions t
LEFT JOIN dbo.customers c
    ON t.customer_id = c.id
WHERE c.id IS NULL;

-- Validation: Check Bill Payments Data
SELECT COUNT(*) AS bill_payment_count
FROM dbo.bill_payments;

-- Validation: investments Row Count

SELECT COUNT(*) AS investment_count
FROM dbo.investments;


-- Validation: Customer ID Relationships
SELECT COUNT(*) AS invalid_customer_ids
FROM dbo.investments i
LEFT JOIN dbo.customers c
    ON i.customer_id = c.id
WHERE c.id IS NULL;

-- Validation: customer_support Row Count
SELECT COUNT(*) AS support_interaction_count
FROM dbo.customer_support;

-- Validation: Customer ID Relationships

SELECT COUNT(*) AS invalid_customer_ids
FROM dbo.customer_support cs
LEFT JOIN dbo.customers c
    ON cs.customer_id = c.id
WHERE c.id IS NULL;

-- Final Validation: All BankSense Tables
-- =========================================================

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM dbo.customers

UNION ALL

SELECT 'transaction_types', COUNT(*)
FROM dbo.transaction_types

UNION ALL

SELECT 'transactions', COUNT(*)
FROM dbo.transactions

UNION ALL

SELECT 'bill_payments', COUNT(*)
FROM dbo.bill_payments

UNION ALL

SELECT 'investments', COUNT(*)
FROM dbo.investments

UNION ALL

SELECT 'customer_support', COUNT(*)
FROM dbo.customer_support;

-- Business Query 1: Top 5 Customers by Deposit Value
-- Business Question:
-- Which customers have the highest total deposited amount?

SELECT TOP 5
    c.id AS customer_id,
    c.full_name,
    c.email,
    SUM(t.amount) AS total_deposited_amount,
    COUNT(t.id) AS deposit_count
FROM dbo.customers c
JOIN dbo.transactions t
    ON c.id = t.customer_id
WHERE t.transaction_type = 'deposit'
  AND t.amount IS NOT NULL
GROUP BY
    c.id,
    c.full_name,
    c.email
ORDER BY total_deposited_amount DESC;


-- Business Query 2: Monthly Deposit vs Withdrawal Flow
-- Business Question:
-- How do monthly deposits and withdrawals affect net liquidity?
-- =========================================================

SELECT
    FORMAT(t.transaction_date, 'yyyy-MM') AS year_month,

    SUM(
        CASE
            WHEN t.transaction_type = 'deposit'
            THEN t.amount
            ELSE 0
        END
    ) AS total_deposits,

    SUM(
        CASE
            WHEN t.transaction_type = 'withdrawal'
            THEN t.amount
            ELSE 0
        END
    ) AS total_withdrawals,

    SUM(
        CASE
            WHEN t.transaction_type = 'deposit'
            THEN t.amount
            ELSE 0
        END
    )
    -
    SUM(
        CASE
            WHEN t.transaction_type = 'withdrawal'
            THEN t.amount
            ELSE 0
        END
    ) AS net_liquidity_flow

FROM dbo.transactions t
WHERE t.amount IS NOT NULL

GROUP BY FORMAT(t.transaction_date, 'yyyy-MM')

ORDER BY year_month;

-- Business Query 3: Bill Payment Analysis
-- Business Question:
-- Which bill categories generate the highest payment value?
-- =========================================================

SELECT
    bp.bill_type,
    COUNT(DISTINCT bp.customer_id) AS unique_customers_paying,
    COUNT(bp.id) AS total_payments_count,
    SUM(bp.amount) AS total_paid_amount,
    AVG(bp.amount) AS avg_payment_amount
FROM dbo.bill_payments bp
WHERE bp.amount IS NOT NULL
GROUP BY bp.bill_type
ORDER BY total_paid_amount DESC;


-- =========================================================
-- Business Query 4: Customer Support Performance
-- Business Question:
-- Which support issues are most common and how effectively
-- are they being resolved?
-- =========================================================

SELECT
    cs.issue_type,
    COUNT(cs.id) AS total_tickets,

    SUM(
        CASE
            WHEN cs.resolution_status = 'resolved'
            THEN 1
            ELSE 0
        END
    ) AS resolved_tickets,

    SUM(
        CASE
            WHEN cs.resolution_status = 'pending'
            THEN 1
            ELSE 0
        END
    ) AS pending_tickets,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN cs.resolution_status = 'resolved'
                THEN 1
                ELSE 0
            END
        ) / COUNT(cs.id),
        2
    ) AS resolution_rate_percentage

FROM dbo.customer_support cs

GROUP BY cs.issue_type

ORDER BY resolution_rate_percentage ASC;

-- =========================================================
-- Business Query 5: Customer Financial Activity
-- Business Question:
-- Which customers have the highest combined deposit
-- and investment activity?
-- =========================================================

WITH transaction_summary AS (
    SELECT
        customer_id,
        SUM(CASE
                WHEN transaction_type = 'deposit' THEN amount
                ELSE 0
            END) AS total_deposits,
        SUM(CASE
                WHEN transaction_type = 'withdrawal' THEN amount
                ELSE 0
            END) AS total_withdrawals
    FROM dbo.transactions
    WHERE amount IS NOT NULL
    GROUP BY customer_id
),
investment_summary AS (
    SELECT
        customer_id,
        SUM(amount) AS total_investments
    FROM dbo.investments
    WHERE amount IS NOT NULL
    GROUP BY customer_id
)
SELECT TOP 10
    c.id AS customer_id,
    c.full_name,
    COALESCE(ts.total_deposits, 0) AS total_deposits,
    COALESCE(ts.total_withdrawals, 0) AS total_withdrawals,
    COALESCE(inv.total_investments, 0) AS total_investments,
    COALESCE(ts.total_deposits, 0)
        + COALESCE(inv.total_investments, 0) AS combined_financial_activity
FROM dbo.customers c
LEFT JOIN transaction_summary ts
    ON c.id = ts.customer_id
LEFT JOIN investment_summary inv
    ON c.id = inv.customer_id
ORDER BY combined_financial_activity DESC;

