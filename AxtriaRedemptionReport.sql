USE Enbrel_GEOlevelreport
GO

/*
To align redemption
1)	get NPI number from tbldoctors using the DoctorID from tblclaims. 
2)	Get NPI number from tblFullFeedImportAllApprovedClaims_fullhistory
3)	Use NPI number to get customer ID
4)	If NPI number is not available, use the physician name/address information from tblFullFeedImportAllApprovedClaims_fullhistory first, then from tbldoctors.
5)	Use first name, last name, zip code to get customer ID
6)	Use customer to terr align first
7)	If not aligned, use zip to terr

To align activation
1)	Use physician information from 1st claim (follow the process above)
2)	If not aligned, use the primary physician information in tblpatientphysician (follow the process above)
3)	If not aligned, use patient¡¯s zip code (zip to terr)

Rawdata:
Enbrel_Production.DBO.tblClaims
Enbrel_Production.DBO.tblProgram
Enbrel_Production.DBO.tblPatientInfo
Enbrel_Production.DBO.tblPharmacies
Enbrel_Production.DBO.tblDoctors
Enbrel_Production.DBO.tblPatientPhysician
Enbrel_Production.dbo.tblTreatmentList
Enbrel_Production.DBO.tblAccountHistory
Enbrel_Production.DBO.tblDebitAmgenEdgeCardInfo
Enbrel_Production.DBO.tblDebitKaiserCardInfo
Enbrel_Production.DBO.tblDebitDiscoveryCardInfo
Enbrel_Production.DBO.tblDebitChargeCardInfo
Enbrel_Production.DBO.tblcardInfoDebitOther
Enbrel_Production.DBO.tblCardInfoCRX
Enbrel_Production.DBO.tblCardInfo
Axtria_dev.DBO.inPhysicianFaxRaw	--inPhysicianFaxRaw_20180402
Axtria_dev.DBO.tblFullFeedImportAllApprovedClaims_fullhistory
Axtria_dev.DBO.tblImportCustNomProf
Axtria_dev.DBO.tblImportCustTerr
Axtria_dev.DBO.tblImportGeoTerr
Axtria_dev.DBO.tblImportTerrHierarchy
Axtria_dev.DBO.tblImportTarget
Axtria_dev.DBO.tblImportAmaPDRP
Axtria_dev.DBO.tblImportRepTerr
Axtria_dev.DBO.tblImportRepTerr_Test	--internal test
Axtria_dev.DBO.inINBURoster		--inINBURoster_20180612

Output:
select * from tblGeo
select * from tblDateConfig

--Territory
select * from OutputDashboardData
select * from OutputPhysicianData_Final

--District
select * from OutputDashboardData1
select * from OutputDashboardData2
select * from OutputPhysicianData_Final_Dist

--Region
select * from OutputDashboardData1_Reg
select * from OutputDashboardData2_Reg
select * from OutputTerritoryDetails
select * from OutputPhysicianData_Final_Reg
select * from OutputIndication_Reg

--Nation
select * from OutputDashboardData1_Nat
select * from OutputDashboardData2_Nat
select * from OutputDistrictDetails
select * from OutputSFDetails
select * from OutputIndication_Nat

--Unknown
select * from OutputDashboardData_Unk
select * from OutputPhysicianData_Unk

--For WebTeam
SELECT * FROM Axtria_dev.DBO.V_RepRoster
SELECT * FROM Axtria_dev.DBO.V_DateConfig

*/

if object_id('tblCalendar') is not null
	drop table tblCalendar

create table tblCalendar (
Date_ID int,
Date_Name date,
Week_ID int,
Week_Start date,
Week_End date,
Month_ID int,
Month_Start date,
Month_End date,
Year_ID int,
Year_Start date,
Year_End date
)

SET DATEFIRST 6

declare @i int = 1,@date date
while @i<= 731
begin
	set @date = cast(DATEADD(day,-(DATEPART(weekday,getdate())),getdate())+1 - @i as date)
	insert into tblCalendar (Date_ID,Date_Name,Week_Start,Week_End,Month_Start,Month_End,Year_Start,Year_End)
	select @i,@date,DATEADD(day,-(DATEPART(weekday,@date)-1),@date)
			,DATEADD(day,-(DATEPART(weekday,@date)-7),@date)
			,dateadd(dd,-day(@date)+1,@date)
			,dateadd(ms,-3,DATEADD(mm, DATEDIFF(m,0,@date)+1, 0))
			,cast(cast(datepart(yy,@date) as varchar)+'0101' as date)
			,cast(cast(datepart(yy,@date) as varchar)+'1231' as date)
	set @i += 1
end

SET DATEFIRST 7

update a
set Week_ID = b.ID
from tblCalendar a,(
select distinct dense_rank() over(order by Week_Start desc) as ID,Week_Start
from tblCalendar
) b
where a.Week_Start = b.Week_Start

update a
set Month_ID = b.ID
from tblCalendar a,(
select distinct dense_rank() over(order by Month_Start desc) as ID,Month_Start
from tblCalendar
) b
where a.Month_Start = b.Month_Start

if (select Week_End from tblCalendar where Date_Id = 1) <> (select Month_End from tblCalendar where Date_Id = 1)
begin
update tblCalendar
set Month_ID = Month_ID - 1
end

update a
set Year_ID = b.ID
from tblCalendar a,(
select distinct dense_rank() over(order by Year_Start desc) as ID,Year_Start
from tblCalendar
) b
where a.Year_Start = b.Year_Start

delete from tblCalendar
where Year_ID > 2 and Week_ID > 52

--select * from tblCalendar
go

if object_id('tblDateConfig') is not null
	drop table tblDateConfig

create table tblDateConfig (
id int identity(1,1),
ItemType varchar(50),
ItemIdx int,
Item varchar(50),
Start_Date date,
End_Date date,
)

insert into tblDateConfig
select 'Period',1,'CYTD',(select min(Date_Name) from tblCalendar where Year_ID = 1),(select Date_Name from tblCalendar where Date_ID = 1)
union all
select 'Period',2,'PYTD',(select min(Date_Name) from tblCalendar where Year_ID = 2),(select dateadd(year,-1,Date_Name) from tblCalendar where Date_ID = 1)
union all
select 'Period',3,'C13W',(select min(Date_Name) from tblCalendar where Week_ID = 13),(select max(Date_Name) from tblCalendar where Week_ID = 1)
union all
select 'Period',4,'P13W',(select min(Date_Name) from tblCalendar where Week_ID = 26),(select max(Date_Name) from tblCalendar where Week_ID = 14)
union all
select 'Period',5,'CW',(select min(Date_Name) from tblCalendar where Week_ID = 1),(select max(Date_Name) from tblCalendar where Week_ID = 1)
union all
select 'Period',6,'PW',(select min(Date_Name) from tblCalendar where Week_ID = 2),(select max(Date_Name) from tblCalendar where Week_ID = 2)
union all
select 'Period',NULL,'C52W',(select min(Date_Name) from tblCalendar where Week_ID = 52),(select max(Date_Name) from tblCalendar where Week_ID = 1)
--union all
--select 'Period',NULL,'P52W',(select min(Date_Name) from tblCalendar where Week_ID = 104),(select max(Date_Name) from tblCalendar where Week_ID = 53)
union all
select 'Period',NULL,'C26W',(select min(Date_Name) from tblCalendar where Week_ID = 26),(select max(Date_Name) from tblCalendar where Week_ID = 1)
union all
select 'Period',NULL,'P26W',(select min(Date_Name) from tblCalendar where Week_ID = 52),(select max(Date_Name) from tblCalendar where Week_ID = 27)

--current year
declare @Year varchar(4) 
set @Year = (select distinct cast(datepart(yy,Date_Name) as varchar) from tblCalendar where Month_ID = 1)
insert into tblDateConfig
select 'Monthly',24,'Dec-'+right(@Year,2),dateadd(M,11,cast(@Year+'0101' as date)),dateadd(M,11,cast(@Year+'0131' as date))
union all
select 'Monthly',23,'Nov-'+right(@Year,2),dateadd(M,10,cast(@Year+'0101' as date)),dateadd(M,10,cast(@Year+'0131' as date))
union all
select 'Monthly',22,'Oct-'+right(@Year,2),dateadd(M,9,cast(@Year+'0101' as date)),dateadd(M,9,cast(@Year+'0131' as date))
union all
select 'Monthly',21,'Sep-'+right(@Year,2),dateadd(M,8,cast(@Year+'0101' as date)),dateadd(M,8,cast(@Year+'0131' as date))
union all
select 'Monthly',20,'Aug-'+right(@Year,2),dateadd(M,7,cast(@Year+'0101' as date)),dateadd(M,7,cast(@Year+'0131' as date))
union all
select 'Monthly',19,'Jul-'+right(@Year,2),dateadd(M,6,cast(@Year+'0101' as date)),dateadd(M,6,cast(@Year+'0131' as date))
union all
select 'Monthly',18,'Jun-'+right(@Year,2),dateadd(M,5,cast(@Year+'0101' as date)),dateadd(M,5,cast(@Year+'0131' as date))
union all
select 'Monthly',17,'May-'+right(@Year,2),dateadd(M,4,cast(@Year+'0101' as date)),dateadd(M,4,cast(@Year+'0131' as date))
union all
select 'Monthly',16,'Apr-'+right(@Year,2),dateadd(M,3,cast(@Year+'0101' as date)),dateadd(M,3,cast(@Year+'0131' as date))
union all
select 'Monthly',15,'Mar-'+right(@Year,2),dateadd(M,2,cast(@Year+'0101' as date)),dateadd(M,2,cast(@Year+'0131' as date))
union all
select 'Monthly',14,'Feb-'+right(@Year,2),dateadd(M,1,cast(@Year+'0101' as date)),dateadd(M,1,cast(@Year+'0131' as date))
union all
select 'Monthly',13,'Jan-'+right(@Year,2),cast(@Year+'0101' as date),cast(@Year+'0131' as date)

------last year
declare @lYear varchar(4) 
set @lYear = (select distinct cast(datepart(yy,Date_Name) as varchar) from tblCalendar where Month_ID = 1) -1
insert into tblDateConfig
select 'Monthly',12,'Dec-'+right(@lYear,2),dateadd(M,11,cast(@lYear+'0101' as date)),dateadd(M,11,cast(@lYear+'0131' as date))
union all
select 'Monthly',11,'Nov-'+right(@lYear,2),dateadd(M,10,cast(@lYear+'0101' as date)),dateadd(M,10,cast(@lYear+'0131' as date))
union all
select 'Monthly',10,'Oct-'+right(@lYear,2),dateadd(M,9,cast(@lYear+'0101' as date)),dateadd(M,9,cast(@lYear+'0131' as date))
union all
select 'Monthly',9,'Sep-'+right(@lYear,2),dateadd(M,8,cast(@lYear+'0101' as date)),dateadd(M,8,cast(@lYear+'0131' as date))
union all
select 'Monthly',8,'Aug-'+right(@lYear,2),dateadd(M,7,cast(@lYear+'0101' as date)),dateadd(M,7,cast(@lYear+'0131' as date))
union all
select 'Monthly',7,'Jul-'+right(@lYear,2),dateadd(M,6,cast(@lYear+'0101' as date)),dateadd(M,6,cast(@lYear+'0131' as date))
union all
select 'Monthly',6,'Jun-'+right(@lYear,2),dateadd(M,5,cast(@lYear+'0101' as date)),dateadd(M,5,cast(@lYear+'0131' as date))
union all
select 'Monthly',5,'May-'+right(@lYear,2),dateadd(M,4,cast(@lYear+'0101' as date)),dateadd(M,4,cast(@lYear+'0131' as date))
union all
select 'Monthly',4,'Apr-'+right(@lYear,2),dateadd(M,3,cast(@lYear+'0101' as date)),dateadd(M,3,cast(@lYear+'0131' as date))
union all
select 'Monthly',3,'Mar-'+right(@lYear,2),dateadd(M,2,cast(@lYear+'0101' as date)),dateadd(M,2,cast(@lYear+'0131' as date))
union all
select 'Monthly',2,'Feb-'+right(@lYear,2),dateadd(M,1,cast(@lYear+'0101' as date)),dateadd(M,1,cast(@lYear+'0131' as date))
union all
select 'Monthly',1,'Jan-'+right(@lYear,2),cast(@lYear+'0101' as date),cast(@lYear+'0131' as date)

--lastest 2 years
declare @CY varchar(4) 
set @CY = (select distinct cast(datepart(yy,Date_Name) as varchar) from tblCalendar where Year_ID = 1)
insert into tblDateConfig
select 'Yearly',2,@CY,cast(@CY+'0101' as date),cast(@CY+'1231' as date)
union all
select 'Yearly',1,@CY-1,dateadd(YEAR,-1,cast(@CY+'0101' as date)),dateadd(YEAR,-1,cast(@CY+'1231' as date))

--select * from tblDateConfig
go


print'Transactions Start'
print getdate()
go
/*
SELECT a.*, b.*
  FROM [Enbrel_Production].[dbo].[tblClaims] a join [TeradataHistory_DoNotDelete].[dbo].[tblFullFeedImportAllApprovedClaims_fullhistory] b
  on a.TeradataClaimReferenceNumber = b.ClaimReferenceNumber 
  where status = 'approved' and TeradataClaimReferenceNumber is not null and BenefitYear >= 2017
*/

IF OBJECT_ID('tblTransactions') IS NOT NULL
DROP TABLE DBO.tblTransactions
GO
SELECT C.tblClaimID, C.PatientID, 
--ISNULL(C.DoctorID,'9999999') AS DoctorID, 
C.DoctorID, 
C.PharmacyID, C.CardID,
CONVERT(DATE, C.DatePrescriptionFilled) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID,
C.ApprovedAmount AS CopayAmount, T.ProgramType, T.VendorCode,
--CONVERT(VARCHAR(100), D.FirstName + ' ' + D.LastName) AS PhysicianName, RTRIM(REPLACE(D.FirstName,'\','')) AS FirstName, D.LastName, 
CONVERT(VARCHAR(100), D.PhysicianFullNameOrLastname) AS PhysicianName, 
D.PhysicianFirstname AS FirstName, REPLACE(D.PhysicianFullNameOrLastname,D.PhysicianFirstname+' ','') AS LastName,
CONVERT(VARCHAR(8),NULL) Target,
--ISNULL(CASE WHEN LTRIM(D.PhysicianNPI) = '' THEN NULL ELSE LTRIM(D.PhysicianNPI) END,LTRIM(C.TeradataPrescriberNPI)) AS NPI, 
ISNULL(PrescriberIDNPI,LTRIM(C.TeradataPrescriberNPI)) AS NPI, 
CONVERT(VARCHAR(10),NULL) CustomerID,
D.PhysicianAddress1 AS Address1, D.PhysicianCity AS City, D.PhysicianState AS State, D.PhysicianZipCode AS Zip,
P.Zip AS PatientZip, 
--H.Zip AS PharmacyZip, 
H.Name AS PharmacyName,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
INTO DBO.tblTransactions
FROM Enbrel_Production.DBO.tblClaims C
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.DatePrescriptionFilled) = V.Date_Name
INNER JOIN (
	SELECT DISTINCT ProgramID, CASE CardType WHEN 'MPRS' THEN 'Retail' WHEN 'VCARD' THEN 'Virtual' ELSE CardType END AS ProgramType,
	CASE IsOpusProgram WHEN 'Y' THEN 'OPU' ELSE 'CRX' END AS VendorCode
	FROM Enbrel_Production.DBO.tblProgram
) T ON C.PatientProgramType = T.ProgramID
--LEFT JOIN Enbrel_Production.DBO.tblDoctors D ON C.DoctorID = D.tblDoctorsID
LEFT JOIN Axtria_dev.DBO.tblFullFeedImportAllApprovedClaims_fullhistory D ON C.tblClaimID = D.tblClaimID
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
LEFT JOIN Enbrel_Production.DBO.tblPharmacies H ON C.PharmacyID = H.tblPharmaciesID
WHERE Status = 'Approved' AND ApprovedAmount > 0
AND ProgramType <> 'Virtual'
GO

/*
SELECT tblClaimID,COUNT(*) FROM DBO.tblTransactions
GROUP BY tblClaimID 
HAVING COUNT(*) >1
--NONE
*/

--Update PharmacyName
UPDATE DBO.tblTransactions
SET PharmacyName = RTRIM(LEFT(PharmacyName,LEN(PharmacyName)-5))
WHERE PharmacyName LIKE '% US'
GO

--Muti NPI Number
/*
SELECT DoctorID, COUNT(*) from (
SELECT DISTINCT DoctorID, NPI
FROM DBO.tblTransactions WHERE NPI IS NOT NULL
) A GROUP BY DoctorID 
HAVING COUNT(*) > 1
*/

--Use last process time NPI
UPDATE A
SET NPI = B.NPI
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT * FROM DBO.tblTransactions A
	WHERE EXISTS (
	SELECT * FROM (
	SELECT DoctorID, MAX(Date_Name) Date_Name
	FROM DBO.tblTransactions WHERE NPI IS NOT NULL
	AND DoctorID IN (SELECT DoctorID from (
					SELECT DISTINCT DoctorID, NPI
					FROM DBO.tblTransactions WHERE NPI IS NOT NULL
					) A GROUP BY DoctorID 
					HAVING COUNT(*) > 1)
	GROUP BY DoctorID
	) B WHERE A.DoctorID = B.DoctorID AND A.Date_Name = B.Date_Name) AND A.NPI IS NOT NULL
) B ON A.DoctorID = B.DoctorID
WHERE A.DoctorID IN (
	SELECT DoctorID from (
	SELECT DISTINCT DoctorID, NPI
	FROM DBO.tblTransactions WHERE NPI IS NOT NULL
	) A GROUP BY DoctorID 
	HAVING COUNT(*) > 1
)
GO

UPDATE A
SET NPI = B.NPI
FROM DBO.tblTransactions A
INNER JOIN DBO.tblTransactions B ON A.DoctorID = B.DoctorID AND B.NPI IS NOT NULL
WHERE A.NPI IS NULL
GO

/*
SELECT NPI,COUNT(DISTINCT DoctorID) FROM DBO.tblTransactions WHERE NPI IS NOT NULL AND PhysicianName IS NOT NULL
GROUP BY NPI HAVING COUNT(DISTINCT DoctorID) > 1
--NONE
*/
--Update NPI Info if tblClaimID is not in tblFullFeedImportAllApprovedClaims_fullhistory
--UPDATE A
--SET NPI = B.NPI
--FROM DBO.tblTransactions A
--INNER JOIN DBO.tblTransactions B
--ON A.DoctorID = B.DoctorID AND B.NPI IS NOT NULL AND B.PhysicianName IS NOT NULL
--WHERE A.NPI IS NULL
--AND NOT EXISTS (
--SELECT * FROM (
--SELECT DISTINCT DoctorID FROM DBO.tblTransactions WHERE NPI IS NOT NULL AND PhysicianName IS NOT NULL
--GROUP BY DoctorID HAVING COUNT(DISTINCT NPI) > 1
--) C WHERE A.DoctorID = C.DoctorID)
--GO

/*
SELECT tblDoctorsID,COUNT(DISTINCT PhysicianNPI)
FROM Enbrel_Production.DBO.tblDoctors WHERE PhysicianNPI IS NOT NULL AND PhysicianNPI <> ''
GROUP BY tblDoctorsID HAVING COUNT(DISTINCT PhysicianNPI) > 1
--NONE
*/
UPDATE A
SET NPI = RIGHT(B.PhysicianNPI,10)
FROM DBO.tblTransactions A
INNER JOIN Enbrel_Production.DBO.tblDoctors B ON A.DoctorID = B.tblDoctorsID
AND B.PhysicianNPI IS NOT NULL AND B.PhysicianNPI <> '' AND LEN(B.PhysicianNPI) > 9
WHERE A.NPI IS NULL
GO

--UPDATE A
--SET NPI = B.NPI
--FROM DBO.tblTransactions A
--INNER JOIN DBO.tblTransactions B
--ON A.DoctorID = B.DoctorID AND B.NPI IS NOT NULL
--WHERE A.NPI IS NULL
--AND NOT EXISTS (
--SELECT * FROM (
--SELECT DISTINCT DoctorID FROM DBO.tblTransactions WHERE NPI IS NOT NULL
--GROUP BY DoctorID HAVING COUNT(DISTINCT NPI) > 1
--) C WHERE A.DoctorID = C.DoctorID)
--GO

/*
SELECT COUNT(DISTINCT PhysicianID), PatientID 
FROM Enbrel_Production.DBO.tblPatientPhysician
WHERE IsActive = 'Y' AND IsPrimary = 'Y'
GROUP BY PatientID
HAVING COUNT(DISTINCT PhysicianID) > 1
--NONE
*/
UPDATE A
SET NPI = B.PhysicianNPI--, DoctorID = ISNULL(A.DoctorID,B.PhysicianID)
FROM DBO.tblTransactions A
INNER JOIN (
SELECT PatientID, PhysicianID, PhysicianNPI
FROM Enbrel_Production.DBO.tblPatientPhysician
WHERE IsActive = 'Y' AND IsPrimary = 'Y'
AND PhysicianNPI IS NOT NULL AND PhysicianNPI <> '' AND LEN(PhysicianNPI) > 9
) B
ON A.PatientID = B.PatientID AND A.DoctorID = B.PhysicianID
WHERE A.NPI IS NULL
GO

--UPDATE A
--SET DoctorID = B.PhysicianID
--FROM DBO.tblTransactions A
--INNER JOIN (
--SELECT PatientID, PhysicianID, PhysicianNPI
--FROM Enbrel_Production.DBO.tblPatientPhysician
--WHERE IsActive = 'Y' AND IsPrimary = 'Y'
--) B
--ON A.PatientID = B.PatientID
--WHERE A.DoctorID IS NULL
--GO

UPDATE DBO.tblTransactions
SET DoctorID = '9999999'
WHERE DoctorID IS NULL
GO

----Update Physician Info
UPDATE A
SET PhysicianName = B.PhysicianName,
FirstName = B.FirstName,
LastName = B.LastName,
Address1 = B.Address1,
City = B.City,
State = B.State,
Zip = B.Zip
FROM DBO.tblTransactions A
INNER JOIN DBO.tblTransactions B
ON A.NPI = B.NPI AND B.PhysicianName IS NOT NULL
WHERE A.PhysicianName IS NULL
GO

UPDATE A
SET PhysicianName = B.PhysicianName,
FirstName = SUBSTRING(B.PhysicianName,1,CHARINDEX(' ',B.PhysicianName)-1),
LastName = SUBSTRING(B.PhysicianName,CHARINDEX(' ',B.PhysicianName)+1,50),
Address1 = B.Address1,
City = B.City,
State = B.State,
Zip = B.Zip
FROM DBO.tblTransactions A
INNER JOIN (
SELECT NPI,				
UPPER(REPLACE(REPLACE(REPLACE(
REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
CASE WHEN ContactName LIKE '%,%' THEN SUBSTRING(ContactName,1,CHARINDEX(',',ContactName)-1) ELSE ContactName END
,'Dr. ',''),' Jr.',''),' Sr.',''),'Mr. ',''),'Ms. ',''),'Mrs. ',''),'Miss ','')
,' Physician Pc',''),'Md Pc',''),' Md Llc','')) AS PhysicianName,
UPPER(Addr1) AS Address1,UPPER(City) AS City, State, LEFT(Zip,5) AS Zip
FROM Axtria_dev.DBO.inPhysicianFaxRaw_20180402
) B ON A.NPI = B.NPI
WHERE A.NPI IS NOT NULL
GO

/*
SELECT COUNT(*) FROM DBO.tblTransactions WHERE NPI IS NOT NULL
SELECT COUNT(*) FROM DBO.tblTransactions WHERE NPI IS NULL
SELECT COUNT(*) FROM DBO.tblTransactions WHERE NPI IS NOT NULL AND PhysicianName IS NULL
SELECT COUNT(*) FROM DBO.tblTransactions WHERE NPI IS NOT NULL AND CustomerID IS NULL
*/
--Get Cusotmer Info
/*
SELECT NPI#,COUNT(DISTINCT CUSTOMER_NUMBER) FROM Axtria_dev.DBO.tblImportCustNomProf WHERE NPI# IS NOT NULL
GROUP BY NPI# HAVING COUNT(DISTINCT CUSTOMER_NUMBER) > 1
*/
UPDATE A
SET CustomerID = 'N_'+B.CUSTOMER_NUMBER, PhysicianName = B.PhysicianName, FirstName = B.FIRST_NAME, LastName = B.LAST_NAME, 
Address1 = B.ADDRESS_LINE1, City = B.CITY, State = B.STATE_OR_PROVINCE, Zip = B.POSTAL_CODE
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT DISTINCT REPLACE(LTRIM(RTRIM(NAME)),'  ','') AS PhysicianName, FIRST_NAME, LAST_NAME, CUSTOMER_NUMBER, NPI#, ADDRESS_LINE1, CITY, STATE_OR_PROVINCE, POSTAL_CODE
	FROM Axtria_dev.DBO.tblImportCustNomProf
	WHERE NPI# IS NOT NULL
) B ON A.NPI = B.NPI#
WHERE A.NPI IS NOT NULL
GO

/*
SELECT NPI, COUNT(DISTINCT PhysicianName) FROM DBO.tblTransactions WHERE NPI IS NOT NULL AND PhysicianName IS NOT NULL
GROUP BY NPI HAVING COUNT(DISTINCT PhysicianName) >1
*/
--UPDATE A
--SET PhysicianName = B.PhysicianName, FirstName = B.FirstName, LastName = B.LastName,
--Address1 = B.Address1, City = B.City, State = B.State, Zip = B.Zip
--FROM DBO.tblTransactions A
--INNER JOIN (
--SELECT DISTINCT NPI, PhysicianName, FirstName, LastName, Address1, City, State, Zip FROM DBO.tblTransactions 
--WHERE NPI IS NOT NULL AND PhysicianName IS NOT NULL) B ON A.NPI = B.NPI
--WHERE A.NPI IS NOT NULL AND A.PhysicianName IS NULL
--GO

UPDATE A
SET NPI = ISNULL(A.NPI,B.NPI#), CustomerID = 'N_'+B.CUSTOMER_NUMBER, PhysicianName = B.PhysicianName, FirstName = B.FIRST_NAME, LastName = B.LAST_NAME, 
Address1 = B.ADDRESS_LINE1, City = B.CITY, State = B.STATE_OR_PROVINCE, Zip = B.POSTAL_CODE
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT DISTINCT REPLACE(LTRIM(RTRIM(NAME)),'  ','') AS PhysicianName, FIRST_NAME, LAST_NAME, CUSTOMER_NUMBER, NPI#, ADDRESS_LINE1, CITY, STATE_OR_PROVINCE, POSTAL_CODE
	FROM Axtria_dev.DBO.tblImportCustNomProf
) B ON A.PhysicianName = B.PhysicianName AND A.Zip = B.POSTAL_CODE
WHERE A.CustomerID IS NULL
GO

UPDATE A
SET NPI = ISNULL(A.NPI,B.NPI#), CustomerID = 'N_'+B.CUSTOMER_NUMBER, PhysicianName = B.PhysicianName, FirstName = B.FIRST_NAME, LastName = B.LAST_NAME, 
Address1 = B.ADDRESS_LINE1, City = B.CITY, State = B.STATE_OR_PROVINCE, Zip = B.POSTAL_CODE
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT DISTINCT REPLACE(LTRIM(RTRIM(NAME)),'  ','') AS PhysicianName, FIRST_NAME, LAST_NAME, CUSTOMER_NUMBER, NPI#, ADDRESS_LINE1, CITY, STATE_OR_PROVINCE, POSTAL_CODE
	FROM Axtria_dev.DBO.tblImportCustNomProf
) B ON A.FirstName = B.FIRST_NAME AND A.LastName = B.LAST_NAME AND A.Zip = B.POSTAL_CODE
WHERE A.CustomerID IS NULL
GO

UPDATE A
SET NPI = B.NPI, CustomerID = B.CustomerID, PhysicianName = B.PhysicianName, FirstName = B.FirstName, LastName = B.LastName, 
Address1 = B.Address1, City = B.City, State = B.State, Zip = B.Zip
FROM DBO.tblTransactions A
INNER JOIN DBO.tblTransactions B ON A.DoctorID = B.DoctorID AND B.NPI IS NOT NULL
WHERE A.NPI IS NULL
GO

--UPDATE A
--SET CustomerID = 'N_'+B.CUSTOMER_NUMBER, PhysicianName = REPLACE(B.NAME,'  ',''), FirstName = B.FIRST_NAME, LastName = B.LAST_NAME, 
--Address1 = B.ADDRESS_LINE1, City = B.CITY, State = B.STATE_OR_PROVINCE, Zip = B.POSTAL_CODE
--FROM DBO.tblTransactions A
--INNER JOIN (
--	SELECT DISTINCT NAME, FIRST_NAME, LAST_NAME, CUSTOMER_NUMBER, NPI#, ADDRESS_LINE1, CITY, STATE_OR_PROVINCE, POSTAL_CODE
--	FROM Axtria_dev.DBO.tblImportCustNomProf
--) B ON REPLACE(A.FirstName,'-',' ') = REPLACE(B.FIRST_NAME,'-',' ') AND  AND A.Zip = B.POSTAL_CODE
--WHERE A.CustomerID IS NULL
--GO

