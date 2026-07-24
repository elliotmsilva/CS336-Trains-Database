<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
%>
<%
    // ---- session check (customer only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"customer".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String message = null;

    // ---- handle cancel (POST only) ----
    if ("POST".equalsIgnoreCase(request.getMethod())
            && "cancel".equals(request.getParameter("action"))) {

        Connection mconn = null;
        PreparedStatement mps = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            mconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

            int resId = Integer.parseInt(request.getParameter("reservation_id"));

            // WHERE username = ? -- customers can only cancel their own
            mps = mconn.prepareStatement(
                "DELETE FROM Reservation " +
                "WHERE reservation_id = ? AND username = ?");
            mps.setInt(1, resId);
            mps.setString(2, username);
            int rows = mps.executeUpdate();
            message = (rows > 0) ? "Reservation cancelled."
                                 : "No such reservation.";
        } catch (NumberFormatException nfe) {
            message = "Invalid input.";
        } catch (Exception e) {
            message = "Error: " + e.getMessage();
        } finally {
            if (mps != null) mps.close();
            if (mconn != null) mconn.close();
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
        <a href="custhome.jsp">Home</a> |
        <a href="custschedule.jsp">Search Schedules</a> |
        <a href="custforum.jsp">Forum</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= esc(message) %></b></p>
<%  } %>

    <table border="1" cellpadding="5">
        <tr>
            <th>Reservation #</th><th>Transit Line</th><th>Train</th>
            <th>Station</th><th>Departure</th><th>Arrival</th>
            <th>Booked On</th><th>Action</th>
        </tr>
<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        ps = conn.prepareStatement(
            "SELECT r.reservation_id, r.reservation_date, sc.train_id, " +
            "       tl.name AS line_name, s.station_name, " +
            "       ts.arrival_datetime, ts.departure_datetime " +
            "FROM Reservation r " +
            "JOIN Schedule sc ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
            "JOIN Station s ON ts.station_id = s.station_id " +
            "WHERE r.username = ? " +
            "ORDER BY ts.departure_datetime");
        ps.setString(1, username);
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
            int resId = rs.getInt("reservation_id");
%>
        <tr>
            <td><%= resId %></td>
            <td><%= esc(rs.getString("line_name")) %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= esc(rs.getString("station_name")) %></td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getTimestamp("arrival_datetime") %></td>
            <td><%= rs.getTimestamp("reservation_date") %></td>
            <td>
                <form method="post" action="custreservations.jsp"
                      onsubmit="return window.confirm('Cancel reservation #<%= resId %>?');">
                    <input type="hidden" name="action" value="cancel">
                    <input type="hidden" name="reservation_id" value="<%= resId %>">
                    <input type="submit" value="Cancel">
                </form>
            </td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="8">You have no reservations yet.
            <a href="custschedule.jsp">Find a train</a>.</td></tr>
<%
        }
    } catch (Exception e) {
%>
    <p>Error: <%= esc(e.getMessage()) %></p>
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
