<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="java.net.URLEncoder" %>
<%
    // ---- session check (passenger only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"passenger".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    // ---- search params ----
    String origin = request.getParameter("origin");
    String dest = request.getParameter("dest");
    String travelDate = request.getParameter("travel_date"); // yyyy-MM-dd
    if (origin == null) origin = "";
    if (dest == null) dest = "";
    if (travelDate == null) travelDate = "";

    // ---- sort param: WHITELIST ONLY, never concatenate user input ----
    String sort = request.getParameter("sort");
    String orderBy;
    if ("arrival".equals(sort))        orderBy = "ts.arrival_datetime";
    else if ("fare".equals(sort))      orderBy = "tl.fare";
    else if ("line".equals(sort))      orderBy = "tl.name";
    else if ("station".equals(sort))   orderBy = "s.station_name";
    else { sort = "departure";         orderBy = "ts.departure_datetime"; }

    // base query string for building sort links (preserves search)
    String qs = "origin=" + URLEncoder.encode(origin, "UTF-8")
              + "&dest=" + URLEncoder.encode(dest, "UTF-8")
              + "&travel_date=" + URLEncoder.encode(travelDate, "UTF-8");

    // schedule whose stops are being viewed (null = none)
    String stopsFor = request.getParameter("stops_for");
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

    <form method="get" action="custschedule.jsp">
        Origin (station or city):
        <input type="text" name="origin" value="<%= origin %>">
        Destination:
        <input type="text" name="dest" value="<%= dest %>">
        Date:
        <input type="date" name="travel_date" value="<%= travelDate %>">
        <input type="submit" value="Search">
        <a href="custschedule.jsp">Clear</a>
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

        // ---- stop listing for one schedule (all stops on its line) ----
        if (stopsFor != null) {
%>
    <div style="border:1px solid black; padding:10px; margin-bottom:15px;">
        <h3>Stops for Schedule #<%= stopsFor %></h3>
        <table border="1" cellpadding="5">
            <tr><th>Station</th><th>City</th><th>State</th>
                <th>Arrival</th><th>Departure</th></tr>
<%
            ps = conn.prepareStatement(
                "SELECT st.station_name, st.city, st.state, " +
                "       t.arrival_datetime, t.departure_datetime " +
                "FROM Schedule sc " +
                "JOIN TrainStop t ON t.line_id = sc.line_id " +
                "JOIN Station st ON t.station_id = st.station_id " +
                "WHERE sc.schedule_id = ? " +
                "ORDER BY t.departure_datetime");
            ps.setInt(1, Integer.parseInt(stopsFor));
            rs = ps.executeQuery();
            boolean anyStop = false;
            while (rs.next()) {
                anyStop = true;
%>
            <tr>
                <td><%= rs.getString("station_name") %></td>
                <td><%= rs.getString("city") %></td>
                <td><%= rs.getString("state") %></td>
                <td><%= rs.getTimestamp("arrival_datetime") %></td>
                <td><%= rs.getTimestamp("departure_datetime") %></td>
            </tr>
<%
            }
            if (!anyStop) {
%>
            <tr><td colspan="5">No stops found for this schedule.</td></tr>
<%
            }
            rs.close();
            ps.close();
%>
        </table>
        <a href="custschedule.jsp?<%= qs %>&sort=<%= sort %>">Close</a>
    </div>
<%
        }

        // ---- main search query ----
        String sql =
            "SELECT sc.schedule_id, tl.name AS line_name, tl.fare, sc.train_id, " +
            "       s.station_name, s.city, s.state, " +
            "       ts.arrival_datetime, ts.departure_datetime " +
            "FROM Schedule sc " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts   ON sc.stop_id = ts.stop_id " +
            "JOIN Station s      ON ts.station_id = s.station_id " +
            "WHERE 1=1 ";

        if (!origin.isEmpty() && !dest.isEmpty()) {
            // line must serve BOTH stations, origin before destination
            sql += "AND EXISTS (" +
                   "  SELECT 1 FROM TrainStop o " +
                   "  JOIN Station os ON o.station_id = os.station_id, " +
                   "       TrainStop d " +
                   "  JOIN Station ds ON d.station_id = ds.station_id " +
                   "  WHERE o.line_id = sc.line_id AND d.line_id = sc.line_id " +
                   "    AND (os.station_name LIKE ? OR os.city LIKE ?) " +
                   "    AND (ds.station_name LIKE ? OR ds.city LIKE ?) " +
                   "    AND o.departure_datetime < d.arrival_datetime) ";
        } else if (!origin.isEmpty()) {
            sql += "AND EXISTS (" +
                   "  SELECT 1 FROM TrainStop o " +
                   "  JOIN Station os ON o.station_id = os.station_id " +
                   "  WHERE o.line_id = sc.line_id " +
                   "    AND (os.station_name LIKE ? OR os.city LIKE ?)) ";
        } else if (!dest.isEmpty()) {
            sql += "AND EXISTS (" +
                   "  SELECT 1 FROM TrainStop d " +
                   "  JOIN Station ds ON d.station_id = ds.station_id " +
                   "  WHERE d.line_id = sc.line_id " +
                   "    AND (ds.station_name LIKE ? OR ds.city LIKE ?)) ";
        }
        if (!travelDate.isEmpty()) {
            sql += "AND DATE(ts.departure_datetime) = ? ";
        }
        sql += "ORDER BY " + orderBy;   // safe: whitelisted above

        ps = conn.prepareStatement(sql);
        int idx = 1;
        if (!origin.isEmpty() && !dest.isEmpty()) {
            String ol = "%" + origin + "%", dl = "%" + dest + "%";
            ps.setString(idx++, ol); ps.setString(idx++, ol);
            ps.setString(idx++, dl); ps.setString(idx++, dl);
        } else if (!origin.isEmpty()) {
            String ol = "%" + origin + "%";
            ps.setString(idx++, ol); ps.setString(idx++, ol);
        } else if (!dest.isEmpty()) {
            String dl = "%" + dest + "%";
            ps.setString(idx++, dl); ps.setString(idx++, dl);
        }
        if (!travelDate.isEmpty()) {
            ps.setString(idx++, travelDate);
        }
        rs = ps.executeQuery();
%>
    <table border="1" cellpadding="5">
        <tr>
            <th>Schedule #</th>
            <th><a href="custschedule.jsp?<%= qs %>&sort=line">Transit Line</a></th>
            <th>Train</th>
            <th><a href="custschedule.jsp?<%= qs %>&sort=station">Station</a></th>
            <th><a href="custschedule.jsp?<%= qs %>&sort=departure">Departure</a></th>
            <th><a href="custschedule.jsp?<%= qs %>&sort=arrival">Arrival</a></th>
            <th><a href="custschedule.jsp?<%= qs %>&sort=fare">Base Fare</a></th>
            <th></th>
        </tr>
<%
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
                <a href="custschedule.jsp?<%= qs %>&sort=<%= sort %>&stops_for=<%= rs.getInt("schedule_id") %>">Stops</a>
            </td>
        </tr>
<%
        }
        if (!any) {
%>
        <tr><td colspan="8">No schedules match your search.</td></tr>
<%
        }
    } catch (Exception e) {
%>
    <p>Error: <%= e.getMessage() %></p>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (conn != null) conn.close();
    }
%>
    </table>
    <p><i>Column headers are clickable to sort. To book one of these,
        go to <a href="custreservation.jsp">My Reservations</a>.</i></p>
</body>
</html>
