﻿/*
Deployment script for DVLog

This code was generated by a tool.
Changes to this file may cause incorrect behavior and will be lost if
the code is regenerated.
*/

GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DatabaseName "DVLog"
:setvar DefaultFilePrefix "DVLog"
:setvar DefaultDataPath ""
:setvar DefaultLogPath ""

GO
:on error exit
GO
/*
Detect SQLCMD mode and disable script execution if SQLCMD mode is not supported.
To re-enable the script after enabling SQLCMD mode, execute the following:
SET NOEXEC OFF; 
*/
:setvar __IsSqlCmdEnabled "True"
GO
IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
        PRINT N'SQLCMD mode must be enabled to successfully execute this script.';
        SET NOEXEC ON;
    END


GO
USE [master];


GO
PRINT N'Creating $(DatabaseName)...'
GO
CREATE DATABASE [$(DatabaseName)] COLLATE SQL_Latin1_General_CP1_CI_AS
GO
DECLARE  @job_state INT = 0;
DECLARE  @index INT = 0;
DECLARE @EscapedDBNameLiteral sysname = N'$(DatabaseName)'
WAITFOR DELAY '00:00:30';
WHILE (@index < 60) 
BEGIN
	SET @job_state = ISNULL( (SELECT SUM (result)  FROM (
		SELECT TOP 1 [state] AS result
		FROM sys.dm_operation_status WHERE resource_type = 0 
		AND operation = 'CREATE DATABASE' AND major_resource_id = @EscapedDBNameLiteral AND [state] = 2
		ORDER BY start_time DESC
		) r), -1);

	SET @index = @index + 1;

	IF @job_state = 0 /* pending */ OR @job_state = 1 /* in progress */ OR @job_state = -1 /* job not found */ OR (SELECT [state] FROM sys.databases WHERE name = @EscapedDBNameLiteral) <> 0
		WAITFOR DELAY '00:00:30';
	ELSE 
    	BREAK;
END
GO
USE [$(DatabaseName)];


GO
USE [$(DatabaseName)];


