-- ============================================================
-- SU Campus Shuttle Management System
-- Triggers
-- ============================================================

USE SU_ShuttleManagement;
GO

-- ============================================================
-- TRIGGER: Audit booking status changes
-- Fires on UPDATE to dbo.Bookings and logs status transitions
-- ============================================================
IF OBJECT_ID('dbo.trg_Bookings_AuditStatusChange', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Bookings_AuditStatusChange;
GO

CREATE TRIGGER dbo.trg_Bookings_AuditStatusChange
ON dbo.Bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.BookingAudit (BookingID, OldStatus, NewStatus, ChangedAt)
    SELECT
        i.BookingID,
        d.Status AS OldStatus,
        i.Status AS NewStatus,
        GETDATE()
    FROM inserted i
    JOIN deleted  d ON i.BookingID = d.BookingID
    WHERE i.Status <> d.Status;
END
GO

-- ============================================================
-- TRIGGER: Enforce pickup stop comes before dropoff stop
-- on the same route
-- ============================================================
IF OBJECT_ID('dbo.trg_Bookings_ValidateStopOrder', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Bookings_ValidateStopOrder;
GO

CREATE TRIGGER dbo.trg_Bookings_ValidateStopOrder
ON dbo.Bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Stops pickup  ON pickup.StopID  = i.PickupStopID
        JOIN dbo.Stops dropoff ON dropoff.StopID = i.DropoffStopID
        WHERE pickup.RouteID  <> dropoff.RouteID
           OR pickup.StopOrder >= dropoff.StopOrder
    )
    BEGIN
        RAISERROR('Pickup stop must come before dropoff stop on the same route.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- ============================================================
-- TRIGGER: Auto-set shuttle status to 'In Service'
-- when a schedule starts (booking confirmed for today)
-- ============================================================
IF OBJECT_ID('dbo.trg_Bookings_UpdateShuttleStatus', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Bookings_UpdateShuttleStatus;
GO

CREATE TRIGGER dbo.trg_Bookings_UpdateShuttleStatus
ON dbo.Bookings
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Mark shuttle as 'In Service' when booking is made for today
    UPDATE dbo.Shuttles
    SET Status    = 'In Service',
        UpdatedAt = GETDATE()
    FROM dbo.Shuttles sh
    JOIN dbo.Schedule sc ON sh.ShuttleID = sc.ShuttleID
    JOIN inserted      i  ON sc.ScheduleID = i.ScheduleID
    WHERE i.RideDate = CAST(GETDATE() AS DATE)
      AND sh.Status  = 'Available';
END
GO

-- ============================================================
-- TRIGGER: Keep UpdatedAt timestamp current on Users
-- ============================================================
IF OBJECT_ID('dbo.trg_Users_UpdateTimestamp', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Users_UpdateTimestamp;
GO

CREATE TRIGGER dbo.trg_Users_UpdateTimestamp
ON dbo.Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Users
    SET UpdatedAt = GETDATE()
    FROM dbo.Users u
    JOIN inserted  i ON u.UserID = i.UserID;
END
GO

-- ============================================================
-- TRIGGER: Keep UpdatedAt timestamp current on Shuttles
-- ============================================================
IF OBJECT_ID('dbo.trg_Shuttles_UpdateTimestamp', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Shuttles_UpdateTimestamp;
GO

CREATE TRIGGER dbo.trg_Shuttles_UpdateTimestamp
ON dbo.Shuttles
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Shuttles
    SET UpdatedAt = GETDATE()
    FROM dbo.Shuttles sh
    JOIN inserted     i  ON sh.ShuttleID = i.ShuttleID;
END
GO

-- ============================================================
-- TRIGGER: Prevent booking cancellation within 15 minutes
-- of the estimated pickup
-- ============================================================
IF OBJECT_ID('dbo.trg_Bookings_PreventLateCancellation', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Bookings_PreventLateCancellation;
GO

CREATE TRIGGER dbo.trg_Bookings_PreventLateCancellation
ON dbo.Bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted  d ON i.BookingID = d.BookingID
        WHERE i.Status = 'Cancelled'
          AND d.Status = 'Confirmed'
          AND i.EstimatedPickup IS NOT NULL
          AND DATEDIFF(MINUTE, GETDATE(), i.EstimatedPickup) < 15
    )
    BEGIN
        RAISERROR('Bookings cannot be cancelled within 15 minutes of the estimated pickup time.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

PRINT 'Triggers created successfully.';
GO
