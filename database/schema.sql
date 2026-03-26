-- ============================================================
-- SU Campus Shuttle Management System
-- Database Schema - SQL Server
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'SU_ShuttleManagement')
BEGIN
    CREATE DATABASE SU_ShuttleManagement;
END
GO

USE SU_ShuttleManagement;
GO

-- ============================================================
-- USERS TABLE
-- Stores students, staff, and admins who use the system
-- ============================================================
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DROP TABLE dbo.Users;
GO

CREATE TABLE dbo.Users (
    UserID      INT IDENTITY(1,1) PRIMARY KEY,
    FirstName   VARCHAR(50)  NOT NULL,
    LastName    VARCHAR(50)  NOT NULL,
    Email       VARCHAR(100) NOT NULL UNIQUE,
    PhoneNumber VARCHAR(20)  NOT NULL,
    Role        VARCHAR(20)  NOT NULL CHECK (Role IN ('Student', 'Staff', 'Admin', 'Driver')),
    IsActive    BIT          NOT NULL DEFAULT 1,
    CreatedAt   DATETIME     NOT NULL DEFAULT GETDATE(),
    UpdatedAt   DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- SHUTTLES TABLE
-- Stores shuttle vehicle information
-- ============================================================
IF OBJECT_ID('dbo.Shuttles', 'U') IS NOT NULL DROP TABLE dbo.Shuttles;
GO

CREATE TABLE dbo.Shuttles (
    ShuttleID       INT IDENTITY(1,1) PRIMARY KEY,
    ShuttleName     VARCHAR(50)  NOT NULL,
    LicensePlate    VARCHAR(20)  NOT NULL UNIQUE,
    Capacity        INT          NOT NULL CHECK (Capacity > 0),
    DriverID        INT          NULL,
    Status          VARCHAR(20)  NOT NULL DEFAULT 'Available'
                        CHECK (Status IN ('Available', 'In Service', 'Maintenance', 'Out of Service')),
    LastServiceDate DATE         NULL,
    CreatedAt       DATETIME     NOT NULL DEFAULT GETDATE(),
    UpdatedAt       DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- ROUTES TABLE
-- Defines shuttle routes across campus
-- ============================================================
IF OBJECT_ID('dbo.Routes', 'U') IS NOT NULL DROP TABLE dbo.Routes;
GO

CREATE TABLE dbo.Routes (
    RouteID     INT IDENTITY(1,1) PRIMARY KEY,
    RouteName   VARCHAR(100) NOT NULL,
    Description VARCHAR(255) NULL,
    IsActive    BIT          NOT NULL DEFAULT 1,
    CreatedAt   DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- STOPS TABLE
-- Individual stops along each route
-- ============================================================
IF OBJECT_ID('dbo.Stops', 'U') IS NOT NULL DROP TABLE dbo.Stops;
GO

CREATE TABLE dbo.Stops (
    StopID            INT IDENTITY(1,1) PRIMARY KEY,
    RouteID           INT          NOT NULL,
    StopName          VARCHAR(100) NOT NULL,
    StopOrder         INT          NOT NULL,
    EstimatedMinutes  INT          NOT NULL DEFAULT 0,  -- minutes from route start
    Latitude          DECIMAL(9,6) NULL,
    Longitude         DECIMAL(9,6) NULL,
    CONSTRAINT FK_Stops_Routes FOREIGN KEY (RouteID) REFERENCES dbo.Routes(RouteID),
    CONSTRAINT UQ_Stop_RouteOrder UNIQUE (RouteID, StopOrder)
);
GO

-- ============================================================
-- SCHEDULE TABLE
-- Defines when shuttles run on which routes
-- ============================================================
IF OBJECT_ID('dbo.Schedule', 'U') IS NOT NULL DROP TABLE dbo.Schedule;
GO

CREATE TABLE dbo.Schedule (
    ScheduleID  INT IDENTITY(1,1) PRIMARY KEY,
    ShuttleID   INT          NOT NULL,
    RouteID     INT          NOT NULL,
    DepartureTime TIME       NOT NULL,
    DaysOfWeek  VARCHAR(50)  NOT NULL,  -- e.g. 'Mon,Tue,Wed,Thu,Fri'
    IsActive    BIT          NOT NULL DEFAULT 1,
    CONSTRAINT FK_Schedule_Shuttles FOREIGN KEY (ShuttleID) REFERENCES dbo.Shuttles(ShuttleID),
    CONSTRAINT FK_Schedule_Routes   FOREIGN KEY (RouteID)   REFERENCES dbo.Routes(RouteID)
);
GO

-- ============================================================
-- BOOKINGS TABLE
-- Records shuttle ride bookings
-- ============================================================
IF OBJECT_ID('dbo.Bookings', 'U') IS NOT NULL DROP TABLE dbo.Bookings;
GO

CREATE TABLE dbo.Bookings (
    BookingID       INT IDENTITY(1,1) PRIMARY KEY,
    UserID          INT          NOT NULL,
    ScheduleID      INT          NOT NULL,
    PickupStopID    INT          NOT NULL,
    DropoffStopID   INT          NOT NULL,
    BookingTime     DATETIME     NOT NULL DEFAULT GETDATE(),
    RideDate        DATE         NOT NULL,
    Status          VARCHAR(20)  NOT NULL DEFAULT 'Pending'
                        CHECK (Status IN ('Pending', 'Confirmed', 'Completed', 'Cancelled', 'No-Show')),
    EstimatedPickup DATETIME     NULL,
    ActualPickup    DATETIME     NULL,
    Notes           VARCHAR(255) NULL,
    CreatedAt       DATETIME     NOT NULL DEFAULT GETDATE(),
    UpdatedAt       DATETIME     NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Bookings_Users     FOREIGN KEY (UserID)        REFERENCES dbo.Users(UserID),
    CONSTRAINT FK_Bookings_Schedule  FOREIGN KEY (ScheduleID)    REFERENCES dbo.Schedule(ScheduleID),
    CONSTRAINT FK_Bookings_Pickup    FOREIGN KEY (PickupStopID)  REFERENCES dbo.Stops(StopID),
    CONSTRAINT FK_Bookings_Dropoff   FOREIGN KEY (DropoffStopID) REFERENCES dbo.Stops(StopID)
);
GO

-- ============================================================
-- BOOKING AUDIT TABLE
-- Tracks all changes to bookings for reporting
-- ============================================================
IF OBJECT_ID('dbo.BookingAudit', 'U') IS NOT NULL DROP TABLE dbo.BookingAudit;
GO

CREATE TABLE dbo.BookingAudit (
    AuditID         INT IDENTITY(1,1) PRIMARY KEY,
    BookingID       INT          NOT NULL,
    OldStatus       VARCHAR(20)  NULL,
    NewStatus       VARCHAR(20)  NULL,
    ChangedBy       INT          NULL,
    ChangeReason    VARCHAR(255) NULL,
    ChangedAt       DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- SHUTTLE LOCATION TABLE
-- Real-time shuttle position tracking
-- ============================================================
IF OBJECT_ID('dbo.ShuttleLocation', 'U') IS NOT NULL DROP TABLE dbo.ShuttleLocation;
GO

CREATE TABLE dbo.ShuttleLocation (
    LocationID  INT IDENTITY(1,1) PRIMARY KEY,
    ShuttleID   INT          NOT NULL,
    Latitude    DECIMAL(9,6) NOT NULL,
    Longitude   DECIMAL(9,6) NOT NULL,
    Speed       DECIMAL(5,2) NULL,
    RecordedAt  DATETIME     NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Location_Shuttles FOREIGN KEY (ShuttleID) REFERENCES dbo.Shuttles(ShuttleID)
);
GO

-- ============================================================
-- Add FK for Shuttle Driver after Users table exists
-- ============================================================
ALTER TABLE dbo.Shuttles
    ADD CONSTRAINT FK_Shuttles_Driver FOREIGN KEY (DriverID) REFERENCES dbo.Users(UserID);
GO

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX IX_Bookings_UserID      ON dbo.Bookings(UserID);
CREATE INDEX IX_Bookings_RideDate    ON dbo.Bookings(RideDate);
CREATE INDEX IX_Bookings_Status      ON dbo.Bookings(Status);
CREATE INDEX IX_Bookings_ScheduleID  ON dbo.Bookings(ScheduleID);
CREATE INDEX IX_ShuttleLocation_ShuttleID ON dbo.ShuttleLocation(ShuttleID);
CREATE INDEX IX_BookingAudit_BookingID    ON dbo.BookingAudit(BookingID);
GO

PRINT 'Schema created successfully.';
GO
