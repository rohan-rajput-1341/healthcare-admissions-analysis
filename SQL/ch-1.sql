/* =====================================================================
   HEALTHCARE ADMISSIONS - BILLING ANALYSIS (PostgreSQL)
   Table : healthcare  (54,860 rows; duplicates and negative bills already removed)
   Focus : billing by medical condition, admission type and insurance provider
   Data runs 2019-05-08 to 2024-05-07, so 2019 and 2024 are partial years.
   ===================================================================== */


/* ---------- OVERVIEW ---------- */

-- Q1. Overall KPIs: size of the business and typical admission
SELECT
    COUNT(*)                       AS total_admissions,
    ROUND(SUM(billing_amount), 2)  AS total_billing,
    ROUND(AVG(billing_amount), 2)  AS avg_bill,
    ROUND(AVG(length_of_stay), 1)  AS avg_stay_days
FROM healthcare;


/* ---------- BILLING BY MEDICAL CONDITION ---------- */

-- Q2. Which conditions bring in the most money, and which cost the most per admission?
SELECT
    medical_condition,
    COUNT(*)                       AS admissions,
    ROUND(SUM(billing_amount), 2)  AS total_billing,
    ROUND(AVG(billing_amount), 2)  AS avg_bill,
    MAX(billing_amount)            AS max_bill
FROM healthcare
GROUP BY medical_condition
ORDER BY total_billing DESC;

-- Q3. What share of total revenue does each condition contribute?
SELECT
    medical_condition,
    ROUND(SUM(billing_amount), 2) AS total_billing,
    ROUND(100.0 * SUM(billing_amount) / SUM(SUM(billing_amount)) OVER (), 2) AS pct_of_revenue
FROM healthcare
GROUP BY medical_condition
ORDER BY pct_of_revenue DESC;

-- Q4. Which conditions are the most expensive per day of hospital stay?
SELECT
    medical_condition,
    ROUND(AVG(billing_amount), 2)                        AS avg_bill,
    ROUND(AVG(length_of_stay), 1)                        AS avg_stay_days,
    ROUND(SUM(billing_amount) / SUM(length_of_stay), 2)  AS billing_per_day
FROM healthcare
GROUP BY medical_condition
ORDER BY billing_per_day DESC;


/* ---------- BILLING BY ADMISSION TYPE ---------- */

-- Q5. Billing summary by admission type
SELECT
    admission_type,
    COUNT(*)                       AS admissions,
    ROUND(SUM(billing_amount), 2)  AS total_billing,
    ROUND(AVG(billing_amount), 2)  AS avg_bill
FROM healthcare
GROUP BY admission_type
ORDER BY total_billing DESC;

-- Q6. Does any admission type earn more (or less) than its share of patients?
SELECT
    admission_type,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                        AS pct_of_admissions,
    ROUND(100.0 * SUM(billing_amount) / SUM(SUM(billing_amount)) OVER (), 2)  AS pct_of_revenue
FROM healthcare
GROUP BY admission_type
ORDER BY pct_of_revenue DESC;

-- Q7. Do emergency, urgent and elective patients stay longer or cost more per day?
SELECT
    admission_type,
    ROUND(AVG(length_of_stay), 1)                        AS avg_stay_days,
    ROUND(SUM(billing_amount) / SUM(length_of_stay), 2)  AS billing_per_day
FROM healthcare
GROUP BY admission_type
ORDER BY billing_per_day DESC;


/* ---------- BILLING BY INSURANCE PROVIDER ---------- */

-- Q8. Billing summary by insurance provider
SELECT
    insurance_provider,
    COUNT(*)                       AS admissions,
    ROUND(SUM(billing_amount), 2)  AS total_billing,
    ROUND(AVG(billing_amount), 2)  AS avg_bill
FROM healthcare
GROUP BY insurance_provider
ORDER BY total_billing DESC;

-- Q9. Insurer ranking by revenue share, and how much revenue the top insurers cover together
SELECT
    insurance_provider,
    ROUND(100.0 * SUM(billing_amount) / SUM(SUM(billing_amount)) OVER (), 2) AS pct_of_revenue,
    ROUND(100.0 * SUM(SUM(billing_amount)) OVER (ORDER BY SUM(billing_amount) DESC)
          / SUM(SUM(billing_amount)) OVER (), 2)                             AS cumulative_pct
FROM healthcare
GROUP BY insurance_provider
ORDER BY pct_of_revenue DESC;


/* ---------- CROSS-ANALYSIS ---------- */

-- Q10. Average bill: medical condition x admission type
SELECT
    medical_condition,
    ROUND(AVG(billing_amount) FILTER (WHERE admission_type = 'Elective'),  2) AS elective,
    ROUND(AVG(billing_amount) FILTER (WHERE admission_type = 'Emergency'), 2) AS emergency,
    ROUND(AVG(billing_amount) FILTER (WHERE admission_type = 'Urgent'),    2) AS urgent
FROM healthcare
GROUP BY medical_condition
ORDER BY medical_condition;

-- Q11. Total billing: medical condition x insurance provider
SELECT
    medical_condition,
    ROUND(SUM(billing_amount) FILTER (WHERE insurance_provider = 'Aetna'),            0) AS aetna,
    ROUND(SUM(billing_amount) FILTER (WHERE insurance_provider = 'Blue Cross'),       0) AS blue_cross,
    ROUND(SUM(billing_amount) FILTER (WHERE insurance_provider = 'Cigna'),            0) AS cigna,
    ROUND(SUM(billing_amount) FILTER (WHERE insurance_provider = 'Medicare'),         0) AS medicare,
    ROUND(SUM(billing_amount) FILTER (WHERE insurance_provider = 'UnitedHealthcare'), 0) AS unitedhealthcare