/*
SELECT CustomerID, COUNT(DISTINCT NPI) FROM DBO.tblTransactions WHERE CustomerID IS NOT NULL
GROUP BY CustomerID HAVING COUNT(DISTINCT NPI) > 1
--NONE
*/

/*
SELECT DoctorID,COUNT(DISTINCT NPI) FROM DBO.tblTransactions
GROUP BY DoctorID HAVING COUNT(DISTINCT NPI) > 1
*/

--UPDATE A
--SET Zip = B.Zip
--FROM DBO.tblTransactions A
--INNER JOIN DBO.tblTransactions B
--ON A.PhysicianName = B.PhysicianName AND A.Address1 = B.Address1
--AND B.Zip <> '00000'
--WHERE A.Zip = '00000'
--GO

--UPDATE A
--SET City = B.City
--FROM DBO.tblTransactions A
--INNER JOIN DBO.tblTransactions B
--ON A.PhysicianName = B.PhysicianName AND A.Address1 = B.Address1 AND A.Zip = B.Zip
--AND B.City <> ''
--WHERE A.City = ''
--GO

--UPDATE A
--SET State = B.State
--FROM DBO.tblTransactions A
--INNER JOIN DBO.tblTransactions B
--ON A.PhysicianName = B.PhysicianName AND A.Address1 = B.Address1 AND A.Zip = B.Zip
--AND B.State <> ''
--WHERE A.State = ''
--GO

--UPDATE A
--SET PhysicianName = B.PhysicianName,
--FirstName = B.FirstName,
--LastName = B.LastName,
--NPI = B.NPI,
--CUSTOMERID = B.CUSTOMERID,
--ADDRESS1 = B.ADDRESS1,
--CITY = B.CITY,
--STATE = B.STATE,
--ZIP = B.ZIP
--FROM DBO.tblTransactions A
--INNER JOIN DBO.tblTransactions B
--ON REPLACE(REPLACE(REPLACE(A.Address1,'DRIVE','DR'),'DR.','DR'),'Circle','CIR') = REPLACE(REPLACE(REPLACE(B.Address1,'DRIVE','DR'),'DR.','DR'),'Circle','CIR')
--AND A.LastName = B.LastName
--AND B.NPI IS NOT NULL
--WHERE A.NPI IS NULL
--GO

UPDATE DBO.tblTransactions
SET PharmacyName = 'Unknown Pharmacy'
WHERE PharmacyName IS NULL
GO

ALTER TABLE DBO.tblTransactions
ADD PhysicianID VARCHAR(10)
GO

UPDATE DBO.tblTransactions
SET PhysicianID = ISNULL(ISNULL(CASE CustomerID WHEN '' THEN NULL ELSE CustomerID END,CASE NPI WHEN '' THEN NULL ELSE NPI END),DoctorID)
GO

/*
SELECT * FROM tblTransactions WHERE PhysicianID IS NULL
--NONE
*/


--One Zip only align to one territory in each Sales Force.
/*
SELECT CUSTOMER_NUMBER, FIELD_FORCE_NAME, COUNT(TERRITORY_NUMBER)
FROM Axtria_dev.DBO.tblImportCustTerr
WHERE FIELD_FORCE_NAME IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
GROUP BY CUSTOMER_NUMBER, FIELD_FORCE_NAME
HAVING COUNT(TERRITORY_NUMBER) > 1
--NONE

SELECT POSTAL_CODE, FIELD_FORCE_NAME, COUNT(TERRITORY_NUMBER)
FROM Axtria_dev.DBO.tblImportGeoTerr 
WHERE FIELD_FORCE_NAME IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
GROUP BY POSTAL_CODE, FIELD_FORCE_NAME
HAVING COUNT(TERRITORY_NUMBER) > 1
--NONE
*/

--Get Terr Info
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CustomerID = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
GO
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.Zip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
WHERE A.APEX_Terr IS NULL
GO
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PatientZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
WHERE A.APEX_Terr IS NULL
GO
--UPDATE A
--SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
--FROM DBO.tblTransactions A
--INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PharmacyZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
--WHERE A.APEX_Terr IS NULL AND A.ProgramType = 'Virtual'
--GO

UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CustomerID = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
GO
UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.Zip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
WHERE A.PINNACLE_Terr IS NULL
GO
UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PatientZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
WHERE A.PINNACLE_Terr IS NULL
GO
--UPDATE A
--SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
--FROM DBO.tblTransactions A
--INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PharmacyZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
--WHERE A.PINNACLE_Terr IS NULL AND A.ProgramType = 'Virtual'
--GO

UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CustomerID = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
GO
UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.Zip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
WHERE A.SUMMIT_Terr IS NULL
GO
UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PatientZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
WHERE A.SUMMIT_Terr IS NULL
GO
--UPDATE A
--SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
--FROM DBO.tblTransactions A
--INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PharmacyZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
--WHERE A.SUMMIT_Terr IS NULL AND A.ProgramType = 'Virtual'
--GO

UPDATE A
SET APEX_TerrName = B.TERRITORY_NAME,
	APEX_Dist = B.LEVEL2_TERRITORY_NUMBER, APEX_DistName = B.LEVEL2_TERRITORY_NAME,
	APEX_Reg = B.LEVEL3_TERRITORY_NUMBER, APEX_RegName = B.LEVEL3_TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT TERRITORY_NUMBER, TERRITORY_NAME, FIELD_FORCE_NAME, 
	LEVEL2_TERRITORY_NUMBER, LEVEL2_TERRITORY_NAME, 
	LEVEL3_TERRITORY_NUMBER, LEVEL3_TERRITORY_NAME
	FROM Axtria_dev.DBO.tblImportTerrHierarchy 
	WHERE FIELD_FORCE_NAME = 'INBU APEX SF' AND TERRITORY_LEVEL_CODE = 1
) B ON A.APEX_Terr = B.TERRITORY_NUMBER
GO

UPDATE A
SET PINNACLE_TerrName = B.TERRITORY_NAME,
	PINNACLE_Dist = B.LEVEL2_TERRITORY_NUMBER, PINNACLE_DistName = B.LEVEL2_TERRITORY_NAME,
	PINNACLE_Reg = B.LEVEL3_TERRITORY_NUMBER, PINNACLE_RegName = B.LEVEL3_TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT TERRITORY_NUMBER, TERRITORY_NAME, FIELD_FORCE_NAME, 
	LEVEL2_TERRITORY_NUMBER, LEVEL2_TERRITORY_NAME, 
	LEVEL3_TERRITORY_NUMBER, LEVEL3_TERRITORY_NAME
	FROM Axtria_dev.DBO.tblImportTerrHierarchy 
	WHERE FIELD_FORCE_NAME = 'INBU PINNACLE SF' AND TERRITORY_LEVEL_CODE = 1
) B ON A.PINNACLE_Terr = B.TERRITORY_NUMBER
GO

UPDATE A
SET SUMMIT_TerrName = B.TERRITORY_NAME,
	SUMMIT_Dist = B.LEVEL2_TERRITORY_NUMBER, SUMMIT_DistName = B.LEVEL2_TERRITORY_NAME,
	SUMMIT_Reg = B.LEVEL3_TERRITORY_NUMBER, SUMMIT_RegName = B.LEVEL3_TERRITORY_NAME
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT TERRITORY_NUMBER, TERRITORY_NAME, FIELD_FORCE_NAME, 
	LEVEL2_TERRITORY_NUMBER, LEVEL2_TERRITORY_NAME, 
	LEVEL3_TERRITORY_NUMBER, LEVEL3_TERRITORY_NAME
	FROM Axtria_dev.DBO.tblImportTerrHierarchy 
	WHERE FIELD_FORCE_NAME = 'INBU SUMMIT SF' AND TERRITORY_LEVEL_CODE = 1
) B ON A.SUMMIT_Terr = B.TERRITORY_NUMBER
GO

--One Customer only align to one target in each Sales Force. In different Sales Force, the target is the same.
/*
SELECT CUSTOMER_NUMBER, FIELD_FORCE_NAME, COUNT(CLASSIFICATION_CODE)
FROM Axtria_dev.DBO.tblImportTarget
WHERE FIELD_FORCE_NAME IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
GROUP BY CUSTOMER_NUMBER, FIELD_FORCE_NAME
HAVING COUNT(CLASSIFICATION_CODE) > 1
--NONE

SELECT CUSTOMER_NUMBER, COUNT(DISTINCT CLASSIFICATION_CODE)
FROM Axtria_dev.DBO.tblImportTarget
WHERE FIELD_FORCE_NAME IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
GROUP BY CUSTOMER_NUMBER
HAVING COUNT(DISTINCT CLASSIFICATION_CODE) > 1
--NONE
*/

--All Other Physicians
UPDATE DBO.tblTransactions
SET PhysicianName = 'All Other Physicians'
WHERE (NPI IS NULL AND CustomerID IS NULL) OR PhysicianName IS NULL
GO
--Get Target Info
UPDATE A
SET Target = B.CLASSIFICATION_CODE
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportTarget B ON A.CustomerID = 'N_'+B.CUSTOMER_NUMBER
AND B.FIELD_FORCE_NAME IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
GO
UPDATE A
SET Target = 'AMA-PDRP', PhysicianName = 'PDRP Physician', NPI = '', CustomerID = '', 
	Address1 = '', City = '', State = '', Zip = '' 
FROM DBO.tblTransactions A
INNER JOIN Axtria_dev.DBO.tblImportAmaPDRP B ON A.CustomerID = 'N_'+B.GCO_BUSINESS_PARTY_NUMBER
GO

--Add Indication
ALTER TABLE DBO.tblTransactions
ADD Indication VARCHAR(20),
	DOB DATE,
	Age INT
GO

UPDATE A
SET Indication = B.TeradataTypeWeb,
	DOB = CASE B.TeradataTypeWeb WHEN 'PSO' THEN B.DOB ELSE NULL END
FROM DBO.tblTransactions A
INNER JOIN (
	SELECT T.TeradataTypeWeb, I.PatientID, I.DOB
	FROM Enbrel_Production.dbo.tblPatientInfo I (NOLOCK) 
	INNER JOIN Enbrel_Production.dbo.tblTreatmentList T (NOLOCK) ON I.TreatmentID = T.TreatmentID
) B ON A.PatientID = B.PatientID
GO

UPDATE DBO.tblTransactions
SET Age = DATEDIFF(YEAR,DOB,DATE_NAME)-1
GO

UPDATE DBO.tblTransactions
SET Indication = 'PSO(aged 18+)'
WHERE Age >= 18
GO

UPDATE DBO.tblTransactions
SET Indication = 'PSO(age 4-17)'
WHERE Age BETWEEN 4 AND 17
GO
/*
SELECT Indication,COUNT(*) FROM tblTransactions
GROUP BY Indication
*/
UPDATE DBO.tblTransactions 
SET Indication = 'Unknown'
WHERE Indication IN ('PSO','UNK') OR Indication IS NULL
GO

/*
select count(*) from tblTransactions
--1399403

select count(*) from tblTransactions where APEX_Terr is null and PINNACLE_Terr is null and SUMMIT_Terr is null
--5844
*/
print'Transactions End'
print getdate()
print'Activations Start'
go

IF OBJECT_ID('tblActivations') IS NOT NULL
DROP TABLE DBO.tblActivations
GO
CREATE TABLE [dbo].[tblActivations](
	[ID] [int] identity primary key NOT NULL,
	[PatientID] [int] NULL,
	[CardID] [varchar](50) NULL,
	[Date_Name] [date] NULL,
	[Date_ID] [int] NULL,
	[Week_ID] [int] NULL,
	[Month_ID] [int] NULL,
	[Year_ID] [int] NULL,
	[ProgramType] [varchar](50) NULL,
	[VendorCode] [varchar](3) NULL,
	[Date_Name_1stTransaction] [date] NULL,
	[Time_1stTransaction] [int] NULL,
	[Zip] [varchar](5) NULL,
	[Customer_Number] [varchar](10) NULL,
	[PatientZip] [varchar](5) NULL,
	--[PharmacyZip] [varchar](5) NULL,
	[PhysicianZip] [varchar](5) NULL,
	[DoctorID] [int] NULL,
	[NPI] [varchar](11) NULL,
	[CustomerID] [varchar](10) NULL,
	[PhysicianID] [varchar](11) NULL,
	[APEX_Terr] [varchar](5) NULL,
	[APEX_TerrName] [varchar](50) NULL,
	[APEX_Dist] [varchar](5) NULL,
	[APEX_DistName] [varchar](50) NULL,
	[APEX_Reg] [varchar](5) NULL,
	[APEX_RegName] [varchar](50) NULL,
	[PINNACLE_Terr] [varchar](5) NULL,
	[PINNACLE_TerrName] [varchar](50) NULL,
	[PINNACLE_Dist] [varchar](5) NULL,
	[PINNACLE_DistName] [varchar](50) NULL,
	[PINNACLE_Reg] [varchar](5) NULL,
	[PINNACLE_RegName] [varchar](50) NULL,
	[SUMMIT_Terr] [varchar](5) NULL,
	[SUMMIT_TerrName] [varchar](50) NULL,
	[SUMMIT_Dist] [varchar](5) NULL,
	[SUMMIT_DistName] [varchar](50) NULL,
	[SUMMIT_Reg] [varchar](5) NULL,
	[SUMMIT_RegName] [varchar](50) NULL
)
GO
INSERT INTO DBO.tblActivations
SELECT C.PatientID, C.CardID,
CONVERT(DATE, C.Date) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID, 
CASE LEFT(C.ActivityType, 27) WHEN 'Patient Enrolled DCARD-OPUS' THEN 'Debit' 
WHEN 'Patient Enrolled DMR-OPUS o' THEN 'DMR' 
WHEN 'Patient Enrolled MPRS-OPUS' THEN 'Retail' WHEN 'Patient Enrolled RCARD-OPUS' THEN 'Retail' END AS ProgramType, 
'OPU' AS VendorCode,
--1st transaction:
CONVERT(DATE, NULL) AS Date_Name_1stTransaction, CONVERT(INT, NULL) AS Time_1stTransaction, CONVERT(VARCHAR(5),NULL) AS Zip, 
CONVERT(VARCHAR(10),NULL) Customer_Number, 
LEFT(P.Zip,5) AS PatientZip, 
--primary physician:
CONVERT(VARCHAR(5),NULL) PhysicianZip,
CONVERT(INT,NULL) AS DoctorID, CONVERT(VARCHAR(11),NULL) NPI, CONVERT(VARCHAR(10),NULL) CustomerID, CONVERT(VARCHAR(11),NULL) PhysicianID,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
FROM Enbrel_Production.DBO.tblAccountHistory C
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.Date) = V.Date_Name
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
WHERE C.ActivityType LIKE '%Patient Enrolled%' AND C.Patientid IS NOT NULL
AND LEFT(C.ActivityType, 27) NOT IN ('Patient Enrolled','Patient Enrolled VCARD-OPUS')
GO
INSERT INTO DBO.tblActivations
SELECT C.PatientID, C.CardID,
CONVERT(DATE, C.Date) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID, 
'Debit' AS ProgramType, 'CRX' AS VendorCode,
CONVERT(DATE, NULL) AS Date_Name_1stTransaction, CONVERT(INT, NULL) AS Time_1stTransaction, CONVERT(VARCHAR(5),NULL) AS Zip, 
CONVERT(VARCHAR(10),NULL) Customer_Number, LEFT(P.Zip,5) AS PatientZip,  CONVERT(VARCHAR(5),NULL) PhysicianZip,
--CONVERT(VARCHAR(5),NULL) AS PharmacyZip, IsActive, 
CONVERT(INT,NULL) AS DoctorID, CONVERT(VARCHAR(11),NULL) NPI, CONVERT(VARCHAR(10),NULL) CustomerID, CONVERT(VARCHAR(11),NULL) PhysicianID,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
FROM Enbrel_Production.DBO.tblAccountHistory C
INNER JOIN (
	SELECT MemberID
	FROM Enbrel_Production.DBO.tblDebitAmgenEdgeCardInfo --ProgramID 60
	UNION
	SELECT MemberID
	FROM Enbrel_Production.DBO.tblDebitKaiserCardInfo --ProgramID 3
	UNION
	SELECT MemberID
	FROM Enbrel_Production.DBO.tblDebitDiscoveryCardInfo --ProgramID 1
	UNION
	SELECT MemberID
	FROM Enbrel_Production.DBO.tblDebitChargeCardInfo --ProgramID 59
	UNION
	SELECT MemberID
	FROM Enbrel_Production.DBO.tblcardInfoDebitOther --ProgramID 4
) R ON C.CardID = R.MemberID
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.Date) = V.Date_Name
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
WHERE C.Patientid IS NOT NULL AND LEFT(C.ActivityType, 27) IN ('Patient Enrolled')
GO
INSERT INTO DBO.tblActivations
SELECT C.PatientID, C.CardID,
CONVERT(DATE, C.Date) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID, 
'Retail' AS ProgramType, 'CRX' AS VendorCode,
CONVERT(DATE, NULL) AS Date_Name_1stTransaction, CONVERT(INT, NULL) AS Time_1stTransaction, CONVERT(VARCHAR(5),NULL) AS Zip, 
CONVERT(VARCHAR(10),NULL) Customer_Number, LEFT(P.Zip,5) AS PatientZip,  CONVERT(VARCHAR(5),NULL) PhysicianZip,
--CONVERT(VARCHAR(5),NULL) AS PharmacyZip, IsActive, 
CONVERT(INT,NULL) AS DoctorID, CONVERT(VARCHAR(11),NULL) NPI, CONVERT(VARCHAR(10),NULL) CustomerID, CONVERT(VARCHAR(11),NULL) PhysicianID,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
FROM Enbrel_Production.DBO.tblAccountHistory C
INNER JOIN Enbrel_Production.DBO.tblCardInfoCRX R --ProgramID 58
ON C.CardID = R.MemberID
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.Date) = V.Date_Name
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
WHERE C.Patientid IS NOT NULL AND LEFT(C.ActivityType, 27) IN ('Patient Enrolled')
GO
INSERT INTO DBO.tblActivations
SELECT C.PatientID, C.CardID,
CONVERT(DATE, C.Date) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID, 
'DMR' AS ProgramType, 'CRX' AS VendorCode,
CONVERT(DATE, NULL) AS Date_Name_1stTransaction, CONVERT(INT, NULL) AS Time_1stTransaction, CONVERT(VARCHAR(5),NULL) AS Zip, 
CONVERT(VARCHAR(10),NULL) Customer_Number, LEFT(P.Zip,5) AS PatientZip,  CONVERT(VARCHAR(5),NULL) PhysicianZip,
--CONVERT(VARCHAR(5),NULL) AS PharmacyZip, IsActive, 
CONVERT(INT,NULL) AS DoctorID, CONVERT(VARCHAR(11),NULL) NPI, CONVERT(VARCHAR(10),NULL) CustomerID, CONVERT(VARCHAR(11),NULL) PhysicianID,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
FROM Enbrel_Production.DBO.tblAccountHistory C
INNER JOIN Enbrel_Production.DBO.tblCardInfo R --ProgramID 5
ON C.CardID = R.MemberID
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.Date) = V.Date_Name
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
WHERE C.Patientid IS NOT NULL AND LEFT(C.ActivityType, 27) IN ('Patient Enrolled')
GO

INSERT INTO DBO.tblActivations
SELECT C.PatientID, C.CardID,
CONVERT(DATE, C.Date) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID, 
'Debit' AS ProgramType, 'CRX' AS VendorCode,
CONVERT(DATE, NULL) AS Date_Name_1stTransaction, CONVERT(INT, NULL) AS Time_1stTransaction, CONVERT(VARCHAR(5),NULL) AS Zip, 
CONVERT(VARCHAR(10),NULL) Customer_Number, LEFT(P.Zip,5) AS PatientZip,  CONVERT(VARCHAR(5),NULL) PhysicianZip,
--CONVERT(VARCHAR(5),NULL) AS PharmacyZip, IsActive, 
CONVERT(INT,NULL) AS DoctorID, CONVERT(VARCHAR(11),NULL) NPI, CONVERT(VARCHAR(10),NULL) CustomerID, CONVERT(VARCHAR(11),NULL) PhysicianID,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
FROM Enbrel_Production.DBO.tblAccountHistory C
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.Date) = V.Date_Name
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
WHERE ActivityType LIKE '%Patient Program change%'
AND C.CardID IS NOT NULL 
AND (SUBSTRING(C.ActivityType,CHARINDEX('to',C.ActivityType)+3,50) LIKE '%Debit%'
OR SUBSTRING(C.ActivityType,CHARINDEX('to',C.ActivityType)+3,50) LIKE '%Amgen Edge%')
AND C.Patientid IS NOT NULL 
GO


INSERT INTO DBO.tblActivations
SELECT C.PatientID, C.CardID,
CONVERT(DATE, C.Date) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID, 
'Retail' AS ProgramType, 
CASE WHEN SUBSTRING(C.ActivityType,CHARINDEX('to',C.ActivityType)+3,50) LIKE '%CRX%' THEN 'CRX' ELSE 'OPU' END AS VendorCode,
CONVERT(DATE, NULL) AS Date_Name_1stTransaction, CONVERT(INT, NULL) AS Time_1stTransaction, CONVERT(VARCHAR(5),NULL) AS Zip, 
CONVERT(VARCHAR(10),NULL) Customer_Number, LEFT(P.Zip,5) AS PatientZip,  CONVERT(VARCHAR(5),NULL) PhysicianZip,
--CONVERT(VARCHAR(5),NULL) AS PharmacyZip, IsActive, 
CONVERT(INT,NULL) AS DoctorID, CONVERT(VARCHAR(11),NULL) NPI, CONVERT(VARCHAR(10),NULL) CustomerID, CONVERT(VARCHAR(11),NULL) PhysicianID,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
FROM Enbrel_Production.DBO.tblAccountHistory C
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.Date) = V.Date_Name
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
WHERE ActivityType LIKE '%Patient Program change%'
AND C.CardID IS NOT NULL 
AND SUBSTRING(C.ActivityType,CHARINDEX('to',C.ActivityType)+3,50) LIKE '%Retail%'
AND C.Patientid IS NOT NULL 
GO

INSERT INTO DBO.tblActivations
SELECT C.PatientID, C.CardID,
CONVERT(DATE, C.Date) AS Date_Name, V.Date_ID, V.Week_ID, V.Month_ID, V.Year_ID, 
'DMR' AS ProgramType, CASE WHEN SUBSTRING(C.ActivityType,CHARINDEX('to',C.ActivityType)+3,50) LIKE '%CRX%' THEN 'CRX' 
WHEN SUBSTRING(C.ActivityType,CHARINDEX('to',C.ActivityType)+3,50) LIKE '%PSKW%' THEN 'CRX' ELSE 'OPU' END AS VendorCode,
CONVERT(DATE, NULL) AS Date_Name_1stTransaction, CONVERT(INT, NULL) AS Time_1stTransaction, CONVERT(VARCHAR(5),NULL) AS Zip, 
CONVERT(VARCHAR(10),NULL) Customer_Number, LEFT(P.Zip,5) AS PatientZip,  CONVERT(VARCHAR(5),NULL) PhysicianZip,
--CONVERT(VARCHAR(5),NULL) AS PharmacyZip, IsActive, 
CONVERT(INT,NULL) AS DoctorID, CONVERT(VARCHAR(11),NULL) NPI, CONVERT(VARCHAR(10),NULL) CustomerID, CONVERT(VARCHAR(11),NULL) PhysicianID,
CONVERT(VARCHAR(5),NULL) AS APEX_Terr, CONVERT(VARCHAR(50),NULL) AS APEX_TerrName,
CONVERT(VARCHAR(5),NULL) AS APEX_Dist, CONVERT(VARCHAR(50),NULL) AS APEX_DistName,
CONVERT(VARCHAR(5),NULL) AS APEX_Reg, CONVERT(VARCHAR(50),NULL) AS APEX_RegName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Terr, CONVERT(VARCHAR(50),NULL) AS PINNACLE_TerrName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Dist, CONVERT(VARCHAR(50),NULL) AS PINNACLE_DistName,
CONVERT(VARCHAR(5),NULL) AS PINNACLE_Reg, CONVERT(VARCHAR(50),NULL) AS PINNACLE_RegName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Terr, CONVERT(VARCHAR(50),NULL) AS SUMMIT_TerrName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Dist, CONVERT(VARCHAR(50),NULL) AS SUMMIT_DistName,
CONVERT(VARCHAR(5),NULL) AS SUMMIT_Reg, CONVERT(VARCHAR(50),NULL) AS SUMMIT_RegName
FROM Enbrel_Production.DBO.tblAccountHistory C
INNER JOIN DBO.tblCalendar V ON CONVERT(DATE, C.Date) = V.Date_Name
LEFT JOIN Enbrel_Production.DBO.tblPatientInfo P ON C.PatientID = P.PatientID
WHERE ActivityType LIKE '%Patient Program change%'
AND C.CardID IS NOT NULL 
AND SUBSTRING(C.ActivityType,CHARINDEX('to',C.ActivityType)+3,50) LIKE '%DMR%'
AND C.Patientid IS NOT NULL 
GO


--One patient only map to one primary physician.
/*
SELECT COUNT(DISTINCT PhysicianID), PatientID 
FROM Enbrel_Production.DBO.tblPatientPhysician
WHERE IsActive = 'Y' AND IsPrimary = 'Y'
GROUP BY PatientID
HAVING COUNT(DISTINCT PhysicianID) > 1
*/

UPDATE A
SET DoctorID = B.PhysicianID, PhysicianZip = LEFT(B.Zip,5)
FROM  tblActivations A INNER JOIN (
SELECT PhysicianID, PatientID,Zip FROM Enbrel_Production.DBO.tblPatientPhysician
WHERE IsActive = 'Y' AND IsPrimary = 'Y'
) B ON A.PatientID = B.PatientID
GO

UPDATE A
SET NPI = C.NPI#, CustomerID = 'N_'+C.CUSTOMER_NUMBER
FROM  tblActivations A 
INNER JOIN Enbrel_Production.DBO.tblDoctors B ON A.DoctorID = B.tblDoctorsID
INNER JOIN Axtria_dev.DBO.tblImportCustNomProf C ON B.PhysicianNPI = C.NPI#
GO
UPDATE A
SET CustomerID = 'N_'+C.CUSTOMER_NUMBER
FROM  tblActivations A 
INNER JOIN Enbrel_Production.DBO.tblDoctors B ON A.DoctorID = B.tblDoctorsID
INNER JOIN Axtria_dev.DBO.tblImportCustNomProf C 
ON B.FirstName = C.FIRST_NAME AND B.LastName = C.LAST_NAME AND RIGHT('00000'+CONVERT(VARCHAR(5),B.Zip),5) = C.POSTAL_CODE
WHERE A.CustomerID IS NULL
GO

UPDATE A
SET NPI = B.NPI
FROM DBO.tblActivations A
INNER JOIN DBO.tblActivations B ON A.CustomerID = B.CustomerID AND B.NPI IS NOT NULL
WHERE A.NPI IS NULL
GO

UPDATE A
SET NPI = B.NPI
FROM DBO.tblActivations A
INNER JOIN (
	SELECT DISTINCT NPI, CustomerID FROM DBO.tblActivations A
	WHERE EXISTS (
	SELECT * FROM (
	SELECT CustomerID, MIN(DoctorID) DoctorID
	FROM DBO.tblActivations
	WHERE CustomerID IN (
	SELECT CustomerID FROM DBO.tblActivations WHERE CustomerID IS NOT NULL
	GROUP BY CustomerID HAVING COUNT(DISTINCT NPI) > 1)
	GROUP BY CustomerID
	) B WHERE A.DoctorID = B.DoctorID AND A.CustomerID = B.CustomerID)
) B ON A.CustomerID = B.CustomerID
WHERE A.CustomerID IN (
	SELECT CustomerID FROM DBO.tblActivations WHERE CustomerID IS NOT NULL
	GROUP BY CustomerID HAVING COUNT(DISTINCT NPI) > 1) 
GO

UPDATE DBO.tblActivations
SET PhysicianID = ISNULL(ISNULL(CASE CustomerID WHEN '' THEN NULL ELSE CustomerID END,CASE NPI WHEN '' THEN NULL ELSE NPI END),DoctorID)
GO

--physician information from 1st claim
UPDATE A
SET Date_Name_1stTransaction = B.Date_Name,
	Time_1stTransaction = DATEDIFF(DAY, A.Date_Name, B.Date_Name),
	Zip = B.Zip, Customer_Number = B.CustomerID
FROM DBO.tblActivations A
INNER JOIN (
	SELECT A.PatientID, A.CardID, A.Date_Name, A.Zip, A.CustomerID FROM DBO.tblTransactions A 
	WHERE EXISTS (
		SELECT * FROM (
		SELECT PatientID, CardID, MIN(Date_Name) Date_Name FROM DBO.tblTransactions	WHERE Zip IS NOT NULL
		GROUP BY PatientID, CardID
	) B WHERE A.PatientID = B.PatientID AND A.CardID = B.CardID AND A.Date_Name = B.Date_Name)
) B ON A.PatientID = B.PatientID AND A.CardID = B.CardID
GO

