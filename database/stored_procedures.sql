-- ============================================================
-- SU Campus Shuttle Management System
-- Stored Procedures
-- ============================================================

USE SU_ShuttleManagement;
GO

-- ============================================================
-- SP: Create a new booking
-- ============================================================
IF OBJECT_ID('dbo.sp_CreateBooking', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_CreateBooking;
GO

CREATE PROCEDURE dbo.sp_CreateBooking
    @UserID         INT,
    @ScheduleID     INT,
    @PickupStopID   INT,
    @DropoffStopID  INT,
    @RideDate       DATE,
    @Notes          VARCHAR(255) = NULL,
    @BookingID      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate user exists and is active
        IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @UserID AND IsActive = 1)
        BEGIN
            RAISERROR('User not found or inactive.', 16, 1);
            RETURN;
        END

        -- Validate schedule exists and is active
        IF NOT EXISTS (SELECT 1 FROM dbo.Schedule WHERE ScheduleID = @ScheduleID AND IsActive = 1)
        BEGIN
            RAISERROR('Schedule not found or inactive.', 16, 1);
            RETURN;
        END

        -- Check shuttle capacity
        DECLARE @ShuttleID INT, @Capacity INT, @CurrentBookings INT;

        SELECT @ShuttleID = s.ShuttleID, @Capacity = sh.Capacity
        FROM dbo.Schedule s
        JOIN dbo.Shuttles sh ON s.ShuttleID = sh.ShuttleID
        WHERE s.ScheduleID = @ScheduleID;

        SELECT @CurrentBookings = COUNT(*)
        FROM dbo.Bookings
        WHERE ScheduleID = @ScheduleID
          AND RideDate = @RideDate
          AND Status IN ('Pending', 'Confirmed');

        IF @CurrentBookings >= @Capacity
        BEGIN
            RAISERROR('Shuttle is fully booked for this schedule.', 16, 1);
            RETURN;
        END

        -- Prevent duplicate booking
        IF EXISTS (
            SELECT 1 FROM dbo.Bookings
            WHERE UserID = @UserID
              AND ScheduleID = @ScheduleID
              AND RideDate = @RideDate
              AND Status IN ('Pending', 'Confirmed')
        )
        BEGIN
            RAISERROR('User already has an active booking for this schedule.', 16, 1);
            RETURN;
        END

        -- Calculate estimated pickup time
        DECLARE @DepartureTime TIME, @PickupOffset INT;

        SELECT @DepartureTime = sc.DepartureTime,
               @PickupOffset  = st.EstimatedMinutes
        FROM dbo.Schedule sc
        JOIN dbo.Stops st ON st.StopID = @PickupStopID
        WHERE sc.ScheduleID = @ScheduleID;

        DECLARE @EstimatedPickup DATETIME;
        SET @EstimatedPickup = CAST(CAST(@RideDate AS DATETIME) AS DATETIME)
                              + CAST(@DepartureTime AS DATETIME)
                              + CAST((@PickupOffset * 60) AS INT) / 86400.0;

        -- Insert booking
        INSERT INTO dbo.Bookings
            (UserID, ScheduleID, PickupStopID, DropoffStopID, RideDate, Status, EstimatedPickup, Notes)
        VALUES
            (@UserID, @ScheduleID, @PickupStopID, @DropoffStopID, @RideDate, 'Confirmed', @EstimatedPickup, @Notes);

        SET @BookingID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
        PRINT 'Booking created successfully. BookingID: ' + CAST(@BookingID AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO

-- ============================================================
-- SP: Cancel a booking
-- ============================================================
IF OBJECT_ID('dbo.sp_CancelBooking', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_CancelBooking;
GO

CREATE PROCEDURE dbo.sp_CancelBooking
    @BookingID   INT,
    @CancelledBy INT,
    @Reason      VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus VARCHAR(20);
        SELECT @CurrentStatus = Status FROM dbo.Bookings WHERE BookingID = @BookingID;

        IF @CurrentStatus IS NULL
        BEGIN
            RAISERROR('Booking not found.', 16, 1);
            RETURN;
        END

        IF @CurrentStatus IN ('Completed', 'Cancelled')
        BEGIN
            RAISERROR('Cannot cancel a booking that is already completed or cancelled.', 16, 1);
            RETURN;
        END

        UPDATE dbo.Bookings
        SET Status    = 'Cancelled',
            UpdatedAt = GETDATE()
        WHERE BookingID = @BookingID;

        -- Audit log is handled by trigger

        COMMIT TRANSACTION;
        PRINT 'Booking ' + CAST(@BookingID AS VARCHAR) + ' cancelled successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO

-- ============================================================
-- SP: Get all bookings for a user
-- ============================================================
IF OBJECT_ID('dbo.sp_GetUserBookings', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_GetUserBookings;
GO

CREATE PROCEDURE dbo.sp_GetUserBookings
    @UserID     INT,
    @Status     VARCHAR(20) = NULL,
    @FromDate   DATE        = NULL,
    @ToDate     DATE        = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.BookingID,
        b.RideDate,
        b.Status,
        b.EstimatedPickup,
        b.ActualPickup,
        b.Notes,
        b.BookingTime,
        r.RouteName,
        pickup.StopName  AS PickupStop,
        dropoff.StopName AS DropoffStop,
        sh.ShuttleName,
        CONCAT(u.FirstName, ' ', u.LastName) AS DriverName
    FROM dbo.Bookings b
    JOIN dbo.Schedule   sc      ON b.ScheduleID     = sc.ScheduleID
    JOIN dbo.Routes     r       ON sc.RouteID        = r.RouteID
    JOIN dbo.Shuttles   sh      ON sc.ShuttleID      = sh.ShuttleID
    JOIN dbo.Stops      pickup  ON b.PickupStopID    = pickup.StopID
    JOIN dbo.Stops      dropoff ON b.DropoffStopID   = dropoff.StopID
    LEFT JOIN dbo.Users u       ON sh.DriverID        = u.UserID
    WHERE b.UserID = @UserID
      AND (@Status   IS NULL OR b.Status   = @Status)
      AND (@FromDate IS NULL OR b.RideDate >= @FromDate)
      AND (@ToDate   IS NULL OR b.RideDate <= @ToDate)
    ORDER BY b.RideDate DESC, b.EstimatedPickup ASC;
END
GO

-- ============================================================
-- SP: Get available shuttles for a route/date
-- ============================================================
IF OBJECT_ID('dbo.sp_GetAvailableShuttles', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_GetAvailableShuttles;
GO

CREATE PROCEDURE dbo.sp_GetAvailableShuttles
    @RouteID    INT,
    @RideDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sc.ScheduleID,
        sh.ShuttleID,
        sh.ShuttleName,
        sh.Capacity,
        sc.DepartureTime,
        sc.DaysOfWeek,
        (sh.Capacity - ISNULL(booked.BookedCount, 0)) AS SeatsAvailable
    FROM dbo.Schedule sc
    JOIN dbo.Shuttles sh ON sc.ShuttleID = sh.ShuttleID
    OUTER APPLY (
        SELECT COUNT(*) AS BookedCount
        FROM dbo.Bookings b
        WHERE b.ScheduleID = sc.ScheduleID
          AND b.RideDate   = @RideDate
          AND b.Status     IN ('Pending', 'Confirmed')
    ) booked
    WHERE sc.RouteID  = @RouteID
      AND sc.IsActive = 1
      AND sh.Status   IN ('Available', 'In Service')
      AND (sh.Capacity - ISNULL(booked.BookedCount, 0)) > 0
    ORDER BY sc.DepartureTime;
END
GO

-- ============================================================
-- SP: Update booking status (complete / no-show)
-- ============================================================
IF OBJECT_ID('dbo.sp_UpdateBookingStatus', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_UpdateBookingStatus;
GO

CREATE PROCEDURE dbo.sp_UpdateBookingStatus
    @BookingID      INT,
    @NewStatus      VARCHAR(20),
    @ChangedBy      INT,
    @ActualPickup   DATETIME    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Bookings WHERE BookingID = @BookingID)
        BEGIN
            RAISERROR('Booking not found.', 16, 1);
            RETURN;
        END

        UPDATE dbo.Bookings
        SET Status      = @NewStatus,
            ActualPickup = COALESCE(@ActualPickup, ActualPickup),
            UpdatedAt   = GETDATE()
        WHERE BookingID = @BookingID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO

-- ============================================================
-- SP: Generate booking report by date range
-- ============================================================
IF OBJECT_ID('dbo.sp_BookingReport', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_BookingReport;
GO

CREATE PROCEDURE dbo.sp_BookingReport
    @FromDate   DATE,
    @ToDate     DATE,
    @RouteID    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.RideDate,
        r.RouteName,
        sh.ShuttleName,
        COUNT(*)                                                          AS TotalBookings,
        SUM(CASE WHEN b.Status = 'Completed'  THEN 1 ELSE 0 END)         AS Completed,
        SUM(CASE WHEN b.Status = 'Cancelled'  THEN 1 ELSE 0 END)         AS Cancelled,
        SUM(CASE WHEN b.Status = 'No-Show'    THEN 1 ELSE 0 END)         AS NoShows,
        AVG(CASE
            WHEN b.ActualPickup IS NOT NULL AND b.EstimatedPickup IS NOT NULL
            THEN DATEDIFF(MINUTE, b.EstimatedPickup, b.ActualPickup)
        END)                                                              AS AvgDelayMinutes
    FROM dbo.Bookings b
    JOIN dbo.Schedule sc ON b.ScheduleID = sc.ScheduleID
    JOIN dbo.Routes   r  ON sc.RouteID   = r.RouteID
    JOIN dbo.Shuttles sh ON sc.ShuttleID = sh.ShuttleID
    WHERE b.RideDate BETWEEN @FromDate AND @ToDate
      AND (@RouteID IS NULL OR sc.RouteID = @RouteID)
    GROUP BY b.RideDate, r.RouteName, sh.ShuttleName
    ORDER BY b.RideDate, r.RouteName;
END
GO

-- ============================================================
-- SP: Get real-time shuttle ETA for a stop
-- ============================================================
IF OBJECT_ID('dbo.sp_GetShuttleETA', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_GetShuttleETA;
GO

CREATE PROCEDURE dbo.sp_GetShuttleETA
    @StopID     INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 5
        sh.ShuttleID,
        sh.ShuttleName,
        r.RouteName,
        st.StopName,
        CAST(sc.DepartureTime AS VARCHAR) AS DepartureTime,
        st.EstimatedMinutes               AS MinutesFromStart,
        CAST(
            DATEADD(MINUTE, st.EstimatedMinutes,
                CAST(CAST(GETDATE() AS DATE) AS DATETIME) + CAST(sc.DepartureTime AS DATETIME))
        AS TIME)                          AS EstimatedArrival,
        (sh.Capacity - ISNULL(booked.BookedCount, 0)) AS SeatsRemaining
    FROM dbo.Stops st
    JOIN dbo.Routes   r  ON st.RouteID   = r.RouteID
    JOIN dbo.Schedule sc ON sc.RouteID   = r.RouteID AND sc.IsActive = 1
    JOIN dbo.Shuttles sh ON sc.ShuttleID = sh.ShuttleID
    OUTER APPLY (
        SELECT COUNT(*) AS BookedCount
        FROM dbo.Bookings b
        WHERE b.ScheduleID = sc.ScheduleID
          AND b.RideDate   = CAST(GETDATE() AS DATE)
          AND b.Status     IN ('Pending', 'Confirmed')
    ) booked
    WHERE st.StopID = @StopID
      AND sh.Status IN ('Available', 'In Service')
      AND CAST(sc.DepartureTime AS DATETIME) + CAST(DATEADD(MINUTE, st.EstimatedMinutes, '00:00:00') AS DATETIME)
          > CAST(GETDATE() AS DATETIME) - CAST(CAST(GETDATE() AS DATE) AS DATETIME)
    ORDER BY EstimatedArrival;
END
GO

-- ============================================================
-- SP: CRUD – Add / Update / Delete Users
-- ============================================================
IF OBJECT_ID('dbo.sp_UpsertUser', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_UpsertUser;
GO

CREATE PROCEDURE dbo.sp_UpsertUser
    @UserID      INT          = NULL,
    @FirstName   VARCHAR(50),
    @LastName    VARCHAR(50),
    @Email       VARCHAR(100),
    @PhoneNumber VARCHAR(20),
    @Role        VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @UserID IS NULL
        BEGIN
            INSERT INTO dbo.Users (FirstName, LastName, Email, PhoneNumber, Role)
            VALUES (@FirstName, @LastName, @Email, @PhoneNumber, @Role);
            SELECT SCOPE_IDENTITY() AS UserID;
        END
        ELSE
        BEGIN
            UPDATE dbo.Users
            SET FirstName   = @FirstName,
                LastName    = @LastName,
                Email       = @Email,
                PhoneNumber = @PhoneNumber,
                Role        = @Role,
                UpdatedAt   = GETDATE()
            WHERE UserID = @UserID;
        END
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO

PRINT 'Stored procedures created successfully.';
GO