GO
IF EXISTS (SELECT 1
           FROM   [sys].[databases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET ANSI_NULLS ON,
                ANSI_PADDING ON,
                ANSI_WARNINGS ON,
                ARITHABORT ON,
                CONCAT_NULL_YIELDS_NULL ON,
                NUMERIC_ROUNDABORT OFF,
                QUOTED_IDENTIFIER ON,
                ANSI_NULL_DEFAULT ON,
                CURSOR_CLOSE_ON_COMMIT OFF,
                AUTO_CREATE_STATISTICS ON,
                AUTO_SHRINK OFF,
                AUTO_UPDATE_STATISTICS ON,
                RECURSIVE_TRIGGERS OFF 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [sys].[databases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET ALLOW_SNAPSHOT_ISOLATION OFF;
    END


GO
IF EXISTS (SELECT 1
           FROM   [sys].[databases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET AUTO_UPDATE_STATISTICS_ASYNC OFF,
                DATE_CORRELATION_OPTIMIZATION OFF 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [sys].[databases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET AUTO_CREATE_STATISTICS ON(INCREMENTAL = OFF) 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [sys].[databases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET QUERY_STORE (QUERY_CAPTURE_MODE = AUTO, OPERATION_MODE = READ_WRITE, DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_PLANS_PER_QUERY = 200, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), MAX_STORAGE_SIZE_MB = 100) 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [sys].[databases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 0;
        ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = PRIMARY;
        ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = OFF;
        ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET LEGACY_CARDINALITY_ESTIMATION = PRIMARY;
        ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = ON;
        ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET PARAMETER_SNIFFING = PRIMARY;
        ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = OFF;
        ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET QUERY_OPTIMIZER_HOTFIXES = PRIMARY;
    END


GO
IF EXISTS (SELECT 1
           FROM   [sys].[databases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET TEMPORAL_HISTORY_RETENTION ON 
            WITH ROLLBACK IMMEDIATE;
    END


GO
PRINT N'Creating [LogWriter]...';


GO
CREATE ROLE [LogWriter]
    AUTHORIZATION [dbo];


GO
PRINT N'Creating [log]...';


GO
CREATE SCHEMA [log]
    AUTHORIZATION [dbo];


GO
PRINT N'Creating [dbo].[sysssislog]...';


GO
CREATE TABLE [dbo].[sysssislog] (
    [id]          INT              IDENTITY (1, 1) NOT NULL,
    [event]       [sysname]        NOT NULL,
    [computer]    NVARCHAR (128)   NOT NULL,
    [operator]    NVARCHAR (128)   NOT NULL,
    [source]      NVARCHAR (1024)  NOT NULL,
    [sourceid]    UNIQUEIDENTIFIER NOT NULL,
    [executionid] UNIQUEIDENTIFIER NOT NULL,
    [starttime]   DATETIME         NOT NULL,
    [endtime]     DATETIME         NOT NULL,
    [datacode]    INT              NOT NULL,
    [databytes]   IMAGE            NULL,
    [message]     NVARCHAR (2048)  NOT NULL,
    CONSTRAINT [PK_sysssislog] PRIMARY KEY CLUSTERED ([id] ASC)
);


GO
PRINT N'Creating [log].[FlowExecutionError]...';


GO
CREATE TABLE [log].[FlowExecutionError] (
    [Id]               BIGINT           IDENTITY (1, 1) NOT NULL,
    [ExecutionId]      UNIQUEIDENTIFIER NOT NULL,
    [ErrorCode]        INT              NOT NULL,
    [ErrorDescription] VARCHAR (MAX)    NOT NULL,
    CONSTRAINT [PK_FlowExecutionError] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Creating [log].[FlowEvent]...';


GO
CREATE TABLE [log].[FlowEvent] (
    [FlowEventId]   INT          NOT NULL,
    [FlowEventName] VARCHAR (50) NOT NULL,
    CONSTRAINT [PK_FlowEvent] PRIMARY KEY CLUSTERED ([FlowEventId] ASC)
);


GO
PRINT N'Creating [log].[FlowExecution]...';


GO
CREATE TABLE [log].[FlowExecution] (
    [Id]                BIGINT           IDENTITY (1, 1) NOT NULL,
    [LoadDate]          DATETIME2 (7)    NOT NULL,
    [FlowName]          VARCHAR (100)    NOT NULL,
    [ExecutionId]       UNIQUEIDENTIFIER NOT NULL,
    [ServerExecutionId] INT              NOT NULL,
    [PackageName]       VARCHAR (100)    NOT NULL,
    [PackageId]         UNIQUEIDENTIFIER NOT NULL,
    [VersionBuild]      INT              NOT NULL,
    [FlowEventId]       INT              NOT NULL,
    [FlowEventDate]     DATETIME2 (7)    NOT NULL,
    CONSTRAINT [PK_FlowExecution] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Creating [log].[vFlowExecutionError]...';


GO
CREATE VIEW [log].[vFlowExecutionError]

AS

SELECT [Id]
  ,[ExecutionId]
  ,[ErrorCode]
  ,[ErrorDescription]
FROM [log].[FlowExecutionError]
WHERE [ErrorCode] != 0
GO
PRINT N'Creating [log].[vFlowExecution]...';


GO
CREATE VIEW [log].[vFlowExecution]

AS 

SELECT ExecStart.[Id]
  ,ExecStart.[LoadDate]
  ,ExecStart.[FlowName]
  ,ExecStart.[ExecutionId]
  ,ExecStart.[ServerExecutionId]
  ,ExecStart.[PackageName]
  ,ExecStart.[PackageId]
  ,ExecStart.[VersionBuild]
  ,[FlowEventId] = ISNULL(ExecEnd.[FlowEventId], ExecStart.[FlowEventId])
  ,[FlowEventStartDate] = ExecStart.[FlowEventDate]
  ,[FlowEventEndDate] = ExecEnd.[FlowEventDate]
FROM [log].[FlowExecution] ExecStart 
  LEFT JOIN [log].[FlowExecution] ExecEnd ON ExecStart.ExecutionId = ExecEnd.ExecutionId
    AND ISNULL(ExecEnd.FlowEventId, 1) != 0
WHERE ExecStart.FlowEventId = 0
GO
PRINT N'Creating [log].[InsertFlowExecutionLog]...';


GO
CREATE PROCEDURE [log].[InsertFlowExecutionLog]
	@LoadDate datetime2
	,@FlowName varchar(100)
	,@ExecutionId uniqueidentifier
    ,@PackageName varchar(100)
    ,@PackageId uniqueidentifier
    ,@VersionBuild int
    ,@FlowEventId int
	,@ServerExecutionId int
AS
BEGIN
  SET NOCOUNT ON;

  INSERT INTO log.FlowExecution
  (
    LoadDate
    ,FlowName
    ,ExecutionId
	,ServerExecutionId
    ,PackageName
    ,PackageId
    ,VersionBuild
    ,FlowEventId
    ,FlowEventDate
  )
  VALUES
  (
    @LoadDate
	,@FlowName
	,@ExecutionId
	,@ServerExecutionId
    ,@PackageName
    ,@PackageId
    ,@VersionBuild
    ,@FlowEventId
    ,SYSDATETIME()
  );
END
GO
PRINT N'Creating [log].[InsertFlowExecutionErrorLog]...';


GO
CREATE PROCEDURE [log].[InsertFlowExecutionErrorLog]
	@ExecutionId uniqueidentifier
	,@ErrorCode int
    ,@ErrorDescription varchar(MAX)
AS
BEGIN
  SET NOCOUNT ON;

  INSERT INTO log.FlowExecutionError
  (
    ExecutionId
    ,ErrorCode
    ,ErrorDescription
  )
  VALUES
  (
    @ExecutionId
    ,@ErrorCode
    ,@ErrorDescription
  );
END
GO
PRINT N'Creating Permission...';


GO
GRANT EXECUTE
    ON OBJECT::[log].[InsertFlowExecutionLog] TO [LogWriter]
    AS [dbo];


GO
PRINT N'Creating Permission...';


GO
GRANT EXECUTE
    ON OBJECT::[log].[InsertFlowExecutionErrorLog] TO [LogWriter]
    AS [dbo];


GO
/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
IF NOT EXISTS (SELECT * FROM log.FlowEvent)
  INSERT INTO log.FlowEvent (FlowEventId, FlowEventName) VALUES
    (-1, 'Error')
    ,(0, 'Start')
    ,(1, 'End');

GO

GO
DECLARE @VarDecimalSupported AS BIT;

SELECT @VarDecimalSupported = 0;

IF ((ServerProperty(N'EngineEdition') = 3)
    AND (((@@microsoftversion / power(2, 24) = 9)
          AND (@@microsoftversion & 0xffff >= 3024))
         OR ((@@microsoftversion / power(2, 24) = 10)
             AND (@@microsoftversion & 0xffff >= 1600))))
    SELECT @VarDecimalSupported = 1;

IF (@VarDecimalSupported > 0)
    BEGIN
        EXECUTE sp_db_vardecimal_storage_format N'$(DatabaseName)', 'ON';
    END


GO
PRINT N'Update complete.';


GO
