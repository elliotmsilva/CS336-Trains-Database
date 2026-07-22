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
    // admin session check
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"manager".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    // searching params
    String custSearch = request.getParameter("customer");
    String lineSearch = request.getParameter("line");
    if (custSearch == null) custSearch = "";
    if (lineSearch == null) lineSearch = "";
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
        <a href="adminmanage.jsp">Manage Representatives</a> |
        <a href="adminreports.jsp">Sales Reports</a> |
        <a href="logout.jsp">Logout</a>
    </p>

    <form method="get" action="adminreservations.jsp">
        Customer (username or name):
        <input type="text" name="customer" value="<%= esc(custSearch) %>">
        Transit line:
        <input type="text" name="line" value="<%= esc(lineSearch) %>">
        <input type="submit" value="Search">
        <a href="adminreservations.jsp">Clear</a>
    </form>
    <br>

<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "es1242");

        // top 5 transit lines
%>
    <h3>Top 5 Transit Lines by Reservations</h3>
    <table border="1" cellpadding="5">
        <tr><th>Rank</th><th>Transit Line</th>
            <th>Reservations</th><th>Total Revenue</th></tr>
<%
        // fare paid per reservation 
        String fareExpr =
            "(tl.fare " +
            " * (CASE r.passenger_type WHEN 'Child' THEN 0.75 " +
            "         WHEN 'Senior' THEN 0.50 ELSE 1.0 END) " +
            " * (CASE r.trip_type WHEN 'round-trip' THEN 2 ELSE 1 END))";

        ps = conn.prepareStatement(
            "SELECT tl.name, COUNT(*) AS num_res, " +
            "       SUM(" + fareExpr + ") AS revenue " +
            "FROM Reservation r " +
            "JOIN Schedule sc ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "GROUP BY tl.line_id, tl.name " +
            "ORDER BY num_res DESC, revenue DESC " +
            "LIMIT 5");
        rs = ps.executeQuery();
        int rank = 0;
        while (rs.next()) {
            rank++;
%>
        <tr>
            <td><%= rank %></td>
            <td><%= esc(rs.getString("name")) %></td>
            <td><%= rs.getInt("num_res") %></td>
            <td>$<%= String.format("%.2f", rs.getDouble("revenue")) %></td>
        </tr>
<%
        }
        if (rank == 0) {
%>
        <tr><td colspan="4">No reservations yet.</td></tr>
<%
        }
        rs.close();
        ps.close();
%>
    </table>
    <hr>

    <h3>Reservation List</h3>
    <table border="1" cellpadding="5">
        <tr>
            <th>Res #</th><th>Customer</th><th>Transit Line</th>
            <th>Train</th><th>Booked On</th><th>Departure</th>
            <th>Fare Paid</th>
        </tr>
<%
        // searching reservation code
        String sql =
            "SELECT r.reservation_id, r.passenger_username, " +
            "       CONCAT(p.first_name, ' ', p.last_name) AS full_name, " +
            "       r.reservation_date, " + fareExpr + " AS fare_paid, " +
            "       tl.name AS line_name, sc.train_id, " +
            "       ts.departure_datetime " +
            "FROM Reservation r " +
            "JOIN Schedule sc ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
            "JOIN Passenger p ON r.passenger_username = p.username " +
            "WHERE 1=1 ";
        if (!custSearch.isEmpty()) {
            sql += "AND (r.passenger_username LIKE ? " +
                   "     OR p.first_name LIKE ? OR p.last_name LIKE ?) ";
        }
        if (!lineSearch.isEmpty()) sql += "AND tl.name LIKE ? ";
        sql += "ORDER BY r.reservation_date DESC";

        ps = conn.prepareStatement(sql);
        int idx = 1;
        if (!custSearch.isEmpty()) {
            String cl = "%" + custSearch + "%";
            ps.setString(idx++, cl);
            ps.setString(idx++, cl);
            ps.setString(idx++, cl);
        }
        if (!lineSearch.isEmpty()) ps.setString(idx++, "%" + lineSearch + "%");
        rs = ps.executeQuery();

        boolean any = false;
        int count = 0;
        double revenue = 0;
        while (rs.next()) {
            any = true;
            count++;
            revenue += rs.getDouble("fare_paid");
%>
        <tr>
            <td><%= rs.getInt("reservation_id") %></td>
            <td><%= esc(rs.getString("full_name")) %> (<%= esc(rs.getString("passenger_username")) %>)</td>
            <td><%= esc(rs.getString("line_name")) %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= rs.getDate("reservation_date") %></td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td>$<%= String.format("%.2f", rs.getDouble("fare_paid")) %></td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="7">No reservations match your search.</td></tr>
<%
        } else {
%>
        <tr>
            <td colspan="6"><b>Total (<%= count %> reservations)</b></td>
            <td><b>$<%= String.format("%.2f", revenue) %></b></td>
        </tr>
<%
        }
    } catch (Exception e) {
%>
        <tr><td colspan="7">Error: <%= esc(e.getMessage()) %></td></tr>
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
