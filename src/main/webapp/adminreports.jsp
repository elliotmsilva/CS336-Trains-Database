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

    // whitelist check
    String report = request.getParameter("report");
    String groupExpr, groupLabel;
    if ("line".equals(report)) {
        groupExpr = "tl.name";
        groupLabel = "Transit Line";
    } else if ("customer".equals(report)) {
        groupExpr = "CONCAT(p.first_name, ' ', p.last_name)";
        groupLabel = "Customer";
    } else {
        report = "month";
        groupExpr = "DATE_FORMAT(r.reservation_date, '%Y-%m')";
        groupLabel = "Month";
    }

    // checking date range
    String fromDate = request.getParameter("from_date");
    String toDate = request.getParameter("to_date");
    if (fromDate == null) fromDate = "";
    if (toDate == null) toDate = "";
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Sales Reports</title>
</head>
<body>
    <h1>Sales Reports</h1>
    <p>
        <a href="adminhome.jsp">Home</a> |
        <a href="adminmanage.jsp">Manage Representatives</a> |
        <a href="adminreservations.jsp">Reservations</a> |
        <a href="logout.jsp">Logout</a>
    </p>

    <form method="get" action="adminreports.jsp">
        Report:
        <select name="report">
            <option value="month" <%= "month".equals(report) ? "selected" : "" %>>
                Sales by Month</option>
            <option value="line" <%= "line".equals(report) ? "selected" : "" %>>
                Sales by Transit Line</option>
            <option value="customer" <%= "customer".equals(report) ? "selected" : "" %>>
                Sales by Customer</option>
        </select>
        From: <input type="date" name="from_date" value="<%= esc(fromDate) %>">
        To: <input type="date" name="to_date" value="<%= esc(toDate) %>">
        <input type="submit" value="Run Report">
        <a href="adminreports.jsp">Reset</a>
    </form>
    <br>

    <table border="1" cellpadding="5">
        <tr>
            <th><%= groupLabel %></th>
            <th>Reservations</th>
            <th>Total Revenue</th>
            <th>Average Fare</th>
        </tr>
<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "es1242");

        // checking fare paid
        String fareExpr =
            "(tl.fare " +
            " * (CASE r.passenger_type WHEN 'Child' THEN 0.75 " +
            "         WHEN 'Senior' THEN 0.50 ELSE 1.0 END) " +
            " * (CASE r.trip_type WHEN 'round-trip' THEN 2 ELSE 1 END))";

        // groupExpr whitelist check
        String sql =
            "SELECT " + groupExpr + " AS grp, " +
            "       COUNT(*) AS num_res, " +
            "       SUM(" + fareExpr + ") AS revenue, " +
            "       AVG(" + fareExpr + ") AS avg_fare " +
            "FROM Reservation r " +
            "JOIN Schedule sc ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN Passenger p ON r.passenger_username = p.username " +
            "WHERE 1=1 ";
        if (!fromDate.isEmpty()) sql += "AND r.reservation_date >= ? ";
        if (!toDate.isEmpty())   sql += "AND r.reservation_date < DATE_ADD(?, INTERVAL 1 DAY) ";
        sql += "GROUP BY grp ORDER BY revenue DESC";

        ps = conn.prepareStatement(sql);
        int idx = 1;
        if (!fromDate.isEmpty()) ps.setString(idx++, fromDate);
        if (!toDate.isEmpty())   ps.setString(idx++, toDate);
        rs = ps.executeQuery();

        boolean any = false;
        int totalRes = 0;
        double totalRev = 0;
        while (rs.next()) {
            any = true;
            totalRes += rs.getInt("num_res");
            totalRev += rs.getDouble("revenue");
%>
        <tr>
            <td><%= esc(rs.getString("grp")) %></td>
            <td><%= rs.getInt("num_res") %></td>
            <td>$<%= String.format("%.2f", rs.getDouble("revenue")) %></td>
            <td>$<%= String.format("%.2f", rs.getDouble("avg_fare")) %></td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="4">No sales in this period.</td></tr>
<%
        } else {
%>
        <tr>
            <td><b>Grand Total</b></td>
            <td><b><%= totalRes %></b></td>
            <td><b>$<%= String.format("%.2f", totalRev) %></b></td>
            <td><b>$<%= String.format("%.2f",
                    totalRes > 0 ? totalRev / totalRes : 0) %></b></td>
        </tr>
<%
        }
    } catch (Exception e) {
%>
        <tr><td colspan="4">Error: <%= esc(e.getMessage()) %></td></tr>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (conn != null) conn.close();
    }
%>
    </table>
    <hr>

    <h3>Best Customers (Top 5 by Revenue)</h3>
    <table border="1" cellpadding="5">
        <tr><th>Rank</th><th>Customer</th>
            <th>Reservations</th><th>Total Revenue</th></tr>
<%
    Connection bcConn = null;
    PreparedStatement bcPs = null;
    ResultSet bcRs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        bcConn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "es1242");

        // Fare rule (dont know how to check for sync update)
        String bcFareExpr =
            "(tl.fare " +
            " * (CASE r.passenger_type WHEN 'Child' THEN 0.75 " +
            "         WHEN 'Senior' THEN 0.50 ELSE 1.0 END) " +
            " * (CASE r.trip_type WHEN 'round-trip' THEN 2 ELSE 1 END))";

        bcPs = bcConn.prepareStatement(
            "SELECT p.username, CONCAT(p.first_name, ' ', p.last_name) AS full_name, " +
            "       COUNT(*) AS num_res, SUM(" + bcFareExpr + ") AS revenue " +
            "FROM Reservation r " +
            "JOIN Schedule sc ON r.schedule_id = sc.schedule_id " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN Passenger p ON r.passenger_username = p.username " +
            "GROUP BY p.username, full_name " +
            "ORDER BY revenue DESC " +
            "LIMIT 5");
        bcRs = bcPs.executeQuery();
        int bcRank = 0;
        while (bcRs.next()) {
            bcRank++;
%>
        <tr>
            <td><%= bcRank %></td>
            <td><%= esc(bcRs.getString("full_name")) %> (<%= esc(bcRs.getString("username")) %>)</td>
            <td><%= bcRs.getInt("num_res") %></td>
            <td>$<%= String.format("%.2f", bcRs.getDouble("revenue")) %></td>
        </tr>
<%
        }
        if (bcRank == 0) {
%>
        <tr><td colspan="4">No reservations yet.</td></tr>
<%
        }
    } catch (Exception e) {
%>
        <tr><td colspan="4">Error: <%= esc(e.getMessage()) %></td></tr>
<%
    } finally {
        if (bcRs != null) bcRs.close();
        if (bcPs != null) bcPs.close();
        if (bcConn != null) bcConn.close();
    }
%>
    </table>
</body>
</html>
