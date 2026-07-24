<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="com.cs336.dbmstrainsproject.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }

    private Timestamp toTimestamp(String s) {
        if (s == null || s.trim().isEmpty()) return null;
        String v = s.trim().replace('T', ' ');
        if (v.length() == 16) v = v + ":00";
        try {
            return Timestamp.valueOf(v);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private String forInput(Timestamp t) {
        if (t == null) return "";
        String s = t.toString();
        if (s.length() >= 16) return s.substring(0, 16).replace(' ', 'T');
        return "";
    }
%>
<%
    // ---- session check (rep only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"rep".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String message = null;

    // ---- add / update / delete schedule ----
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String action = request.getParameter("action");
        ApplicationDB mdb = new ApplicationDB();
        Connection mconn = mdb.getConnection();
        PreparedStatement mps = null;
        ResultSet mrs = null;
        try {
            if ("add".equals(action) || "update".equals(action)) {
                int trainId = Integer.parseInt(request.getParameter("train_id"));
                int stopId = Integer.parseInt(request.getParameter("stop_id"));
                Timestamp dep = toTimestamp(request.getParameter("departure_time"));
                Timestamp arr = toTimestamp(request.getParameter("arrival_time"));
                String stopsDesc = request.getParameter("stops");
                if (stopsDesc != null && stopsDesc.trim().isEmpty()) stopsDesc = null;

                // line_id comes from the chosen stop so they always match
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
                            "INSERT INTO Schedule " +
                            "(line_id, train_id, stop_id, departure_time, arrival_time, stops) " +
                            "VALUES (?, ?, ?, ?, ?, ?)");
                        mps.setInt(1, lineId);
                        mps.setInt(2, trainId);
                        mps.setInt(3, stopId);
                        mps.setTimestamp(4, dep);
                        mps.setTimestamp(5, arr);
                        mps.setString(6, stopsDesc);
                        mps.executeUpdate();
                        message = "Schedule added.";
                    } else {
                        int schedId = Integer.parseInt(request.getParameter("schedule_id"));
                        mps = mconn.prepareStatement(
                            "UPDATE Schedule SET line_id = ?, train_id = ?, stop_id = ?, " +
                            "departure_time = ?, arrival_time = ?, stops = ? " +
                            "WHERE schedule_id = ?");
                        mps.setInt(1, lineId);
                        mps.setInt(2, trainId);
                        mps.setInt(3, stopId);
                        mps.setTimestamp(4, dep);
                        mps.setTimestamp(5, arr);
                        mps.setString(6, stopsDesc);
                        mps.setInt(7, schedId);
                        int rows = mps.executeUpdate();
                        message = (rows > 0) ? "Schedule updated." : "No such schedule.";
                    }
                }

            } else if ("delete".equals(action)) {
                int schedId = Integer.parseInt(request.getParameter("schedule_id"));
                mps = mconn.prepareStatement(
                    "DELETE FROM Schedule WHERE schedule_id = ?");
                mps.setInt(1, schedId);
                int rows = mps.executeUpdate();
                message = (rows > 0) ? "Schedule deleted." : "No such schedule.";
            }
        } catch (SQLIntegrityConstraintViolationException fk) {
            message = "Cannot delete schedule: it still has reservations.";
        } catch (NumberFormatException nfe) {
            message = "Invalid input.";
        } catch (Exception e) {
            message = "Error: " + e.getMessage();
        } finally {
            if (mrs != null) mrs.close();
            if (mps != null) mps.close();
            if (mconn != null) mdb.closeConnection(mconn);
        }
    }

    String editing = request.getParameter("edit");
    String stationParam = request.getParameter("station_id");
    String lineParam = request.getParameter("line_id");
    String dateParam = request.getParameter("travel_date");
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Manage Schedules</title>
</head>
<body>
    <h1>Train Schedules</h1>
    <p>
        <a href="representativehome.jsp">Home</a> |
        <a href="repforum.jsp">Customer Q&amp;A</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= esc(message) %></b></p>
<%  } %>

<%
    ApplicationDB db = new ApplicationDB();
    Connection conn = db.getConnection();
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        // ---- dropdown options reused in every row ----
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
        Departure: <input type="datetime-local" name="departure_time">
        Arrival: <input type="datetime-local" name="arrival_time">
        Stops: <input type="text" name="stops" maxlength="100">
        <input type="submit" value="Add">
    </form>
    <p><i>The transit line is set automatically from the chosen stop.</i></p>
    <hr>

    <h3>Current Schedules</h3>
    <table border="1" cellpadding="5">
        <tr>
            <th>Schedule #</th><th>Transit Line</th><th>Train</th>
            <th>Station</th><th>Departure</th><th>Arrival</th>
            <th>Stops</th><th colspan="2">Actions</th>
        </tr>
