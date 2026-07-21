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
    // ---- session check (employee/rep only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"employee".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String message = null;

    // ---- handle add / update / delete (POST only) ----
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String action = request.getParameter("action");
        Connection mconn = null;
        PreparedStatement mps = null;
        ResultSet mrs = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            mconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

            if ("add".equals(action) || "update".equals(action)) {
                int trainId = Integer.parseInt(request.getParameter("train_id"));
                int stopId = Integer.parseInt(request.getParameter("stop_id"));

                // derive line_id from the chosen stop -- keeps Schedule
                // consistent with its stop by construction
                mps = mconn.prepareStatement(
                    "SELECT line_id FROM TrainStop WHERE stop_id = ?");
                mps.setInt(1, stopId);
                mrs = mps.executeQuery();
                if (!mrs.next()) {
                    message = "No such stop.";
                } else {
                    int lineId = mrs.getInt("line_id");
                    mrs.close();
                    mps.close();

                    if ("add".equals(action)) {
                        mps = mconn.prepareStatement(
                            "INSERT INTO Schedule (line_id, train_id, stop_id) " +
                            "VALUES (?, ?, ?)");
                        mps.setInt(1, lineId);
                        mps.setInt(2, trainId);
                        mps.setInt(3, stopId);
                        mps.executeUpdate();
                        message = "Schedule added.";
                    } else {
                        int schedId = Integer.parseInt(
                            request.getParameter("schedule_id"));
                        mps = mconn.prepareStatement(
                            "UPDATE Schedule SET line_id = ?, train_id = ?, " +
                            "stop_id = ? WHERE schedule_id = ?");
                        mps.setInt(1, lineId);
                        mps.setInt(2, trainId);
                        mps.setInt(3, stopId);
                        mps.setInt(4, schedId);
                        int rows = mps.executeUpdate();
                        message = (rows > 0) ? "Schedule updated."
                                             : "No such schedule.";
                    }
                }

            } else if ("delete".equals(action)) {
                int schedId = Integer.parseInt(
                    request.getParameter("schedule_id"));
                mps = mconn.prepareStatement(
                    "DELETE FROM Schedule WHERE schedule_id = ?");
                mps.setInt(1, schedId);
                int rows = mps.executeUpdate();
                message = (rows > 0) ? "Schedule deleted."
                                     : "No such schedule.";
            }
        } catch (SQLIntegrityConstraintViolationException fk) {
            message = "Cannot delete: this schedule has reservations.";
        } catch (NumberFormatException nfe) {
            message = "Invalid input.";
        } catch (Exception e) {
            message = "Error: " + e.getMessage();
        } finally {
            if (mrs != null) mrs.close();
            if (mps != null) mps.close();
            if (mconn != null) mconn.close();
        }
    }

    // which schedule (if any) is being edited
    String editing = request.getParameter("edit");
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Manage Schedules</title>
</head>
<body>
    <h1>Manage Train Schedules</h1>
    <p>
        <a href="rephome.jsp">Home</a> |
        <a href="repforum.jsp">Forum</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= esc(message) %></b></p>
<%  } %>

<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        // ---- build the shared dropdown options once ----
        StringBuilder trainOpts = new StringBuilder();
        ps = conn.prepareStatement("SELECT train_id FROM Train ORDER BY train_id");
        rs = ps.executeQuery();
        while (rs.next()) {
            int t = rs.getInt("train_id");
            trainOpts.append("<option value=\"").append(t).append("\">Train ")
                     .append(t).append("</option>");
        }
        rs.close();
        ps.close();

        StringBuilder stopOpts = new StringBuilder();
        ps = conn.prepareStatement(
            "SELECT ts.stop_id, tl.name AS line_name, s.station_name, " +
            "       ts.departure_datetime " +
            "FROM TrainStop ts " +
            "JOIN TransitLine tl ON ts.line_id = tl.line_id " +
            "JOIN Station s ON ts.station_id = s.station_id " +
            "ORDER BY tl.name, ts.departure_datetime");
        rs = ps.executeQuery();
        while (rs.next()) {
            stopOpts.append("<option value=\"").append(rs.getInt("stop_id"))
                    .append("\">[").append(esc(rs.getString("line_name")))
                    .append("] ").append(esc(rs.getString("station_name")))
                    .append(" - dep ").append(rs.getTimestamp("departure_datetime"))
                    .append("</option>");
        }
        rs.close();
        ps.close();
%>
    <h3>Add New Schedule</h3>
    <form method="post" action="repschedule.jsp">
        <input type="hidden" name="action" value="add">
        Train: <select name="train_id"><%= trainOpts %></select>
        Stop: <select name="stop_id"><%= stopOpts %></select>
        <input type="submit" value="Add">
    </form>
    <p><i>The transit line is set automatically from the chosen stop.</i></p>
    <hr>

    <h3>Current Schedules</h3>
    <table border="1" cellpadding="5">
        <tr>
            <th>Schedule #</th><th>Transit Line</th><th>Train</th>
            <th>Station</th><th>Departure</th><th>Arrival</th>
            <th colspan="2">Actions</th>
        </tr>
<%
        ps = conn.prepareStatement(
            "SELECT sc.schedule_id, sc.train_id, tl.name AS line_name, " +
            "       s.station_name, ts.arrival_datetime, ts.departure_datetime " +
            "FROM Schedule sc " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
            "JOIN Station s ON ts.station_id = s.station_id " +
            "ORDER BY ts.departure_datetime");
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
            int schedId = rs.getInt("schedule_id");

            if (String.valueOf(schedId).equals(editing)) {
                // ---- inline edit row ----
%>
        <tr>
            <form method="post" action="repschedule.jsp">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="schedule_id" value="<%= schedId %>">
                <td><%= schedId %></td>
                <td colspan="2">
                    Train: <select name="train_id"><%= trainOpts %></select>
                </td>
                <td colspan="3">
                    Stop: <select name="stop_id"><%= stopOpts %></select>
                </td>
                <td colspan="2">
                    <input type="submit" value="Save">
                    <a href="repschedule.jsp">Cancel</a>
                </td>
            </form>
        </tr>
<%
            } else {
                // ---- normal row ----
%>
        <tr>
            <td><%= schedId %></td>
            <td><%= esc(rs.getString("line_name")) %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= esc(rs.getString("station_name")) %></td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><%= rs.getTimestamp("arrival_datetime") %></td>
            <td><a href="repschedule.jsp?edit=<%= schedId %>">Edit</a></td>
            <td>
                <form method="post" action="repschedule.jsp"
                      onsubmit="return window.confirm('Delete schedule #<%= schedId %>?');">
                    <input type="hidden" name="action" value="delete">
                    <input type="hidden" name="schedule_id" value="<%= schedId %>">
                    <input type="submit" value="Delete">
                </form>
            </td>
        </tr>
<%
            }
        }
        if (!any) {
%>
        <tr><td colspan="8">No schedules yet.</td></tr>
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
