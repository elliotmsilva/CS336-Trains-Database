<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    // ---- fare rules: adjust these to match YOUR project spec ----
    // base fare comes from TransitLine.fare (an INT)
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

    String message = null;

    // ---- handle cancellation ----
    String cancelId = request.getParameter("cancel_id");
    if (cancelId != null) {
        Connection cconn = null;
        PreparedStatement cps = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            cconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

            // username in WHERE clause so users can only cancel THEIR OWN
            cps = cconn.prepareStatement(
                "DELETE FROM Reservation " +
                "WHERE reservation_id = ? AND passenger_username = ?");
            cps.setInt(1, Integer.parseInt(cancelId));
            cps.setString(2, username);
            int rows = cps.executeUpdate();
            message = (rows > 0) ? "Reservation cancelled."
                                 : "Reservation not found.";
        } catch (Exception e) {
            message = "Error cancelling: " + e.getMessage();
        } finally {
            if (cps != null) cps.close();
            if (cconn != null) cconn.close();
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>My Reservations</title>
</head>
<body>
    <h1>My Reservations</h1>
    <p>
        <a href="customerhome.jsp">Home</a> |
        <a href="custschedule.jsp">Schedules</a> |
        <a href="custforum.jsp">Forum</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= message %></b></p>
<%  } %>

    <table border="1" cellpadding="5">
        <tr>
            <th>Res. #</th>
            <th>Booked On</th>
            <th>Line</th>
            <th>Train</th>
            <th>Station</th>
            <th>Departure</th>
            <th>Arrival</th>
            <th>Trip</th>
            <th>Passenger</th>
            <th>Price</th>
            <th></th>
        </tr>
<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        String sql =
            "SELECT r.reservation_id, r.reservation_date, r.trip_type, " +
            "       r.passenger_type, " +
            "       tl.name AS line_name, tl.fare, " +
            "       sc.train_id, " +
            "       s.station_name, s.city, s.state, " +
            "       ts.arrival_datetime, ts.departure_datetime " +
            "FROM Reservation r " +
            "JOIN Schedule sc    ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON r.stop_id = ts.stop_id " +
            "JOIN Station s      ON ts.station_id = s.station_id " +
            "WHERE r.passenger_username = ? " +
            "ORDER BY ts.departure_datetime";

        ps = conn.prepareStatement(sql);
        ps.setString(1, username);
        rs = ps.executeQuery();

        boolean any = false;
        double total = 0;
        while (rs.next()) {
            any = true;
            double price = computePrice(
                rs.getInt("fare"),
                rs.getString("passenger_type"),
                rs.getString("trip_type"));
            total += price;
%>
        <tr>
            <td><%= rs.getInt("reservation_id") %></td>
            <td><%= rs.getDate("reservation_date") %></td>
            <td><%= rs.getString("line_name") %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= rs.getString("station_name") %>
                (<%= rs.getString("city") %>, <%= rs.getString("state") %>)</td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getTimestamp("arrival_datetime") %></td>
            <td><%= rs.getString("trip_type") %></td>
            <td><%= rs.getString("passenger_type") %></td>
            <td>$<%= String.format("%.2f", price) %></td>
            <td>
                <a href="custreservation.jsp?cancel_id=<%= rs.getInt("reservation_id") %>"
                   onclick="return confirm('Cancel this reservation?');">
                    Cancel
                </a>
            </td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="11">You have no reservations yet.
            <a href="custschedule.jsp">Browse schedules</a> to book one.</td></tr>
<%
        } else {
%>
        <tr>
            <td colspan="9" align="right"><b>Total:</b></td>
            <td><b>$<%= String.format("%.2f", total) %></b></td>
            <td></td>
        </tr>
<%
        }
    } catch (Exception e) {
%>
        <tr><td colspan="11">Error: <%= e.getMessage() %></td></tr>
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
