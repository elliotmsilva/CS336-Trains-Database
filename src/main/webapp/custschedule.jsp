<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="com.cs336.dbmstrainsproject.ApplicationDB" %>
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

    // ---- read search params (GET: searches are bookmarkable/refreshable) ----
    String keyword = request.getParameter("keyword");
    if (keyword == null) keyword = "";

    String stationParam = request.getParameter("station_id");
    int stationId = -1;
    if (stationParam != null && !stationParam.isEmpty()) {
        try { stationId = Integer.parseInt(stationParam); }
        catch (NumberFormatException nfe) { stationId = -1; }
    }

    String dateParam = request.getParameter("date");
    if (dateParam == null) dateParam = "";

    // sort: whitelist only -- ORDER BY cannot be a bind parameter
    String sortParam = request.getParameter("sort");
    String orderBy;
    if ("line".equals(sortParam)) {
        orderBy = "tl.name, ts.departure_datetime";
    } else {
        sortParam = "dep";
        orderBy = "ts.departure_datetime";
    }

    // query string to preserve state in links and redirects
    String qs = "keyword=" + java.net.URLEncoder.encode(keyword, "UTF-8")
              + (stationId != -1 ? "&station_id=" + stationId : "")
              + (!dateParam.isEmpty()
                    ? "&date=" + java.net.URLEncoder.encode(dateParam, "UTF-8") : "");

    // ---- handle booking (POST), then redirect back to the search (GET) ----
    if ("POST".equalsIgnoreCase(request.getMethod())
            && "book".equals(request.getParameter("action"))) {

        String msg = "error";
        Connection bconn = null;
        PreparedStatement bps = null;
        ResultSet brs = null;
        ApplicationDB bdao = null;
        try {
            bdao = new ApplicationDB();
            bconn = bdao.getConnection();

            int schedId = Integer.parseInt(request.getParameter("schedule_id"));

            // verify the schedule exists before inserting
            bps = bconn.prepareStatement(
                "SELECT schedule_id FROM Schedule WHERE schedule_id = ?");
            bps.setInt(1, schedId);
            brs = bps.executeQuery();
            if (!brs.next()) {
                msg = "noschedule";
            } else {
                brs.close();
                bps.close();
                bps = bconn.prepareStatement(
                    "INSERT INTO Reservation " +
                    "(username, schedule_id, reservation_date) " +
                    "VALUES (?, ?, NOW())");
                bps.setString(1, username);
                bps.setInt(2, schedId);
                bps.executeUpdate();
                msg = "booked";
            }
        } catch (NumberFormatException nfe) {
            msg = "invalid";
        } catch (Exception e) {
            msg = "error";
        } finally {
            try { if (brs != null) brs.close(); } catch (Exception ignore) {}
            try { if (bps != null) bps.close(); } catch (Exception ignore) {}
            try { if (bconn != null) bdao.closeConnection(bconn); } catch (Exception ignore) {}
        }
        // Post/Redirect/Get: refresh after booking re-runs the SEARCH,
        // not the INSERT
        response.sendRedirect("custschedule.jsp?" + qs + "&msg=" + msg);
        return;
    }

    // ---- map msg code to display text (whitelist, never echo raw param) ----
    String msgParam = request.getParameter("msg");
    String message = null;
    if ("booked".equals(msgParam)) {
        message = "Reservation booked! See My Reservations to view or cancel it.";
    } else if ("noschedule".equals(msgParam)) {
        message = "No such schedule.";
    } else if ("invalid".equals(msgParam)) {
        message = "Invalid input.";
    } else if ("error".equals(msgParam)) {
        message = "Could not book reservation.";
    }
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Search Train Schedules</title>
</head>
<body>
    <h1>Search Train Schedules</h1>
    <p>
        <a href="custhome.jsp">Home</a> |
        <a href="custreservations.jsp">My Reservations</a> |
        <a href="custforum.jsp">Forum</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= esc(message) %></b></p>
