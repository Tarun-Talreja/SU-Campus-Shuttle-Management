"""
SU Campus Shuttle Management System
REST API – Flask + pyodbc (SQL Server)
"""

import os
from datetime import date
from flask import Flask, request, jsonify, abort
import pyodbc

app = Flask(__name__)

# ──────────────────────────────────────────────
# Database connection
# ──────────────────────────────────────────────
DB_SERVER   = os.getenv("DB_SERVER",   "localhost")
DB_NAME     = os.getenv("DB_NAME",     "SU_ShuttleManagement")
DB_USER     = os.getenv("DB_USER",     "sa")
DB_PASSWORD = os.getenv("DB_PASSWORD", "YourStrong!Password")

CONN_STRING = (
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={DB_SERVER};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};"
    f"PWD={DB_PASSWORD};"
    f"TrustServerCertificate=yes;"
)


def get_conn():
    return pyodbc.connect(CONN_STRING)


def rows_to_dicts(cursor):
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


# ──────────────────────────────────────────────
# Bookings
# ──────────────────────────────────────────────
@app.route("/api/bookings", methods=["POST"])
def create_booking():
    data = request.get_json(force=True)
    required = {"user_id", "schedule_id", "pickup_stop_id", "dropoff_stop_id", "ride_date"}
    if not required.issubset(data):
        abort(400, description=f"Missing fields: {required - data.keys()}")

    try:
        conn   = get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "DECLARE @bid INT; "
            "EXEC dbo.sp_CreateBooking ?, ?, ?, ?, ?, ?, @bid OUTPUT; "
            "SELECT @bid;",
            data["user_id"],
            data["schedule_id"],
            data["pickup_stop_id"],
            data["dropoff_stop_id"],
            data["ride_date"],
            data.get("notes"),
        )
        booking_id = cursor.fetchval()
        conn.commit()
        return jsonify({"booking_id": booking_id}), 201
    except pyodbc.Error as exc:
        return jsonify({"error": str(exc)}), 400


@app.route("/api/bookings/<int:booking_id>/cancel", methods=["PATCH"])
def cancel_booking(booking_id):
    data       = request.get_json(force=True) or {}
    changed_by = data.get("cancelled_by")
    reason     = data.get("reason")
    if not changed_by:
        abort(400, description="cancelled_by is required")

    try:
        conn   = get_conn()
        cursor = conn.cursor()
        cursor.execute("EXEC dbo.sp_CancelBooking ?, ?, ?", booking_id, changed_by, reason)
        conn.commit()
        return jsonify({"message": "Booking cancelled"}), 200
    except pyodbc.Error as exc:
        return jsonify({"error": str(exc)}), 400


@app.route("/api/users/<int:user_id>/bookings", methods=["GET"])
def get_user_bookings(user_id):
    status     = request.args.get("status")
    from_date  = request.args.get("from_date")
    to_date    = request.args.get("to_date")

    conn   = get_conn()
    cursor = conn.cursor()
    cursor.execute(
        "EXEC dbo.sp_GetUserBookings ?, ?, ?, ?",
        user_id, status, from_date, to_date
    )
    bookings = rows_to_dicts(cursor)

    # Serialize date/datetime objects
    for b in bookings:
        for k, v in b.items():
            if hasattr(v, "isoformat"):
                b[k] = v.isoformat()

    return jsonify(bookings), 200


@app.route("/api/bookings/<int:booking_id>/status", methods=["PATCH"])
def update_booking_status(booking_id):
    data = request.get_json(force=True)
    if "status" not in data or "changed_by" not in data:
        abort(400, description="status and changed_by are required")

    try:
        conn   = get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_UpdateBookingStatus ?, ?, ?, ?",
            booking_id,
            data["status"],
            data["changed_by"],
            data.get("actual_pickup"),
        )
        conn.commit()
        return jsonify({"message": "Status updated"}), 200
    except pyodbc.Error as exc:
        return jsonify({"error": str(exc)}), 400


# ──────────────────────────────────────────────
# Shuttles / Availability
# ──────────────────────────────────────────────
@app.route("/api/routes/<int:route_id>/available", methods=["GET"])
def get_available_shuttles(route_id):
    ride_date = request.args.get("ride_date", str(date.today()))

    conn   = get_conn()
    cursor = conn.cursor()
    cursor.execute("EXEC dbo.sp_GetAvailableShuttles ?, ?", route_id, ride_date)
    shuttles = rows_to_dicts(cursor)

    for s in shuttles:
        for k, v in s.items():
            if hasattr(v, "isoformat"):
                s[k] = v.isoformat()

    return jsonify(shuttles), 200


