<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%
    // ---- session check (customer only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"customer".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
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
        <a href="searchschedules.jsp">Book a Trip</a> |
        <a href="logout.jsp">Logout</a>
    </p>

    <table border="1" cellpadding="5">
        <tr>
            <th>Reservation #</th>
            <th>Date</th>
            <th>Trip Type</th>
            <th>Passenger Type</th>
            <th>Transit Line</th>
            <th>Station</th>
            <th>Departure</th>
            <th>Arrival</th>
            <th>Total Fare</th>
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
            "       r.passenger_type, tl.name AS line_name, tl.fare, " +
            "       st.station_name, st.city, st.state, " +
            "       ts.arrival_datetime, ts.departure_datetime " +
            "FROM Reservation r " +
            "JOIN Schedule s     ON r.schedule_id = s.schedule_id " +
            "JOIN TransitLine tl ON s.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON r.stop_id = ts.stop_id " +
            "JOIN Station st     ON ts.station_id = st.station_id " +
            "WHERE r.passenger_username = ? " +
            "ORDER BY r.reservation_date DESC";

        ps = conn.prepareStatement(sql);
        ps.setString(1, username);
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;

            // ---- compute total fare ----
            double fare = rs.getInt("fare");
            String pType = rs.getString("passenger_type");
            if ("Child".equals(pType))  fare *= 0.75;  // 25% off
            if ("Senior".equals(pType)) fare *= 0.65;  // 35% off
            if ("round-trip".equalsIgnoreCase(rs.getString("trip_type")))
                fare *= 2;
%>
        <tr>
            <td><%= rs.getInt("reservation_id") %></td>
            <td><%= rs.getDate("reservation_date") %></td>
            <td><%= rs.getString("trip_type") %></td>
            <td><%= pType %></td>
            <td><%= rs.getString("line_name") %></td>
            <td><%= rs.getString("station_name") %> 
                (<%= rs.getString("city") %>, <%= rs.getString("state") %>)</td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getTimestamp("arrival_datetime") %></td>
            <td>$<%= String.format("%.2f", fare) %></td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="9">No reservations found.</td></tr>
<%
        }
    } catch (Exception e) {
%>
        <tr><td colspan="9">Error: <%= e.getMessage() %></td></tr>
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
