<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    // ---- fare rules: adjust to match your spec ----
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

    // ---- handle new booking ----
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

            // stop_id copied from the schedule row itself (integrity)
            bps = bconn.prepareStatement(
                "INSERT INTO Reservation " +
                "(trip_type, passenger_type, reservation_date, " +
                " schedule_id, passenger_username, stop_id) " +
                "SELECT ?, ?, CURDATE(), sc.schedule_id, ?, sc.stop_id " +
                "FROM Schedule sc WHERE sc.schedule_id = ?");
            bps.setString(1, tripType);
            bps.setString(2, passengerType);
            bps.setString(3, username);
            bps.setInt(4, Integer.parseInt(scheduleId));
            int rows = bps.executeUpdate();
            message = (rows > 0) ? "Reservation booked!"
                                 : "That schedule no longer exists.";
        } catch (Exception e) {
            message = "Booking failed: " + e.getMessage();
        } finally {
            if (bps != null) bps.close();
            if (bconn != null) bconn.close();
        }
    }

    // ---- handle cancellation ----
    String cancelId = request.getParameter("cancel_id");
    if (cancelId != null) {
        Connection cconn = null;
        PreparedStatement cps = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            cconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

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

<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");
%>
    <!-- ================= Booking form ================= -->
    <h3>Make a Reservation</h3>
    <p>
        Discounts: Children 25% off, Seniors 50% off.
        Round-trip is twice the one-way price.
    </p>
    <form method="post" action="custreservation.jsp">
        Route:
        <select name="schedule_id">
<%
        ps = conn.prepareStatement(
            "SELECT sc.schedule_id, tl.name AS line_name, tl.fare, " +
            "       s.station_name, ts.departure_datetime " +
            "FROM Schedule sc " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON sc.stop_id = ts.stop_id " +
            "JOIN Station s      ON ts.station_id = s.station_id " +
            "WHERE ts.departure_datetime > NOW() " +
            "ORDER BY ts.departure_datetime");
        rs = ps.executeQuery();
        while (rs.next()) {
%>
            <option value="<%= rs.getInt("schedule_id") %>">
                <%= rs.getString("line_name") %> -
                <%= rs.getString("station_name") %> -
                <%= rs.getTimestamp("departure_datetime") %>
                ($<%= rs.getInt("fare") %> base)
            </option>
<%
        }
        rs.close();
        ps.close();
%>
        </select>

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

        <input type="submit" name="confirm_booking" value="Book">
    </form>
    <hr>

<%
        // ---- shared query for both tables ----
        String baseSql =
            "SELECT r.reservation_id, r.reservation_date, r.trip_type, " +
            "       r.passenger_type, " +
            "       tl.name AS line_name, tl.fare, " +
            "       sc.train_id, " +
            "       s.station_name, s.city, s.state, " +
            "       ts.departure_datetime " +
            "FROM Reservation r " +
            "JOIN Schedule sc    ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON r.stop_id = ts.stop_id " +
            "JOIN Station s      ON ts.station_id = s.station_id " +
            "WHERE r.passenger_username = ? ";

        // two passes: 0 = upcoming, 1 = past
        for (int pass = 0; pass < 2; pass++) {
            boolean upcoming = (pass == 0);
%>
    <h3><%= upcoming ? "Current / Upcoming Reservations"
                     : "Past Reservations" %></h3>
    <table border="1" cellpadding="5">
        <tr>
            <th>Res. #</th>
            <th>Booked On</th>
            <th>Line</th>
            <th>Train</th>
            <th>Station</th>
            <th>Departure</th>
            <th>Trip</th>
            <th>Passenger</th>
            <th>Price</th>
<%          if (upcoming) { %>
            <th></th>
<%          } %>
        </tr>
<%
            String sql = baseSql
                + (upcoming ? "AND ts.departure_datetime > NOW() "
                            : "AND ts.departure_datetime <= NOW() ")
                + "ORDER BY ts.departure_datetime "
                + (upcoming ? "" : "DESC");

            ps = conn.prepareStatement(sql);
            ps.setString(1, username);
            rs = ps.executeQuery();

            boolean any = false;
            while (rs.next()) {
                any = true;
                double price = computePrice(
                    rs.getInt("fare"),
                    rs.getString("passenger_type"),
                    rs.getString("trip_type"));
%>
        <tr>
            <td><%= rs.getInt("reservation_id") %></td>
            <td><%= rs.getDate("reservation_date") %></td>
            <td><%= rs.getString("line_name") %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= rs.getString("station_name") %>
                (<%= rs.getString("city") %>, <%= rs.getString("state") %>)</td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getString("trip_type") %></td>
            <td><%= rs.getString("passenger_type") %></td>
            <td>$<%= String.format("%.2f", price) %></td>
<%              if (upcoming) { %>
            <td>
                <a href="custreservation.jsp?cancel_id=<%= rs.getInt("reservation_id") %>"
                   onclick="return confirm('Cancel this reservation?');">
                    Cancel
                </a>
            </td>
<%              } %>
        </tr>
<%
            }
            if (!any) {
%>
        <tr><td colspan="<%= upcoming ? 10 : 9 %>">
            <%= upcoming ? "No upcoming reservations." : "No past reservations." %>
        </td></tr>
<%
            }
            rs.close();
            ps.close();
%>
    </table>
    <br>
<%
        } // end for
    } catch (Exception e) {
%>
    <p>Error: <%= e.getMessage() %></p>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (conn != null) conn.close();
    }
%>
</body>
</html>