--Set to 0 if Time_1stTransaction is negative
UPDATE DBO.tblActivations
SET Time_1stTransaction = 0
WHERE Time_1stTransaction < 0
GO

--UPDATE A
--SET PharmacyZip = B.PharmacyZip
--FROM DBO.tblActivations A
--INNER JOIN (
--	SELECT A.PatientID, A.CardID, A.Date_Name, LEFT(A.PharmacyZip,5) AS PharmacyZip FROM DBO.tblTransactions A 
--	WHERE EXISTS (
--		SELECT * FROM (
--		SELECT PatientID, CardID, MIN(Date_Name) Date_Name FROM DBO.tblTransactions	WHERE PharmacyZip <> '00000'
--		GROUP BY PatientID, CardID
--	) B WHERE A.PatientID = B.PatientID AND A.CardID = B.CardID AND A.Date_Name = B.Date_Name)
--) B ON A.PatientID = B.PatientID AND A.CardID = B.CardID
--GO

--Get Terr Info
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CUSTOMER_NUMBER = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
GO
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.Zip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
WHERE A.APEX_Terr IS NULL
GO
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CustomerID = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
WHERE A.APEX_Terr IS NULL
GO
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PhysicianZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
WHERE A.APEX_Terr IS NULL
GO
UPDATE A
SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PatientZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
WHERE A.APEX_Terr IS NULL
GO
--UPDATE A
--SET APEX_Terr = B.TERRITORY_NUMBER, APEX_TerrName = B.TERRITORY_NAME
--FROM DBO.tblActivations A
--INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PharmacyZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU APEX SF'
--WHERE A.APEX_Terr IS NULL AND A.ProgramType = 'Virtual'
--GO

UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CUSTOMER_NUMBER = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
GO
UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.Zip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
WHERE A.PINNACLE_Terr IS NULL
GO
UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CustomerID = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
WHERE A.PINNACLE_Terr IS NULL
GO
UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PhysicianZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
WHERE A.PINNACLE_Terr IS NULL
GO
UPDATE A
SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PatientZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
WHERE A.PINNACLE_Terr IS NULL
GO
--UPDATE A
--SET PINNACLE_Terr = B.TERRITORY_NUMBER, PINNACLE_TerrName = B.TERRITORY_NAME
--FROM DBO.tblActivations A
--INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PharmacyZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU PINNACLE SF'
--WHERE A.PINNACLE_Terr IS NULL AND A.ProgramType = 'Virtual'
--GO

UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CUSTOMER_NUMBER = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
GO
UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.Zip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
WHERE A.SUMMIT_Terr IS NULL
GO
UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportCustTerr B ON A.CustomerID = 'N_'+B.CUSTOMER_NUMBER AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
WHERE A.SUMMIT_Terr IS NULL
GO
UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PhysicianZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
WHERE A.SUMMIT_Terr IS NULL
GO
UPDATE A
SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PatientZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
WHERE A.SUMMIT_Terr IS NULL
GO
--UPDATE A
--SET SUMMIT_Terr = B.TERRITORY_NUMBER, SUMMIT_TerrName = B.TERRITORY_NAME
--FROM DBO.tblActivations A
--INNER JOIN Axtria_dev.DBO.tblImportGeoTerr B ON A.PharmacyZip = B.POSTAL_CODE AND B.FIELD_FORCE_NAME = 'INBU SUMMIT SF'
--WHERE A.SUMMIT_Terr IS NULL AND A.ProgramType = 'Virtual'
--GO

UPDATE A
SET APEX_TerrName = B.TERRITORY_NAME,
	APEX_Dist = B.LEVEL2_TERRITORY_NUMBER, APEX_DistName = B.LEVEL2_TERRITORY_NAME,
	APEX_Reg = B.LEVEL3_TERRITORY_NUMBER, APEX_RegName = B.LEVEL3_TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN (
	SELECT TERRITORY_NUMBER, TERRITORY_NAME, FIELD_FORCE_NAME, 
	LEVEL2_TERRITORY_NUMBER, LEVEL2_TERRITORY_NAME, 
	LEVEL3_TERRITORY_NUMBER, LEVEL3_TERRITORY_NAME
	FROM Axtria_dev.DBO.tblImportTerrHierarchy 
	WHERE FIELD_FORCE_NAME = 'INBU APEX SF' AND TERRITORY_LEVEL_CODE = 1
) B ON A.APEX_Terr = B.TERRITORY_NUMBER
GO

UPDATE A
SET PINNACLE_TerrName = B.TERRITORY_NAME,
	PINNACLE_Dist = B.LEVEL2_TERRITORY_NUMBER, PINNACLE_DistName = B.LEVEL2_TERRITORY_NAME,
	PINNACLE_Reg = B.LEVEL3_TERRITORY_NUMBER, PINNACLE_RegName = B.LEVEL3_TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN (
	SELECT TERRITORY_NUMBER, TERRITORY_NAME, FIELD_FORCE_NAME, 
	LEVEL2_TERRITORY_NUMBER, LEVEL2_TERRITORY_NAME, 
	LEVEL3_TERRITORY_NUMBER, LEVEL3_TERRITORY_NAME
	FROM Axtria_dev.DBO.tblImportTerrHierarchy 
	WHERE FIELD_FORCE_NAME = 'INBU PINNACLE SF' AND TERRITORY_LEVEL_CODE = 1
) B ON A.PINNACLE_Terr = B.TERRITORY_NUMBER
GO

UPDATE A
SET SUMMIT_TerrName = B.TERRITORY_NAME,
	SUMMIT_Dist = B.LEVEL2_TERRITORY_NUMBER, SUMMIT_DistName = B.LEVEL2_TERRITORY_NAME,
	SUMMIT_Reg = B.LEVEL3_TERRITORY_NUMBER, SUMMIT_RegName = B.LEVEL3_TERRITORY_NAME
FROM DBO.tblActivations A
INNER JOIN (
	SELECT TERRITORY_NUMBER, TERRITORY_NAME, FIELD_FORCE_NAME, 
	LEVEL2_TERRITORY_NUMBER, LEVEL2_TERRITORY_NAME, 
	LEVEL3_TERRITORY_NUMBER, LEVEL3_TERRITORY_NAME
	FROM Axtria_dev.DBO.tblImportTerrHierarchy 
	WHERE FIELD_FORCE_NAME = 'INBU SUMMIT SF' AND TERRITORY_LEVEL_CODE = 1
) B ON A.SUMMIT_Terr = B.TERRITORY_NUMBER
GO

--Add Indication
ALTER TABLE DBO.tblActivations
ADD Indication VARCHAR(20),
	DOB DATE,
	Age INT
GO

UPDATE A
SET Indication = B.TeradataTypeWeb,
	DOB = CASE B.TeradataTypeWeb WHEN 'PSO' THEN B.DOB ELSE NULL END
FROM DBO.tblActivations A
INNER JOIN (
	SELECT T.TeradataTypeWeb, I.PatientID, I.DOB
	FROM Enbrel_Production.dbo.tblPatientInfo I (NOLOCK) 
	INNER JOIN Enbrel_Production.dbo.tblTreatmentList T (NOLOCK) ON I.TreatmentID = T.TreatmentID
) B ON A.PatientID = B.PatientID
GO

UPDATE DBO.tblActivations
SET Age = DATEDIFF(YEAR,DOB,DATE_NAME)-1
GO

UPDATE DBO.tblActivations
SET Indication = 'PSO(aged 18+)'
WHERE Age >= 18
GO

UPDATE DBO.tblActivations
SET Indication = 'PSO(age 4-17)'
WHERE Age BETWEEN 4 AND 17
GO
/*
SELECT Indication,COUNT(*) FROM tblActivations
GROUP BY Indication
*/
UPDATE DBO.tblActivations 
SET Indication = 'Unknown'
WHERE Indication IN ('PSO','UNK') OR Indication IS NULL
GO
/*
select count(*) from tblActivations
--188743

select count(*) from tblActivations where APEX_Terr is null and PINNACLE_Terr is null and SUMMIT_Terr is null
--661
*/

print'Activations End'
print getdate()
print'Dashboard Start'
go

--Dashboard Transactions
IF OBJECT_ID('tblGeoTransactions') IS NOT NULL
DROP TABLE DBO.tblGeoTransactions
GO
--One Terr is only under one team
SELECT 'Terr' Lev, A.APEX_Terr AS Geo, CONVERT(VARCHAR(16),'INBU APEX SF') AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
INTO DBO.tblGeoTransactions
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.APEX_Terr IS NOT NULL
GROUP BY A.APEX_Terr, A.ProgramType, B.Item
GO
INSERT INTO DBO.tblGeoTransactions
SELECT 'Terr' Lev, A.PINNACLE_Terr AS Geo, 'INBU PINNACLE SF' AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.PINNACLE_Terr IS NOT NULL
GROUP BY A.PINNACLE_Terr, A.ProgramType, B.Item
GO
INSERT INTO DBO.tblGeoTransactions
SELECT 'Terr' Lev, A.SUMMIT_Terr AS Geo, 'INBU SUMMIT SF' AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.SUMMIT_Terr IS NOT NULL
GROUP BY A.SUMMIT_Terr, A.ProgramType, B.Item
GO

INSERT INTO DBO.tblGeoTransactions
SELECT 'Terr' Lev, A.APEX_Terr AS Geo, CONVERT(VARCHAR(16),'INBU APEX SF') AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.APEX_Terr IS NOT NULL
GROUP BY A.APEX_Terr, B.Item
GO
INSERT INTO DBO.tblGeoTransactions
SELECT 'Terr' Lev, A.PINNACLE_Terr AS Geo, 'INBU PINNACLE SF' AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.PINNACLE_Terr IS NOT NULL
GROUP BY A.PINNACLE_Terr, B.Item
GO
INSERT INTO DBO.tblGeoTransactions
SELECT 'Terr' Lev, A.SUMMIT_Terr AS Geo, 'INBU SUMMIT SF' AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.SUMMIT_Terr IS NOT NULL
GROUP BY A.SUMMIT_Terr, B.Item
GO

--Dist combine 3 teams to one
INSERT INTO DBO.tblGeoTransactions
SELECT 'Dist' Lev, A.Geo, NULL AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM (
SELECT APEX_Dist AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE APEX_Dist IS NOT NULL
UNION ALL
SELECT PINNACLE_Dist AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE PINNACLE_Dist IS NOT NULL AND APEX_Dist <> PINNACLE_Dist
UNION ALL
SELECT A.SUMMIT_Dist AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions A
WHERE SUMMIT_Dist IS NOT NULL AND APEX_Dist <> SUMMIT_Dist AND PINNACLE_Dist <> SUMMIT_Dist
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, A.ProgramType, B.Item
GO

--Dist combine 3 teams to one
INSERT INTO DBO.tblGeoTransactions
SELECT 'Dist' Lev, A.Geo, NULL AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM (
SELECT APEX_Dist AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE APEX_Dist IS NOT NULL
UNION ALL
SELECT PINNACLE_Dist AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE PINNACLE_Dist IS NOT NULL AND APEX_Dist <> PINNACLE_Dist
UNION ALL
SELECT A.SUMMIT_Dist AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions A
WHERE SUMMIT_Dist IS NOT NULL AND APEX_Dist <> SUMMIT_Dist AND PINNACLE_Dist <> SUMMIT_Dist
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, B.Item
GO

--Reg combine 3 teams to one
INSERT INTO DBO.tblGeoTransactions
SELECT 'Reg' Lev, A.Geo, NULL AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM (
SELECT APEX_Reg AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE APEX_Reg IS NOT NULL
UNION ALL
SELECT PINNACLE_Reg AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE PINNACLE_Reg IS NOT NULL AND APEX_Reg <> PINNACLE_Reg
UNION ALL
SELECT A.SUMMIT_Reg AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions A
WHERE SUMMIT_Reg IS NOT NULL AND APEX_Reg <> SUMMIT_Reg AND PINNACLE_Reg <> SUMMIT_Reg
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, A.ProgramType, B.Item
GO

--Reg combine 3 teams to one
INSERT INTO DBO.tblGeoTransactions
SELECT 'Reg' Lev, A.Geo, NULL AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM (
SELECT APEX_Reg AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE APEX_Reg IS NOT NULL
UNION ALL
SELECT PINNACLE_Reg AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions
WHERE PINNACLE_Reg IS NOT NULL AND APEX_Reg <> PINNACLE_Reg
UNION ALL
SELECT A.SUMMIT_Reg AS Geo, tblClaimID, ProgramType, Date_Name, CopayAmount
FROM DBO.tblTransactions A
WHERE SUMMIT_Reg IS NOT NULL AND APEX_Reg <> SUMMIT_Reg AND PINNACLE_Reg <> SUMMIT_Reg
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, B.Item
GO

--Nation include all data
INSERT INTO DBO.tblGeoTransactions
SELECT 'Nat' Lev, '30000' AS Geo, NULL AS Team, A.ProgramType, 
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.ProgramType, B.Item
GO

INSERT INTO DBO.tblGeoTransactions
SELECT 'Nat' Lev, '30000' AS Geo, NULL AS Team, 'All' AS ProgramType, 
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY B.Item
GO

--Not aligned data (included in nation)
INSERT INTO DBO.tblGeoTransactions
SELECT 'Unk' Lev, '00000' AS Geo, NULL AS Team, A.ProgramType, 
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE SUMMIT_Terr IS NULL AND APEX_Terr IS NULL AND PINNACLE_Terr IS NULL
GROUP BY A.ProgramType, B.Item
GO

INSERT INTO DBO.tblGeoTransactions
SELECT 'Unk' Lev, '00000' AS Geo, NULL AS Team, 'All' AS ProgramType, 
B.Item AS Period, COUNT(*) AS Transactions, AVG(CopayAmount) AS AvgCopay
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE SUMMIT_Terr IS NULL AND APEX_Terr IS NULL AND PINNACLE_Terr IS NULL
GROUP BY B.Item
GO


IF OBJECT_ID('tblGeoTransactions_VendorCode') IS NOT NULL
DROP TABLE DBO.tblGeoTransactions_VendorCode
GO
SELECT 'Unk' Lev, '00000' AS Geo, NULL AS Team, 'All' AS ProgramType, 
VendorCode, B.Item AS Period, COUNT(*) AS Transactions
INTO DBO.tblGeoTransactions_VendorCode
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
AND B.ItemType = 'Yearly'
WHERE SUMMIT_Terr IS NULL AND APEX_Terr IS NULL AND PINNACLE_Terr IS NULL
GROUP BY A.VendorCode, B.Item
GO


--Top 10 Pharmacies
IF OBJECT_ID('tblGeoTop10Pharmacies') IS NOT NULL
DROP TABLE DBO.tblGeoTop10Pharmacies
GO
--Terr
SELECT 'Terr' Lev, APEX_Terr AS Geo, CONVERT(VARCHAR(16),'INBU APEX SF') AS Team, ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY APEX_Terr, ProgramType ORDER BY COUNT(*) Desc, PharmacyName) Rnk
INTO DBO.tblGeoTop10Pharmacies
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND APEX_Terr IS NOT NULL
GROUP BY APEX_Terr, ProgramType, PharmacyName
GO
INSERT INTO DBO.tblGeoTop10Pharmacies
SELECT 'Terr' Lev, PINNACLE_Terr AS Geo, 'INBU PINNACLE SF' AS Team, ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY PINNACLE_Terr, ProgramType ORDER BY COUNT(*) Desc, PharmacyName) Rnk
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND PINNACLE_Terr IS NOT NULL
GROUP BY PINNACLE_Terr, ProgramType, PharmacyName
GO
INSERT INTO DBO.tblGeoTop10Pharmacies
SELECT 'Terr' Lev, SUMMIT_Terr AS Geo, 'INBU SUMMIT SF' AS Team, ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY SUMMIT_Terr, ProgramType ORDER BY COUNT(*) Desc, PharmacyName) Rnk
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND  SUMMIT_Terr IS NOT NULL
GROUP BY SUMMIT_Terr, ProgramType, PharmacyName
GO

INSERT INTO DBO.tblGeoTop10Pharmacies
SELECT 'Terr' Lev, APEX_Terr AS Geo, CONVERT(VARCHAR(16),'INBU APEX SF') AS Team, 'All' AS ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY APEX_Terr ORDER BY COUNT(*) Desc, PharmacyName) Rnk
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND APEX_Terr IS NOT NULL
GROUP BY APEX_Terr, PharmacyName
GO
INSERT INTO DBO.tblGeoTop10Pharmacies
SELECT 'Terr' Lev, PINNACLE_Terr AS Geo, 'INBU PINNACLE SF' AS Team, 'All' AS ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY PINNACLE_Terr ORDER BY COUNT(*) Desc, PharmacyName) Rnk
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND PINNACLE_Terr IS NOT NULL
GROUP BY PINNACLE_Terr, PharmacyName
GO
INSERT INTO DBO.tblGeoTop10Pharmacies
SELECT 'Terr' Lev, SUMMIT_Terr AS Geo, 'INBU SUMMIT SF' AS Team, 'All' AS ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY SUMMIT_Terr ORDER BY COUNT(*) Desc, PharmacyName) Rnk
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND  SUMMIT_Terr IS NOT NULL
GROUP BY SUMMIT_Terr, PharmacyName
GO

--Dist combine 3 teams to one
INSERT INTO DBO.tblGeoTop10Pharmacies
SELECT 'Dist' Lev, Geo, NULL AS Team, ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY Geo, ProgramType ORDER BY COUNT(*) Desc, PharmacyName) Rnk
FROM (
SELECT APEX_Dist AS Geo, tblClaimID, ProgramType, Date_Name, PharmacyName
FROM DBO.tblTransactions
WHERE Week_ID <= 13 AND APEX_Dist IS NOT NULL
UNION ALL
SELECT PINNACLE_Dist AS Geo, tblClaimID, ProgramType, Date_Name, PharmacyName
FROM DBO.tblTransactions
WHERE Week_ID <= 13 AND PINNACLE_Dist IS NOT NULL AND APEX_Dist <> PINNACLE_Dist
UNION ALL
SELECT A.SUMMIT_Dist AS Geo, tblClaimID, ProgramType, Date_Name, PharmacyName
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND SUMMIT_Dist IS NOT NULL AND APEX_Dist <> SUMMIT_Dist AND PINNACLE_Dist <> SUMMIT_Dist
) A 
GROUP BY Geo, ProgramType, PharmacyName
GO

INSERT INTO DBO.tblGeoTop10Pharmacies
SELECT 'Dist' Lev, Geo, NULL AS Team, 'All' AS ProgramType, PharmacyName, COUNT(*) AS Transactions,
RANK() OVER (PARTITION BY Geo ORDER BY COUNT(*) Desc, PharmacyName) Rnk
FROM (
SELECT APEX_Dist AS Geo, tblClaimID, ProgramType, Date_Name, PharmacyName
FROM DBO.tblTransactions
WHERE Week_ID <= 13 AND APEX_Dist IS NOT NULL
UNION ALL
SELECT PINNACLE_Dist AS Geo, tblClaimID, ProgramType, Date_Name, PharmacyName
FROM DBO.tblTransactions
WHERE Week_ID <= 13 AND PINNACLE_Dist IS NOT NULL AND APEX_Dist <> PINNACLE_Dist
UNION ALL
SELECT A.SUMMIT_Dist AS Geo, tblClaimID, ProgramType, Date_Name, PharmacyName
FROM DBO.tblTransactions A
WHERE Week_ID <= 13 AND SUMMIT_Dist IS NOT NULL AND APEX_Dist <> SUMMIT_Dist AND PINNACLE_Dist <> SUMMIT_Dist
) A
GROUP BY Geo, PharmacyName
GO

DELETE FROM DBO.tblGeoTop10Pharmacies
WHERE Rnk > 10
GO

--Dashboard Activations
IF OBJECT_ID('tblGeoActivations') IS NOT NULL
DROP TABLE DBO.tblGeoActivations
GO
--One Terr is only under one team
SELECT 'Terr' Lev, A.APEX_Terr AS Geo, CONVERT(VARCHAR(16),'INBU APEX SF') AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
INTO DBO.tblGeoActivations
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.APEX_Terr IS NOT NULL
GROUP BY A.APEX_Terr, A.ProgramType, B.Item
GO
INSERT INTO DBO.tblGeoActivations
SELECT 'Terr' Lev, A.PINNACLE_Terr AS Geo, 'INBU PINNACLE SF' AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.PINNACLE_Terr IS NOT NULL
GROUP BY A.PINNACLE_Terr, A.ProgramType, B.Item
GO
INSERT INTO DBO.tblGeoActivations
SELECT 'Terr' Lev, A.SUMMIT_Terr AS Geo, 'INBU SUMMIT SF' AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.SUMMIT_Terr IS NOT NULL
GROUP BY A.SUMMIT_Terr, A.ProgramType, B.Item
GO

INSERT INTO DBO.tblGeoActivations
SELECT 'Terr' Lev, A.APEX_Terr AS Geo, CONVERT(VARCHAR(16),'INBU APEX SF') AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.APEX_Terr IS NOT NULL
GROUP BY A.APEX_Terr, B.Item
GO
INSERT INTO DBO.tblGeoActivations
SELECT 'Terr' Lev, A.PINNACLE_Terr AS Geo, 'INBU PINNACLE SF' AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.PINNACLE_Terr IS NOT NULL
GROUP BY A.PINNACLE_Terr, B.Item
GO
INSERT INTO DBO.tblGeoActivations
SELECT 'Terr' Lev, A.SUMMIT_Terr AS Geo, 'INBU SUMMIT SF' AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE A.SUMMIT_Terr IS NOT NULL
GROUP BY A.SUMMIT_Terr, B.Item
GO

