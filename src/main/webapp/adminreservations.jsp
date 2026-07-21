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
    // ---- session check (admin only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"admin".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    // ---- search params ----
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
        Customer username:
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
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        // ================= TOP 5 TRANSIT LINES =================
%>
    <h3>Top 5 Transit Lines by Reservations</h3>
    <table border="1" cellpadding="5">
        <tr><th>Rank</th><th>Transit Line</th>
            <th>Reservations</th><th>Total Revenue</th></tr>
<%
        ps = conn.prepareStatement(
            "SELECT tl.name, COUNT(*) AS num_res, " +
            "       SUM(r.total_fare) AS revenue " +
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
        // ================= RESERVATION SEARCH =================
        String sql =
            "SELECT r.reservation_id, r.username, r.reservation_date, " +
            "       r.total_fare, tl.name AS line_name, sc.train_id, " +
            "       ts.departure_datetime " +
            "FROM Reservation r " +
            "JOIN Schedule sc ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
            "WHERE 1=1 ";
        if (!custSearch.isEmpty()) sql += "AND r.username LIKE ? ";
        if (!lineSearch.isEmpty()) sql += "AND tl.name LIKE ? ";
        sql += "ORDER BY r.reservation_date DESC";

        ps = conn.prepareStatement(sql);
        int idx = 1;
        if (!custSearch.isEmpty()) ps.setString(idx++, "%" + custSearch + "%");
        if (!lineSearch.isEmpty()) ps.setString(idx++, "%" + lineSearch + "%");
        rs = ps.executeQuery();

        boolean any = false;
        int count = 0;
        double revenue = 0;
        while (rs.next()) {
            any = true;
            count++;
            revenue += rs.getDouble("total_fare");
%>
        <tr>
            <td><%= rs.getInt("reservation_id") %></td>
            <td><%= esc(rs.getString("username")) %></td>
            <td><%= esc(rs.getString("line_name")) %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= rs.getTimestamp("reservation_date") %></td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td>$<%= String.format("%.2f", rs.getDouble("total_fare")) %></td>
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
