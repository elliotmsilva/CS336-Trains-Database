<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    // ---- SAME fare rules as custreservation.jsp — keep these in sync! ----
    private double computePrice(int baseFare, String passengerType, String tripType) {
        double price = baseFare;
        if ("Child".equals(passengerType)) {
            price *= 0.75;   // 25% off
        } else if ("Senior".equals(passengerType)) {
            price *= 0.50;   // 50% off
        }
        if ("round-trip".equals(tripType)) {
            price *= 2;
        }
        return price;
    }
%>
<%
    // ---- session check (passenger only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"passenger".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String search = request.getParameter("search");
    if (search == null) search = "";

    // schedule the user clicked "Book" on (null = none selected)
    String bookScheduleId = request.getParameter("book_schedule_id");

    // ---- handle booking form submission ----
    String bookingMessage = null;
    if ("POST".equalsIgnoreCase(request.getMethod())
            && request.getParameter("confirm_booking") != null) {

        String scheduleId = request.getParameter("schedule_id");
        String tripType = request.getParameter("trip_type");
        String passengerType = request.getParameter("passenger_type");

        Connection bconn = null;
        PreparedStatement bps = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            bconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

            // stop_id is copied FROM the schedule row itself, so the
            // reservation can never reference a stop that contradicts
            // its schedule (the schema wouldn't stop that; this does).
            String insertSql =
                "INSERT INTO Reservation " +
                "(trip_type, passenger_type, reservation_date, " +
                " schedule_id, passenger_username, stop_id) " +
                "SELECT ?, ?, CURDATE(), sc.schedule_id, ?, sc.stop_id " +
                "FROM Schedule sc WHERE sc.schedule_id = ?";

            bps = bconn.prepareStatement(insertSql);
            bps.setString(1, tripType);
            bps.setString(2, passengerType);
            bps.setString(3, username);
            bps.setInt(4, Integer.parseInt(scheduleId));
            int rows = bps.executeUpdate();

            bookingMessage = (rows > 0)
                ? "Reservation booked! View it on the My Reservations page."
                : "That schedule no longer exists.";
            bookScheduleId = null; // hide the form again
        } catch (Exception e) {
            bookingMessage = "Booking failed: " + e.getMessage();
        } finally {
            if (bps != null) bps.close();
            if (bconn != null) bconn.close();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Train Schedules</title>
</head>
<body>
    <h1>Train Schedules</h1>
    <p>
        <a href="customerhome.jsp">Home</a> |
        <a href="custreservation.jsp">My Reservations</a> |
        <a href="custforum.jsp">Forum</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (bookingMessage != null) { %>
    <p><b><%= bookingMessage %></b></p>
<%  } %>

<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        // ---- booking form (shows only after clicking Book) ----
        if (bookScheduleId != null) {
            ps = conn.prepareStatement(
                "SELECT sc.schedule_id, tl.name AS line_name, tl.fare, " +
                "       s.station_name, ts.departure_datetime " +
                "FROM Schedule sc " +
                "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
                "JOIN TrainStop ts   ON sc.stop_id = ts.stop_id " +
                "JOIN Station s      ON ts.station_id = s.station_id " +
                "WHERE sc.schedule_id = ?");
            ps.setInt(1, Integer.parseInt(bookScheduleId));
            rs = ps.executeQuery();
            if (rs.next()) {
                int fare = rs.getInt("fare");
%>
    <div style="border:1px solid black; padding:10px; margin-bottom:10px;">
        <h3>Book: <%= rs.getString("line_name") %> from
            <%= rs.getString("station_name") %>
            (<%= rs.getTimestamp("departure_datetime") %>)</h3>
        <p>
            Prices &mdash;
            Adult: $<%= String.format("%.2f", computePrice(fare, "Adult", "one-way")) %> |
            Child: $<%= String.format("%.2f", computePrice(fare, "Child", "one-way")) %> |
            Senior: $<%= String.format("%.2f", computePrice(fare, "Senior", "one-way")) %>
            (one-way; round-trip is double)
        </p>
        <form method="post" action="custschedule.jsp">
            <input type="hidden" name="schedule_id" value="<%= rs.getInt("schedule_id") %>">

            Trip type:
            <select name="trip_type">
                <option value="one-way">One-way</option>
                <option value="round-trip">Round-trip</option>
            </select>

            Passenger type:
            <select name="passenger_type">
                <option value="Adult">Adult</option>
                <option value="Child">Child</option>
                <option value="Senior">Senior</option>
            </select>

            <input type="submit" name="confirm_booking" value="Confirm Booking">
            <a href="custschedule.jsp">Cancel</a>
        </form>
    </div>
<%
            } else {
%>
    <p><b>That schedule was not found.</b></p>
<%
            }
            rs.close();
            ps.close();
        }
%>

    <form method="get" action="custschedule.jsp">
        Search by station, city, or line:
        <input type="text" name="search" value="<%= search %>">
        <input type="submit" value="Search">
        <a href="custschedule.jsp">Clear</a>
    </form>
    <br>

    <table border="1" cellpadding="5">
        <tr>
            <th>Schedule #</th>
            <th>Transit Line</th>
            <th>Train</th>
            <th>Station</th>
            <th>Departure</th>
            <th>Arrival</th>
            <th>Base Fare</th>
            <th></th>
        </tr>
<%
        String sql =
            "SELECT sc.schedule_id, tl.name AS line_name, tl.fare, sc.train_id, " +
            "       s.station_name, s.city, s.state, " +
            "       ts.arrival_datetime, ts.departure_datetime " +
            "FROM Schedule sc " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON sc.stop_id = ts.stop_id " +
            "JOIN Station s      ON ts.station_id = s.station_id ";

        if (!search.isEmpty()) {
            sql += "WHERE s.station_name LIKE ? OR tl.name LIKE ? OR s.city LIKE ? ";
        }
        sql += "ORDER BY ts.departure_datetime";

        ps = conn.prepareStatement(sql);
        if (!search.isEmpty()) {
            String like = "%" + search + "%";
            ps.setString(1, like);
            ps.setString(2, like);
            ps.setString(3, like);
        }
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
%>
        <tr>
            <td><%= rs.getInt("schedule_id") %></td>
            <td><%= rs.getString("line_name") %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= rs.getString("station_name") %>
                (<%= rs.getString("city") %>, <%= rs.getString("state") %>)</td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getTimestamp("arrival_datetime") %></td>
            <td>$<%= String.format("%.2f", (double) rs.getInt("fare")) %></td>
            <td>
                <a href="custschedule.jsp?book_schedule_id=<%= rs.getInt("schedule_id") %>">Book</a>
            </td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="8">No schedules found.</td></tr>
<%
        }
    } catch (Exception e) {
%>
        <tr><td colspan="8">Error: <%= e.getMessage() %></td></tr>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (conn != null) conn.close();
    }
%>
    </table>
</body>
</html>