--Dist combine 3 teams to one
INSERT INTO DBO.tblGeoActivations
SELECT 'Dist' Lev, A.Geo, NULL AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM (
SELECT APEX_Dist AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE APEX_Dist IS NOT NULL
UNION ALL
SELECT PINNACLE_Dist AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE PINNACLE_Dist IS NOT NULL AND APEX_Dist <> PINNACLE_Dist
UNION ALL
SELECT SUMMIT_Dist AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations A
WHERE SUMMIT_Dist IS NOT NULL AND APEX_Dist <> SUMMIT_Dist AND PINNACLE_Dist <> SUMMIT_Dist
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, A.ProgramType, B.Item
GO

--Dist combine 3 teams to one
INSERT INTO DBO.tblGeoActivations
SELECT 'Dist' Lev, A.Geo, NULL AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM (
SELECT APEX_Dist AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE APEX_Dist IS NOT NULL
UNION ALL
SELECT PINNACLE_Dist AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE PINNACLE_Dist IS NOT NULL AND APEX_Dist <> PINNACLE_Dist
UNION ALL
SELECT SUMMIT_Dist AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations A
WHERE SUMMIT_Dist IS NOT NULL AND APEX_Dist <> SUMMIT_Dist AND PINNACLE_Dist <> SUMMIT_Dist
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, B.Item
GO

--Reg combine 3 teams to one
INSERT INTO DBO.tblGeoActivations
SELECT 'Reg' Lev, A.Geo, NULL AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM (
SELECT APEX_Reg AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE APEX_Reg IS NOT NULL
UNION ALL
SELECT PINNACLE_Reg AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE PINNACLE_Reg IS NOT NULL AND APEX_Reg <> PINNACLE_Reg
UNION ALL
SELECT SUMMIT_Reg AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations A
WHERE SUMMIT_Reg IS NOT NULL AND APEX_Reg <> SUMMIT_Reg AND PINNACLE_Reg <> SUMMIT_Reg
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, A.ProgramType, B.Item
GO

--Reg combine 3 teams to one
INSERT INTO DBO.tblGeoActivations
SELECT 'Reg' Lev, A.Geo, NULL AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM (
SELECT APEX_Reg AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE APEX_Reg IS NOT NULL
UNION ALL
SELECT PINNACLE_Reg AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations
WHERE PINNACLE_Reg IS NOT NULL AND APEX_Reg <> PINNACLE_Reg
UNION ALL
SELECT SUMMIT_Reg AS Geo, ID, ProgramType, Date_Name, Time_1stTransaction
FROM DBO.tblActivations A
WHERE SUMMIT_Reg IS NOT NULL AND APEX_Reg <> SUMMIT_Reg AND PINNACLE_Reg <> SUMMIT_Reg
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.Geo, B.Item
GO

--Nation include all data
INSERT INTO DBO.tblGeoActivations
SELECT 'Nat' Lev, '30000' AS Geo, NULL AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY A.ProgramType, B.Item
GO

INSERT INTO DBO.tblGeoActivations
SELECT 'Nat' Lev, '30000' AS Geo, NULL AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
GROUP BY B.Item
GO

--Not aligned data (included in nation)
INSERT INTO DBO.tblGeoActivations
SELECT 'Unk' Lev, '00000' AS Geo, NULL AS Team, A.ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE APEX_Terr IS NULL AND PINNACLE_Terr IS NULL AND SUMMIT_Terr IS NULL
GROUP BY A.ProgramType, B.Item
GO

INSERT INTO DBO.tblGeoActivations
SELECT 'Unk' Lev, '00000' AS Geo, NULL AS Team, 'All' AS ProgramType,
B.Item AS Period, COUNT(*) AS Activations, AVG(Time_1stTransaction) AS Time_1stTransaction
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
WHERE APEX_Terr IS NULL AND PINNACLE_Terr IS NULL AND SUMMIT_Terr IS NULL
GROUP BY B.Item
GO

IF OBJECT_ID('tblGeoActivations_VendorCode') IS NOT NULL
DROP TABLE DBO.tblGeoActivations_VendorCode
GO
SELECT 'Unk' Lev, '00000' AS Geo, NULL AS Team, 'All' AS ProgramType, 
VendorCode, B.Item AS Period, COUNT(*) AS Activations
INTO DBO.tblGeoActivations_VendorCode
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
AND B.ItemType = 'Yearly'
WHERE SUMMIT_Terr IS NULL AND APEX_Terr IS NULL AND PINNACLE_Terr IS NULL
GROUP BY A.VendorCode, B.Item
GO

--Reg/Nat Transactions by Indication
IF OBJECT_ID('tblGeoTransactions_Indication') IS NOT NULL
DROP TABLE DBO.tblGeoTransactions_Indication
GO
--Reg combine 3 teams to one
SELECT 'Reg' Lev, A.Geo, A.Indication,
B.Item AS Period, B.ItemIdx AS PeriodIdx, COUNT(*) AS Transactions
INTO DBO.tblGeoTransactions_Indication
FROM (
SELECT APEX_Reg AS Geo, tblClaimID, Indication, Date_Name
FROM DBO.tblTransactions
WHERE APEX_Reg IS NOT NULL
UNION ALL
SELECT PINNACLE_Reg AS Geo, tblClaimID, Indication, Date_Name
FROM DBO.tblTransactions
WHERE PINNACLE_Reg IS NOT NULL AND APEX_Reg <> PINNACLE_Reg
UNION ALL
SELECT A.SUMMIT_Reg AS Geo, tblClaimID, Indication, Date_Name
FROM DBO.tblTransactions A
WHERE SUMMIT_Reg IS NOT NULL AND APEX_Reg <> SUMMIT_Reg AND PINNACLE_Reg <> SUMMIT_Reg
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date 
AND B.ItemType = 'Monthly'
WHERE A.Date_Name <= (SELECT DISTINCT Month_End FROM tblCalendar where Month_ID = 1)
GROUP BY A.Geo, A.Indication, B.Item, B.ItemIdx, B.Id
GO

--Nation include all data
INSERT INTO DBO.tblGeoTransactions_Indication
SELECT 'Nat' Lev, '30000' AS Geo, A.Indication, 
B.Item AS Period, B.ItemIdx AS PeriodIdx, COUNT(*) AS Transactions
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
AND B.ItemType = 'Monthly'
WHERE A.Date_Name <= (SELECT DISTINCT Month_End FROM tblCalendar where Month_ID = 1)
GROUP BY A.Indication, B.Item, B.ItemIdx, B.Id
GO

--Not aligned data (included in nation)
INSERT INTO DBO.tblGeoTransactions_Indication
SELECT 'Unk' Lev, '00000' AS Geo, A.Indication, 
B.Item AS Period, B.ItemIdx AS PeriodIdx, COUNT(*) AS Transactions
FROM DBO.tblTransactions A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
AND B.ItemType = 'Monthly'
WHERE SUMMIT_Terr IS NULL AND APEX_Terr IS NULL AND PINNACLE_Terr IS NULL
AND A.Date_Name <= (SELECT DISTINCT Month_End FROM tblCalendar where Month_ID = 1)
GROUP BY A.Indication, B.Item, B.ItemIdx, B.Id
GO

--Reg/Nat Activations by Indication
IF OBJECT_ID('tblGeoActivations_Indication') IS NOT NULL
DROP TABLE DBO.tblGeoActivations_Indication
GO
--Reg combine 3 teams to one
SELECT 'Reg' Lev, A.Geo, A.Indication,
B.Item AS Period, B.ItemIdx AS PeriodIdx, COUNT(*) AS Activations
INTO DBO.tblGeoActivations_Indication
FROM (
SELECT APEX_Reg AS Geo, ID, Indication, Date_Name
FROM DBO.tblActivations
WHERE APEX_Reg IS NOT NULL
UNION ALL
SELECT PINNACLE_Reg AS Geo, ID, Indication, Date_Name
FROM DBO.tblActivations
WHERE PINNACLE_Reg IS NOT NULL AND APEX_Reg <> PINNACLE_Reg
UNION ALL
SELECT A.SUMMIT_Reg AS Geo, ID, Indication, Date_Name
FROM DBO.tblActivations A
WHERE SUMMIT_Reg IS NOT NULL AND APEX_Reg <> SUMMIT_Reg AND PINNACLE_Reg <> SUMMIT_Reg
) A INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
AND B.ItemType = 'Monthly'
WHERE A.Date_Name <= (SELECT DISTINCT Month_End FROM tblCalendar where Month_ID = 1)
GROUP BY A.Geo, A.Indication, B.Item, B.ItemIdx, B.Id
GO

--Nation include all data
INSERT INTO DBO.tblGeoActivations_Indication
SELECT 'Nat' Lev, '30000' AS Geo, A.Indication, 
B.Item AS Period, B.ItemIdx AS PeriodIdx, COUNT(*) AS Activations
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
AND B.ItemType = 'Monthly'
WHERE A.Date_Name <= (SELECT DISTINCT Month_End FROM tblCalendar where Month_ID = 1)
GROUP BY A.Indication, B.Item, B.ItemIdx, B.Id
GO

--Not aligned data (included in nation)
INSERT INTO DBO.tblGeoActivations_Indication
SELECT 'Unk' Lev, '00000' AS Geo, A.Indication, 
B.Item AS Period, B.ItemIdx AS PeriodIdx, COUNT(*) AS Activations
FROM DBO.tblActivations A
INNER JOIN DBO.tblDateConfig B ON A.Date_Name BETWEEN B.Start_Date AND B.End_Date
AND B.ItemType = 'Monthly'
WHERE SUMMIT_Terr IS NULL AND APEX_Terr IS NULL AND PINNACLE_Terr IS NULL
AND A.Date_Name <= (SELECT DISTINCT Month_End FROM tblCalendar where Month_ID = 1)
GROUP BY A.Indication, B.Item, B.ItemIdx, B.Id
GO


--OutputAll(tblGeo)
IF OBJECT_ID('tblGeo') IS NOT NULL
DROP TABLE DBO.tblGeo
GO
SELECT TERRITORY_NUMBER AS Terr, TERRITORY_NAME AS TerrName, FIELD_FORCE_NAME AS Team, 
	LEVEL2_TERRITORY_NUMBER AS Dist, LEVEL2_TERRITORY_NAME AS DistName, 
	LEVEL3_TERRITORY_NUMBER AS Reg, LEVEL3_TERRITORY_NAME AS RegName,
	LEVEL5_TERRITORY_NUMBER AS Nat, 'Nation' AS NatName
INTO DBO.tblGeo
FROM Axtria_dev.DBO.tblImportTerrHierarchy 
WHERE TERRITORY_LEVEL_CODE =1
AND FIELD_FORCE_NAME IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
GO

--SELECT * FROM tblGeo

IF OBJECT_ID('V_OutputGeo') IS NOT NULL
DROP TABLE V_OutputGeo
GO
CREATE VIEW V_OutputGeo
AS
SELECT 'Terr' AS Lev, Terr AS Geo, TerrName AS GeoName
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 'Dist' AS Lev, Dist AS Geo, DistName AS GeoName
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 'Reg' AS Lev, Reg AS Geo, RegName AS GeoName
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 'Nat' AS Lev, Nat AS Geo, NatName AS GeoName
FROM DBO.tblGeo
UNION ALL
SELECT 'Unk' AS Lev, '00000' AS Geo, 'Unknown' AS GeoName
GO
/*
USE Axtria_dev
GO
ALTER VIEW V_RepRoster
AS
SELECT TERRITORY_NUMBER AS Geo, STAFF_EMAIL AS Email
FROM Axtria_dev.DBO.tblImportRepTerr_Test
WHERE PRIMARY_TERRITORY = 'Y' AND IS_ACTIVE = 'Y'
AND TERRITORY_NUMBER IN (SELECT Geo FROM Enbrel_GEOlevelreport.DBO.V_OutputGeo)
--SELECT [Territory #] AS Geo, Email
--FROM Axtria_dev.DBO.inINBURoster
--WHERE Flag = 'PRI' AND FFName IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
--AND [Territory #] IN (SELECT Geo FROM Enbrel_GEOlevelreport.DBO.V_OutputGeo)
GO

select * from Axtria_dev.DBO.tblImportRepTerr_Test

CREATE VIEW V_DateConfig
AS
SELECT End_Date AS CW
FROM Enbrel_GEOlevelreport.DBO.tblDateConfig WHERE Item = 'CW'
GO

SELECT * FROM Enbrel_GEOlevelreport.DBO.V_OutputGeo
WHERE GEO NOT IN (
SELECT TERRITORY_NUMBER FROM Axtria_dev.DBO.tblImportRepTerr
WHERE PRIMARY_TERRITORY = 'Y' AND IS_ACTIVE = 'Y'
)

SELECT * FROM Enbrel_GEOlevelreport.DBO.V_OutputGeo
WHERE GEO NOT IN (
SELECT [Territory #] FROM Axtria_dev.DBO.inINBURoster
WHERE Flag = 'PRI' AND FFName IN ('INBU APEX SF','INBU PINNACLE SF','INBU SUMMIT SF')
)

SELECT * INTO Axtria_dev.DBO.tblImportRepTerr_Test
FROM Axtria_dev.DBO.tblImportRepTerr WHERE 1 = 0

INSERT INTO Axtria_dev.DBO.tblImportRepTerr_Test (STAFF_EMAIL, TERRITORY_NUMBER, PRIMARY_TERRITORY, IS_ACTIVE)
VALUES ('hunter.ruan@xsunt.com', '30000', 'Y', 'Y')
INSERT INTO Axtria_dev.DBO.tblImportRepTerr_Test (STAFF_EMAIL, TERRITORY_NUMBER, PRIMARY_TERRITORY, IS_ACTIVE)
VALUES ('czhu@xsunt.com', '3P000', 'Y', 'Y')
INSERT INTO Axtria_dev.DBO.tblImportRepTerr_Test (STAFF_EMAIL, TERRITORY_NUMBER, PRIMARY_TERRITORY, IS_ACTIVE)
VALUES ('vicky.chen@xsunt.com', '3PA00', 'Y', 'Y')
INSERT INTO Axtria_dev.DBO.tblImportRepTerr_Test (STAFF_EMAIL, TERRITORY_NUMBER, PRIMARY_TERRITORY, IS_ACTIVE)
VALUES ('hannah.zheng@xsunt.com', '3PA01', 'Y', 'Y')
*/


IF OBJECT_ID('tblGeoRanking') IS NOT NULL
DROP TABLE DBO.tblGeoRanking
GO
--National Rank in selected team
SELECT T.Lev, T.Geo, T.Team,
	   CASE WHEN B.Transactions = 0 THEN NULL ELSE A.Transactions*1.0/B.Transactions-1 END AS YTDTransactionsGrowth, 
	   CASE WHEN D.Activations = 0 THEN NULL ELSE C.Activations*1.0/D.Activations-1 END AS YTDActivationsGrowth,
	   CONVERT(INT,NULL) AS TransactionsRnk, CONVERT(INT,NULL) AS ActivationsRnk
INTO DBO.tblGeoRanking
FROM (
SELECT 'Terr' AS Lev, Terr AS Geo, Team FROM DBO.tblGeo
) T LEFT JOIN (
SELECT * FROM DBO.tblGeoTransactions WHERE Lev = 'Terr' AND Period = 'CYTD' AND ProgramType = 'All') A
ON A.Geo = T.Geo AND A.Team = T.Team
LEFT JOIN (
SELECT * FROM DBO.tblGeoTransactions WHERE Lev = 'Terr' AND Period = 'PYTD' AND ProgramType = 'All') B
ON B.Geo = T.Geo AND B.Team = T.Team
LEFT JOIN (
SELECT * FROM DBO.tblGeoActivations WHERE Lev = 'Terr' AND Period = 'CYTD' AND ProgramType = 'All') C
ON C.Geo = T.Geo AND C.Team = T.Team
LEFT JOIN (
SELECT * FROM DBO.tblGeoActivations WHERE Lev = 'Terr' AND Period = 'PYTD' AND ProgramType = 'All') D
ON D.Geo = T.Geo AND D.Team = T.Team
GO

UPDATE A
SET TransactionsRnk = B.TransactionsRnk, ActivationsRnk = B.ActivationsRnk
FROM DBO.tblGeoRanking A
INNER JOIN (
	SELECT Geo, Team, 
	RANK () OVER(PARTITION BY Team ORDER BY YTDTransactionsGrowth DESC) AS TransactionsRnk,
	RANK () OVER(PARTITION BY Team ORDER BY YTDActivationsGrowth DESC) AS ActivationsRnk
	FROM DBO.tblGeoRanking
	WHERE Lev = 'Terr'
) B ON A.Geo = B.Geo
WHERE Lev = 'Terr'
GO

--National Rank for Dist
INSERT INTO DBO.tblGeoRanking
SELECT T.Lev, T.Geo, NULL AS Team, 
	   CASE WHEN B.Transactions = 0 THEN NULL ELSE A.Transactions*1.0/B.Transactions-1 END AS YTDTransactionsGrowth, 
	   CASE WHEN D.Activations = 0 THEN NULL ELSE C.Activations*1.0/D.Activations-1 END AS YTDActivationsGrowth,
	   CONVERT(INT,NULL) AS TransactionsRnk, CONVERT(INT,NULL) AS ActivationsRnk
FROM (
SELECT DISTINCT 'Dist' AS Lev, Dist AS Geo FROM DBO.tblGeo
) T LEFT JOIN (
SELECT * FROM DBO.tblGeoTransactions WHERE Lev = 'Dist' AND Period = 'CYTD' AND ProgramType = 'All') A
ON A.Geo = T.Geo
LEFT JOIN (
SELECT * FROM DBO.tblGeoTransactions WHERE Lev = 'Dist' AND Period = 'PYTD' AND ProgramType = 'All') B
ON B.Geo = T.Geo
LEFT JOIN (
SELECT * FROM DBO.tblGeoActivations WHERE Lev = 'Dist' AND Period = 'CYTD' AND ProgramType = 'All') C
ON C.Geo = T.Geo
LEFT JOIN (
SELECT * FROM DBO.tblGeoActivations WHERE Lev = 'Dist' AND Period = 'PYTD' AND ProgramType = 'All') D
ON D.Geo = T.Geo
GO

UPDATE A
SET TransactionsRnk = B.TransactionsRnk, ActivationsRnk = B.ActivationsRnk
FROM DBO.tblGeoRanking A
INNER JOIN (
	SELECT Geo, 
	RANK () OVER(ORDER BY YTDTransactionsGrowth DESC) AS TransactionsRnk,
	RANK () OVER(ORDER BY YTDActivationsGrowth DESC) AS ActivationsRnk
	FROM DBO.tblGeoRanking
	WHERE Lev = 'Dist'
) B ON A.Geo = B.Geo
WHERE Lev = 'Dist'
GO

--National Rank for Reg
INSERT INTO DBO.tblGeoRanking
SELECT T.Lev, T.Geo, NULL AS Team, 
	   CASE WHEN B.Transactions = 0 THEN NULL ELSE A.Transactions*1.0/B.Transactions-1 END AS YTDTransactionsGrowth, 
	   CASE WHEN D.Activations = 0 THEN NULL ELSE C.Activations*1.0/D.Activations-1 END AS YTDActivationsGrowth,
	   CONVERT(INT,NULL) AS TransactionsRnk, CONVERT(INT,NULL) AS ActivationsRnk
FROM (
SELECT DISTINCT 'Reg' AS Lev, Reg AS Geo FROM DBO.tblGeo
) T LEFT JOIN (
SELECT * FROM DBO.tblGeoTransactions WHERE Lev = 'Reg' AND Period = 'CYTD' AND ProgramType = 'All') A
ON A.Geo = T.Geo
LEFT JOIN (
SELECT * FROM DBO.tblGeoTransactions WHERE Lev = 'Reg' AND Period = 'PYTD' AND ProgramType = 'All') B
ON B.Geo = T.Geo
LEFT JOIN (
SELECT * FROM DBO.tblGeoActivations WHERE Lev = 'Reg' AND Period = 'CYTD' AND ProgramType = 'All') C
ON C.Geo = T.Geo
LEFT JOIN (
SELECT * FROM DBO.tblGeoActivations WHERE Lev = 'Reg' AND Period = 'PYTD' AND ProgramType = 'All') D
ON D.Geo = T.Geo
GO

UPDATE A
SET TransactionsRnk = B.TransactionsRnk, ActivationsRnk = B.ActivationsRnk
FROM DBO.tblGeoRanking A
INNER JOIN (
	SELECT Geo, 
	RANK () OVER(ORDER BY YTDTransactionsGrowth DESC) AS TransactionsRnk,
	RANK () OVER(ORDER BY YTDActivationsGrowth DESC) AS ActivationsRnk
	FROM DBO.tblGeoRanking
	WHERE Lev = 'Reg'
) B ON A.Geo = B.Geo
WHERE Lev = 'Reg'
GO

--Territory Level
--OutputTerr1(OutputDashboardData)
IF OBJECT_ID('OutputDashboardData') IS NOT NULL
DROP TABLE DBO.OutputDashboardData
GO
SELECT 1 AS A, Terr AS B, TerrName AS C, Team AS D, CONVERT(VARCHAR(20),(SELECT DISTINCT MONTH(Month_Start) FROM tblCalendar where Month_ID = 1)) AS E, Terr AS Terr
INTO DBO.OutputDashboardData
FROM DBO.tblGeo
UNION ALL
SELECT 2, DistName, RegName, NatName, (SELECT CONVERT(VARCHAR(10),End_Date,111) FROM DBO.tblDateConfig WHERE Item = 'CW'), Terr
FROM DBO.tblGeo
UNION ALL
SELECT 3, 'CYTD', CONVERT(VARCHAR(20),ActivationsRnk), CONVERT(VARCHAR(20),TransactionsRnk),'', A.Terr
FROM DBO.tblGeo A 
LEFT JOIN DBO.tblGeoRanking B ON A.Terr = B.Geo
--All
UNION ALL
SELECT B.ID + 3, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Terr' AND C.ProgramType = 'All' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Terr' AND D.ProgramType = 'All' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 9, B.Period + ' District', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'All' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'All' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 15, B.Period + ' Region', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'All' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'All' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 21, B.Period + ' Nation', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'All' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'All' AND B.Period = D.Period
UNION ALL
SELECT 28, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'All', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Terr' AND C.ProgramType = 'All'
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Terr' AND D.ProgramType = 'All'
UNION ALL
SELECT 29, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'All', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Dist' AND C.ProgramType = 'All'
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Dist' AND D.ProgramType = 'All'
UNION ALL
SELECT 30, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'All', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Reg' AND C.ProgramType = 'All'
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Reg' AND D.ProgramType = 'All'
UNION ALL
SELECT 31, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'All', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Nat' AND C.ProgramType = 'All'
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Nat' AND D.ProgramType = 'All'
--Retail
UNION ALL
SELECT B.ID + 31, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Terr' AND C.ProgramType = 'Retail' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Terr' AND D.ProgramType = 'Retail' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 37, B.Period + ' District', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'Retail' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'Retail' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 43, B.Period + ' Region', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'Retail' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'Retail' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 49, B.Period + ' Nation', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'Retail' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'Retail' AND B.Period = D.Period
UNION ALL
SELECT 56, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'Retail', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Terr' AND C.ProgramType = 'Retail'
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Terr' AND D.ProgramType = 'Retail'
UNION ALL
SELECT 57, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'Retail', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Dist' AND C.ProgramType = 'Retail'
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Dist' AND D.ProgramType = 'Retail'
UNION ALL
SELECT 58, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'Retail', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Reg' AND C.ProgramType = 'Retail'
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Reg' AND D.ProgramType = 'Retail'
UNION ALL
SELECT 59, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'Retail', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Nat' AND C.ProgramType = 'Retail'
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Nat' AND D.ProgramType = 'Retail'
--Debit
UNION ALL
SELECT B.ID + 59, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Terr' AND C.ProgramType = 'Debit' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Terr' AND D.ProgramType = 'Debit' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 65, B.Period + ' District', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'Debit' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'Debit' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 71, B.Period + ' Region', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'Debit' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'Debit' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 77, B.Period + ' Nation', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'Debit' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'Debit' AND B.Period = D.Period
UNION ALL
SELECT 84, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', NULL, 'Debit', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Terr' AND C.ProgramType = 'Debit'
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Terr' AND D.ProgramType = 'Debit'
UNION ALL
SELECT 85, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'Debit', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Dist' AND C.ProgramType = 'Debit'
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Dist' AND D.ProgramType = 'Debit'
UNION ALL
SELECT 86, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'Debit', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Reg' AND C.ProgramType = 'Debit'
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Reg' AND D.ProgramType = 'Debit'
UNION ALL
SELECT 87, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'Debit', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Nat' AND C.ProgramType = 'Debit'
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
WHERE D.Period in ('C52W') AND D.Lev = 'Nat' AND D.ProgramType = 'Debit'
--DMR
UNION ALL
SELECT B.ID + 87, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Terr' AND C.ProgramType = 'DMR' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Terr' AND D.ProgramType = 'DMR' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 93, B.Period + ' District', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'DMR' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'DMR' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 99, B.Period + ' Region', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'DMR' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'DMR' AND B.Period = D.Period
UNION ALL
SELECT B.ID + 105, B.Period + ' Nation', CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'DMR' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'DMR' AND B.Period = D.Period
UNION ALL
SELECT 112, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'DMR', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Terr' AND C.ProgramType = 'DMR'
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Terr' AND D.ProgramType = 'DMR'
UNION ALL
SELECT 113, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'DMR', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Dist' AND C.ProgramType = 'DMR'
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Dist' AND D.ProgramType = 'DMR'
UNION ALL
SELECT 114, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'DMR', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Reg' AND C.ProgramType = 'DMR'
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Reg' AND D.ProgramType = 'DMR'
UNION ALL
SELECT 115, CONVERT(VARCHAR(20),C.AvgCopay), CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days', '', 'DMR', A.Terr FROM DBO.tblGeo A
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Nat' AND C.ProgramType = 'DMR'
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Nat' AND D.ProgramType = 'DMR'
--All
UNION ALL
SELECT 116, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'All', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 116 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'All', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT 129, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'All', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 129 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Retail'
UNION ALL
SELECT 142, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Retail', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 142 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Retail', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT 155, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Retail', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 155 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Debit'
UNION ALL
SELECT 168, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Debit', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 168 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Debit', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT 181, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Debit', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 181 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'DMR'
UNION ALL
SELECT 194, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'DMR', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 194 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'DMR', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT 207, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'DMR', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT B.ID + 207 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Terr FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Terr' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Terr = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Terr' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--Top 10 Pharmacy
UNION ALL
SELECT 220, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT 220 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Terr FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Terr = C.Geo
AND C.Lev = 'Terr' AND C.ProgramType = 'All'
UNION ALL
SELECT 220 + 11, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT 220 + 11 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Terr FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Terr = C.Geo
AND C.Lev = 'Terr' AND C.ProgramType = 'Retail'
UNION ALL
SELECT 220 + 22, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT 220 + 22 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Terr FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Terr = C.Geo
AND C.Lev = 'Terr' AND C.ProgramType = 'Debit'
UNION ALL
SELECT 220 + 33, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Terr 
FROM DBO.tblGeo
UNION ALL
SELECT 220 + 33 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Terr FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Terr = C.Geo
AND C.Lev = 'Terr' AND C.ProgramType = 'DMR'

--District Level

--OutputDist1(OutputDashboardData1)
IF OBJECT_ID('OutputDashboardData1') IS NOT NULL
DROP TABLE DBO.OutputDashboardData1
GO
SELECT DISTINCT 1 AS A, Dist AS B, CONVERT(VARCHAR(50),'') AS C, CONVERT(VARCHAR(20),'') AS D, CONVERT(VARCHAR(20),(SELECT DISTINCT MONTH(Month_Start) FROM tblCalendar where Month_ID = 1)) AS E, Dist AS Dist
INTO DBO.OutputDashboardData1
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 2, DistName, Reg, NatName, (SELECT CONVERT(VARCHAR(10),End_Date,111) FROM DBO.tblDateConfig WHERE Item = 'CW'), Dist
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 3, 'CYTD', CONVERT(VARCHAR(20),ActivationsRnk), CONVERT(VARCHAR(20),TransactionsRnk),'', A.Dist
FROM DBO.tblGeo A 
LEFT JOIN DBO.tblGeoRanking B ON A.Dist = B.Geo
--All
UNION ALL
SELECT DISTINCT B.ID + 3, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'All' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'All' AND B.Period = D.Period
--Retail
UNION ALL
SELECT DISTINCT B.ID + 9, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'Retail' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'Retail' AND B.Period = D.Period
--Debit
UNION ALL
SELECT DISTINCT B.ID + 15, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'Debit' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'Debit' AND B.Period = D.Period
--DMR
UNION ALL
SELECT DISTINCT B.ID + 21, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Dist' AND C.ProgramType = 'DMR' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Dist' AND D.ProgramType = 'DMR' AND B.Period = D.Period
--All
UNION ALL
SELECT DISTINCT 28, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'All', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 28 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'All', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 41, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'All', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 41 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Retail'
UNION ALL
SELECT DISTINCT 54, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Retail', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 54 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Retail', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 67, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Retail', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 67 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Debit'
UNION ALL
SELECT DISTINCT 80, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Debit', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 80 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Debit', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 93, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Debit', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 93 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'DMR'
UNION ALL
SELECT DISTINCT 106, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'DMR', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 106 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'DMR', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 119, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'DMR', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 119 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Dist FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Dist' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Dist = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Dist' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--Top 10 Pharmacy
UNION ALL
SELECT DISTINCT 132, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 132 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Dist FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Dist = C.Geo
AND C.Lev = 'Dist' AND C.ProgramType = 'All'
UNION ALL
SELECT DISTINCT 132 + 11, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 132 + 11 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Dist FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Dist = C.Geo
AND C.Lev = 'Dist' AND C.ProgramType = 'Retail'
UNION ALL
SELECT DISTINCT 132 + 22, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 132 + 22 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Dist FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Dist = C.Geo
AND C.Lev = 'Dist' AND C.ProgramType = 'Debit'
UNION ALL
SELECT DISTINCT 132 + 33, 'Rank', 'Pharmacy Name', 'Volume of Transactions', 'Program_Type', Dist 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 132 + 33 + C.Rnk ID, CONVERT(VARCHAR(20),C.Rnk) Rnk, CONVERT(VARCHAR(50),C.PharmacyName) PharmacyName, CONVERT(VARCHAR(20),C.Transactions) Transactions, C.ProgramType, A.Dist FROM DBO.tblGeo A
INNER JOIN DBO.tblGeoTop10Pharmacies C ON A.Dist = C.Geo
AND C.Lev = 'Dist' AND C.ProgramType = 'DMR'
GO

--OutputDist2(OutputDashboardData2)
IF OBJECT_ID('OutputDashboardData2') IS NOT NULL
DROP TABLE DBO.OutputDashboardData2
GO
--Dist
SELECT 2 AS Idx, A.ProgramType, Geo, GeoName, E, F, G, H, I, J, K, L, M, N, A.Dist 
INTO DBO.OutputDashboardData2
FROM (
SELECT DISTINCT B.ProgramType, A.Dist AS Geo, A.DistName AS GeoName,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, 
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) B ON A.Dist = B.Dist AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, 
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) C ON A.Dist = C.Dist AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Dist 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
) D ON A.Dist = D.Dist AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Dist, ActivationsRnk AS M, TransactionsRnk AS N
FROM tblGeoRanking
) E ON A.Geo = E.Dist

--Region
INSERT INTO DBO.OutputDashboardData2
SELECT 4 AS Idx, A.ProgramType, Geo, GeoName, E, F, G, H, I, J, K, L, M, N, A.Dist FROM (
SELECT DISTINCT B.ProgramType, A.Reg AS Geo, A.RegName AS GeoName,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Reg' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Reg' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Reg,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Reg' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Reg' AND B.ProgramType = F.ProgramType
) B ON A.Dist = B.Dist AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, 
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Reg' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Reg' AND B.ProgramType = F.ProgramType
) C ON A.Dist = C.Dist AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Dist 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
) D ON A.Dist = D.Dist AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Reg, ActivationsRnk AS M, TransactionsRnk AS N
FROM tblGeoRanking
) E ON A.Geo = E.Reg
GO
--Nation
INSERT INTO DBO.OutputDashboardData2
SELECT 5 AS Idx, A.ProgramType, 'Nation', '-', E, F, G, H, I, J, K, L, '-', '-', A.Dist FROM (
SELECT DISTINCT B.ProgramType, A.Reg AS Geo, A.RegName AS GeoName,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Nat = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Nat' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Nat = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Nat' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Nat,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Nat = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Nat' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Nat = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Nat' AND B.ProgramType = F.ProgramType
) B ON A.Dist = B.Dist AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, 
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Nat = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Nat' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Nat = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Nat' AND B.ProgramType = F.ProgramType
) C ON A.Dist = C.Dist AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Dist 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
) D ON A.Dist = D.Dist AND A.ProgramType = D.ProgramType
GO
--Territory
INSERT INTO DBO.OutputDashboardData2
SELECT 6 AS Idx, A.ProgramType, Geo, GeoName, E, F, G, H, I, J, K, L, M, N, A.Dist FROM (
SELECT DISTINCT B.ProgramType, A.Terr AS Geo, A.Team AS GeoName,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) B ON A.Dist = B.Dist AND A.ProgramType = B.ProgramType AND A.Geo = B.Terr
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Dist FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) C ON A.Dist = C.Dist AND A.ProgramType = C.ProgramType AND A.Geo = C.Terr
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Dist 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
) D ON A.Dist = D.Dist AND A.ProgramType = D.ProgramType AND A.Geo = D.Terr
LEFT JOIN (
SELECT Geo AS Terr, ActivationsRnk AS M, TransactionsRnk AS N
FROM tblGeoRanking
) E ON A.Geo = E.Terr
GO

--Nation Level

--OutputNat1(OutputDashboardData1_Nat)
IF OBJECT_ID('OutputDashboardData1_Nat') IS NOT NULL
DROP TABLE DBO.OutputDashboardData1_Nat
GO
SELECT DISTINCT 1 AS A, (SELECT CONVERT(VARCHAR(10),End_Date,111) FROM DBO.tblDateConfig WHERE Item = 'CW') AS B, CONVERT(VARCHAR(20),'') AS C, CONVERT(VARCHAR(20),'') AS D, CONVERT(VARCHAR(20),(SELECT DISTINCT MONTH(Month_Start) FROM tblCalendar where Month_ID = 1)) AS E, Nat
INTO DBO.OutputDashboardData1_Nat
FROM DBO.tblGeo
--All
UNION ALL
SELECT DISTINCT B.ID + 2, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'All' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'All' AND B.Period = D.Period
--Retail
UNION ALL
SELECT DISTINCT B.ID + 8, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'Retail' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'Retail' AND B.Period = D.Period
--Debit
UNION ALL
SELECT DISTINCT B.ID + 14, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'Debit' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'Debit' AND B.Period = D.Period
--DMR
UNION ALL
SELECT DISTINCT B.ID + 20, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Nat' AND C.ProgramType = 'DMR' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Nat' AND D.ProgramType = 'DMR' AND B.Period = D.Period
--All
UNION ALL
SELECT DISTINCT 27, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'All', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 27 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'All', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 40, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'All', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 40 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Retail'
UNION ALL
SELECT DISTINCT 53, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Retail', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 53 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Retail', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 66, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Retail', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 66 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Debit'
UNION ALL
SELECT DISTINCT 79, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Debit', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 79 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Debit', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 92, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Debit', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 92 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'DMR'
UNION ALL
SELECT DISTINCT 105, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'DMR', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 105 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'DMR', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 118, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'DMR', Nat 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 118 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Nat FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Nat' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Nat = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Nat' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
GO

--OutputNat2(OutputDashboardData2_Nat)
IF OBJECT_ID('OutputDashboardData2_Nat') IS NOT NULL
DROP TABLE DBO.OutputDashboardData2_Nat
GO
--Nation
SELECT 2 AS A, A.ProgramType AS B, CONVERT(VARCHAR(20),A.Geo) AS C, CONVERT(VARCHAR(20),A.GeoName) AS D, E, F, G, H, I, J, K, L, CONVERT(VARCHAR(20),'-') AS M, CONVERT(VARCHAR(20),'-') AS N, A.Nat 
INTO DBO.OutputDashboardData2_Nat
FROM (
SELECT DISTINCT B.ProgramType, 'Nation' AS Geo, '-' AS GeoName,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Nat = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Nat' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Nat = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Nat' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Nat = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Nat' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Nat = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Nat' AND B.ProgramType = F.ProgramType
) B ON A.Nat = B.Nat AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, 
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Nat = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Nat' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Nat = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Nat' AND B.ProgramType = F.ProgramType
) C ON A.Nat = C.Nat AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Nat 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Nat = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Nat' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Nat = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Nat' AND B.ProgramType = D.ProgramType
) D ON A.Nat = D.Nat AND A.ProgramType = D.ProgramType
GO

