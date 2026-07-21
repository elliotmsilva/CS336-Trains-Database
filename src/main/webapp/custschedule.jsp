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

    String search = request.getParameter("search");
    if (search == null) search = "";

    // schedule the user clicked "Book" on (null = none selected)
    String bookScheduleId = request.getParameter("book_schedule_id");
    String bookStopId = request.getParameter("book_stop_id");

    // ---- handle booking form submission ----
    String bookingMessage = null;
    if ("POST".equalsIgnoreCase(request.getMethod())
            && request.getParameter("confirm_booking") != null) {

        String scheduleId = request.getParameter("schedule_id");
        String stopId = request.getParameter("stop_id");
        String tripType = request.getParameter("trip_type");
        String passengerType = request.getParameter("passenger_type");

        Connection bconn = null;
        PreparedStatement bps = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            bconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

            String insertSql =
                "INSERT INTO Reservation " +
                "(trip_type, passenger_type, reservation_date, " +
                " schedule_id, passenger_username, stop_id) " +
                "VALUES (?, ?, CURDATE(), ?, ?, ?)";

            bps = bconn.prepareStatement(insertSql);
            bps.setString(1, tripType);
            bps.setString(2, passengerType);
            bps.setInt(3, Integer.parseInt(scheduleId));
            bps.setString(4, username);
            bps.setInt(5, Integer.parseInt(stopId));
            bps.executeUpdate();

            bookingMessage = "Reservation booked! View it on the My Reservations page.";
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

<%  // ---- booking form (shows only after clicking Book) ----
    if (bookScheduleId != null && bookStopId != null) { %>
    <div style="border:1px solid black; padding:10px; margin-bottom:10px;">
        <h3>Book Schedule #<%= bookScheduleId %></h3>
        <form method="post" action="custschedule.jsp">
            <input type="hidden" name="schedule_id" value="<%= bookScheduleId %>">
            <input type="hidden" name="stop_id" value="<%= bookStopId %>">

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
<%  } %>

    <form method="get" action="custschedule.jsp">
        Search by station or line:
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
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        String sql =
            "SELECT s.schedule_id, tl.name AS line_name, tl.fare, s.train_id, " +
            "       st.station_name, st.city, st.state, " +
            "       ts.stop_id, ts.arrival_datetime, ts.departure_datetime " +
            "FROM Schedule s " +
            "JOIN TransitLine tl ON s.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON s.stop_id = ts.stop_id " +
            "JOIN Station st     ON ts.station_id = st.station_id ";

        if (!search.isEmpty()) {
            sql += "WHERE st.station_name LIKE ? OR tl.name LIKE ? " +
                   "   OR st.city LIKE ? ";
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
                <a href="custschedule.jsp?book_schedule_id=<%= rs.getInt("schedule_id") %>&book_stop_id=<%= rs.getInt("stop_id") %>">
                    Book
                </a>
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