<%
        ps = conn.prepareStatement(
            "SELECT sc.schedule_id, sc.train_id, sc.stops, tl.name AS line_name, " +
            "       s.station_name, " +
            "       COALESCE(sc.departure_time, ts.departure_datetime) AS dep, " +
            "       COALESCE(sc.arrival_time, ts.arrival_datetime) AS arr " +
            "FROM Schedule sc " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
            "JOIN Station s ON ts.station_id = s.station_id " +
            "ORDER BY COALESCE(sc.departure_time, ts.departure_datetime)");
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
            int schedId = rs.getInt("schedule_id");

            if (String.valueOf(schedId).equals(editing)) {
                // inline edit row
%>
        <tr>
            <form method="post" action="repschedule.jsp">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="schedule_id" value="<%= schedId %>">
                <td><%= schedId %></td>
                <td colspan="2"><select name="train_id"><%= trainOpts %></select></td>
                <td><select name="stop_id"><%= stopOpts %></select></td>
                <td><input type="datetime-local" name="departure_time"
                        value="<%= forInput(rs.getTimestamp("dep")) %>"></td>
                <td><input type="datetime-local" name="arrival_time"
                        value="<%= forInput(rs.getTimestamp("arr")) %>"></td>
                <td><input type="text" name="stops" maxlength="100"
                        value="<%= esc(rs.getString("stops")) %>"></td>
                <td colspan="2">
                    <input type="submit" value="Save">
                    <a href="repschedule.jsp">Cancel</a>
                </td>
            </form>
        </tr>
<%
            } else {
%>
        <tr>
            <td><%= schedId %></td>
            <td><%= esc(rs.getString("line_name")) %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= esc(rs.getString("station_name")) %></td>
            <td><%= rs.getTimestamp("dep") == null ? "-" : rs.getTimestamp("dep") %></td>
            <td><%= rs.getTimestamp("arr") == null ? "-" : rs.getTimestamp("arr") %></td>
            <td><%= esc(rs.getString("stops")) %></td>
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
        <tr><td colspan="9">No schedules yet.</td></tr>
<%
        }
        rs.close();
        ps.close();
%>
    </table>
    <hr>

    <h3>Schedules for a Station (as Origin / Destination)</h3>
    <form method="get" action="repschedule.jsp">
        Station:
        <select name="station_id">
            <option value="">-- choose a station --</option>
<%
        ps = conn.prepareStatement(
            "SELECT station_id, station_name, city, state FROM Station ORDER BY station_name");
        rs = ps.executeQuery();
        while (rs.next()) {
            String sid = String.valueOf(rs.getInt("station_id"));
%>
            <option value="<%= sid %>" <%= sid.equals(stationParam) ? "selected" : "" %>>
                <%= esc(rs.getString("station_name")) %>
                (<%= esc(rs.getString("city")) %>, <%= esc(rs.getString("state")) %>)</option>
<%
        }
        rs.close();
        ps.close();
%>
        </select>
        <input type="submit" value="Search">
    </form>
<%
        if (stationParam != null && !stationParam.trim().isEmpty()) {
            int stationId = Integer.parseInt(stationParam.trim());
%>
    <table border="1" cellpadding="5">
        <tr>
            <th>Schedule #</th><th>Transit Line</th><th>Train</th>
            <th>Station Is</th><th>Line Origin</th><th>Line Destination</th>
            <th>This Stop</th><th>Departure</th><th>Arrival</th><th>Fare</th>
        </tr>
<%
            // origin = line's earliest departing stop, destination = latest arriving stop
            ps = conn.prepareStatement(
                "SELECT sc.schedule_id, sc.train_id, tl.name AS line_name, tl.fare, " +
                "       og.station_name AS origin_name, dg.station_name AS dest_name, " +
                "       stn.station_name AS stop_name, " +
                "       COALESCE(sc.departure_time, ts.departure_datetime) AS dep, " +
                "       COALESCE(sc.arrival_time, ts.arrival_datetime) AS arr, " +
                "       CASE WHEN ost.station_id = ? AND dst.station_id = ? THEN 'Origin & Destination' " +
                "            WHEN ost.station_id = ? THEN 'Origin' ELSE 'Destination' END AS station_role " +
                "FROM Schedule sc " +
                "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
                "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
                "JOIN Station stn ON ts.station_id = stn.station_id " +
                "JOIN TrainStop ost ON ost.stop_id = (SELECT t.stop_id FROM TrainStop t " +
                "     WHERE t.line_id = tl.line_id " +
                "     ORDER BY (t.departure_datetime IS NULL), t.departure_datetime, t.stop_id LIMIT 1) " +
                "JOIN TrainStop dst ON dst.stop_id = (SELECT t.stop_id FROM TrainStop t " +
                "     WHERE t.line_id = tl.line_id " +
                "     ORDER BY (t.arrival_datetime IS NULL), t.arrival_datetime DESC, t.stop_id DESC LIMIT 1) " +
                "JOIN Station og ON ost.station_id = og.station_id " +
                "JOIN Station dg ON dst.station_id = dg.station_id " +
                "WHERE ost.station_id = ? OR dst.station_id = ? " +
                "ORDER BY tl.name, dep");
            ps.setInt(1, stationId);
            ps.setInt(2, stationId);
            ps.setInt(3, stationId);
            ps.setInt(4, stationId);
            ps.setInt(5, stationId);
            rs = ps.executeQuery();
            boolean found = false;
            while (rs.next()) {
                found = true;
%>
        <tr>
            <td><%= rs.getInt("schedule_id") %></td>
            <td><%= esc(rs.getString("line_name")) %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><b><%= esc(rs.getString("station_role")) %></b></td>
            <td><%= esc(rs.getString("origin_name")) %></td>
            <td><%= esc(rs.getString("dest_name")) %></td>
            <td><%= esc(rs.getString("stop_name")) %></td>
            <td><%= rs.getTimestamp("dep") == null ? "-" : rs.getTimestamp("dep") %></td>
            <td><%= rs.getTimestamp("arr") == null ? "-" : rs.getTimestamp("arr") %></td>
            <td>$<%= rs.getInt("fare") %></td>
        </tr>
<%
            }
            if (!found) {
%>
        <tr><td colspan="10">No schedules found for that station.</td></tr>
<%
            }
            rs.close();
            ps.close();
%>
    </table>
<%
        }