--Region
INSERT INTO DBO.OutputDashboardData2_Nat
SELECT 3 AS Idx, A.ProgramType, Geo, GeoName, E, F, G, H, I, J, K, L, M, N, A.Nat FROM (
SELECT DISTINCT B.ProgramType, A.Reg AS Geo, A.RegName AS GeoName,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Reg' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Reg' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Reg,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Reg' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Reg' AND B.ProgramType = F.ProgramType
) B ON A.Geo = B.Reg AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Reg,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Reg' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Reg' AND B.ProgramType = F.ProgramType
) C ON A.Geo = C.Reg AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Reg, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Nat 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Reg' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Reg' AND B.ProgramType = D.ProgramType
) D ON A.Geo = D.Reg AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Reg, ActivationsRnk AS M, TransactionsRnk AS N
FROM tblGeoRanking
) E ON A.Geo = E.Reg
GO

--Unknown
INSERT INTO DBO.OutputDashboardData2_Nat
SELECT 3 AS Idx, A.ProgramType, '', 'Unknown', E, F, G, H, I, J, K, L, M, N, A.Nat FROM (
SELECT DISTINCT B.ProgramType, A.Reg AS Geo,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Nat FROM (SELECT '00000' AS Reg, '30000' AS Nat) A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Unk' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Unk' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Unk' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Unk' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Reg,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Nat FROM (SELECT '00000' AS Reg, '30000' AS Nat) A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Unk' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Unk' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Unk' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Unk' AND B.ProgramType = F.ProgramType
) B ON A.Geo = B.Reg AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Reg,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Nat FROM (SELECT '00000' AS Reg, '30000' AS Nat) A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Unk' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Unk' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Reg = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Unk' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Reg = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Unk' AND B.ProgramType = F.ProgramType
) C ON A.Geo = C.Reg AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Reg, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Nat 
FROM (SELECT '00000' AS Reg, '30000' AS Nat) A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Unk' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Unk' AND B.ProgramType = D.ProgramType
) D ON A.Geo = D.Reg AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Reg, ActivationsRnk AS M, TransactionsRnk AS N
FROM tblGeoRanking
) E ON A.Geo = E.Reg
GO


--Region Level

--OutputReg1(OutputDashboardData1_Reg)
IF OBJECT_ID('OutputDashboardData1_Reg') IS NOT NULL
DROP TABLE DBO.OutputDashboardData1_Reg
GO
SELECT DISTINCT 1 AS A, RegName AS B, Reg AS C, (SELECT CONVERT(VARCHAR(10),End_Date,111) FROM DBO.tblDateConfig WHERE Item = 'CW') AS D, CONVERT(VARCHAR(20),(SELECT DISTINCT MONTH(Month_Start) FROM tblCalendar where Month_ID = 1)) AS E, Reg
INTO DBO.OutputDashboardData1_Reg
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT 2, 'CYTD', CONVERT(VARCHAR(20),ActivationsRnk), CONVERT(VARCHAR(20),TransactionsRnk),'', A.Reg
FROM DBO.tblGeo A 
LEFT JOIN DBO.tblGeoRanking B ON A.Reg = B.Geo
--All
UNION ALL
SELECT DISTINCT B.ID + 2, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'All' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'All' AND B.Period = D.Period
--Retail
UNION ALL
SELECT DISTINCT B.ID + 8, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'Retail' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'Retail' AND B.Period = D.Period
--Debit
UNION ALL
SELECT DISTINCT B.ID + 14, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'Debit' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'Debit' AND B.Period = D.Period
--DMR
UNION ALL
SELECT DISTINCT B.ID + 20, B.Period, CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Period' AND ItemIdx IS NOT NULL) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND C.Lev = 'Reg' AND C.ProgramType = 'DMR' AND B.Period = C.Period
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period in ('CYTD','PYTD','C13W','P13W','CW','PW') AND D.Lev = 'Reg' AND D.ProgramType = 'DMR' AND B.Period = D.Period
--All
UNION ALL
SELECT DISTINCT 27, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'All', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 27 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'All', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 40, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'All', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 40 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'All', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'All' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'All' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Retail'
UNION ALL
SELECT DISTINCT 53, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Retail', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 53 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Retail', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 66, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Retail', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 66 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Retail', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'Retail' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'Retail' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'Debit'
UNION ALL
SELECT DISTINCT 79, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'Debit', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 79 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'Debit', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 92, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'Debit', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 92 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'Debit', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'Debit' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'Debit' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
--'DMR'
UNION ALL
SELECT DISTINCT 105, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Activations', 'DMR', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 105 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Activations), CONVERT(VARCHAR(20),C.Activations), 'DMR', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoActivations C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoActivations D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
UNION ALL
SELECT DISTINCT 118, 'Month', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) - 1 FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', CONVERT(VARCHAR(4),(SELECT YEAR(End_Date) FROM DBO.TBLDATECONFIG WHERE Item = 'CW'))+' Transactions', 'DMR', Reg 
FROM DBO.tblGeo
UNION ALL
SELECT DISTINCT B.ID + 118 - 12, LEFT(B.Period,3), CONVERT(VARCHAR(20),D.Transactions), CONVERT(VARCHAR(20),C.Transactions), 'DMR', A.Reg FROM DBO.tblGeo A
INNER JOIN (SELECT ItemIdx AS ID, Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Reg = C.Geo
AND C.Period LIKE '%-%' AND C.Lev = 'Reg' AND C.ProgramType = 'DMR' AND B.Period = C.Period AND C.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 13 AND 24)
LEFT JOIN DBO.tblGeoTransactions D ON A.Reg = D.Geo
AND D.Period LIKE '%-%' AND D.Lev = 'Reg' AND D.ProgramType = 'DMR' AND B.Period = LEFT(D.Period,4)+CONVERT(VARCHAR(2),RIGHT(RIGHT(D.Period,2)+1,2)) AND D.Period IN (SELECT Item AS Period FROM DBO.tblDateConfig WHERE ItemType = 'Monthly' AND ItemIdx BETWEEN 1 AND 12)
GO

--OutputReg2(OutputDashboardData2_Reg)
IF OBJECT_ID('OutputDashboardData2_Reg') IS NOT NULL
DROP TABLE DBO.OutputDashboardData2_Reg
GO
--Nation & Region
SELECT A, B, C, CONVERT(VARCHAR(50),D) AS D, E, F, G, H, I, J, K, L, M, N, B.Reg
INTO DBO.OutputDashboardData2_Reg
FROM DBO.OutputDashboardData2_Nat A
INNER JOIN (SELECT DISTINCT Reg FROM DBO.tblGeo) B ON 1 = 1
GO
--District
INSERT INTO DBO.OutputDashboardData2_Reg
SELECT 4 AS Idx, A.ProgramType, Geo, GeoName, E, F, G, H, I, J, K, L, M, N, A.Reg 
FROM (
SELECT DISTINCT B.ProgramType, A.Dist AS Geo, A.DistName AS GeoName,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS E, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS H,
A.Reg FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Dist,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS F, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS I,
A.Reg FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) B ON A.Geo = B.Dist AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Dist,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Reg FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) C ON A.Geo = C.Dist AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Dist, CONVERT(VARCHAR(20),C.AvgCopay) AS K, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS L, A.Reg 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
) D ON A.Geo = D.Dist AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Dist, ActivationsRnk AS M, TransactionsRnk AS N
FROM tblGeoRanking
) E ON A.Geo = E.Dist
GO


--Nation District Details 
--OutputNat3(OutputDistrictDetails)
IF OBJECT_ID('OutputDistrictDetails') IS NOT NULL
DROP TABLE DBO.OutputDistrictDetails
GO
--District
SELECT 6 AS A, A.Reg AS B, A.Dist AS C, A.DistName AS D, E, F, G, H, I, J, K, L, M, N, A.Nat 
INTO DBO.OutputDistrictDetails
FROM (
SELECT DISTINCT B.ProgramType, A.Dist, A.DistName, A.Reg,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Dist,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS H, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS K,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) B ON A.Dist = B.Dist AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Dist,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS I, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS L,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Dist = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Dist' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Dist = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Dist' AND B.ProgramType = F.ProgramType
) C ON A.Dist = C.Dist AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Dist, CONVERT(VARCHAR(20),C.AvgCopay) AS M, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS N, A.Nat 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Dist = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Dist' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Dist = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Dist' AND B.ProgramType = D.ProgramType
) D ON A.Dist = D.Dist AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Dist, ActivationsRnk AS E, TransactionsRnk AS F
FROM tblGeoRanking
) E ON A.Dist = E.Dist
GO


--Nation SF Details 
--OutputNat4(OutputSFDetails)
IF OBJECT_ID('OutputSFDetails') IS NOT NULL
DROP TABLE DBO.OutputSFDetails
GO
--Territory
SELECT 6 AS A, A.Dist AS B, A.Terr AS C, A.TerrName AS D, E, F, G, H, I, J, K, L, M, N, REPLACE(REPLACE(A.Team,'INBU ',''),' SF','') AS O, A.Nat 
INTO DBO.OutputSFDetails
FROM (
SELECT DISTINCT B.ProgramType, A.Terr, A.TerrName, A.Dist, A.Team,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS G, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS J,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS H, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS K,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) B ON A.Terr = B.Terr AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS I, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS L,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) C ON A.Terr = C.Terr AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr, CONVERT(VARCHAR(20),C.AvgCopay) AS M, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS N, A.Nat 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
) D ON A.Terr = D.Terr AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Terr, ActivationsRnk AS E, TransactionsRnk AS F
FROM tblGeoRanking
) E ON A.Terr = E.Terr
GO


--Region Territory Details 
--OutputReg3(OutputTerritoryDetails)
IF OBJECT_ID('OutputTerritoryDetails') IS NOT NULL
DROP TABLE DBO.OutputTerritoryDetails
GO
--Territory
SELECT 6 AS A, A.Dist AS B, A.Terr AS C, A.TerrName AS D, A.Team AS E, F, G, H, I, J, K, L, M, N, O, A.Reg
INTO DBO.OutputTerritoryDetails
FROM (
SELECT DISTINCT B.ProgramType, A.Terr, A.TerrName, A.Dist, A.Team,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS H, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS K,
A.Reg FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CYTD') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CYTD') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('PYTD') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('PYTD') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) A INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS I, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS L,
A.Nat FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C13W') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C13W') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('P13W') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('P13W') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) B ON A.Terr = B.Terr AND A.ProgramType = B.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr,
CASE WHEN F.Activations = 0 THEN NULL ELSE D.Activations*1.0/F.Activations -1 END AS J, 
CASE WHEN E.Transactions = 0 THEN NULL ELSE C.Transactions*1.0/E.Transactions -1 END AS M,
A.Reg FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('CW') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('CW') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
LEFT JOIN DBO.tblGeoTransactions E ON A.Terr = E.Geo
AND E.Period in ('PW') AND E.Lev = 'Terr' AND B.ProgramType = E.ProgramType
LEFT JOIN DBO.tblGeoActivations F ON A.Terr = F.Geo
AND F.Period in ('PW') AND F.Lev = 'Terr' AND B.ProgramType = F.ProgramType
) C ON A.Terr = C.Terr AND A.ProgramType = C.ProgramType
INNER JOIN (
SELECT DISTINCT B.ProgramType, A.Terr, CONVERT(VARCHAR(20),C.AvgCopay) AS N, 
CONVERT(VARCHAR(15),D.Time_1stTransaction) + ' days' AS O, A.Reg 
FROM DBO.tblGeo A
INNER JOIN (
SELECT DISTINCT PROGRAMTYPE FROM tblGeoTransactions WHERE PROGRAMTYPE = 'All'
) B ON 1=1
LEFT JOIN DBO.tblGeoTransactions C ON A.Terr = C.Geo
AND C.Period in ('C52W') AND C.Lev = 'Terr' AND B.ProgramType = C.ProgramType
LEFT JOIN DBO.tblGeoActivations D ON A.Terr = D.Geo
AND D.Period in ('C52W') AND D.Lev = 'Terr' AND B.ProgramType = D.ProgramType
) D ON A.Terr = D.Terr AND A.ProgramType = D.ProgramType
LEFT JOIN (
SELECT Geo AS Terr, ActivationsRnk AS F, TransactionsRnk AS G
FROM tblGeoRanking
) E ON A.Terr = E.Terr
GO


--Region Level

--OutputReg4(OutputIndication_Reg)
IF OBJECT_ID('OutputIndication_Reg') IS NOT NULL
DROP TABLE DBO.OutputIndication_Reg
GO
SELECT 1 AS A, CONVERT(VARCHAR(5),(SELECT DISTINCT MONTH(Month_Start) FROM tblCalendar where Month_ID = 1)) AS B, CONVERT(VARCHAR(20),'Region') AS C, CONVERT(VARCHAR(20),'Indication') AS D,
[1] AS E,[2] AS F,[3] AS G,[4] AS H,[5] AS I,[6] AS J,[7] AS K,[8] AS L,[9] AS M,[10] AS N,[11] AS O,[12] AS P,
[13] AS Q,[14] AS R,[15] AS S,[16] AS T,[17] AS U,[18] AS V,[19] AS W,[20] AS X,[21] AS Y,[22] AS Z,[23] AS AA,[24] AS AB,
A.Reg
INTO DBO.OutputIndication_Reg
FROM (SELECT DISTINCT Reg FROM DBO.tblGeo) A
INNER JOIN (
SELECT [1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24] FROM (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Monthly'
) P
PIVOT(
	MAX(Period) FOR PeriodIdx IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],
	[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24])
) AS PVT
) B ON 1 = 1
GO

INSERT INTO DBO.OutputIndication_Reg
SELECT row_number() over(order by Geo, IndicationIdx) + 1 AS Idx,
Geo,GeoName,Indication,[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24],
Geo
FROM (
	SELECT A.Lev, A.Geo, A.GeoName, B.Indication, B.IndicationIdx, C.Activations, C. PeriodIdx
	FROM (
	SELECT DISTINCT 'Reg' AS Lev, Reg AS Geo, RegName AS GeoName FROM DBO.tblGeo
	) A INNER JOIN (
	SELECT DISTINCT Indication,CASE Indication WHEN 'RA' THEN 1 WHEN 'PSA' THEN 2 WHEN 'PSO(aged 18+)' THEN 3 WHEN 'PSO(age 4-17)' THEN 4 WHEN 'AS' THEN 5 WHEN 'JIA' THEN 6 WHEN 'PSP' THEN 7 WHEN 'Unknown' THEN 8 END AS IndicationIdx FROM tblGeoActivations_Indication
	) B ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,Indication,Activations,PeriodIdx
	FROM tblGeoActivations_Indication WHERE Lev = 'Reg'
	) C ON A.Geo = C.Geo AND B.Indication = C.Indication
) P
PIVOT(
	MAX(Activations) FOR PeriodIdx IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],
	[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24])
) AS PVT
GO

INSERT INTO DBO.OutputIndication_Reg
SELECT row_number() over(order by Geo, IndicationIdx) + 9 AS Idx,
Geo,GeoName,Indication,[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24],
Geo
FROM (
	SELECT A.Lev, A.Geo, A.GeoName, B.Indication, B.IndicationIdx, C.Transactions, C. PeriodIdx
	FROM (
	SELECT DISTINCT 'Reg' AS Lev, Reg AS Geo, RegName AS GeoName FROM DBO.tblGeo
	) A INNER JOIN (
	SELECT DISTINCT Indication,CASE Indication WHEN 'RA' THEN 1 WHEN 'PSA' THEN 2 WHEN 'PSO(aged 18+)' THEN 3 WHEN 'PSO(age 4-17)' THEN 4 WHEN 'AS' THEN 5 WHEN 'JIA' THEN 6 WHEN 'PSP' THEN 7 WHEN 'Unknown' THEN 8 END AS IndicationIdx FROM tblGeoActivations_Indication
	) B ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,Indication,Transactions,PeriodIdx
	FROM tblGeoTransactions_Indication WHERE Lev = 'Reg'
	) C ON A.Geo = C.Geo AND B.Indication = C.Indication
) P
PIVOT(
	MAX(Transactions) FOR PeriodIdx IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],
	[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24])
) AS PVT
GO


--Nation Level

--OutputReg4(OutputIndication_Nat)
IF OBJECT_ID('OutputIndication_Nat') IS NOT NULL
DROP TABLE DBO.OutputIndication_Nat
GO
SELECT 1 AS A, CONVERT(VARCHAR(7),(SELECT DISTINCT MONTH(Month_Start) FROM tblCalendar where Month_ID = 1)) AS B, CONVERT(VARCHAR(20),'Region') AS C, CONVERT(VARCHAR(20),'Indication') AS D,
[1] AS E,[2] AS F,[3] AS G,[4] AS H,[5] AS I,[6] AS J,[7] AS K,[8] AS L,[9] AS M,[10] AS N,[11] AS O,[12] AS P,
[13] AS Q,[14] AS R,[15] AS S,[16] AS T,[17] AS U,[18] AS V,[19] AS W,[20] AS X,[21] AS Y,[22] AS Z,[23] AS AA,[24] AS AB,
A.Nat
INTO DBO.OutputIndication_Nat
FROM (SELECT DISTINCT Nat FROM DBO.tblGeo) A
INNER JOIN (
SELECT [1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24] FROM (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Monthly'
) P
PIVOT(
	MAX(Period) FOR PeriodIdx IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],
	[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24])
) AS PVT
) B ON 1 = 1
GO

INSERT INTO DBO.OutputIndication_Nat
SELECT row_number() over(order by CASE Geo WHEN '00000' THEN '99999' ELSE Geo END, IndicationIdx) + 1 AS Idx,
Geo,GeoName,Indication,[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24],
'30000'
FROM (
	SELECT A.Lev, A.Geo, A.GeoName, B.Indication, B.IndicationIdx, C.Activations, C. PeriodIdx
	FROM (
	SELECT DISTINCT 'Nat' AS Lev, Nat AS Geo, NatName AS GeoName FROM DBO.tblGeo
	UNION ALL
	SELECT DISTINCT 'Reg' AS Lev, Reg AS Geo, RegName AS GeoName FROM DBO.tblGeo
	UNION ALL
	SELECT DISTINCT 'Unk' AS Lev, '00000' AS Geo, 'Unknown' AS GeoName FROM DBO.tblGeo
	) A INNER JOIN (
	SELECT DISTINCT Indication,CASE Indication WHEN 'RA' THEN 1 WHEN 'PSA' THEN 2 WHEN 'PSO(aged 18+)' THEN 3 WHEN 'PSO(age 4-17)' THEN 4 WHEN 'AS' THEN 5 WHEN 'JIA' THEN 6 WHEN 'PSP' THEN 7 WHEN 'Unknown' THEN 8 END AS IndicationIdx FROM tblGeoActivations_Indication
	) B ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,Indication,Activations,PeriodIdx
	FROM tblGeoActivations_Indication
	) C ON A.Geo = C.Geo AND B.Indication = C.Indication
) P
PIVOT(
	MAX(Activations) FOR PeriodIdx IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],
	[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24])
) AS PVT
GO

INSERT INTO DBO.OutputIndication_Nat
SELECT row_number() over(order by CASE Geo WHEN '00000' THEN '99999' ELSE Geo END, IndicationIdx) + 73 AS Idx,
Geo,GeoName,Indication,[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24],
'30000'
FROM (
	SELECT A.Lev, A.Geo, A.GeoName, B.Indication, B.IndicationIdx, C.Transactions, C. PeriodIdx
	FROM (
	SELECT DISTINCT 'Nat' AS Lev, Nat AS Geo, NatName AS GeoName FROM DBO.tblGeo
	UNION ALL
	SELECT DISTINCT 'Reg' AS Lev, Reg AS Geo, RegName AS GeoName FROM DBO.tblGeo
	UNION ALL
	SELECT DISTINCT 'Unk' AS Lev, '00000' AS Geo, 'Unknown' AS GeoName FROM DBO.tblGeo
	) A INNER JOIN (
	SELECT DISTINCT Indication,CASE Indication WHEN 'RA' THEN 1 WHEN 'PSA' THEN 2 WHEN 'PSO(aged 18+)' THEN 3 WHEN 'PSO(age 4-17)' THEN 4 WHEN 'AS' THEN 5 WHEN 'JIA' THEN 6 WHEN 'PSP' THEN 7 WHEN 'Unknown' THEN 8 END AS IndicationIdx FROM tblGeoActivations_Indication
	) B ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,Indication,Transactions,PeriodIdx
	FROM tblGeoTransactions_Indication
	) C ON A.Geo = C.Geo AND B.Indication = C.Indication
) P
PIVOT(
	MAX(Transactions) FOR PeriodIdx IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],
	[13],[14],[15],[16],[17],[18],[19],[20],[21],[22],[23],[24])
) AS PVT
GO

UPDATE DBO.OutputIndication_Nat
SET B = 'Nation'
WHERE B = '30000'
GO

UPDATE DBO.OutputIndication_Nat
SET B = 'Unknown'
WHERE B = '00000'
GO

--Unknown Level
--OutputUnk1(OutputDashboardData_Unk)
IF OBJECT_ID('OutputDashboardData_Unk') IS NOT NULL
DROP TABLE DBO.OutputDashboardData_Unk
GO

SELECT 1 AS A, CONVERT(VARCHAR(20),(SELECT CONVERT(VARCHAR(10),End_Date,111) FROM DBO.tblDateConfig WHERE Item = 'CW')) AS B,
CONVERT(VARCHAR(20),'') AS C, CONVERT(VARCHAR(20),'') AS D, '00000' AS Unk
INTO DBO.OutputDashboardData_Unk
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT 2 AS A, 'Program Type' AS B, [1] AS C,[2] AS D,
'00000'
FROM (
SELECT [1],[2] FROM (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
) P
PIVOT(
	MAX(Period) FOR PeriodIdx IN ([1],[2])
) AS PVT
) A
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT row_number() over(order by ProgramTypeIdx) + 2 AS Idx,
ProgramType,[1],[2],Geo
FROM (
	SELECT A.Geo, B.ProgramTypeDisplay AS ProgramType, B.ProgramTypeIdx, C.PeriodIdx, D.Activations
	FROM (
	SELECT '00000' AS Geo
	) A INNER JOIN (
	SELECT DISTINCT ProgramType,
	CASE ProgramType WHEN 'Debit' THEN 'DCARD' WHEN 'Retail' THEN 'RCARD' ELSE ProgramType END AS ProgramTypeDisplay,
	CASE ProgramType WHEN 'All' THEN 1 WHEN 'Debit' THEN '2' WHEN 'DMR' THEN '3' WHEN 'Retail' THEN '4' END AS ProgramTypeIdx
	FROM tblGeoActivations
	) B ON 1 = 1
	INNER JOIN (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
	) C ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,ProgramType,Period,Activations
	FROM tblGeoActivations WHERE Lev = 'Unk'
	) D ON A.Geo = D.Geo AND B.ProgramType = D.ProgramType AND C.Period = D.Period
) P
PIVOT(
	MAX(Activations) FOR PeriodIdx IN ([1],[2])
) AS PVT
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT 7 AS A, 'Program Type' AS B, [1] AS C,[2] AS D,
'00000'
FROM (
SELECT [1],[2] FROM (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
) P
PIVOT(
	MAX(Period) FOR PeriodIdx IN ([1],[2])
) AS PVT
) A
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT row_number() over(order by ProgramTypeIdx) + 7 AS Idx,
ProgramType,[1],[2],Geo
FROM (
	SELECT A.Geo, B.ProgramTypeDisplay AS ProgramType, B.ProgramTypeIdx, C.PeriodIdx, D.Transactions
	FROM (
	SELECT '00000' AS Geo
	) A INNER JOIN (
	SELECT DISTINCT ProgramType,
	CASE ProgramType WHEN 'Debit' THEN 'DCARD' WHEN 'Retail' THEN 'RCARD' ELSE ProgramType END AS ProgramTypeDisplay,
	CASE ProgramType WHEN 'All' THEN 1 WHEN 'Debit' THEN '2' WHEN 'DMR' THEN '3' WHEN 'Retail' THEN '4' END AS ProgramTypeIdx
	FROM tblGeoTransactions
	) B ON 1 = 1
	INNER JOIN (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
	) C ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,ProgramType,Period,Transactions
	FROM tblGeoTransactions WHERE Lev = 'Unk'
	) D ON A.Geo = D.Geo AND B.ProgramType = D.ProgramType AND C.Period = D.Period
) P
PIVOT(
	MAX(Transactions) FOR PeriodIdx IN ([1],[2])
) AS PVT
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT 12 AS A, 'Vendor Code' AS B, [1] AS C,[2] AS D,
'00000'
FROM (
SELECT [1],[2] FROM (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
) P
PIVOT(
	MAX(Period) FOR PeriodIdx IN ([1],[2])
) AS PVT
) A
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT row_number() over(order by VendorCodeIdx) + 12 AS Idx,
VendorCode,[1],[2],Geo
FROM (
	SELECT A.Geo, B.VendorCode, B.VendorCodeIdx, C.PeriodIdx, D.Activations
	FROM (
	SELECT '00000' AS Geo
	) A INNER JOIN (
	SELECT DISTINCT VendorCode,
	CASE VendorCode WHEN 'OPU' THEN 1 WHEN 'CRx' THEN '2' END AS VendorCodeIdx
	FROM tblGeoActivations_VendorCode
	) B ON 1 = 1
	INNER JOIN (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
	) C ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,VendorCode,Period,Activations
	FROM tblGeoActivations_VendorCode WHERE Lev = 'Unk'
	) D ON A.Geo = D.Geo AND B.VendorCode = D.VendorCode AND C.Period = D.Period
) P
PIVOT(
	MAX(Activations) FOR PeriodIdx IN ([1],[2])
) AS PVT
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT 15 AS A, 'Vendor Code' AS B, [1] AS C,[2] AS D,
'00000'
FROM (
SELECT [1],[2] FROM (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
) P
PIVOT(
	MAX(Period) FOR PeriodIdx IN ([1],[2])
) AS PVT
) A
GO

INSERT INTO DBO.OutputDashboardData_Unk
SELECT row_number() over(order by VendorCodeIdx) + 15 AS Idx,
VendorCode,[1],[2],Geo
FROM (
	SELECT A.Geo, B.VendorCode, B.VendorCodeIdx, C.PeriodIdx, D.Transactions
	FROM (
	SELECT '00000' AS Geo
	) A INNER JOIN (
	SELECT DISTINCT VendorCode,
	CASE VendorCode WHEN 'OPU' THEN 1 WHEN 'CRx' THEN '2' END AS VendorCodeIdx
	FROM tblGeoTransactions_VendorCode
	) B ON 1 = 1
	INNER JOIN (
	SELECT Item AS Period, ItemIdx AS PeriodIdx FROM tblDateConfig
	WHERE ItemType = 'Yearly'
	) C ON 1 = 1
	LEFT JOIN (
	SELECT Lev,Geo,VendorCode,Period,Transactions
	FROM tblGeoTransactions_VendorCode WHERE Lev = 'Unk'
	) D ON A.Geo = D.Geo AND B.VendorCode = D.VendorCode AND C.Period = D.Period
) P
PIVOT(
	MAX(Transactions) FOR PeriodIdx IN ([1],[2])
) AS PVT
GO

--Unknown Level
--OutputUnk2(OutputPhysicianData_Unk)
IF OBJECT_ID('OutputPhysicianData_Unk') IS NOT NULL
DROP TABLE DBO.OutputPhysicianData_Unk
GO
DECLARE @End_Date VARCHAR(10) 
SET @End_Date = (SELECT End_Date FROM DBO.tblDateConfig WHERE Item = 'PYTD')
SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) + 1 AS A,
NPI,
COUNT(CASE WHEN Year_ID = 1 THEN 1 ELSE NULL END) AS CYTD_Transaction,
COUNT(CASE WHEN Year_ID = 2 AND Date_Name <= @End_Date THEN 1 ELSE NULL END) AS PYTD_Transaction,
COUNT(CASE WHEN Week_ID <= 26 THEN 1 ELSE NULL END) AS C26W_Transactions,
COUNT(CASE WHEN Week_ID <= 13 THEN 1 ELSE NULL END) AS C13W_Transactions,
COUNT(CASE WHEN Week_ID = 1 THEN 1 ELSE NULL END) AS CW_Transactions,
COUNT(CASE WHEN Week_ID = 2 THEN 1 ELSE NULL END) AS PW_Transactions
INTO DBO.OutputPhysicianData_Unk
FROM DBO.tblTransactions WHERE NPI IS NOT NULL AND CustomerID IS NULL
GROUP BY NPI
GO

print'Dashboard End'
print getdate()
print'Physician Detail Start'
go
--Prescriber Detail Processing
if object_id('tblPhysicianMapping') is not null
	drop table tblPhysicianMapping
select distinct PhysicianID,DoctorID into tblPhysicianMapping from tbltransactions
go

if object_id('tblDoctorTerrList') is not null
	drop table tblDoctorTerrList
select PhysicianID,APEX_Terr,PINNACLE_Terr,SUMMIT_Terr 
into tblDoctorTerrList
from tblTransactions
where APEX_Terr is not null or PINNACLE_Terr is not null or SUMMIT_Terr is not null 
go