<%  } %>

<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    ApplicationDB dao = null;
    try {
        dao = new ApplicationDB();
        conn = dao.getConnection();

        // ---- station dropdown ----
        StringBuilder stationOpts = new StringBuilder(
            "<option value=\"\">-- any station --</option>");
        ps = conn.prepareStatement(
            "SELECT station_id, station_name FROM Station ORDER BY station_name");
        rs = ps.executeQuery();
        while (rs.next()) {
            int sid = rs.getInt("station_id");
            stationOpts.append("<option value=\"").append(sid).append("\"")
                       .append(sid == stationId ? " selected" : "")
                       .append(">").append(esc(rs.getString("station_name")))
                       .append("</option>");
        }
        rs.close();
        ps.close();
%>
    <form method="get" action="custschedule.jsp">
        Transit line:
        <input type="text" name="keyword" value="<%= esc(keyword) %>">
        Line serves station:
        <select name="station_id"><%= stationOpts %></select>
        Departure date:
        <input type="date" name="date" value="<%= esc(dateParam) %>">
        <input type="submit" value="Search">
        <a href="custschedule.jsp">Clear</a>
    </form>
    <br>

    <table border="1" cellpadding="5">
        <tr>
            <th><a href="custschedule.jsp?<%= qs %>&sort=line">Transit Line</a></th>
            <th>Train</th>
            <th>Station</th>
            <th><a href="custschedule.jsp?<%= qs %>&sort=dep">Departure</a></th>
            <th>Arrival</th>
            <th>Action</th>
        </tr>
<%
        // ---- main search query ----
        String sql =
            "SELECT sc.schedule_id, sc.train_id, tl.name AS line_name, " +
            "       s.station_name, ts.arrival_datetime, ts.departure_datetime " +
            "FROM Schedule sc " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
            "JOIN Station s ON ts.station_id = s.station_id " +
            "WHERE 1=1 ";
        if (!keyword.isEmpty()) {
            sql += "AND tl.name LIKE ? ";
        }
        if (stationId != -1) {
            // schedules on lines that SERVE this station (any of the
            // line's stops), not just schedules stopping there
            sql += "AND EXISTS (SELECT 1 FROM TrainStop ts2 " +
                   "            WHERE ts2.line_id = sc.line_id " +
                   "              AND ts2.station_id = ?) ";
        }
        if (!dateParam.isEmpty()) {
            sql += "AND DATE(ts.departure_datetime) = ? ";
        }
        sql += "ORDER BY " + orderBy;

        ps = conn.prepareStatement(sql);
        int idx = 1;
        if (!keyword.isEmpty()) {
            ps.setString(idx++, "%" + keyword + "%");
        }
        if (stationId != -1) {
            ps.setInt(idx++, stationId);
        }
        if (!dateParam.isEmpty()) {
            ps.setString(idx++, dateParam);
        }
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
%>
        <tr>
            <td><%= esc(rs.getString("line_name")) %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= esc(rs.getString("station_name")) %></td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getTimestamp("arrival_datetime") %></td>
            <td>
                <form method="post" action="custschedule.jsp?<%= qs %>">
                    <input type="hidden" name="action" value="book">
                    <input type="hidden" name="schedule_id"
                           value="<%= rs.getInt("schedule_id") %>">
                    <input type="submit" value="Reserve">
                </form>
            </td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="6">No schedules match your search.</td></tr>
<%
        }
    } catch (Exception e) {
%>
    <p>Error: <%= esc(e.getMessage()) %></p>
<%
    } finally {
        try { if (rs != null) rs.close(); } catch (Exception ignore) {}
        try { if (ps != null) ps.close(); } catch (Exception ignore) {}
        try { if (conn != null) dao.closeConnection(conn); } catch (Exception ignore) {}
    }
%>
    </table>
</body>
</html>
