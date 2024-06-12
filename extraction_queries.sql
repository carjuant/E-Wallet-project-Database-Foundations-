/* Extraction Queries */

--show description,amount and date of transactions made by a specific user

SELECT description, amount, date
FROM transactions
WHERE fk_user_origin = :user_phone_number;
/* :user_phone_number the : is used for reuse querys and to prevent injection attacks */

--show the description, amount and origin user of the previous day's transactions

SELECT t.description, t.amount, u.names AS user_origin
FROM transactions t
JOIN users u ON t.fk_user_origin = u.phone_number
WHERE t.date >= CURRENT_DATE - INTERVAL '1 day'
AND t.date < CURRENT_DATE;

-- show the sum of all money spent by a user in a specific time (such as holy week) through banking transactions and service payments

--Taking Holy Week As

WITH SemanaSanta AS (
    SELECT '2024-04-01'::date AS start_date, '2024-04-07'::date AS end_date
)
SELECT u.phone_number, u.names, u.lastNames,
       COALESCE(SUM(ub.amount), 0) + COALESCE(SUM(ps.amount), 0) AS total_spent
FROM users u
JOIN user_bank_rel ub ON ub.fk_user = u.phone_number
JOIN payment_service ps ON ps.fk_user = u.phone_number
JOIN SemanaSanta ss ON (ub.date BETWEEN ss.start_date AND ss.end_date
                        OR ps.date BETWEEN ss.start_date AND ss.end_date)
--WHERE u.phone_number = 1234567890
GROUP BY u.phone_number, u.names, u.lastNames;


--show the sum of money received from "bancolombia" bank accounts and from "Correspondent Banking" account types and the accounts with the dates, to know when the nekiwi was recharged

SELECT
    ub.date,
    ba.account_number,
    ba.headline,
    SUM(ub.amount) AS total_received
FROM
    user_bank_rel ub
JOIN
    bank_account ba ON ub.fk_bank_account = ba.id_bank_account
JOIN
    type_account ta ON ba.fk_type_account = ta.id_type_account
WHERE
    ba.bank_name = 'Bancolombia'
    AND ta.type_account = 'corresponsales'
GROUP BY
    ub.date, ba.account_number, ba.headline
ORDER BY
    ub.date;

--show the date, amount, account number, headline and description of all transactions to the same bank account   
   
SELECT
    ub.date,
    ub.amount,
    ub.description,
    ba.account_number,
    ba.headline
FROM
    user_bank_rel ub
JOIN
    bank_account ba ON ub.fk_bank_account = ba.id_bank_account
WHERE
    ub.fk_bank_account = 1
ORDER BY
    ub.date;

--show transactions made for the "Current Account" account type that are in "pending approval" status since the beginning of the month

SELECT
    ub.date,
    ub.amount,
    ub.description
FROM
    user_bank_rel ub
JOIN
    bank_account ba ON ub.fk_bank_account = ba.id_bank_account
JOIN
    type_account ta ON ba.fk_type_account = ta.id_type_account
JOIN
    state s ON ub.fk_state = s.id_state
WHERE
    ta.type_account = 'Current Account'
    AND s.state = 'pending approval'
    AND ub.date >= DATE_TRUNC('month', CURRENT_DATE)
ORDER BY
    ub.date;

--show bank account, headlines and all money (sum) sent to bank accounts
   
SELECT
    ba.account_number,
    ba.headline,
    SUM(ub.amount) AS total_sent
FROM
    user_bank_rel ub
JOIN
    bank_account ba ON ub.fk_bank_account = ba.id_bank_account
GROUP BY
    ba.account_number, ba.headline
ORDER BY
    total_sent DESC;

--show the name of the service and the amount of money paid in services (service payment amount)

SELECT
    s.name_service,
    SUM(ps.amount) AS total_paid_in_services
FROM
    payment_service ps
JOIN
    service s ON ps.fk_service = s.id_service
GROUP BY
    s.name_service
ORDER BY
    total_paid_in_services DESC;

   
--show the date, amount and service name of payments made in the previous month
   
SELECT
    ps.date,
    ps.amount,
    s.name_service
FROM
    payment_service ps
JOIN
    service s ON ps.fk_service = s.id_service
WHERE
    ps.date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month'
    AND ps.date < DATE_TRUNC('month', CURRENT_DATE)
ORDER BY
    ps.date;


   
--show how much (sum) money was pay (paid services) to the 'EAAB' service   

SELECT
    s.name_service,
    SUM(ps.amount) AS total_paid
FROM
    payment_service ps
JOIN
    service s ON ps.fk_service = s.id_service
WHERE
    s.name_service = 'EAAB'
GROUP BY
    s.name_service;