%>
    <hr>

    <h3>Customers with Reservations on a Transit Line and Date</h3>
    <form method="get" action="repschedule.jsp">
        Transit line:
        <select name="line_id">
            <option value="">-- choose a transit line --</option>
<%
        ps = conn.prepareStatement("SELECT line_id, name FROM TransitLine ORDER BY name");
        rs = ps.executeQuery();
        while (rs.next()) {
            String lid = String.valueOf(rs.getInt("line_id"));
%>
            <option value="<%= lid %>" <%= lid.equals(lineParam) ? "selected" : "" %>>
                <%= esc(rs.getString("name")) %></option>
<%
        }
        rs.close();
        ps.close();
%>
        </select>
        Date: <input type="date" name="travel_date"
            value="<%= dateParam == null ? "" : esc(dateParam) %>">
        <input type="submit" value="Search">
    </form>
<%
        if (lineParam != null && !lineParam.trim().isEmpty()
                && dateParam != null && !dateParam.trim().isEmpty()) {
            int lineId = Integer.parseInt(lineParam.trim());
%>
    <table border="1" cellpadding="5">
        <tr>
            <th>Customer</th><th>Username</th><th>Email</th>
            <th>Reservation #</th><th>Train</th><th>Boards At</th>
            <th>Departure</th><th>Trip Type</th><th>Passenger Type</th>
        </tr>
<%
            ps = conn.prepareStatement(
                "SELECT p.username, p.first_name, p.last_name, p.email, " +
                "       r.reservation_id, r.trip_type, r.passenger_type, " +
                "       sc.train_id, stn.station_name AS boarding_stop, " +
                "       COALESCE(sc.departure_time, ts.departure_datetime) AS dep " +
                "FROM Reservation r " +
                "JOIN Passenger p ON r.passenger_username = p.username " +
                "JOIN Schedule sc ON r.schedule_id = sc.schedule_id " +
                "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
                "JOIN TrainStop ts ON r.stop_id = ts.stop_id " +
                "JOIN Station stn ON ts.station_id = stn.station_id " +
                "WHERE tl.line_id = ? " +
                "AND DATE(COALESCE(sc.departure_time, ts.departure_datetime)) = ? " +
                "ORDER BY p.last_name, p.first_name, r.reservation_id");
            ps.setInt(1, lineId);
            ps.setString(2, dateParam.trim());
            rs = ps.executeQuery();
            boolean found = false;
            while (rs.next()) {
                found = true;
%>
        <tr>
            <td><%= esc(rs.getString("last_name")) %>, <%= esc(rs.getString("first_name")) %></td>
            <td><%= esc(rs.getString("username")) %></td>
            <td><%= esc(rs.getString("email")) %></td>
            <td><%= rs.getInt("reservation_id") %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= esc(rs.getString("boarding_stop")) %></td>
            <td><%= rs.getTimestamp("dep") == null ? "-" : rs.getTimestamp("dep") %></td>
            <td><%= esc(rs.getString("trip_type")) %></td>
            <td><%= esc(rs.getString("passenger_type")) %></td>
        </tr>
<%
            }
            if (!found) {
%>
        <tr><td colspan="9">No customers have reservations on that line for that date.</td></tr>
<%
            }
            rs.close();
            ps.close();
%>
    </table>
<%
        }
    } catch (Exception e) {
%>
    <p>Error: <%= esc(e.getMessage()) %></p>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (conn != null) db.closeConnection(conn);
    }
%>
</body>
</html>