@app.route("/api/stops/<int:stop_id>/eta", methods=["GET"])
def get_shuttle_eta(stop_id):
    conn   = get_conn()
    cursor = conn.cursor()
    cursor.execute("EXEC dbo.sp_GetShuttleETA ?", stop_id)
    etas = rows_to_dicts(cursor)

    for e in etas:
        for k, v in e.items():
            if hasattr(v, "isoformat"):
                e[k] = v.isoformat()

    return jsonify(etas), 200


# ──────────────────────────────────────────────
# Reports
# ──────────────────────────────────────────────
@app.route("/api/reports/bookings", methods=["GET"])
def booking_report():
    from_date = request.args.get("from_date")
    to_date   = request.args.get("to_date")
    route_id  = request.args.get("route_id")

    if not from_date or not to_date:
        abort(400, description="from_date and to_date query params are required")

    conn   = get_conn()
    cursor = conn.cursor()
    cursor.execute("EXEC dbo.sp_BookingReport ?, ?, ?", from_date, to_date, route_id)
    report = rows_to_dicts(cursor)

    for row in report:
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()

    return jsonify(report), 200


# ──────────────────────────────────────────────
# Users – CRUD
# ──────────────────────────────────────────────
@app.route("/api/users", methods=["POST"])
def create_user():
    data     = request.get_json(force=True)
    required = {"first_name", "last_name", "email", "phone_number", "role"}
    if not required.issubset(data):
        abort(400, description=f"Missing fields: {required - data.keys()}")

    try:
        conn   = get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_UpsertUser NULL, ?, ?, ?, ?, ?",
            data["first_name"], data["last_name"],
            data["email"],      data["phone_number"], data["role"]
        )
        user_id = cursor.fetchval()
        conn.commit()
        return jsonify({"user_id": user_id}), 201
    except pyodbc.Error as exc:
        return jsonify({"error": str(exc)}), 400


@app.route("/api/users/<int:user_id>", methods=["PUT"])
def update_user(user_id):
    data     = request.get_json(force=True)
    required = {"first_name", "last_name", "email", "phone_number", "role"}
    if not required.issubset(data):
        abort(400, description=f"Missing fields: {required - data.keys()}")

    try:
        conn   = get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_UpsertUser ?, ?, ?, ?, ?, ?",
            user_id,
            data["first_name"], data["last_name"],
            data["email"],      data["phone_number"], data["role"]
        )
        conn.commit()
        return jsonify({"message": "User updated"}), 200
    except pyodbc.Error as exc:
        return jsonify({"error": str(exc)}), 400


@app.route("/api/users/<int:user_id>", methods=["DELETE"])
def deactivate_user(user_id):
    try:
        conn   = get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE dbo.Users SET IsActive = 0, UpdatedAt = GETDATE() WHERE UserID = ?",
            user_id
        )
        conn.commit()
        return jsonify({"message": "User deactivated"}), 200
    except pyodbc.Error as exc:
        return jsonify({"error": str(exc)}), 400


# ──────────────────────────────────────────────
# Routes & Stops – read-only
# ──────────────────────────────────────────────
@app.route("/api/routes", methods=["GET"])
def list_routes():
    conn   = get_conn()
    cursor = conn.cursor()
    cursor.execute("SELECT RouteID, RouteName, Description FROM dbo.Routes WHERE IsActive = 1")
    return jsonify(rows_to_dicts(cursor)), 200


@app.route("/api/routes/<int:route_id>/stops", methods=["GET"])
def list_stops(route_id):
    conn   = get_conn()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT StopID, StopName, StopOrder, EstimatedMinutes, Latitude, Longitude "
        "FROM dbo.Stops WHERE RouteID = ? ORDER BY StopOrder",
        route_id
    )
    stops = rows_to_dicts(cursor)
    for s in stops:
        for k, v in s.items():
            if hasattr(v, "isoformat"):
                s[k] = v.isoformat()
    return jsonify(stops), 200


if __name__ == "__main__":
    app.run(debug=False, host="0.0.0.0", port=5000)