if object_id('tblActivations_unit') is not null
	drop table tblActivations_unit
select * 
into tblActivations_unit
from tblActivations
where id in (
select min(id) from tblActivations
group by patientid,cardid
)
go

if object_id('tblActivations_unit2') is not null
	drop table tblActivations_unit2

select 	
ID,PatientID,CardID,Date_Name,Date_ID,Week_ID,Month_ID,Year_ID,ProgramType,Date_Name_1stTransaction,Time_1stTransaction
,Zip,PhysicianID,CustomerID
,APEX_Terr as Terr
,APEX_TerrName as TerrName
,APEX_Dist as Dist
,APEX_DistName as DistName
,APEX_Reg as Reg
,APEX_RegName as RegName
,cast('APEX' as varchar(50)) as Type
into tblActivations_unit2
from tblActivations_unit where APEX_Terr is not null
union all
select 	
ID,PatientID,CardID,Date_Name,Date_ID,Week_ID,Month_ID,Year_ID,ProgramType,Date_Name_1stTransaction,Time_1stTransaction
,Zip,PhysicianID,CustomerID
,PINNACLE_Terr as Terr
,PINNACLE_TerrName as TerrName
,PINNACLE_Dist as Dist
,PINNACLE_DistName as DistName
,PINNACLE_Reg as Reg
,PINNACLE_RegName as RegName
,cast('PINNACLE' as varchar(50)) as Type
from tblActivations_unit where PINNACLE_Terr is not null
union all
select 	
ID,PatientID,CardID,Date_Name,Date_ID,Week_ID,Month_ID,Year_ID,ProgramType,Date_Name_1stTransaction,Time_1stTransaction
,Zip,PhysicianID,CustomerID
,SUMMIT_Terr as Terr
,SUMMIT_TerrName as TerrName
,SUMMIT_Dist as Dist
,SUMMIT_DistName as DistName
,SUMMIT_Reg as Reg
,SUMMIT_RegName as RegName
,cast('SUMMIT' as varchar(50)) as Type
from tblActivations_unit where SUMMIT_Terr is not null

create index idx on tblActivations_unit2 (PhysicianID,Terr)
go

if object_id('tbltransactions2') is not null
	drop table tbltransactions2

select 
tblClaimID,PatientID,PhysicianID,PharmacyID,CardID,Date_Name,Date_ID,Week_ID,Month_ID,Year_ID,CopayAmount,ProgramType,VendorCode
,PhysicianName,FirstName,LastName,Target,NPI,CustomerID,Address1,City,State,Zip,PharmacyName
,APEX_Terr as Terr
,APEX_TerrName as TerrName
,APEX_Dist as Dist
,APEX_DistName as DistName
,APEX_Reg as Reg
,APEX_RegName as RegName
,cast('APEX' as varchar(50)) as Type
into tbltransactions2
from tbltransactions where APEX_Terr is not null
union all
select 
tblClaimID,PatientID,PhysicianID,PharmacyID,CardID,Date_Name,Date_ID,Week_ID,Month_ID,Year_ID,CopayAmount,ProgramType,VendorCode
,PhysicianName,FirstName,LastName,Target,NPI,CustomerID,Address1,City,State,Zip,PharmacyName
,PINNACLE_Terr as Terr
,PINNACLE_TerrName as TerrName
,PINNACLE_Dist as Dist
,PINNACLE_DistName as DistName
,PINNACLE_Reg as Reg
,PINNACLE_RegName as RegName
,cast('PINNACLE' as varchar(50)) as Type
from tbltransactions where PINNACLE_Terr is not null
union all
select 
tblClaimID,PatientID,PhysicianID,PharmacyID,CardID,Date_Name,Date_ID,Week_ID,Month_ID,Year_ID,CopayAmount,ProgramType,VendorCode
,PhysicianName,FirstName,LastName,Target,NPI,CustomerID,Address1,City,State,Zip,PharmacyName
,SUMMIT_Terr as Terr
,SUMMIT_TerrName as TerrName
,SUMMIT_Dist as Dist
,SUMMIT_DistName as DistName
,SUMMIT_Reg as Reg
,SUMMIT_RegName as RegName
,cast('SUMMIT' as varchar(50)) as Type
from tbltransactions where SUMMIT_Terr is not null

create index idx on tbltransactions2 (PatientID,PhysicianID,Date_Name,Terr)

if object_id('PhySicianList') is not null
	drop table PhySicianList
select distinct Terr,PhysicianID,'Unknown' as type 
into PhySicianList
from tblTransactions2 
where PhysicianName = 'Unknown Physician' or PhysicianName = 'All Other Physicians'
Union 
select distinct Terr,PhysicianID,'PDRP' as type 
from tblTransactions2
where Target = 'AMA-PDRP'
Union 
select distinct Terr,PhysicianID,'Normal' as type 
from tblTransactions2
where (Target != 'AMA-PDRP' or Target is null) and PhysicianName != 'Unknown Physician' and PhysicianName != 'All Other Physicians'
go

if object_id('PhySicianList_Dist') is not null
	drop table PhySicianList_Dist
select distinct Dist,PhysicianID,'Unknown' as type 
into PhySicianList_Dist
from tblTransactions2 
where PhysicianName = 'Unknown Physician' or PhysicianName = 'All Other Physicians'
Union 
select distinct Dist,PhysicianID,'PDRP' as type 
from tblTransactions2
where Target = 'AMA-PDRP'
Union 
select distinct Dist,PhysicianID,'Normal' as type 
from tblTransactions2
where (Target != 'AMA-PDRP' or Target is null) and PhysicianName != 'Unknown Physician' and PhysicianName != 'All Other Physicians'
go

if object_id('PhySicianList_Reg') is not null
	drop table PhySicianList_Reg
select distinct Reg,PhysicianID,'Unknown' as type 
into PhySicianList_Reg
from tblTransactions2 
where PhysicianName = 'Unknown Physician' or PhysicianName = 'All Other Physicians'
Union 
select distinct Reg,PhysicianID,'PDRP' as type 
from tblTransactions2
where Target = 'AMA-PDRP'
Union 
select distinct Reg,PhysicianID,'Normal' as type 
from tblTransactions2
where (Target != 'AMA-PDRP' or Target is null) and PhysicianName != 'Unknown Physician' and PhysicianName != 'All Other Physicians'
go
------------------------Output table:OutputPhysicianData,OutputPhysicianData_PDRP,OutputPhysicianData_Unknown,OutputPhysicianData_Final
if object_id('OutputPhysicianData') is not null
	drop table OutputPhysicianData
create table OutputPhysicianData(
	[PhysicianID] [varchar](200) NULL,
	[Physician_Name] [varchar](100) NULL,
	[Target] [varchar](100) NULL,
	[Terr] [varchar](5) NULL,
	[Patients_Not_Using_Copay_Card_Percentage_Of_Total] [decimal](19, 2) NULL,
	[NPI] [varchar](50) NULL,
	[Amgen_Customer_Master_ID] [varchar](10) NULL,
	[Street] [varchar](255) NULL,
	[City] [varchar](100) NULL,
	[State] [varchar](100) NULL,
	[Zip] [varchar](10) NULL,
	[C52W_Time_to_1st_Transaction] [varchar](50) NULL,
	[C52W_Average_Copay_Payout] [varchar](50) NULL,
	[CYTD_Transaction] [int] NULL,
	[PYTD_Transaction] [int] NULL,
	[CYTD_vs_PYTD_Transactions_Growth] [decimal](19, 3) NULL,
	[C26W_Transactions] [int] NULL,
	[C26W_vs_P26W_Transactions_Growth] [decimal](19, 3) NULL,
	[C13W_Transactions] [int] NULL,
	[C13W_vs_P13W_Transactions_Growth] [decimal](19, 3) NULL,
	[CW_transactions] [int] NULL,
	[PW_transactions] [int] NULL,
	[CW_vs_PW_Transactions_Growth] [decimal](19, 3) NULL,
	[C13W_Expirations] [int] NULL,
	[P13W_Expirations] [int] NULL,
	[C13W_vs_P13W_Expirations_Growth] [decimal](19, 3) NULL,
	[CYTD_vs_PYTD_Expirations_Growth] [decimal](19, 3) NULL,
	[Pharmacy_Rank_1] [varchar](255) NULL,
	[PharmacyID_Rank_1] [int] NULL,
	[Pharmacy_Rank_2] [varchar](255) NULL,
	[PharmacyID_Rank_2] [int] NULL,
	[Pharmacy_Rank_3] [varchar](255) NULL,
	[PharmacyID_Rank_3] [int] NULL,
	[Cat1] [int] NULL,
	[Cat2] [int] NULL,
	[Cat3] [int] NULL,
	[Cat4] [int] NULL,
	[Cat5] [int] NULL,
	[Cat6] [int] NULL,
	[Cat7] [int] NULL,
	[Cat8] [int] NULL,
	[Cat9] [int] NULL
)

truncate table OutputPhysicianData
insert into OutputPhysicianData(PhysicianID,Physician_Name,Target
								,Terr
								,NPI,Amgen_Customer_Master_ID,Street,City,State,Zip
								)
select distinct PhysicianID,PhysicianName,Target
		,Terr
		,NPI,CustomerID,Address1,City,State,Zip
from tbltransactions2  
where Terr is not null


if object_id('tempTransactionsWithPeriod') is not null
	drop table tempTransactionsWithPeriod
select a.*,b.Item 
into tempTransactionsWithPeriod
from tblTransactions2 a
inner join tblDateConfig b
on a.Date_Name between b.Start_Date and b.End_Date
where item in ('CYTD','PYTD','C13W','P13W','CW','PW','C26W','P26W','C52W','P52W')

create index idx on tempTransactionsWithPeriod(PhysicianID,Terr,Item)


if object_id('tempTransactions') is not null
	drop table tempTransactions

select Terr,PhysicianID
		,isnull(CYTD,0) as CYTD
		,isnull(PYTD,0) as PYTD
		,isnull(C13W,0) as C13W
		,isnull(P13W,0) as P13W
		,isnull(CW  ,0) as CW  
		,isnull(PW  ,0) as PW  
		,isnull(C26W,0) as C26W
		,isnull(P26W,0) as P26W
		,isnull(C52W,0) as C52W
		,isnull(P52W,0) as P52W
into tempTransactions
from (
select Terr,PhysicianID,Item as TimePeriod,count(tblClaimID) as CountClaim 
from tempTransactionsWithPeriod
group by Terr,PhysicianID,Item
) a
pivot (
	sum(CountClaim) for TimePeriod in (CYTD,PYTD,C13W,P13W,CW,PW,C26W,P26W,C52W,P52W)
) b

create index idx on tempTransactions(PhysicianID,Terr)

if object_id('tempTransactions_Dist') is not null
	drop table tempTransactions_Dist

select Dist,PhysicianID
		,isnull(CYTD,0) as CYTD
		,isnull(PYTD,0) as PYTD
		,isnull(C13W,0) as C13W
		,isnull(P13W,0) as P13W
		,isnull(CW  ,0) as CW  
		,isnull(PW  ,0) as PW  
		,isnull(C26W,0) as C26W
		,isnull(P26W,0) as P26W
		,isnull(C52W,0) as C52W
		,isnull(P52W,0) as P52W
into tempTransactions_Dist
from (
select Dist,PhysicianID,Item as TimePeriod,count(distinct tblClaimID) as CountClaim 
from tempTransactionsWithPeriod
group by Dist,PhysicianID,Item
) a
pivot (
	sum(CountClaim) for TimePeriod in (CYTD,PYTD,C13W,P13W,CW,PW,C26W,P26W,C52W,P52W)
) b

create index idx on tempTransactions_Dist(PhysicianID,Dist)


if object_id('tempTransactions_Reg') is not null
	drop table tempTransactions_Reg

select Reg,PhysicianID
		,isnull(CYTD,0) as CYTD
		,isnull(PYTD,0) as PYTD
		,isnull(C13W,0) as C13W
		,isnull(P13W,0) as P13W
		,isnull(CW  ,0) as CW  
		,isnull(PW  ,0) as PW  
		,isnull(C26W,0) as C26W
		,isnull(P26W,0) as P26W
		,isnull(C52W,0) as C52W
		,isnull(P52W,0) as P52W
into tempTransactions_Reg
from (
select Reg,PhysicianID,Item as TimePeriod,count(distinct tblClaimID) as CountClaim 
from tempTransactionsWithPeriod
group by Reg,PhysicianID,Item
) a
pivot (
	sum(CountClaim) for TimePeriod in (CYTD,PYTD,C13W,P13W,CW,PW,C26W,P26W,C52W,P52W)
) b

create index idx on tempTransactions_Reg(PhysicianID,Reg)


update a
set CYTD_Transaction = b.CYTD,PYTD_Transaction = b.PYTD,CYTD_vs_PYTD_Transactions_Growth = case when b.PYTD = 0 then null else cast((b.CYTD - b.PYTD) * 1.0/b.PYTD as decimal(19,3)) end 
,C26W_Transactions = b.C26W,C26W_vs_P26W_Transactions_Growth = case when b.P26W = 0 then null else cast((b.C26W - b.P26W) * 1.0/b.P26W as decimal(19,3)) end 
,C13W_Transactions = b.C13W,C13W_vs_P13W_Transactions_Growth = case when b.P13W = 0 then null else cast((b.C13W - b.P13W) * 1.0/b.P13W as decimal(19,3)) end 
,CW_transactions = b.CW,PW_transactions = b.PW,CW_vs_PW_Transactions_Growth = case when b.PW = 0 then null else cast((b.CW - b.PW) * 1.0/b.PW as decimal(19,3)) end 
from OutputPhysicianData a,tempTransactions b
where a.PhysicianID = b.PhysicianID and a.terr = b.terr

update a
set C52W_Average_Copay_Payout = b.AvgAmount
from OutputPhysicianData a,(
	select terr,PhysicianID,avg(CopayAmount) as AvgAmount 
	from tempTransactionsWithPeriod
	where Item = 'C52W'
	group by terr,PhysicianID

) b
where a.PhysicianID = b.PhysicianID and a.Terr = b.Terr

-----------------rank Pharmacy
if object_id('RankPharmacy') is not null
	drop table RankPharmacy

select row_number() over(partition by Terr,PhysicianID order by CountClaim desc,PharmacyName) as RankNum,* 
into RankPharmacy
from (
		select Terr,PhysicianID,PharmacyID,PharmacyName,count(tblClaimID) as CountClaim 
		from tempTransactionsWithPeriod
		group by Terr,PhysicianID,PharmacyID,PharmacyName
	) a

update a
set Pharmacy_Rank_1 = b.PharmacyName , PharmacyID_Rank_1 = b.PharmacyID
from OutputPhysicianData a,RankPharmacy b
where a.PhysicianID = b.PhysicianID and a.Terr = b.Terr and b.RankNum = 1

update a
set Pharmacy_Rank_2 = b.PharmacyName , PharmacyID_Rank_2 = b.PharmacyID
from OutputPhysicianData a,RankPharmacy b
where a.PhysicianID = b.PhysicianID and a.Terr = b.Terr and b.RankNum = 2

update a
set Pharmacy_Rank_3 = b.PharmacyName , PharmacyID_Rank_3 = b.PharmacyID
from OutputPhysicianData a,RankPharmacy b
where a.PhysicianID = b.PhysicianID and a.Terr = b.Terr and b.RankNum = 3

-----------------------------------
if object_id('tempTimetoFirstTransaction') is not null
	drop table tempTimetoFirstTransaction

select Terr,PhysicianID,avg(Time_1stTransaction) as Avg_Time_1stTransaction
into tempTimetoFirstTransaction
from (
	select distinct a.Terr,a.PhysicianID,a.PatientID,a.CardID,a.Date_Name as Claim_Date,b.Date_Name as CardActive_Date,b.Time_1stTransaction
	from (
	select PhysicianID,PatientID,CardID,Date_Name,Terr from tblTransactions2
	) a
	inner join (
	select PatientID,CardID,Date_Name,Date_Name_1stTransaction,Time_1stTransaction,Terr from tblActivations_unit2
	where week_id <= 52 and Date_Name_1stTransaction is not null
	) b
	on a.Terr = b.Terr and a.PatientID = b.PatientID and a.CardID = b.CardID and a.Date_Name = b.Date_Name_1stTransaction
) a
group by Terr,PhysicianID

update a
set C52W_Time_to_1st_Transaction = cast(round(b.Avg_Time_1stTransaction,0) as varchar) + ' days'
from OutputPhysicianData a,tempTimetoFirstTransaction b
where a.PhysicianID = b.PhysicianID and a.Terr = b.Terr

-------------------------------------------

if object_id('tempNotUsingCard') is not null
	drop table tempNotUsingCard

select Terr,PhysicianID,count(distinct PatientID) as PatientNum,sum(case when ClaimNum > 0 then 1 else 0 end) as isUseCard
into tempNotUsingCard
from (
	select a.terr,a.PhysicianID,a.PatientID
			,sum(case when b.PatientID is null then 0 else 1 end) as ClaimNum
	from tblActivations_unit2 a
	left join tblTransactions2 b
	on a.PatientID = b.PatientID and a.CardID = b.CardID and a.Terr = b.Terr
	where a.PhysicianID is not null
	group by a.terr,a.PhysicianID,a.PatientID
) a
group by Terr,PhysicianID

update a
set Patients_Not_Using_Copay_Card_Percentage_Of_Total = cast((b.PatientNum - b.isUseCard) * 1.0 / b.PatientNum as decimal(19,2))
from OutputPhysicianData a,tempNotUsingCard b
where a.PhysicianID = b.PhysicianID and a.Terr = b.Terr

--------------------------------------------
if object_id('tempExpiredPatient') is not null
	drop table tempExpiredPatient

select c.PhysicianID,a.patientID,cast(b.EnrollmentAnniversary as date) as ExpirationDate 
into tempExpiredPatient
from Enbrel_Production..tblPatientPhysician a
inner join tblPhysicianMapping c on a.PhysicianID = c.DoctorID
left join Enbrel_Production..tblPatientInfo b on a.PatientID = b.PatientID
where a.IsActive='Y' and a.IsPrimary = 'Y' and b.ActiveFlag = 1

if object_id('tempPhysicianExpiredPatient') is not null
	drop table tempPhysicianExpiredPatient
	
select PhysicianID,isnull(CYTD,0) as CYTD,isnull(PYTD,0) as PYTD,isnull(C13W,0) as C13W,isnull(P13W,0) as P13W
into tempPhysicianExpiredPatient
from (
select PhysicianID,b.item,count(distinct PatientID) as ExpiredCardNum from tempExpiredPatient a
inner join tblDateConfig b
on ExpirationDate between b.Start_Date and b.End_Date
where b.item in ('CYTD','PYTD','C13W','P13W')
group by PhysicianID,b.item
) a
pivot(
 max(ExpiredCardNum) for item in (CYTD,PYTD,C13W,P13W)
) b

update a
set C13W_Expirations = isnull(C13W,0)
,P13W_Expirations = isnull(P13W,0)
,C13W_vs_P13W_Expirations_Growth = case when P13W = 0 then null else (C13W - P13W) * 1.0 / P13W end
,CYTD_vs_PYTD_Expirations_Growth = case when PYTD = 0 then null else (CYTD - PYTD) * 1.0 / PYTD end
from OutputPhysicianData a
left join tempPhysicianExpiredPatient b
on a.PhysicianID = b.PhysicianID


-------------------------------------PDRP
---------------------------------
if object_id('OutputPhysicianData_PDRP') is not null
	drop table OutputPhysicianData_PDRP
select * into OutputPhysicianData_PDRP from OutputPhysicianData where 1=0

truncate table OutputPhysicianData_PDRP
	
insert into OutputPhysicianData_PDRP(Physician_Name,Target,Terr)
select distinct Physician_Name,Target,Terr from OutputPhysicianData a
where exists  (select Terr,PhysicianID from PhySicianList b where Type = 'PDRP' and a.PhysicianID = b.PhysicianID and a.Terr = b.Terr) 
--and a.Physician_Name = 'PDRP Physician'

