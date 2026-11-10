/*
Universidad: Universidad Nacional de La Matanza
Materia: Bases de Datos Aplicadas - Grupo 05
Autor: Canseco Carrizo, Yamil Simón
Integrantes: 
Casella, Mateo Ezequiel
Chungara Tenorio, Denis Abner 
Torczuk, Elías Alexei
Canseco Carrizo, Yamil Simón
Objetivo: Realizar un reset total de la base de datos para limpiar el entorno local
*/


USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'MundialFutbol')
BEGIN
	ALTER DATABASE MundialFutbol SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE MundialFutbol;
END
GO