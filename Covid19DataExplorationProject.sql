SELECT * 
FROM PortfolioProject.dbo.['covid-deaths$']
ORDER BY 3, 4

SELECT * 
FROM PortfolioProject.dbo.['covid-vaccinations$']
ORDER BY 3, 4

SELECT location, date, total_cases, new_cases, total_deaths, population
From ['covid-deaths$']
ORDER BY 1, 2

-- Looking at total cases vs. total death. (basically, mortality rate in Egypt)
SELECT location, date, total_cases, total_deaths, (CONVERT(float, total_deaths) / CONVERT(float, total_cases) ) * 100 as DeathPercentageToCases
From ['covid-deaths$']
WHERE location = 'EGYPT'
ORDER BY 1, 2

--Looking at total cases vs. population.
SELECT location, date, total_cases, population, (CONVERT(float, total_cases) / CONVERT(float, population) ) * 100 as casesPercentageToPopulation
FROM ['covid-deaths$']
WHERE location = 'EGYPT'
ORDER BY 2

--Looking at countries with highest infection rate relative to population
SELECT location, population, MAX(total_cases) AS HighestInfectionCount, MAX((CONVERT(float, total_cases) / CONVERT(float, population))) * 100 as PercentageOfPopulationInfected
FROM ['covid-deaths$']
WHERE continent is  not null
GROUP BY location, population
ORDER BY PercentageOfPopulationInfected DESC


--Looking at deaths count from highest to lowest countries
SELECT location, MAX(CAST(total_deaths as float)) AS TotalDeathCount
FROM ['covid-deaths$']
WHERE continent is  not null
GROUP BY location
ORDER BY TotalDeathCount DESC


--Looking at deaths count by population percentage order from highest to lowest
SELECT location, population, (MAX(CONVERT(float, total_deaths)) / CONVERT(float, population) ) * 100 AS DeathsPercentageToPopulation
FROM ['covid-deaths$']
WHERE continent is  not null
GROUP BY location, population
ORDER BY DeathsPercentageToPopulation DESC

--Breaking it down by location where continent is null.
SELECT location, MAX(CAST(total_deaths as float)) AS TotalDeathCount
FROM ['covid-deaths$']
WHERE continent is null
GROUP BY location
ORDER BY TotalDeathCount DESC


--Breaking it down by continent.
SELECT continent, MAX(CAST(total_deaths as float)) AS TotalDeathCount
FROM ['covid-deaths$']
WHERE continent is not null
GROUP BY continent
ORDER BY TotalDeathCount DESC

---------------------------------------------------------------------------------
--Global Numbers. total worldwide cases, total worldwide deaths, and worldwide deaths/cases percentage.
SELECT SUM(new_cases) as totalCases, 
       SUM(new_deaths) as totalDeaths,
	   SUM(new_deaths) / SUM(new_cases) AS DeathPercentageWorldWideToCases
FROM ['covid-deaths$']
WHERE continent IS NOT NULL
--------------------------------------------------------------------------------
-- Looking at total population vs vaccinated population.
SELECT dea.continent, SUM(cast(vac.new_vaccinations as bigint))
FROM ['covid-deaths$'] dea
JOIN ['covid-vaccinations$'] vac
ON dea.location = vac.location
and dea.date = vac.date
WHERE dea.continent is not null
GROUP BY dea.continent