FROM healthcare
GROUP BY medical_condition
ORDER BY medical_condition;

-- Q12. Average bill: insurance provider x admission type
SELECT
    insurance_provider,
    ROUND(AVG(billing_amount) FILTER (WHERE admission_type = 'Elective'),  2) AS elective,
    ROUND(AVG(billing_amount) FILTER (WHERE admission_type = 'Emergency'), 2) AS emergency,
    ROUND(AVG(billing_amount) FILTER (WHERE admission_type = 'Urgent'),    2) AS urgent
FROM healthcare
GROUP BY insurance_provider
ORDER BY insurance_provider;

-- Q13. For each insurer, which condition generates the most billing?
WITH ranked AS (
    SELECT
        insurance_provider,
        medical_condition,
        SUM(billing_amount) AS total_billing,
        ROW_NUMBER() OVER (PARTITION BY insurance_provider ORDER BY SUM(billing_amount) DESC) AS rn
    FROM healthcare
    GROUP BY insurance_provider, medical_condition
)
SELECT insurance_provider, medical_condition, ROUND(total_billing, 2) AS total_billing
FROM ranked
WHERE rn = 1
ORDER BY total_billing DESC;

-- Q14. Top 10 condition + admission type + insurer combinations by total billing
SELECT
    medical_condition,
    admission_type,
    insurance_provider,
    COUNT(*)                       AS admissions,
    ROUND(SUM(billing_amount), 2)  AS total_billing
FROM healthcare
GROUP BY medical_condition, admission_type, insurance_provider
ORDER BY total_billing DESC
LIMIT 10;

-- Q15. Which condition/insurer pairs cost MORE than that insurer's own average bill?
WITH insurer_avg AS (
    SELECT insurance_provider, AVG(billing_amount) AS insurer_avg_bill
    FROM healthcare
    GROUP BY insurance_provider
)
SELECT
    h.insurance_provider,
    h.medical_condition,
    ROUND(AVG(h.billing_amount), 2)                           AS avg_bill,
    ROUND(i.insurer_avg_bill, 2)                              AS insurer_avg_bill,
    ROUND(AVG(h.billing_amount) - i.insurer_avg_bill, 2)      AS diff_vs_insurer_avg
FROM healthcare h
JOIN insurer_avg i ON i.insurance_provider = h.insurance_provider
GROUP BY h.insurance_provider, h.medical_condition, i.insurer_avg_bill
HAVING AVG(h.billing_amount) > i.insurer_avg_bill
ORDER BY diff_vs_insurer_avg DESC;


/* ---------- TRENDS OVER TIME ---------- */

-- Q16. Yearly billing and year-over-year change (compare full years 2020-2023 only)
WITH yearly AS (
    SELECT admission_year, SUM(billing_amount) AS total_billing
    FROM healthcare
    GROUP BY admission_year
)
SELECT
    admission_year,
    ROUND(total_billing, 2)                                              AS total_billing,
    ROUND(100.0 * (total_billing - LAG(total_billing) OVER (ORDER BY admission_year))
          / LAG(total_billing) OVER (ORDER BY admission_year), 1)        AS yoy_change_pct
FROM yearly
ORDER BY admission_year;

-- Q17. Monthly billing with a 3-month moving average (feeds the dashboard line chart)
WITH monthly AS (
    SELECT admission_month, SUM(billing_amount) AS total_billing
    FROM healthcare
    GROUP BY admission_month
)
SELECT
    admission_month,
    ROUND(total_billing, 2) AS total_billing,
    ROUND(AVG(total_billing) OVER (ORDER BY admission_month
                                   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM monthly
ORDER BY admission_month;


/* ---------- DRILL-DOWNS ---------- */

-- Q18. How are bills spread across price bands, by admission type?
SELECT
    CASE
        WHEN billing_amount < 10000 THEN '1. Under 10k'
        WHEN billing_amount < 25000 THEN '2. 10k - 25k'
        WHEN billing_amount < 40000 THEN '3. 25k - 40k'
        ELSE                             '4. 40k and above'
    END AS bill_band,
    COUNT(*) FILTER (WHERE admission_type = 'Elective')  AS elective,
    COUNT(*) FILTER (WHERE admission_type = 'Emergency') AS emergency,
    COUNT(*) FILTER (WHERE admission_type = 'Urgent')    AS urgent
FROM healthcare
GROUP BY bill_band
ORDER BY bill_band;

-- Q19. Which age group has the highest average bill, for each condition?
SELECT
    medical_condition,
    ROUND(AVG(billing_amount) FILTER (WHERE age <  36),             2) AS under_36,
    ROUND(AVG(billing_amount) FILTER (WHERE age BETWEEN 36 AND 50), 2) AS age_36_50,
    ROUND(AVG(billing_amount) FILTER (WHERE age BETWEEN 51 AND 65), 2) AS age_51_65,
    ROUND(AVG(billing_amount) FILTER (WHERE age >  65),             2) AS over_65
FROM healthcare
GROUP BY medical_condition
ORDER BY medical_condition;

-- Q20. Which conditions have the biggest share of high-cost admissions (bill of 40k or more)?
SELECT
    medical_condition,
    COUNT(*) FILTER (WHERE billing_amount >= 40000)                          AS high_cost_admissions,
    ROUND(100.0 * COUNT(*) FILTER (WHERE billing_amount >= 40000) / COUNT(*), 2) AS pct_high_cost
FROM healthcare
GROUP BY medical_condition
ORDER BY pct_high_cost DESC;