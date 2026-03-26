-- ============================================================
-- SU Campus Shuttle Management System
-- Seed / Sample Data
-- ============================================================

USE SU_ShuttleManagement;
GO

-- ============================================================
-- USERS
-- ============================================================
INSERT INTO dbo.Users (FirstName, LastName, Email, PhoneNumber, Role) VALUES
('Alice',   'Johnson',  'alice.johnson@su.edu',   '555-0101', 'Student'),
('Bob',     'Smith',    'bob.smith@su.edu',        '555-0102', 'Student'),
('Carol',   'Williams', 'carol.williams@su.edu',  '555-0103', 'Staff'),
('David',   'Brown',    'david.brown@su.edu',     '555-0104', 'Admin'),
('Eve',     'Davis',    'eve.davis@su.edu',        '555-0105', 'Driver'),
('Frank',   'Miller',   'frank.miller@su.edu',    '555-0106', 'Driver'),
('Grace',   'Wilson',   'grace.wilson@su.edu',    '555-0107', 'Student'),
('Henry',   'Moore',    'henry.moore@su.edu',     '555-0108', 'Student');
GO

-- ============================================================
-- SHUTTLES
-- ============================================================
INSERT INTO dbo.Shuttles (ShuttleName, LicensePlate, Capacity, DriverID, Status) VALUES
('Blaze 1',  'SU-001', 12, 5, 'Available'),
('Blaze 2',  'SU-002', 12, 6, 'Available'),
('Blaze 3',  'SU-003', 8,  NULL, 'Maintenance');
GO

-- ============================================================
-- ROUTES
-- ============================================================
INSERT INTO dbo.Routes (RouteName, Description) VALUES
('Main Loop',         'Circles the main academic buildings and dorms'),
('Library Express',   'Direct route between dorms and the main library'),
('Athletic Complex',  'Connects dorms and academic buildings to the athletic complex');
GO

-- ============================================================
-- STOPS (Route 1 – Main Loop)
-- ============================================================
INSERT INTO dbo.Stops (RouteID, StopName, StopOrder, EstimatedMinutes, Latitude, Longitude) VALUES
(1, 'North Dorm',        1,  0,  43.0481, -76.1474),
(1, 'Student Union',     2,  5,  43.0490, -76.1460),
(1, 'Science Building',  3,  10, 43.0500, -76.1445),
(1, 'Library',           4,  15, 43.0510, -76.1430),
(1, 'South Dorm',        5,  20, 43.0520, -76.1415),
(1, 'North Dorm',        6,  25, 43.0481, -76.1474);  -- completes the loop

-- STOPS (Route 2 – Library Express)
INSERT INTO dbo.Stops (RouteID, StopName, StopOrder, EstimatedMinutes, Latitude, Longitude) VALUES
(2, 'East Dorm',  1, 0,  43.0475, -76.1480),
(2, 'Library',    2, 8,  43.0510, -76.1430);

-- STOPS (Route 3 – Athletic Complex)
INSERT INTO dbo.Stops (RouteID, StopName, StopOrder, EstimatedMinutes, Latitude, Longitude) VALUES
(3, 'Main Gate',          1,  0,  43.0460, -76.1500),
(3, 'Student Union',      2,  6,  43.0490, -76.1460),
(3, 'Athletic Complex',   3,  14, 43.0540, -76.1410);
GO

-- ============================================================
-- SCHEDULE
-- ============================================================
INSERT INTO dbo.Schedule (ShuttleID, RouteID, DepartureTime, DaysOfWeek) VALUES
(1, 1, '07:00', 'Mon,Tue,Wed,Thu,Fri'),
(1, 1, '09:00', 'Mon,Tue,Wed,Thu,Fri'),
(1, 1, '11:00', 'Mon,Tue,Wed,Thu,Fri'),
(1, 1, '13:00', 'Mon,Tue,Wed,Thu,Fri'),
(1, 1, '15:00', 'Mon,Tue,Wed,Thu,Fri'),
(1, 1, '17:00', 'Mon,Tue,Wed,Thu,Fri'),
(2, 2, '08:00', 'Mon,Tue,Wed,Thu,Fri'),
(2, 2, '12:00', 'Mon,Tue,Wed,Thu,Fri'),
(2, 2, '16:00', 'Mon,Tue,Wed,Thu,Fri'),
(2, 3, '10:00', 'Mon,Tue,Wed,Thu,Fri,Sat'),
(2, 3, '14:00', 'Mon,Tue,Wed,Thu,Fri,Sat'),
(2, 3, '18:00', 'Mon,Tue,Wed,Thu,Fri,Sat');
GO

-- ============================================================
-- SAMPLE BOOKINGS (historical data for reporting)
-- ============================================================
INSERT INTO dbo.Bookings
    (UserID, ScheduleID, PickupStopID, DropoffStopID, RideDate, Status, EstimatedPickup, ActualPickup)
VALUES
(1, 1, 1, 4, CAST(GETDATE()-7 AS DATE), 'Completed', DATEADD(HOUR, 7,  CAST(CAST(GETDATE()-7 AS DATE) AS DATETIME)), DATEADD(MINUTE, 2, DATEADD(HOUR, 7, CAST(CAST(GETDATE()-7 AS DATE) AS DATETIME)))),
(2, 1, 2, 5, CAST(GETDATE()-7 AS DATE), 'Completed', DATEADD(MINUTE, 5, DATEADD(HOUR, 7, CAST(CAST(GETDATE()-7 AS DATE) AS DATETIME))), DATEADD(MINUTE, 6, DATEADD(HOUR, 7, CAST(CAST(GETDATE()-7 AS DATE) AS DATETIME)))),
(7, 2, 1, 3, CAST(GETDATE()-6 AS DATE), 'Completed', DATEADD(HOUR, 9,  CAST(CAST(GETDATE()-6 AS DATE) AS DATETIME)), DATEADD(MINUTE, 1, DATEADD(HOUR, 9, CAST(CAST(GETDATE()-6 AS DATE) AS DATETIME)))),
(8, 7, 7, 8, CAST(GETDATE()-5 AS DATE), 'Completed', DATEADD(HOUR, 8,  CAST(CAST(GETDATE()-5 AS DATE) AS DATETIME)), DATEADD(MINUTE, 3, DATEADD(HOUR, 8, CAST(CAST(GETDATE()-5 AS DATE) AS DATETIME)))),
(1, 8, 7, 8, CAST(GETDATE()-4 AS DATE), 'Cancelled', DATEADD(HOUR,12,  CAST(CAST(GETDATE()-4 AS DATE) AS DATETIME)), NULL),
(3, 3, 1, 4, CAST(GETDATE()-3 AS DATE), 'Completed', DATEADD(HOUR,11,  CAST(CAST(GETDATE()-3 AS DATE) AS DATETIME)), DATEADD(MINUTE, 4, DATEADD(HOUR,11, CAST(CAST(GETDATE()-3 AS DATE) AS DATETIME)))),
(2, 4, 2, 4, CAST(GETDATE()-2 AS DATE), 'No-Show',   DATEADD(HOUR,13,  CAST(CAST(GETDATE()-2 AS DATE) AS DATETIME)), NULL),
(7, 5, 3, 5, CAST(GETDATE()-1 AS DATE), 'Completed', DATEADD(HOUR,15,  CAST(CAST(GETDATE()-1 AS DATE) AS DATETIME)), DATEADD(MINUTE, 1, DATEADD(HOUR,15, CAST(CAST(GETDATE()-1 AS DATE) AS DATETIME))));
GO

PRINT 'Seed data inserted successfully.';
GO