-----------------------------------------------------Derived vs. Original columns--------------------------------------------------
-- The next query won't work because we are trying to use a derived column (reference it) in the same select statement which is not allowed.
-- we can use other way like CTE or Temp Tables.
--SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
--	   SUM(cast(vac.new_vaccinations as bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) totalVacsPerLocation,
--	   (totalVacsPerLocation / dea.population) * 100 AS percentage_vaccinated
--FROM ['covid-deaths$'] dea
--JOIN ['covid-vaccinations$'] vac
--ON dea.location = vac.location
--and dea.date = vac.date
--WHERE dea.continent IS NOT NULL AND vac.new_vaccinations IS NOT NULL
--ORDER BY 2, 3

-- USING CTE
WITH POPVSVAC (Continent, location, date, population, New_Vaccinations, totalVacsPerLocation)
AS
(
    SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
           SUM(cast(vac.new_vaccinations as bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) totalVacsPerLocation
    FROM ['covid-deaths$'] dea
    JOIN ['covid-vaccinations$'] vac
    ON dea.location = vac.location
    AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL AND vac.new_vaccinations IS NOT NULL
)
SELECT *, totalVacsPerLocation/population * 100 
FROM POPVSVAC


--USING temp table
DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
totalVacsPerLocation numeric
)
Insert Into #PercentPopulationVaccinated
    SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
           SUM(cast(vac.new_vaccinations as bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) totalVacsPerLocation
    FROM ['covid-deaths$'] dea
    JOIN ['covid-vaccinations$'] vac
    ON dea.location = vac.location
    AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL AND vac.new_vaccinations IS NOT NULL

-- Querying from the temp table as we do normally to any table  so we can now use what was a dervied column before which is now an original column
-- in the newly created temp table.
SELECT *, (totalVacsPerLocation / Population) * 100 AS percentageVaccinated 
FROM #PercentPopulationVaccinated
ORDER BY location, Date

-- In conclusion, we needed to convert this derived column to a raw-ish column by using CTE or temp table so we can reference it when we want.
-------------------------------------------------------------------------------------------------------------------------------------------------


-- Creating views to store data for future visualizations.
----------------------------------------------------------
Create View VaccinatedVsPopulationPercentage AS
    SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
           SUM(cast(vac.new_vaccinations as bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) totalVacsPerLocation
    FROM ['covid-deaths$'] dea
    JOIN ['covid-vaccinations$'] vac
    ON dea.location = vac.location
    AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL AND vac.new_vaccinations IS NOT NULL


Select * 
from VaccinatedVsPopulationPercentage

----------------------------------------------------------------------------------------------------------------------
--Further Exploration--
SELECT *
FROM ['covid-deaths$'] dea
JOIN ['covid-vaccinations$'] vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE icu_patients IS NOT NULL AND hosp_patients IS NOT NULL
GROUP BY dea.location
-----------------------------
--Getting the percentage of hospitalized patients that got to ICU from all hospitalized patients. (Not all countries have data of this)
SELECT dea.location, MAX(CAST(icu_patients as int)) AS TotalICUPatientsPerCountry, MAX(CAST(hosp_patients as int)) TotalHospPatientsPerCountry,
	   (MAX(CAST(icu_patients as float)) / MAX(CAST(hosp_patients as float))) * 100 AS ICUPatientsPercentageToHospitalizedPatients
FROM ['covid-deaths$'] dea
JOIN ['covid-vaccinations$'] vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE icu_patients IS NOT NULL AND hosp_patients IS NOT NULL
GROUP BY dea.location

-- Creating a view of ICU_Patients / Hospitalized_Patients percentage.
Create View ICUPatientsPercentageToAllHospitalized AS
	SELECT dea.location, MAX(CAST(icu_patients as int)) AS TotalICUPatientsPerCountry, MAX(CAST(hosp_patients as int)) TotalHospPatientsPerCountry,
	   (MAX(CAST(icu_patients as float)) / MAX(CAST(hosp_patients as float))) * 100 AS ICUPatientsPercentageToHospitalizedPatients
FROM ['covid-deaths$'] dea
JOIN ['covid-vaccinations$'] vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE icu_patients IS NOT NULL AND hosp_patients IS NOT NULL
GROUP BY dea.location

-- From the highest ICU percentage to lowest country (Highest: Netherlands, Lowest:Serbia)
SELECT * 
FROM ICUPatientsPercentageToAllHospitalized
ORDER BY ICUPatientsPercentageToHospitalizedPatients DESC