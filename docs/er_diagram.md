# SU Campus Shuttle Management – ER Diagram

## Entities & Relationships

```
Users (UserID PK)
  |-- 1:N --> Bookings (UserID FK)
  |-- 1:N --> Shuttles (DriverID FK)

Routes (RouteID PK)
  |-- 1:N --> Stops    (RouteID FK)
  |-- 1:N --> Schedule (RouteID FK)

Shuttles (ShuttleID PK)
  |-- 1:N --> Schedule      (ShuttleID FK)
  |-- 1:N --> ShuttleLocation (ShuttleID FK)

Schedule (ScheduleID PK)
  |-- 1:N --> Bookings (ScheduleID FK)

Stops (StopID PK)
  |-- 1:N --> Bookings (PickupStopID FK)
  |-- 1:N --> Bookings (DropoffStopID FK)

Bookings (BookingID PK)
  |-- 1:N --> BookingAudit (BookingID FK)
```

## Conceptual Model

- A **User** can make many **Bookings**; each Booking belongs to one User.
- A **Route** has many **Stops** (ordered sequence).
- A **Shuttle** runs on many **Schedules**; each Schedule links one Shuttle to one Route at a departure time.
- A **Booking** references one **Schedule**, a pickup Stop, and a dropoff Stop (both on the same Route).
- **BookingAudit** records every status change on a Booking (populated by trigger).
- **ShuttleLocation** stores GPS breadcrumbs for real-time ETA calculations.

## Logical Model – Key Constraints

| Table          | PK            | Important FKs / Constraints                                    |
|----------------|---------------|----------------------------------------------------------------|
| Users          | UserID        | Email UNIQUE; Role IN ('Student','Staff','Admin','Driver')     |
| Shuttles       | ShuttleID     | LicensePlate UNIQUE; DriverID → Users                         |
| Routes         | RouteID       | –                                                              |
| Stops          | StopID        | RouteID → Routes; (RouteID, StopOrder) UNIQUE                 |
| Schedule       | ScheduleID    | ShuttleID → Shuttles; RouteID → Routes                        |
| Bookings       | BookingID     | UserID → Users; ScheduleID → Schedule; Pickup/Dropoff → Stops |
| BookingAudit   | AuditID       | BookingID → Bookings                                          |
| ShuttleLocation| LocationID    | ShuttleID → Shuttles                                          |