update a
set CYTD_Transaction = b.CYTD,PYTD_Transaction = b.PYTD,CYTD_vs_PYTD_Transactions_Growth = case when b.PYTD = 0 then null else cast((b.CYTD - b.PYTD) * 1.0/b.PYTD as decimal(19,3)) end 
,C26W_Transactions = b.C26W,C26W_vs_P26W_Transactions_Growth = case when b.P26W = 0 then null else cast((b.C26W - b.P26W) * 1.0/b.P26W as decimal(19,3)) end 
,C13W_Transactions = b.C13W,C13W_vs_P13W_Transactions_Growth = case when b.P13W = 0 then null else cast((b.C13W - b.P13W) * 1.0/b.P13W as decimal(19,3)) end 
,CW_transactions = b.CW,PW_transactions = b.PW,CW_vs_PW_Transactions_Growth = case when b.PW = 0 then null else cast((b.CW - b.PW) * 1.0/b.PW as decimal(19,3)) end 
from OutputPhysicianData_PDRP a,(
	select a.Terr,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W,sum(CW) as CW,sum(CYTD) as PW
			,sum(C26W) as C26W,sum(P26W) as P26W,sum(C52W) as C52W,sum(P52W) as P52W
	from tempTransactions a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
	where b.type = 'PDRP'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C52W_Average_Copay_Payout = b.AvgAmount
from OutputPhysicianData_PDRP a,(
	select b.Terr,avg(CopayAmount) as AvgAmount from tempTransactionsWithPeriod a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
	where Item = 'C52W' and b.type = 'PDRP'
	group by b.Terr
) b
where a.Terr = b.Terr


if object_id('RankPharmacy_PDRP') is not null
	drop table RankPharmacy_PDRP
	
select row_number() over(partition by Terr order by CountClaim desc,PharmacyName) as RankNum,* 
into RankPharmacy_PDRP
from (
select b.Terr,a.PharmacyID,a.PharmacyName,sum(CountClaim) as CountClaim 
from RankPharmacy a
inner join PhysicianList b
on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
where b.type = 'PDRP'
group by b.Terr,a.PharmacyID,a.PharmacyName
) a

update a
set Pharmacy_Rank_1 = b.PharmacyName , PharmacyID_Rank_1 = b.PharmacyID
from OutputPhysicianData_PDRP a,RankPharmacy_PDRP b
where a.Terr = b.Terr and b.RankNum = 1

update a
set Pharmacy_Rank_2 = b.PharmacyName , PharmacyID_Rank_2 = b.PharmacyID
from OutputPhysicianData_PDRP a,RankPharmacy_PDRP b
where a.Terr = b.Terr and b.RankNum = 2

update a
set Pharmacy_Rank_3 = b.PharmacyName , PharmacyID_Rank_3 = b.PharmacyID
from OutputPhysicianData_PDRP a,RankPharmacy_PDRP b
where a.Terr = b.Terr and b.RankNum = 3


if object_id('tempTimetoFirstTransaction_PDRP') is not null
	drop table tempTimetoFirstTransaction_PDRP

select a.Terr,avg(Time_1stTransaction) as Avg_Time_1stTransaction
into tempTimetoFirstTransaction_PDRP
from (
	select distinct a.Terr,a.PhysicianID,a.PatientID,a.CardID,a.Date_Name as Claim_Date,b.Date_Name as CardActive_Date,b.Time_1stTransaction
	from (
	select PhysicianID,PatientID,CardID,Date_Name,Terr from tblTransactions2
	) a
	inner join (
	select PatientID,CardID,Date_Name,Date_Name_1stTransaction,Time_1stTransaction,Terr from tblActivations_unit2 
	where week_id <= 52 and Date_Name_1stTransaction is not null
	) b
	on a.PatientID = b.PatientID and a.CardID = b.CardID and a.Date_Name = b.Date_Name_1stTransaction and a.Terr = B.Terr
) a
inner join PhysicianList b
on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
where b.Type = 'PDRP'
group by a.Terr

update a
set C52W_Time_to_1st_Transaction = cast(round(b.Avg_Time_1stTransaction,0) as varchar) + ' days'
from OutputPhysicianData_PDRP a,tempTimetoFirstTransaction_PDRP b
where a.Terr = b.Terr

update a
set Patients_Not_Using_Copay_Card_Percentage_Of_Total = cast((b.PatientNum - b.isUseCard) * 1.0 / b.PatientNum as decimal(19,2))
from OutputPhysicianData_PDRP a,(select a.Terr,sum(PatientNum) as PatientNum ,sum(isUseCard) as isUseCard
	from tempNotUsingCard a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
	where b.type = 'PDRP'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C13W_Expirations = isnull(C13W,0)
,P13W_Expirations = isnull(P13W,0)
,C13W_vs_P13W_Expirations_Growth = case when P13W = 0 then null else (C13W - P13W) * 1.0 / P13W end
,CYTD_vs_PYTD_Expirations_Growth = case when PYTD = 0 then null else (CYTD - PYTD) * 1.0 / PYTD end
from OutputPhysicianData_PDRP a
left join (select b.Terr,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W
	from tempPhysicianExpiredPatient a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID 
	where b.type = 'PDRP'
	group by b.Terr
) b
on a.Terr = b.Terr

--District Level

if object_id('OutputPhysicianData_PDRP_Dist') is not null
	drop table OutputPhysicianData_PDRP_Dist
select * into OutputPhysicianData_PDRP_Dist from OutputPhysicianData where 1=0
	
insert into OutputPhysicianData_PDRP_Dist(Physician_Name,Target,Terr)
select distinct Physician_Name,Target,left(Terr,3)+'00' from OutputPhysicianData a
where exists  (select Dist,PhysicianID from PhySicianList_Dist b where Type = 'PDRP' and a.PhysicianID = b.PhysicianID and left(a.Terr,3)+'00' = b.Dist) 
--and a.Physician_Name = 'PDRP Physician'

update a
set CYTD_Transaction = b.CYTD,PYTD_Transaction = b.PYTD,CYTD_vs_PYTD_Transactions_Growth = case when b.PYTD = 0 then null else cast((b.CYTD - b.PYTD) * 1.0/b.PYTD as decimal(19,3)) end 
,C26W_Transactions = b.C26W,C26W_vs_P26W_Transactions_Growth = case when b.P26W = 0 then null else cast((b.C26W - b.P26W) * 1.0/b.P26W as decimal(19,3)) end 
,C13W_Transactions = b.C13W,C13W_vs_P13W_Transactions_Growth = case when b.P13W = 0 then null else cast((b.C13W - b.P13W) * 1.0/b.P13W as decimal(19,3)) end 
,CW_transactions = b.CW,PW_transactions = b.PW,CW_vs_PW_Transactions_Growth = case when b.PW = 0 then null else cast((b.CW - b.PW) * 1.0/b.PW as decimal(19,3)) end 
from OutputPhysicianData_PDRP_Dist a,(
	select a.Dist,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W,sum(CW) as CW,sum(CYTD) as PW
			,sum(C26W) as C26W,sum(P26W) as P26W,sum(C52W) as C52W,sum(P52W) as P52W
	from tempTransactions_Dist a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Dist = b.Dist
	where b.type = 'PDRP'
	group by a.Dist
) b
where a.Terr = b.Dist

update a
set C52W_Average_Copay_Payout = b.AvgAmount
from OutputPhysicianData_PDRP_Dist a,(
	select a.Dist,avg(CopayAmount) as AvgAmount
	from tempTransactionsWithPeriod a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Dist = b.Dist and b.type = 'PDRP'
	where a.Item = 'C52W'
	group by a.Dist
) b
where a.Terr = b.Dist


if object_id('RankPharmacy_PDRP_Dist') is not null
	drop table RankPharmacy_PDRP_Dist
	
select row_number() over(partition by Terr order by CountClaim desc,PharmacyName) as RankNum,* 
into RankPharmacy_PDRP_Dist
from (
	select a.Terr,a.PharmacyID,a.PharmacyName,sum(CountClaim) as CountClaim 
	from (select distinct left(Terr,3)+'00' as Terr,PhysicianID,PharmacyID,PharmacyName,CountClaim
	From RankPharmacy) a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Dist
	where b.type = 'PDRP'
	group by a.Terr,a.PharmacyID,a.PharmacyName
) a

update a
set Pharmacy_Rank_1 = b.PharmacyName , PharmacyID_Rank_1 = b.PharmacyID
from OutputPhysicianData_PDRP_Dist a,RankPharmacy_PDRP_Dist b
where a.Terr = b.Terr and b.RankNum = 1

update a
set Pharmacy_Rank_2 = b.PharmacyName , PharmacyID_Rank_2 = b.PharmacyID
from OutputPhysicianData_PDRP_Dist a,RankPharmacy_PDRP_Dist b
where a.Terr = b.Terr and b.RankNum = 2

update a
set Pharmacy_Rank_3 = b.PharmacyName , PharmacyID_Rank_3 = b.PharmacyID
from OutputPhysicianData_PDRP_Dist a,RankPharmacy_PDRP_Dist b
where a.Terr = b.Terr and b.RankNum = 3


if object_id('tempTimetoFirstTransaction_PDRP_Dist') is not null
	drop table tempTimetoFirstTransaction_PDRP_Dist

select a.Dist,avg(Time_1stTransaction) as Avg_Time_1stTransaction
into tempTimetoFirstTransaction_PDRP_Dist
from (
	select distinct a.Dist,a.PhysicianID,a.PatientID,a.CardID,a.Date_Name as Claim_Date,b.Date_Name as CardActive_Date,b.Time_1stTransaction
	from (
	select distinct PhysicianID,PatientID,CardID,Date_Name,Dist from tblTransactions2
	) a
	inner join (
	select distinct PatientID,CardID,Date_Name,Date_Name_1stTransaction,Time_1stTransaction,Dist from tblActivations_unit2 
	where week_id <= 52 and Date_Name_1stTransaction is not null
	) b
	on a.PatientID = b.PatientID and a.CardID = b.CardID and a.Date_Name = b.Date_Name_1stTransaction and a.Dist = B.Dist
) a
inner join PhysicianList_Dist b
on a.PhysicianID = b.PhysicianID and a.Dist = b.Dist
where b.Type = 'PDRP'
group by a.Dist

update a
set C52W_Time_to_1st_Transaction = cast(round(b.Avg_Time_1stTransaction,0) as varchar) + ' days'
from OutputPhysicianData_PDRP_Dist a,tempTimetoFirstTransaction_PDRP_Dist b
where a.Terr = b.Dist

update a
set Patients_Not_Using_Copay_Card_Percentage_Of_Total = cast((b.PatientNum - b.isUseCard) * 1.0 / b.PatientNum as decimal(19,2))
from OutputPhysicianData_PDRP_Dist a,(select a.Terr,sum(PatientNum) as PatientNum ,sum(isUseCard) as isUseCard
	from (select distinct left(terr,3)+'00' as Terr, PhysicianID,PatientNum,isUseCard from tempNotUsingCard) a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Dist
	where b.type = 'PDRP'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C13W_Expirations = isnull(C13W,0)
,P13W_Expirations = isnull(P13W,0)
,C13W_vs_P13W_Expirations_Growth = case when P13W = 0 then null else (C13W - P13W) * 1.0 / P13W end
,CYTD_vs_PYTD_Expirations_Growth = case when PYTD = 0 then null else (CYTD - PYTD) * 1.0 / PYTD end
from OutputPhysicianData_PDRP_Dist a
left join (select b.Dist,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W
	from tempPhysicianExpiredPatient a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID 
	where b.type = 'PDRP'
	group by b.Dist
) b
on a.Terr = b.Dist


--Region Level

if object_id('OutputPhysicianData_PDRP_Reg') is not null
	drop table OutputPhysicianData_PDRP_Reg
select * into OutputPhysicianData_PDRP_Reg from OutputPhysicianData where 1=0
	
insert into OutputPhysicianData_PDRP_Reg(Physician_Name,Target,Terr)
select distinct Physician_Name,Target,left(Terr,2)+'000' from OutputPhysicianData a
where exists  (select Reg,PhysicianID from PhySicianList_Reg b where Type = 'PDRP' and a.PhysicianID = b.PhysicianID and left(a.Terr,2)+'000' = b.Reg) 
--and a.Physician_Name = 'PDRP Physician'

update a
set CYTD_Transaction = b.CYTD,PYTD_Transaction = b.PYTD,CYTD_vs_PYTD_Transactions_Growth = case when b.PYTD = 0 then null else cast((b.CYTD - b.PYTD) * 1.0/b.PYTD as decimal(19,3)) end 
,C26W_Transactions = b.C26W,C26W_vs_P26W_Transactions_Growth = case when b.P26W = 0 then null else cast((b.C26W - b.P26W) * 1.0/b.P26W as decimal(19,3)) end 
,C13W_Transactions = b.C13W,C13W_vs_P13W_Transactions_Growth = case when b.P13W = 0 then null else cast((b.C13W - b.P13W) * 1.0/b.P13W as decimal(19,3)) end 
,CW_transactions = b.CW,PW_transactions = b.PW,CW_vs_PW_Transactions_Growth = case when b.PW = 0 then null else cast((b.CW - b.PW) * 1.0/b.PW as decimal(19,3)) end 
from OutputPhysicianData_PDRP_Reg a,(
	select a.Reg,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W,sum(CW) as CW,sum(CYTD) as PW
			,sum(C26W) as C26W,sum(P26W) as P26W,sum(C52W) as C52W,sum(P52W) as P52W
	from tempTransactions_Reg a
	inner join PhySicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Reg = b.Reg
	where b.type = 'PDRP'
	group by a.Reg
) b
where a.Terr = b.Reg

update a
set C52W_Average_Copay_Payout = b.AvgAmount
from OutputPhysicianData_PDRP_Reg a,(
	select a.Reg,avg(CopayAmount) as AvgAmount
	from tempTransactionsWithPeriod a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Reg = b.Reg and b.type = 'PDRP'
	where a.Item = 'C52W'
	group by a.Reg
) b
where a.Terr = b.Reg


if object_id('RankPharmacy_PDRP_Reg') is not null
	drop table RankPharmacy_PDRP_Reg
	
select row_number() over(partition by Terr order by CountClaim desc,PharmacyName) as RankNum,* 
into RankPharmacy_PDRP_Reg
from (
	select a.Terr,a.PharmacyID,a.PharmacyName,sum(CountClaim) as CountClaim 
	from (select distinct left(Terr,2)+'000' as Terr,PhysicianID,PharmacyID,PharmacyName,CountClaim
	From RankPharmacy) a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Reg
	where b.type = 'PDRP'
	group by a.Terr,a.PharmacyID,a.PharmacyName
) a

update a
set Pharmacy_Rank_1 = b.PharmacyName , PharmacyID_Rank_1 = b.PharmacyID
from OutputPhysicianData_PDRP_Reg a,RankPharmacy_PDRP_Reg b
where a.Terr = b.Terr and b.RankNum = 1

update a
set Pharmacy_Rank_2 = b.PharmacyName , PharmacyID_Rank_2 = b.PharmacyID
from OutputPhysicianData_PDRP_Reg a,RankPharmacy_PDRP_Reg b
where a.Terr = b.Terr and b.RankNum = 2

update a
set Pharmacy_Rank_3 = b.PharmacyName , PharmacyID_Rank_3 = b.PharmacyID
from OutputPhysicianData_PDRP_Reg a,RankPharmacy_PDRP_Reg b
where a.Terr = b.Terr and b.RankNum = 3


if object_id('tempTimetoFirstTransaction_PDRP_Reg') is not null
	drop table tempTimetoFirstTransaction_PDRP_Reg

select a.Reg,avg(Time_1stTransaction) as Avg_Time_1stTransaction
into tempTimetoFirstTransaction_PDRP_Reg
from (
	select distinct a.Reg,a.PhysicianID,a.PatientID,a.CardID,a.Date_Name as Claim_Date,b.Date_Name as CardActive_Date,b.Time_1stTransaction
	from (
	select distinct PhysicianID,PatientID,CardID,Date_Name,Reg from tblTransactions2
	) a
	inner join (
	select distinct PatientID,CardID,Date_Name,Date_Name_1stTransaction,Time_1stTransaction,Reg from tblActivations_unit2 
	where week_id <= 52 and Date_Name_1stTransaction is not null
	) b
	on a.PatientID = b.PatientID and a.CardID = b.CardID and a.Date_Name = b.Date_Name_1stTransaction and a.Reg = B.Reg
) a
inner join PhysicianList_Reg b
on a.PhysicianID = b.PhysicianID and a.Reg = b.Reg
where b.Type = 'PDRP'
group by a.Reg

update a
set C52W_Time_to_1st_Transaction = cast(round(b.Avg_Time_1stTransaction,0) as varchar) + ' days'
from OutputPhysicianData_PDRP_Reg a,tempTimetoFirstTransaction_PDRP_Reg b
where a.Terr = b.Reg

update a
set Patients_Not_Using_Copay_Card_Percentage_Of_Total = cast((b.PatientNum - b.isUseCard) * 1.0 / b.PatientNum as decimal(19,2))
from OutputPhysicianData_PDRP_Reg a,(select a.Terr,sum(PatientNum) as PatientNum ,sum(isUseCard) as isUseCard
	from (select distinct left(terr,2)+'000' as Terr, PhysicianID,PatientNum,isUseCard from tempNotUsingCard) a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Reg
	where b.type = 'PDRP'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C13W_Expirations = isnull(C13W,0)
,P13W_Expirations = isnull(P13W,0)
,C13W_vs_P13W_Expirations_Growth = case when P13W = 0 then null else (C13W - P13W) * 1.0 / P13W end
,CYTD_vs_PYTD_Expirations_Growth = case when PYTD = 0 then null else (CYTD - PYTD) * 1.0 / PYTD end
from OutputPhysicianData_PDRP_Reg a
left join (select b.Reg,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W
	from tempPhysicianExpiredPatient a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID 
	where b.type = 'PDRP'
	group by b.Reg
) b
on a.Terr = b.Reg



-------------------------------------Unknown
---------------------------------
if object_id('OutputPhysicianData_Unknown') is not null
	drop table OutputPhysicianData_Unknown
select * into OutputPhysicianData_Unknown from OutputPhysicianData where 1=0
	
insert into OutputPhysicianData_Unknown(Physician_Name,Target,Terr)
select distinct Physician_Name,Target,Terr from OutputPhysicianData a
where exists  (select Terr,PhysicianID from PhySicianList b where Type = 'Unknown' and a.PhysicianID = b.PhysicianID and a.Terr = b.Terr) 
--and a.Physician_Name = 'All Other Physicians'

update a
set CYTD_Transaction = b.CYTD,PYTD_Transaction = b.PYTD,CYTD_vs_PYTD_Transactions_Growth = case when b.PYTD = 0 then null else cast((b.CYTD - b.PYTD) * 1.0/b.PYTD as decimal(19,3)) end 
,C26W_Transactions = b.C26W,C26W_vs_P26W_Transactions_Growth = case when b.P26W = 0 then null else cast((b.C26W - b.P26W) * 1.0/b.P26W as decimal(19,3)) end 
,C13W_Transactions = b.C13W,C13W_vs_P13W_Transactions_Growth = case when b.P13W = 0 then null else cast((b.C13W - b.P13W) * 1.0/b.P13W as decimal(19,3)) end 
,CW_transactions = b.CW,PW_transactions = b.PW,CW_vs_PW_Transactions_Growth = case when b.PW = 0 then null else cast((b.CW - b.PW) * 1.0/b.PW as decimal(19,3)) end 
from OutputPhysicianData_Unknown a,(
	select a.Terr,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W,sum(CW) as CW,sum(CYTD) as PW
			,sum(C26W) as C26W,sum(P26W) as P26W,sum(C52W) as C52W,sum(P52W) as P52W
	from tempTransactions a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
	where b.type = 'Unknown'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C52W_Average_Copay_Payout = b.AvgAmount
from OutputPhysicianData_Unknown a,(
	select b.Terr,avg(CopayAmount) as AvgAmount from tempTransactionsWithPeriod a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
	where Item = 'C52W' and b.type = 'Unknown'
	group by b.Terr
) b
where a.Terr = b.Terr


if object_id('RankPharmacy_Unknown') is not null
	drop table RankPharmacy_Unknown
	
select row_number() over(partition by Terr order by CountClaim desc,PharmacyName) as RankNum,* 
into RankPharmacy_Unknown
from (
select b.Terr,a.PharmacyID,a.PharmacyName,sum(CountClaim) as CountClaim 
from RankPharmacy a
inner join PhysicianList b
on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
where b.type = 'Unknown'
group by b.Terr,a.PharmacyID,a.PharmacyName
) a

update a
set Pharmacy_Rank_1 = b.PharmacyName , PharmacyID_Rank_1 = b.PharmacyID
from OutputPhysicianData_Unknown a,RankPharmacy_Unknown b
where a.Terr = b.Terr and b.RankNum = 1

update a
set Pharmacy_Rank_2 = b.PharmacyName , PharmacyID_Rank_2 = b.PharmacyID
from OutputPhysicianData_Unknown a,RankPharmacy_Unknown b
where a.Terr = b.Terr and b.RankNum = 2

update a
set Pharmacy_Rank_3 = b.PharmacyName , PharmacyID_Rank_3 = b.PharmacyID
from OutputPhysicianData_Unknown a,RankPharmacy_Unknown b
where a.Terr = b.Terr and b.RankNum = 3


if object_id('tempTimetoFirstTransaction_Unknown') is not null
	drop table tempTimetoFirstTransaction_Unknown

select a.Terr,avg(Time_1stTransaction) as Avg_Time_1stTransaction
into tempTimetoFirstTransaction_Unknown
from (
	select distinct a.Terr,a.PhysicianID,a.PatientID,a.CardID,a.Date_Name as Claim_Date,b.Date_Name as CardActive_Date,b.Time_1stTransaction
	from (
	select PhysicianID,PatientID,CardID,Date_Name,Terr from tblTransactions2
	) a
	inner join (
	select PatientID,CardID,Date_Name,Date_Name_1stTransaction,Time_1stTransaction,Terr from tblActivations_unit2 
	where week_id <= 52 and Date_Name_1stTransaction is not null
	) b
	on a.PatientID = b.PatientID and a.CardID = b.CardID and a.Date_Name = b.Date_Name_1stTransaction and a.Terr = B.Terr
) a
inner join PhysicianList b
on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
where b.Type = 'Unknown'
group by a.Terr

update a
set C52W_Time_to_1st_Transaction = cast(round(b.Avg_Time_1stTransaction,0) as varchar) + ' days'
from OutputPhysicianData_Unknown a,tempTimetoFirstTransaction_Unknown b
where a.Terr = b.Terr

update a
set Patients_Not_Using_Copay_Card_Percentage_Of_Total = cast((b.PatientNum - b.isUseCard) * 1.0 / b.PatientNum as decimal(19,2))
from OutputPhysicianData_Unknown a,(select a.Terr,sum(PatientNum) as PatientNum ,sum(isUseCard) as isUseCard
	from tempNotUsingCard a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Terr
	where b.type = 'Unknown'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C13W_Expirations = isnull(C13W,0)
,P13W_Expirations = isnull(P13W,0)
,C13W_vs_P13W_Expirations_Growth = case when P13W = 0 then null else (C13W - P13W) * 1.0 / P13W end
,CYTD_vs_PYTD_Expirations_Growth = case when PYTD = 0 then null else (CYTD - PYTD) * 1.0 / PYTD end
from OutputPhysicianData_Unknown a
left join (select b.Terr,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W
	from tempPhysicianExpiredPatient a
	inner join PhysicianList b
	on a.PhysicianID = b.PhysicianID 
	where b.type = 'Unknown'
	group by b.Terr
) b
on a.Terr = b.Terr

--District Level

if object_id('OutputPhysicianData_Unknown_Dist') is not null
	drop table OutputPhysicianData_Unknown_Dist
select * into OutputPhysicianData_Unknown_Dist from OutputPhysicianData where 1=0
	
insert into OutputPhysicianData_Unknown_Dist(Physician_Name,Target,Terr)
select distinct Physician_Name,Target,left(Terr,3)+'00' from OutputPhysicianData a
where exists  (select Dist,PhysicianID from PhySicianList_Dist b where Type = 'Unknown' and a.PhysicianID = b.PhysicianID and left(a.Terr,3)+'00' = b.Dist) 

update a
set CYTD_Transaction = b.CYTD,PYTD_Transaction = b.PYTD,CYTD_vs_PYTD_Transactions_Growth = case when b.PYTD = 0 then null else cast((b.CYTD - b.PYTD) * 1.0/b.PYTD as decimal(19,3)) end 
,C26W_Transactions = b.C26W,C26W_vs_P26W_Transactions_Growth = case when b.P26W = 0 then null else cast((b.C26W - b.P26W) * 1.0/b.P26W as decimal(19,3)) end 
,C13W_Transactions = b.C13W,C13W_vs_P13W_Transactions_Growth = case when b.P13W = 0 then null else cast((b.C13W - b.P13W) * 1.0/b.P13W as decimal(19,3)) end 
,CW_transactions = b.CW,PW_transactions = b.PW,CW_vs_PW_Transactions_Growth = case when b.PW = 0 then null else cast((b.CW - b.PW) * 1.0/b.PW as decimal(19,3)) end 
from OutputPhysicianData_Unknown_Dist a,(
	select a.Dist,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W,sum(CW) as CW,sum(CYTD) as PW
			,sum(C26W) as C26W,sum(P26W) as P26W,sum(C52W) as C52W,sum(P52W) as P52W
	from tempTransactions_Dist a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Dist = b.Dist
	where b.type = 'Unknown'
	group by a.Dist
) b
where a.Terr = b.Dist

update a
set C52W_Average_Copay_Payout = b.AvgAmount
from OutputPhysicianData_Unknown_Dist a,(
	select a.Dist,avg(CopayAmount) as AvgAmount
	from tempTransactionsWithPeriod a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Dist = b.Dist and b.type = 'Unknown'
	where a.Item = 'C52W'
	group by a.Dist
) b
where a.Terr = b.Dist


if object_id('RankPharmacy_Unknown_Dist') is not null
	drop table RankPharmacy_Unknown_Dist
	
select row_number() over(partition by Terr order by CountClaim desc,PharmacyName) as RankNum,* 
into RankPharmacy_Unknown_Dist
from (
	select a.Terr,a.PharmacyID,a.PharmacyName,sum(CountClaim) as CountClaim 
	from (select distinct left(Terr,3)+'00' as Terr,PhysicianID,PharmacyID,PharmacyName,CountClaim
	From RankPharmacy) a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Dist
	where b.type = 'Unknown'
	group by a.Terr,a.PharmacyID,a.PharmacyName
) a

update a
set Pharmacy_Rank_1 = b.PharmacyName , PharmacyID_Rank_1 = b.PharmacyID
from OutputPhysicianData_Unknown_Dist a,RankPharmacy_Unknown_Dist b
where a.Terr = b.Terr and b.RankNum = 1

update a
set Pharmacy_Rank_2 = b.PharmacyName , PharmacyID_Rank_2 = b.PharmacyID
from OutputPhysicianData_Unknown_Dist a,RankPharmacy_Unknown_Dist b
where a.Terr = b.Terr and b.RankNum = 2

update a
set Pharmacy_Rank_3 = b.PharmacyName , PharmacyID_Rank_3 = b.PharmacyID
from OutputPhysicianData_Unknown_Dist a,RankPharmacy_Unknown_Dist b
where a.Terr = b.Terr and b.RankNum = 3


if object_id('tempTimetoFirstTransaction_Unknown_Dist') is not null
	drop table tempTimetoFirstTransaction_Unknown_Dist

select a.Dist,avg(Time_1stTransaction) as Avg_Time_1stTransaction
into tempTimetoFirstTransaction_Unknown_Dist
from (
	select distinct a.Dist,a.PhysicianID,a.PatientID,a.CardID,a.Date_Name as Claim_Date,b.Date_Name as CardActive_Date,b.Time_1stTransaction
	from (
	select distinct PhysicianID,PatientID,CardID,Date_Name,Dist from tblTransactions2
	) a
	inner join (
	select distinct PatientID,CardID,Date_Name,Date_Name_1stTransaction,Time_1stTransaction,Dist from tblActivations_unit2 
	where week_id <= 52 and Date_Name_1stTransaction is not null
	) b
	on a.PatientID = b.PatientID and a.CardID = b.CardID and a.Date_Name = b.Date_Name_1stTransaction and a.Dist = B.Dist
) a
inner join PhysicianList_Dist b
on a.PhysicianID = b.PhysicianID and a.Dist = b.Dist
where b.Type = 'Unknown'
group by a.Dist

update a
set C52W_Time_to_1st_Transaction = cast(round(b.Avg_Time_1stTransaction,0) as varchar) + ' days'
from OutputPhysicianData_Unknown_Dist a,tempTimetoFirstTransaction_Unknown_Dist b
where a.Terr = b.Dist

update a
set Patients_Not_Using_Copay_Card_Percentage_Of_Total = cast((b.PatientNum - b.isUseCard) * 1.0 / b.PatientNum as decimal(19,2))
from OutputPhysicianData_Unknown_Dist a,(select a.Terr,sum(PatientNum) as PatientNum ,sum(isUseCard) as isUseCard
	from (select distinct left(terr,3)+'00' as Terr, PhysicianID,PatientNum,isUseCard from tempNotUsingCard) a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Dist
	where b.type = 'Unknown'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C13W_Expirations = isnull(C13W,0)
,P13W_Expirations = isnull(P13W,0)
,C13W_vs_P13W_Expirations_Growth = case when P13W = 0 then null else (C13W - P13W) * 1.0 / P13W end
,CYTD_vs_PYTD_Expirations_Growth = case when PYTD = 0 then null else (CYTD - PYTD) * 1.0 / PYTD end
from OutputPhysicianData_Unknown_Dist a
left join (select b.Dist,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W
	from tempPhysicianExpiredPatient a
	inner join PhysicianList_Dist b
	on a.PhysicianID = b.PhysicianID 
	where b.type = 'Unknown'
	group by b.Dist
) b
on a.Terr = b.Dist

--Region Level

if object_id('OutputPhysicianData_Unknown_Reg') is not null
	drop table OutputPhysicianData_Unknown_Reg
select * into OutputPhysicianData_Unknown_Reg from OutputPhysicianData where 1=0
	
insert into OutputPhysicianData_Unknown_Reg(Physician_Name,Target,Terr)
select distinct Physician_Name,Target,left(Terr,2)+'000' from OutputPhysicianData a
where exists  (select Reg,PhysicianID from PhySicianList_Reg b where Type = 'Unknown' and a.PhysicianID = b.PhysicianID and left(a.Terr,2)+'000' = b.Reg) 

update a
set CYTD_Transaction = b.CYTD,PYTD_Transaction = b.PYTD,CYTD_vs_PYTD_Transactions_Growth = case when b.PYTD = 0 then null else cast((b.CYTD - b.PYTD) * 1.0/b.PYTD as decimal(19,3)) end 
,C26W_Transactions = b.C26W,C26W_vs_P26W_Transactions_Growth = case when b.P26W = 0 then null else cast((b.C26W - b.P26W) * 1.0/b.P26W as decimal(19,3)) end 
,C13W_Transactions = b.C13W,C13W_vs_P13W_Transactions_Growth = case when b.P13W = 0 then null else cast((b.C13W - b.P13W) * 1.0/b.P13W as decimal(19,3)) end 
,CW_transactions = b.CW,PW_transactions = b.PW,CW_vs_PW_Transactions_Growth = case when b.PW = 0 then null else cast((b.CW - b.PW) * 1.0/b.PW as decimal(19,3)) end 
from OutputPhysicianData_Unknown_Reg a,(
	select a.Reg,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W,sum(CW) as CW,sum(CYTD) as PW
			,sum(C26W) as C26W,sum(P26W) as P26W,sum(C52W) as C52W,sum(P52W) as P52W
	from tempTransactions_Reg a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Reg = b.Reg
	where b.type = 'Unknown'
	group by a.Reg
) b
where a.Terr = b.Reg

update a
set C52W_Average_Copay_Payout = b.AvgAmount
from OutputPhysicianData_Unknown_Reg a,(
	select a.Reg,avg(CopayAmount) as AvgAmount
	from tempTransactionsWithPeriod a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Reg = b.Reg and b.type = 'Unknown'
	where a.Item = 'C52W'
	group by a.Reg
) b
where a.Terr = b.Reg


if object_id('RankPharmacy_Unknown_Reg') is not null
	drop table RankPharmacy_Unknown_Reg
	
select row_number() over(partition by Terr order by CountClaim desc,PharmacyName) as RankNum,* 
into RankPharmacy_Unknown_Reg
from (
	select a.Terr,a.PharmacyID,a.PharmacyName,sum(CountClaim) as CountClaim 
	from (select distinct left(Terr,3)+'00' as Terr,PhysicianID,PharmacyID,PharmacyName,CountClaim
	From RankPharmacy) a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Reg
	where b.type = 'Unknown'
	group by a.Terr,a.PharmacyID,a.PharmacyName
) a

update a
set Pharmacy_Rank_1 = b.PharmacyName , PharmacyID_Rank_1 = b.PharmacyID
from OutputPhysicianData_Unknown_Reg a,RankPharmacy_Unknown_Reg b
where a.Terr = b.Terr and b.RankNum = 1

update a
set Pharmacy_Rank_2 = b.PharmacyName , PharmacyID_Rank_2 = b.PharmacyID
from OutputPhysicianData_Unknown_Reg a,RankPharmacy_Unknown_Reg b
where a.Terr = b.Terr and b.RankNum = 2

update a
set Pharmacy_Rank_3 = b.PharmacyName , PharmacyID_Rank_3 = b.PharmacyID
from OutputPhysicianData_Unknown_Reg a,RankPharmacy_Unknown_Reg b
where a.Terr = b.Terr and b.RankNum = 3


if object_id('tempTimetoFirstTransaction_Unknown_Reg') is not null
	drop table tempTimetoFirstTransaction_Unknown_Reg

select a.Reg,avg(Time_1stTransaction) as Avg_Time_1stTransaction
into tempTimetoFirstTransaction_Unknown_Reg
from (
	select distinct a.Reg,a.PhysicianID,a.PatientID,a.CardID,a.Date_Name as Claim_Date,b.Date_Name as CardActive_Date,b.Time_1stTransaction
	from (
	select distinct PhysicianID,PatientID,CardID,Date_Name,Reg from tblTransactions2
	) a
	inner join (
	select distinct PatientID,CardID,Date_Name,Date_Name_1stTransaction,Time_1stTransaction,Reg from tblActivations_unit2 
	where week_id <= 52 and Date_Name_1stTransaction is not null
	) b
	on a.PatientID = b.PatientID and a.CardID = b.CardID and a.Date_Name = b.Date_Name_1stTransaction and a.Reg = B.Reg
) a
inner join PhysicianList_Reg b
on a.PhysicianID = b.PhysicianID and a.Reg = b.Reg
where b.Type = 'Unknown'
group by a.Reg

update a
set C52W_Time_to_1st_Transaction = cast(round(b.Avg_Time_1stTransaction,0) as varchar) + ' days'
from OutputPhysicianData_Unknown_Reg a,tempTimetoFirstTransaction_Unknown_Reg b
where a.Terr = b.Reg

update a
set Patients_Not_Using_Copay_Card_Percentage_Of_Total = cast((b.PatientNum - b.isUseCard) * 1.0 / b.PatientNum as decimal(19,2))
from OutputPhysicianData_Unknown_Reg a,(select a.Terr,sum(PatientNum) as PatientNum ,sum(isUseCard) as isUseCard
	from (select distinct left(terr,3)+'00' as Terr, PhysicianID,PatientNum,isUseCard from tempNotUsingCard) a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID and a.Terr = b.Reg
	where b.type = 'Unknown'
	group by a.Terr
) b
where a.Terr = b.Terr

update a
set C13W_Expirations = isnull(C13W,0)
,P13W_Expirations = isnull(P13W,0)
,C13W_vs_P13W_Expirations_Growth = case when P13W = 0 then null else (C13W - P13W) * 1.0 / P13W end
,CYTD_vs_PYTD_Expirations_Growth = case when PYTD = 0 then null else (CYTD - PYTD) * 1.0 / PYTD end
from OutputPhysicianData_Unknown_Reg a
left join (select b.Reg,sum(CYTD) as CYTD,sum(PYTD) as PYTD,sum(C13W) as C13W,sum(P13W) as P13W
	from tempPhysicianExpiredPatient a
	inner join PhysicianList_Reg b
	on a.PhysicianID = b.PhysicianID 
	where b.type = 'Unknown'
	group by b.Reg
) b
on a.Terr = b.Reg

--------------------final

--OutputTerr2(OutputPhysicianData_Final)
if object_id('OutputPhysicianData_Final') is not null
	drop table OutputPhysicianData_Final

select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,Apex_Terr as D,Pinnacle_Terr as E
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as F,NPI as G,Amgen_Customer_Master_ID as H
,Street as I,City as J,State as K,Zip as L,C52W_Time_to_1st_Transaction as M,C52W_Average_Copay_Payout as N
,CYTD_Transaction as O,PYTD_Transaction as P,CYTD_vs_PYTD_Transactions_Growth as Q,C26W_Transactions as R
,C26W_vs_P26W_Transactions_Growth as S,C13W_Transactions as T,C13W_vs_P13W_Transactions_Growth as U
,CW_transactions as V,PW_transactions as W,CW_vs_PW_Transactions_Growth as X,C13W_Expirations as Y
,P13W_Expirations as Z,C13W_vs_P13W_Expirations_Growth as AA,CYTD_vs_PYTD_Expirations_Growth as AB
,Pharmacy_Rank_1 as AC,Pharmacy_Rank_2 as AD,Pharmacy_Rank_3 as AE
,Cat1 as AF,Cat2 as AG,Cat3 as AH,Cat4 as AI,Cat5 as AJ,Cat6 as AK,Cat7 as AL,Cat8 as AM,Cat9 as AN
,Terr
into OutputPhysicianData_Final
from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,SUMMIT_Terr order by SUMMIT_Terr,isnull(APEX_Terr,'ZZZZZ'),isnull(PINNACLE_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where SUMMIT_Terr is not null
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.SUMMIT_Terr and b.Rank_Num = 1

insert into OutputPhysicianData_Final
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,PINNACLE_Terr as D,SUMMIT_Terr as E
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as F,NPI as G,Amgen_Customer_Master_ID as H
,Street as I,City as J,State as K,Zip as L,C52W_Time_to_1st_Transaction as M,C52W_Average_Copay_Payout as N
,CYTD_Transaction as O,PYTD_Transaction as P,CYTD_vs_PYTD_Transactions_Growth as Q,C26W_Transactions as R
,C26W_vs_P26W_Transactions_Growth as S,C13W_Transactions as T,C13W_vs_P13W_Transactions_Growth as U
,CW_transactions as V,PW_transactions as W,CW_vs_PW_Transactions_Growth as X,C13W_Expirations as Y
,P13W_Expirations as Z,C13W_vs_P13W_Expirations_Growth as AA,CYTD_vs_PYTD_Expirations_Growth as AB
,Pharmacy_Rank_1 as AC,Pharmacy_Rank_2 as AD,Pharmacy_Rank_3 as AE
,Cat1 as AF,Cat2 as AG,Cat3 as AH,Cat4 as AI,Cat5 as AJ,Cat6 as AK,Cat7 as AL,Cat8 as AM,Cat9 as AN
,Terr from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,APEX_Terr order by APEX_Terr,isnull(PINNACLE_Terr,'ZZZZZ'),isnull(SUMMIT_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where APEX_Terr is not null
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.APEX_Terr and b.Rank_Num = 1

insert into OutputPhysicianData_Final
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,APEX_Terr as D,SUMMIT_Terr as E
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as F,NPI as G,Amgen_Customer_Master_ID as H
,Street as I,City as J,State as K,Zip as L,C52W_Time_to_1st_Transaction as M,C52W_Average_Copay_Payout as N
,CYTD_Transaction as O,PYTD_Transaction as P,CYTD_vs_PYTD_Transactions_Growth as Q,C26W_Transactions as R
,C26W_vs_P26W_Transactions_Growth as S,C13W_Transactions as T,C13W_vs_P13W_Transactions_Growth as U
,CW_transactions as V,PW_transactions as W,CW_vs_PW_Transactions_Growth as X,C13W_Expirations as Y
,P13W_Expirations as Z,C13W_vs_P13W_Expirations_Growth as AA,CYTD_vs_PYTD_Expirations_Growth as AB
,Pharmacy_Rank_1 as AC,Pharmacy_Rank_2 as AD,Pharmacy_Rank_3 as AE
,Cat1 as AF,Cat2 as AG,Cat3 as AH,Cat4 as AI,Cat5 as AJ,Cat6 as AK,Cat7 as AL,Cat8 as AM,Cat9 as AN
,Terr from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,PINNACLE_Terr order by PINNACLE_Terr,isnull(APEX_Terr,'ZZZZZ'),isnull(SUMMIT_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where PINNACLE_Terr is not null
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.PINNACLE_Terr and b.Rank_Num = 1

-------

insert into OutputPhysicianData_Final
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,cast(null as varchar(5)) as D,cast(null as varchar(5)) as E
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as F,NPI as G,Amgen_Customer_Master_ID as H
,Street as I,City as J,State as K,Zip as L,C52W_Time_to_1st_Transaction as M,C52W_Average_Copay_Payout as N
,CYTD_Transaction as O,PYTD_Transaction as P,CYTD_vs_PYTD_Transactions_Growth as Q,C26W_Transactions as R
,C26W_vs_P26W_Transactions_Growth as S,C13W_Transactions as T,C13W_vs_P13W_Transactions_Growth as U
,CW_transactions as V,PW_transactions as W,CW_vs_PW_Transactions_Growth as X,C13W_Expirations as Y
,P13W_Expirations as Z,C13W_vs_P13W_Expirations_Growth as AA,CYTD_vs_PYTD_Expirations_Growth as AB
,Pharmacy_Rank_1 as AC,Pharmacy_Rank_2 as AD,Pharmacy_Rank_3 as AE
,Cat1 as AF,Cat2 as AG,Cat3 as AH,Cat4 as AI,Cat5 as AJ,Cat6 as AK,Cat7 as AL,Cat8 as AM,Cat9 as AN
,Terr
from( 
select * from OutputPhysicianData_PDRP 
union all
select * from OutputPhysicianData_Unknown
) a

update OutputPhysicianData_Final
set AF = 1,AG = 0,AH = 0,AI = 0,AJ = 0,AK = 0,AL = 0,AM = 0,AN = 0

update A
SET AG = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A, Dense_Rank() Over (Partition by Terr Order by F DESC,B) AS RankCat2
FROM OutputPhysicianData_Final
WHERE C = 'Derm A' AND F > 0
) B ON A.Terr = B.Terr AND A.A = B.A AND B.RankCat2 <= 10

update A
SET AH = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A, Dense_Rank() Over (Partition by Terr Order by F DESC,B) AS RankCat3
FROM OutputPhysicianData_Final
WHERE C = 'Rheum A' AND F > 0
) B ON A.Terr = B.Terr AND A.A = B.A AND B.RankCat3 <= 10

update A
SET AI = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A
FROM OutputPhysicianData_Final
WHERE (C = 'Rheum A' OR C = 'Rheum B' OR C = 'Rheum B1' OR C = 'Rheum B2') AND T = 0
) B ON A.Terr = B.Terr AND A.A = B.A

update A
SET AJ = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A
FROM OutputPhysicianData_Final
WHERE (C = 'Derm A' OR C = 'Derm B') AND T = 0
) B ON A.Terr = B.Terr AND A.A = B.A

update A
SET AK = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A, Dense_Rank() Over (Partition by Terr Order by S,B) AS RankCat6
FROM OutputPhysicianData_Final
WHERE (C = 'Rheum A' OR C = 'Rheum B' OR C = 'Rheum B1' OR C = 'Rheum B2') AND S < 0
) B ON A.Terr = B.Terr AND A.A = B.A AND B.RankCat6 <= 15

update A
SET AL = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A, Dense_Rank() Over (Partition by Terr Order by S,B) AS RankCat7
FROM OutputPhysicianData_Final
WHERE (C = 'Derm A' OR C = 'Derm B') AND S < 0
) B ON A.Terr = B.Terr AND A.A = B.A AND B.RankCat7 <= 15

update A
SET AM = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A, Dense_Rank() Over (Partition by Terr Order by Q DESC,B) AS RankCat8
FROM OutputPhysicianData_Final
WHERE B NOT IN ('PDRP Physician','All Other Physicians') AND Q > 0
) B ON A.Terr = B.Terr AND A.A = B.A AND B.RankCat8 <= 15

update A
SET AN = 1
FROM OutputPhysicianData_Final A
INNER JOIN (
SELECT Terr, A, Dense_Rank() Over (Partition by Terr Order by AA DESC,B) AS RankCat9
FROM OutputPhysicianData_Final
WHERE B NOT IN ('PDRP Physician','All Other Physicians') AND AA > 0
) B ON A.Terr = B.Terr AND A.A = B.A AND B.RankCat9 <= 10

update OutputPhysicianData_Final
set D = NULL, E = NULL
WHERE B = 'All Other Physicians'

--District Level

--OutputDist2(OutputPhysicianData_Final_Dist)
if object_id('OutputPhysicianData_Final_Dist') is not null
	drop table OutputPhysicianData_Final_Dist

select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,Apex_Terr as D,Pinnacle_Terr as E,Summit_Terr as F
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as G,NPI as H,Amgen_Customer_Master_ID as I
,Street as J,City as K,State as L,Zip as M,C52W_Time_to_1st_Transaction as N,C52W_Average_Copay_Payout as O
,CYTD_Transaction as P,PYTD_Transaction as Q,CYTD_vs_PYTD_Transactions_Growth as R,C26W_Transactions as S
,C26W_vs_P26W_Transactions_Growth as T,C13W_Transactions as U,C13W_vs_P13W_Transactions_Growth as V
,CW_transactions as W,PW_transactions as X,CW_vs_PW_Transactions_Growth as Y,C13W_Expirations as Z
,P13W_Expirations as AA,C13W_vs_P13W_Expirations_Growth as AB,CYTD_vs_PYTD_Expirations_Growth as AC
,Pharmacy_Rank_1 as AD,Pharmacy_Rank_2 as AE,Pharmacy_Rank_3 as AF
,Cat1 as AG,Cat2 as AH,Cat3 as AI,Cat4 as AJ,Cat5 as AK,Cat6 as AL,Cat7 as AM,Cat8 as AN,Cat9 as AO
,left(Terr,3)+'00' as Dist 
into OutputPhysicianData_Final_Dist
from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,SUMMIT_Terr order by SUMMIT_Terr,isnull(APEX_Terr,'ZZZZZ'),isnull(PINNACLE_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where SUMMIT_Terr is not null
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.SUMMIT_Terr and b.Rank_Num = 1

insert into OutputPhysicianData_Final_Dist
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,Apex_Terr as D,Pinnacle_Terr as E,Summit_Terr as F
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as G,NPI as H,Amgen_Customer_Master_ID as I
,Street as J,City as K,State as L,Zip as M,C52W_Time_to_1st_Transaction as N,C52W_Average_Copay_Payout as O
,CYTD_Transaction as P,PYTD_Transaction as Q,CYTD_vs_PYTD_Transactions_Growth as R,C26W_Transactions as S
,C26W_vs_P26W_Transactions_Growth as T,C13W_Transactions as U,C13W_vs_P13W_Transactions_Growth as V
,CW_transactions as W,PW_transactions as X,CW_vs_PW_Transactions_Growth as Y,C13W_Expirations as Z
,P13W_Expirations as AA,C13W_vs_P13W_Expirations_Growth as AB,CYTD_vs_PYTD_Expirations_Growth as AC
,Pharmacy_Rank_1 as AD,Pharmacy_Rank_2 as AE,Pharmacy_Rank_3 as AF
,Cat1 as AG,Cat2 as AH,Cat3 as AI,Cat4 as AJ,Cat5 as AK,Cat6 as AL,Cat7 as AM,Cat8 as AN,Cat9 as AO
,left(Terr,3)+'00' as Dist from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,APEX_Terr order by APEX_Terr,isnull(PINNACLE_Terr,'ZZZZZ'),isnull(SUMMIT_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where APEX_Terr is not null and left(isnull(SUMMIT_Terr,'ZZZZZ'),3) <> left(isnull(APEX_Terr,'ZZZZZ'),3)
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.APEX_Terr and b.Rank_Num = 1

insert into OutputPhysicianData_Final_Dist
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,Apex_Terr as D,Pinnacle_Terr as E,Summit_Terr as F
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as G,NPI as H,Amgen_Customer_Master_ID as I
,Street as J,City as K,State as L,Zip as M,C52W_Time_to_1st_Transaction as N,C52W_Average_Copay_Payout as O
,CYTD_Transaction as P,PYTD_Transaction as Q,CYTD_vs_PYTD_Transactions_Growth as R,C26W_Transactions as S
,C26W_vs_P26W_Transactions_Growth as T,C13W_Transactions as U,C13W_vs_P13W_Transactions_Growth as V
,CW_transactions as W,PW_transactions as X,CW_vs_PW_Transactions_Growth as Y,C13W_Expirations as Z
,P13W_Expirations as AA,C13W_vs_P13W_Expirations_Growth as AB,CYTD_vs_PYTD_Expirations_Growth as AC
,Pharmacy_Rank_1 as AD,Pharmacy_Rank_2 as AE,Pharmacy_Rank_3 as AF
,Cat1 as AG,Cat2 as AH,Cat3 as AI,Cat4 as AJ,Cat5 as AK,Cat6 as AL,Cat7 as AM,Cat8 as AN,Cat9 as AO
,left(Terr,3)+'00' as Dist from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,PINNACLE_Terr order by PINNACLE_Terr,isnull(APEX_Terr,'ZZZZZ'),isnull(SUMMIT_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where PINNACLE_Terr is not null and left(isnull(PINNACLE_Terr,'ZZZZZ'),3) <> left(isnull(APEX_Terr,'ZZZZZ'),3) and left(isnull(PINNACLE_Terr,'ZZZZZ'),3) <> left(isnull(SUMMIT_Terr,'ZZZZZ'),3)
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.PINNACLE_Terr and b.Rank_Num = 1

-------

insert into OutputPhysicianData_Final_Dist
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,cast(null as varchar(5)) as D,cast(null as varchar(5)) as E,cast(null as varchar(5)) as F
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as G,NPI as H,Amgen_Customer_Master_ID as I
,Street as J,City as K,State as L,Zip as M,C52W_Time_to_1st_Transaction as N,C52W_Average_Copay_Payout as O
,CYTD_Transaction as P,PYTD_Transaction as Q,CYTD_vs_PYTD_Transactions_Growth as R,C26W_Transactions as S
,C26W_vs_P26W_Transactions_Growth as T,C13W_Transactions as U,C13W_vs_P13W_Transactions_Growth as V
,CW_transactions as W,PW_transactions as X,CW_vs_PW_Transactions_Growth as Y,C13W_Expirations as Z
,P13W_Expirations as AA,C13W_vs_P13W_Expirations_Growth as AB,CYTD_vs_PYTD_Expirations_Growth as AC
,Pharmacy_Rank_1 as AD,Pharmacy_Rank_2 as AE,Pharmacy_Rank_3 as AF
,Cat1 as AG,Cat2 as AH,Cat3 as AI,Cat4 as AJ,Cat5 as AK,Cat6 as AL,Cat7 as AM,Cat8 as AN,Cat9 as AO
,left(Terr,3)+'00' as Dist
from( 
select * from OutputPhysicianData_PDRP_Dist
union all
select * from OutputPhysicianData_Unknown_Dist
) a 

update OutputPhysicianData_Final_Dist
set AG = 1,AH = 0,AI = 0,AJ = 0,AK = 0,AL = 0,AM = 0,AN = 0,AO=0

update A
SET AH = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A, Dense_Rank() Over (Partition by Dist Order by G DESC,B) AS RankCat2
FROM OutputPhysicianData_Final_Dist
WHERE C = 'Derm A' AND G > 0
) B ON A.Dist = B.Dist AND A.A = B.A AND B.RankCat2 <= 10

update A
SET AI = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A, Dense_Rank() Over (Partition by Dist Order by G DESC,B) AS RankCat3
FROM OutputPhysicianData_Final_Dist
WHERE C = 'Rheum A' AND G > 0
) B ON A.Dist = B.Dist AND A.A = B.A AND B.RankCat3 <= 10

update A
SET AJ = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A
FROM OutputPhysicianData_Final_Dist
WHERE (C = 'Rheum A' OR C = 'Rheum B' OR C = 'Rheum B1' OR C = 'Rheum B2') AND U = 0
) B ON A.Dist = B.Dist AND A.A = B.A

update A
SET AK = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A
FROM OutputPhysicianData_Final_Dist
WHERE (C = 'Derm A' OR C = 'Derm B') AND U = 0
) B ON A.Dist = B.Dist AND A.A = B.A

update A
SET AL = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A, Dense_Rank() Over (Partition by Dist Order by T,B) AS RankCat6
FROM OutputPhysicianData_Final_Dist
WHERE (C = 'Rheum A' OR C = 'Rheum B' OR C = 'Rheum B1' OR C = 'Rheum B2') AND T < 0
) B ON A.Dist = B.Dist AND A.A = B.A AND B.RankCat6 <= 15

update A
SET AM = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A, Dense_Rank() Over (Partition by Dist Order by T,B) AS RankCat7
FROM OutputPhysicianData_Final_Dist
WHERE (C = 'Derm A' OR C = 'Derm B') AND T < 0
) B ON A.Dist = B.Dist AND A.A = B.A AND B.RankCat7 <= 15

