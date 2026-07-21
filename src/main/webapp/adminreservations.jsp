<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    // ---- SAME fare rules as custreservation/custschedule — keep in sync! ----
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
    // ---- session check (manager only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"manager".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String filterUser = request.getParameter("filter_user");
    String filterLine = request.getParameter("filter_line");
    if (filterUser == null) filterUser = "";
    if (filterLine == null) filterLine = "";

    String message = null;

    // ---- handle admin cancellation ----
    String cancelId = request.getParameter("cancel_id");
    if (cancelId != null) {
        Connection cconn = null;
        PreparedStatement cps = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            cconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

            // no username restriction here — manager can cancel any reservation
            cps = cconn.prepareStatement(
                "DELETE FROM Reservation WHERE reservation_id = ?");
            cps.setInt(1, Integer.parseInt(cancelId));
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
<title>All Reservations</title>
</head>
<body>
    <h1>All Reservations</h1>
    <p>
        <a href="adminhome.jsp">Home</a> |
        <a href="adminmanage.jsp">Manage System</a> |
        <a href="adminreports.jsp">Reports</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= message %></b></p>
<%  } %>

    <form method="get" action="adminreservations.jsp">
        Passenger username:
        <input type="text" name="filter_user" value="<%= filterUser %>">
        Transit line:
        <input type="text" name="filter_line" value="<%= filterLine %>">
        <input type="submit" value="Filter">
        <a href="adminreservations.jsp">Clear</a>
    </form>
    <br>

    <table border="1" cellpadding="5">
        <tr>
            <th>Res. #</th>
            <th>Passenger</th>
            <th>Booked On</th>
            <th>Line</th>
            <th>Train</th>
            <th>Station</th>
            <th>Departure</th>
            <th>Trip</th>
            <th>Type</th>
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
            "SELECT r.reservation_id, r.passenger_username, r.reservation_date, " +
            "       r.trip_type, r.passenger_type, " +
            "       tl.name AS line_name, tl.fare, " +
            "       sc.train_id, " +
            "       s.station_name, s.city, s.state, " +
            "       ts.departure_datetime " +
            "FROM Reservation r " +
            "JOIN Schedule sc    ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON r.stop_id = ts.stop_id " +
            "JOIN Station s      ON ts.station_id = s.station_id " +
            "WHERE 1=1 ";

        if (!filterUser.isEmpty()) {
            sql += "AND r.passenger_username LIKE ? ";
        }
        if (!filterLine.isEmpty()) {
            sql += "AND tl.name LIKE ? ";
        }
        sql += "ORDER BY ts.departure_datetime";

        ps = conn.prepareStatement(sql);
        int idx = 1;
        if (!filterUser.isEmpty()) {
            ps.setString(idx++, "%" + filterUser + "%");
        }
        if (!filterLine.isEmpty()) {
            ps.setString(idx++, "%" + filterLine + "%");
        }
        rs = ps.executeQuery();

        boolean any = false;
        int count = 0;
        double total = 0;
        while (rs.next()) {
            any = true;
            count++;
            double price = computePrice(
                rs.getInt("fare"),
                rs.getString("passenger_type"),
                rs.getString("trip_type"));
            total += price;
%>
        <tr>
            <td><%= rs.getInt("reservation_id") %></td>
            <td><%= rs.getString("passenger_username") %></td>
            <td><%= rs.getDate("reservation_date") %></td>
            <td><%= rs.getString("line_name") %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= rs.getString("station_name") %>
                (<%= rs.getString("city") %>, <%= rs.getString("state") %>)</td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getString("trip_type") %></td>
            <td><%= rs.getString("passenger_type") %></td>
            <td>$<%= String.format("%.2f", price) %></td>
            <td>
                <a href="adminreservations.jsp?cancel_id=<%= rs.getInt("reservation_id") %>&filter_user=<%= filterUser %>&filter_line=<%= filterLine %>"
                   onclick="return confirm('Cancel this reservation?');">
                    Cancel
                </a>
            </td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="11">No reservations found.</td></tr>
<%
        } else {
%>
        <tr>
            <td colspan="9" align="right">
                <b>Total (<%= count %> reservation<%= count == 1 ? "" : "s" %>):</b>
            </td>
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
