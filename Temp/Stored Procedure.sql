ALTER PROCEDURE GetCustomerDetail_TotalSales @Country NVARCHAR(50) = 'USA'
AS
BEGIN

DECLARE @TotalCustomers INT, @AvgScore FLOAT;

-- Prepare and Cleanup Data
IF EXISTS (SELECT 1 FROM Sales.Customers WHERE Score IS NULL AND Country = @Country)
	BEGIN
		PRINT ('Updating NULL Scores to 0');
		UPDATE Sales.Customers
		SET Score = 0
		WHERE Score IS NULL AND Country = @Country
	END

ELSE
	BEGIN
		PRINT ('No NULL Scores found')
	END;

-- Generating reports
SELECT
	o.OrderID,
	o.OrderDate,
	p.Product,
	p.Category,
	COALESCE (c.FirstName, '') + ' ' + COALESCE (c.LastName, '') AS CustomerName,
	c.Country,
	COALESCE (e.FirstName, '') + ' ' + COALESCE (e.LastName, '') AS SalesPerson,
	e.Department,
	o.Sales,
	o.Quantity
FROM Sales.Orders o
LEFT JOIN Sales.Products p
	ON o.ProductID = p.ProductID
LEFT JOIN Sales.Customers c
	ON o.CustomerID = c.CustomerID
LEFT JOIN Sales.Employees e
	ON o.SalesPersonID = e.EmployeeID
WHERE c.Country = @Country;

-- Finds the total sales per Customers
WITH CTE_total_sales AS
(
SELECT 
CustomerID,
	SUM (Sales) AS Total_sales
	FROM Sales.Orders
Group by CustomerID
)
-- Finds the last order date for each customer
, CTE_last_order_date AS
(
SELECT 
	CustomerID,
	MAX (OrderDate) AS Last_order
	FROM Sales.Orders
GROUP BY CustomerID
)
-- Ranks Customers based on total sales per customers
, CTE_rank_customes AS
(
SELECT
	CustomerID,
	Total_sales,
	RANK() OVER (ORDER BY Total_sales DESC) Rank_customers
FROM CTE_total_sales
)
-- Segments customers based on their total sales
, CTE_segment_customers AS
(
SELECT
	CustomerID,
	Total_sales,
	CASE 
		 WHEN Total_sales > 100 THEN 'HIGH'
		 WHEN Total_sales > 80  THEN 'MEDIUM'
		 ELSE 'LOW'
	END Segment_customers
FROM CTE_total_sales
)
-- Main Query
SELECT 
	c.CustomerID,
	c.FirstName,
	c.LastName,
	cts.Total_sales,
	clo.Last_order,
	crc.Rank_customers,
	csc.Segment_customers
FROM Sales.Customers c
LEFT JOIN CTE_total_sales cts
	ON c.CustomerID = cts.CustomerID
LEFT JOIN CTE_last_order_date clo
	ON c.CustomerID = clo.CustomerID
LEFT JOIN CTE_rank_customes crc
	ON c.CustomerID = crc.CustomerID
LEFT JOIN CTE_segment_customers csc
	ON c.CustomerID = csc.CustomerID;

SELECT 
	@TotalCustomers = COUNT(*),
	@AvgScore = AVG(Score)
FROM Sales.Customers
WHERE Country = @Country;

PRINT 'Total Customers from ' + @Country + ':' + CAST(@TotalCustomers AS NVARCHAR);
PRINT 'Average Score from ' + @Country + ':' + CAST(@AvgScore AS NVARCHAR);

END