update A
SET AN = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A, Dense_Rank() Over (Partition by Dist Order by R DESC,B) AS RankCat8
FROM OutputPhysicianData_Final_Dist
WHERE B NOT IN ('PDRP Physician','All Other Physicians') AND R > 0
) B ON A.Dist = B.Dist AND A.A = B.A AND B.RankCat8 <= 15

update A
SET AO = 1
FROM OutputPhysicianData_Final_Dist A
INNER JOIN (
SELECT Dist, A, Dense_Rank() Over (Partition by Dist Order by AB DESC,B) AS RankCat9
FROM OutputPhysicianData_Final_Dist
WHERE B NOT IN ('PDRP Physician','All Other Physicians') AND AB > 0
) B ON A.Dist = B.Dist AND A.A = B.A AND B.RankCat9 <= 10

update OutputPhysicianData_Final_Dist
set D = NULL, E = NULL, F = NULL
WHERE B = 'All Other Physicians'

update OutputPhysicianData_Final_Dist
set D = NULL
where left(D,3) <> left(Dist,3)

update OutputPhysicianData_Final_Dist
set E = NULL
where left(E,3) <> left(Dist,3)

update OutputPhysicianData_Final_Dist
set F = NULL
where left(F,3) <> left(Dist,3)

/*
select sum(O) from OutputPhysicianData_Final
where Terr = '3PA01'

select D from OutputDashboardData
where Terr = '3PA01' and A = 4

select sum(P) from OutputPhysicianData_Final_Dist
where Dist = '3QC00'

select D from OutputDashboardData1
where Dist = '3QC00' and A = 4
*/

--Region Level

--OutputReg3(OutputPhysicianData_Final_Reg)
if object_id('OutputPhysicianData_Final_Reg') is not null
	drop table OutputPhysicianData_Final_Reg

select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,left(Terr,3)+'00' as D, Apex_Terr as E,Pinnacle_Terr as F,Summit_Terr as G
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as H,NPI as I,Amgen_Customer_Master_ID as J
,Street as K,City as L,State as M,Zip as N,C52W_Time_to_1st_Transaction as O,C52W_Average_Copay_Payout as P
,CYTD_Transaction as Q,PYTD_Transaction as R,CYTD_vs_PYTD_Transactions_Growth as S,C26W_Transactions as T
,C26W_vs_P26W_Transactions_Growth as U,C13W_Transactions as V,C13W_vs_P13W_Transactions_Growth as W
,CW_transactions as X,PW_transactions as Y,CW_vs_PW_Transactions_Growth as Z,C13W_Expirations as AA
,P13W_Expirations as AB,C13W_vs_P13W_Expirations_Growth as AC,CYTD_vs_PYTD_Expirations_Growth as AD
,Pharmacy_Rank_1 as AE,Pharmacy_Rank_2 as AF,Pharmacy_Rank_3 as AG
,Cat1 as AH,Cat2 as AI,Cat3 as AJ,Cat4 as AK,Cat5 as AL,Cat6 as AM,Cat7 as AN,Cat8 as AO,Cat9 as AP
,left(Terr,2)+'000' as Reg 
into OutputPhysicianData_Final_Reg
from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,SUMMIT_Terr order by SUMMIT_Terr,isnull(APEX_Terr,'ZZZZZ'),isnull(PINNACLE_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where SUMMIT_Terr is not null
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.SUMMIT_Terr and b.Rank_Num = 1

insert into OutputPhysicianData_Final_Reg
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,left(Terr,3)+'00' as D,Apex_Terr as E,Pinnacle_Terr as F,Summit_Terr as G
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as H,NPI as I,Amgen_Customer_Master_ID as J
,Street as K,City as L,State as M,Zip as N,C52W_Time_to_1st_Transaction as O,C52W_Average_Copay_Payout as P
,CYTD_Transaction as Q,PYTD_Transaction as R,CYTD_vs_PYTD_Transactions_Growth as S,C26W_Transactions as T
,C26W_vs_P26W_Transactions_Growth as U,C13W_Transactions as V,C13W_vs_P13W_Transactions_Growth as W
,CW_transactions as X,PW_transactions as Y,CW_vs_PW_Transactions_Growth as Z,C13W_Expirations as AA
,P13W_Expirations as AB,C13W_vs_P13W_Expirations_Growth as AC,CYTD_vs_PYTD_Expirations_Growth as AD
,Pharmacy_Rank_1 as AE,Pharmacy_Rank_2 as AF,Pharmacy_Rank_3 as AG
,Cat1 as AH,Cat2 as AI,Cat3 as AJ,Cat4 as AK,Cat5 as AL,Cat6 as AM,Cat7 as AN,Cat8 as AO,Cat9 as AP
,left(Terr,2)+'000' as Reg from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,APEX_Terr order by APEX_Terr,isnull(PINNACLE_Terr,'ZZZZZ'),isnull(SUMMIT_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where APEX_Terr is not null and left(isnull(SUMMIT_Terr,'ZZZZZ'),3) <> left(isnull(APEX_Terr,'ZZZZZ'),3)
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.APEX_Terr and b.Rank_Num = 1

insert into OutputPhysicianData_Final_Reg
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,left(Terr,3)+'00' as D,Apex_Terr as E,Pinnacle_Terr as F,Summit_Terr as G
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as H,NPI as I,Amgen_Customer_Master_ID as J
,Street as K,City as L,State as M,Zip as N,C52W_Time_to_1st_Transaction as O,C52W_Average_Copay_Payout as P
,CYTD_Transaction as Q,PYTD_Transaction as R,CYTD_vs_PYTD_Transactions_Growth as S,C26W_Transactions as T
,C26W_vs_P26W_Transactions_Growth as U,C13W_Transactions as V,C13W_vs_P13W_Transactions_Growth as W
,CW_transactions as X,PW_transactions as Y,CW_vs_PW_Transactions_Growth as Z,C13W_Expirations as AA
,P13W_Expirations as AB,C13W_vs_P13W_Expirations_Growth as AC,CYTD_vs_PYTD_Expirations_Growth as AD
,Pharmacy_Rank_1 as AE,Pharmacy_Rank_2 as AF,Pharmacy_Rank_3 as AG
,Cat1 as AH,Cat2 as AI,Cat3 as AJ,Cat4 as AK,Cat5 as AL,Cat6 as AM,Cat7 as AN,Cat8 as AO,Cat9 as AP
,left(Terr,2)+'000' as Reg from (
 select * from  OutputPhysicianData a
where exists (select Terr,PhysicianID from PhySicianList b where Type = 'Normal' and a.Terr = b.Terr and a.PhysicianID = b.PhysicianID)
) a
inner join (
 select row_number() over(partition by PhysicianID,PINNACLE_Terr order by PINNACLE_Terr,isnull(APEX_Terr,'ZZZZZ'),isnull(SUMMIT_Terr,'ZZZZZ')) as Rank_Num,* 
 from tblDoctorTerrList 
 where PINNACLE_Terr is not null and left(isnull(PINNACLE_Terr,'ZZZZZ'),3) <> left(isnull(APEX_Terr,'ZZZZZ'),3) and left(isnull(PINNACLE_Terr,'ZZZZZ'),3) <> left(isnull(SUMMIT_Terr,'ZZZZZ'),3)
 ) b
 on a.PhysicianID = b.PhysicianID and a.Terr = b.PINNACLE_Terr and b.Rank_Num = 1

-------

insert into OutputPhysicianData_Final_Reg
select row_number() over(order by (select 1)) as A,Physician_Name as B,Target as C
,cast(null as varchar(5)) as E, cast(null as varchar(5)) as F,cast(null as varchar(5)) as G,cast(null as varchar(5)) as H
,Patients_Not_Using_Copay_Card_Percentage_Of_Total as H,NPI as I,Amgen_Customer_Master_ID as J
,Street as K,City as L,State as M,Zip as N,C52W_Time_to_1st_Transaction as O,C52W_Average_Copay_Payout as P
,CYTD_Transaction as Q,PYTD_Transaction as R,CYTD_vs_PYTD_Transactions_Growth as S,C26W_Transactions as T
,C26W_vs_P26W_Transactions_Growth as U,C13W_Transactions as V,C13W_vs_P13W_Transactions_Growth as W
,CW_transactions as X,PW_transactions as Y,CW_vs_PW_Transactions_Growth as Z,C13W_Expirations as AA
,P13W_Expirations as AB,C13W_vs_P13W_Expirations_Growth as AC,CYTD_vs_PYTD_Expirations_Growth as AD
,Pharmacy_Rank_1 as AE,Pharmacy_Rank_2 as AF,Pharmacy_Rank_3 as AG
,Cat1 as AH,Cat2 as AI,Cat3 as AJ,Cat4 as AK,Cat5 as AL,Cat6 as AM,Cat7 as AN,Cat8 as AO,Cat9 as AP
,left(Terr,2)+'000' as Reg from (
select * from OutputPhysicianData_PDRP_Reg
union all
select * from OutputPhysicianData_Unknown_Reg
) a 

update OutputPhysicianData_Final_Reg
set AH = 1,AI = 0,AJ = 0,AK = 0,AL = 0,AM = 0,AN = 0,AO=0,AP = 0

update A
SET AI = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A, Dense_Rank() Over (Partition by Reg Order by H DESC,B) AS RankCat2
FROM OutputPhysicianData_Final_Reg
WHERE C = 'Derm A' AND H > 0
) B ON A.Reg = B.Reg AND A.A = B.A AND B.RankCat2 <= 10

update A
SET AJ = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A, Dense_Rank() Over (Partition by Reg Order by H DESC,B) AS RankCat3
FROM OutputPhysicianData_Final_Reg
WHERE C = 'Rheum A' AND H > 0
) B ON A.Reg = B.Reg AND A.A = B.A AND B.RankCat3 <= 10

update A
SET AK = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A
FROM OutputPhysicianData_Final_Reg
WHERE (C = 'Rheum A' OR C = 'Rheum B' OR C = 'Rheum B1' OR C = 'Rheum B2') AND V = 0
) B ON A.Reg = B.Reg AND A.A = B.A

update A
SET AL = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A
FROM OutputPhysicianData_Final_Reg
WHERE (C = 'Derm A' OR C = 'Derm B') AND V = 0
) B ON A.Reg = B.Reg AND A.A = B.A

update A
SET AM = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A, Dense_Rank() Over (Partition by Reg Order by U,B) AS RankCat6
FROM OutputPhysicianData_Final_Reg
WHERE (C = 'Rheum A' OR C = 'Rheum B' OR C = 'Rheum B1' OR C = 'Rheum B2') AND U < 0
) B ON A.Reg = B.Reg AND A.A = B.A AND B.RankCat6 <= 15

update A
SET AN = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A, Dense_Rank() Over (Partition by Reg Order by U,B) AS RankCat7
FROM OutputPhysicianData_Final_Reg
WHERE (C = 'Derm A' OR C = 'Derm B') AND U < 0
) B ON A.Reg = B.Reg AND A.A = B.A AND B.RankCat7 <= 15

update A
SET AO = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A, Dense_Rank() Over (Partition by Reg Order by S DESC,B) AS RankCat8
FROM OutputPhysicianData_Final_Reg
WHERE B NOT IN ('PDRP Physician','All Other Physicians') AND S > 0
) B ON A.Reg = B.Reg AND A.A = B.A AND B.RankCat8 <= 15

update A
SET AP = 1
FROM OutputPhysicianData_Final_Reg A
INNER JOIN (
SELECT Reg, A, Dense_Rank() Over (Partition by Reg Order by AC DESC,B) AS RankCat9
FROM OutputPhysicianData_Final_Reg
WHERE B NOT IN ('PDRP Physician','All Other Physicians') AND AC > 0
) B ON A.Reg = B.Reg AND A.A = B.A AND B.RankCat9 <= 10

update OutputPhysicianData_Final_Reg
set D = NULL, E = NULL, F = NULL, G = NULL
WHERE B = 'All Other Physicians'

update OutputPhysicianData_Final_Reg
set E = NULL
where left(E,2) <> left(Reg,2)

update OutputPhysicianData_Final_Reg
set F = NULL
where left(F,2) <> left(Reg,2)

update OutputPhysicianData_Final_Reg
set G = NULL
where left(G,2) <> left(Reg,2)



print'Physician Detail End'
print getdate()
go

if object_id('tempExpiredPatient') is not null
drop table tempExpiredPatient
if object_id('tempNotUsingCard') is not null
drop table tempNotUsingCard
if object_id('tempPhysicianExpiredPatient') is not null
drop table tempPhysicianExpiredPatient
if object_id('tempPhysicianExpiredPatient') is not null
drop table tempPhysicianExpiredPatient
if object_id('tempTimetoFirstTransaction') is not null
drop table tempTimetoFirstTransaction
if object_id('tempTimetoFirstTransaction_PDRP') is not null
drop table tempTimetoFirstTransaction_PDRP
if object_id('tempTimetoFirstTransaction_PDRP_Dist') is not null
drop table tempTimetoFirstTransaction_PDRP_Dist
if object_id('tempTimetoFirstTransaction_PDRP_Reg') is not null
drop table tempTimetoFirstTransaction_PDRP_Reg
if object_id('tempTimetoFirstTransaction_Unknown') is not null
drop table tempTimetoFirstTransaction_Unknown
if object_id('tempTimetoFirstTransaction_Unknown_Dist') is not null
drop table tempTimetoFirstTransaction_Unknown_Dist
if object_id('tempTimetoFirstTransaction_Unknown_Reg') is not null
drop table tempTimetoFirstTransaction_Unknown_Reg
if object_id('tempTimetoFirstTransaction_Unknown_Dist') is not null
drop table tempTimetoFirstTransaction_Unknown_Dist
if object_id('tempTransactions') is not null
drop table tempTransactions
if object_id('tempTransactions_Dist') is not null
drop table tempTransactions_Dist
if object_id('tempTransactions_Reg') is not null
drop table tempTransactions_Reg
if object_id('tempTransactionsWithPeriod') is not null
drop table tempTransactionsWithPeriod
go




















